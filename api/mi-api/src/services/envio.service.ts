import { AppDataSource } from "../config/data-source.js";
import { Envio } from "../entity/Envio.js";
import { Paquete } from "../entity/Paquete.js";
import { HistorialRastreo, ESTADOS_EVENTO } from "../entity/HistorialRastreo.js";
import { clienteRepository } from "../repository/ClienteRepository.js";
import { direccionRepository } from "../repository/DireccionRepository.js";
import { almacenRepository } from "../repository/AlmacenRepository.js";
import { envioRepository } from "../repository/EnvioRepository.js";
import { historialRastreoRepository } from "../repository/HistorialRastreoRepository.js";
import { auditoriaEnvioRepository } from "../repository/AuditoriaEnvioRepository.js";
import { HttpError } from "../utils/http-error.js";
import {
    validarId, validarNumero, validarTexto, validarTextoOpcional, validarEnum, validarFechaOpcional,
} from "../utils/validaciones.js";

const ESTADOS_CERRADOS = ["ENTREGADO", "CANCELADO"];

// ---------------------------------------------------------------------
// Endpoint 1: POST /api/envios
// Crea el envío y sus paquetes iniciales en UNA transacción (QueryRunner).
// Si algún paquete trae almacenId, el trigger before_insert_paquete_almacen
// valida la capacidad; si falla, se hace rollback de todo el envío.
// ---------------------------------------------------------------------
export const crearEnvio = async (body: any) => {
    const remitenteId = validarId(body?.remitenteId, "remitenteId");
    const destinatarioId = validarId(body?.destinatarioId, "destinatarioId");
    const direccionOrigenId = validarId(body?.direccionOrigenId, "direccionOrigenId");
    const direccionDestinoId = validarId(body?.direccionDestinoId, "direccionDestinoId");
    const costoTotal = validarNumero(body?.costoTotal, "costoTotal", true);

    if (!Array.isArray(body?.paquetes) || body.paquetes.length === 0) {
        throw new HttpError(400, "paquetes debe ser un arreglo con al menos un paquete");
    }

    const paquetes = body.paquetes.map((p: any, i: number) => ({
        pesoKg: validarNumero(p?.pesoKg, `paquetes[${i}].pesoKg`),
        largoCm: validarNumero(p?.largoCm, `paquetes[${i}].largoCm`),
        anchoCm: validarNumero(p?.anchoCm, `paquetes[${i}].anchoCm`),
        altoCm: validarNumero(p?.altoCm, `paquetes[${i}].altoCm`),
        contenido: validarTexto(p?.contenido, `paquetes[${i}].contenido`, 200),
        almacenId: p?.almacenId === undefined || p?.almacenId === null
            ? null
            : validarId(p.almacenId, `paquetes[${i}].almacenId`),
    }));

    // Validaciones de negocio
    const remitente = await clienteRepository.findById(remitenteId);
    if (!remitente) throw new HttpError(404, "El remitente no existe");
    if (remitente.estado !== "ACTIVO") throw new HttpError(400, "El remitente está INACTIVO y no puede registrar envíos");

    const destinatario = await clienteRepository.findById(destinatarioId);
    if (!destinatario) throw new HttpError(404, "El destinatario no existe");

    const origen = await direccionRepository.findById(direccionOrigenId);
    if (!origen || origen.clienteId !== remitenteId || origen.tipo !== "ORIGEN") {
        throw new HttpError(400, "direccionOrigenId debe ser una dirección de tipo ORIGEN del remitente");
    }

    const destino = await direccionRepository.findById(direccionDestinoId);
    if (!destino || destino.clienteId !== destinatarioId || destino.tipo !== "DESTINO") {
        throw new HttpError(400, "direccionDestinoId debe ser una dirección de tipo DESTINO del destinatario");
    }

    for (const p of paquetes) {
        if (p.almacenId !== null && !(await almacenRepository.findById(p.almacenId))) {
            throw new HttpError(404, `El almacén ${p.almacenId} no existe`);
        }
    }

    // Transacción con QueryRunner
    const queryRunner = AppDataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
        const envio = queryRunner.manager.create(Envio, {
            remitenteId,
            destinatarioId,
            direccionOrigenId,
            direccionDestinoId,
            costoTotal,
            estado: "REGISTRADO",
        });
        await queryRunner.manager.save(envio);

        // Uno por uno para que el trigger evalúe cada paquete
        for (const p of paquetes) {
            const paquete = queryRunner.manager.create(Paquete, { ...p, envioId: envio.envioId });
            await queryRunner.manager.save(paquete);
        }

        // Primer evento de rastreo
        const rastreo = queryRunner.manager.create(HistorialRastreo, {
            envioId: envio.envioId,
            ubicacionActual: `${origen.ciudad}, ${origen.entidadFederativa}`,
            estadoEvento: "REGISTRADO",
            observaciones: "Envío registrado vía API",
        });
        await queryRunner.manager.save(rastreo);

        await queryRunner.commitTransaction();
        return await envioRepository.findById(envio.envioId);
    } catch (error) {
        await queryRunner.rollbackTransaction();
        throw error;
    } finally {
        await queryRunner.release();
    }
};

// ---------------------------------------------------------------------
// Endpoint 2: PUT /api/envios/:id/costo
// Actualiza costo_total -> dispara after_update_envio_costo.
// Se usa un QueryRunner para que SET @usuario_app y el UPDATE viajen por la
// MISMA conexión; así el trigger guarda el usuario que hizo el cambio.
// ---------------------------------------------------------------------
export const actualizarCosto = async (idParam: unknown, body: any) => {
    const envioId = validarId(idParam, "id");
    const costoTotal = validarNumero(body?.costoTotal, "costoTotal", true);
    const usuario = validarTextoOpcional(body?.usuario, "usuario", 100);

    const envio = await envioRepository.findSimple(envioId);
    if (!envio) throw new HttpError(404, "Envío no encontrado");
    if (envio.estado === "CANCELADO") throw new HttpError(400, "No se puede modificar el costo de un envío CANCELADO");

    const costoAnterior = envio.costoTotal;

    const queryRunner = AppDataSource.createQueryRunner();
    await queryRunner.connect();

    try {
        await queryRunner.startTransaction();
        await queryRunner.query("SET @usuario_app = ?", [usuario]);
        await queryRunner.manager.update(Envio, { envioId }, { costoTotal });
        await queryRunner.commitTransaction();
    } catch (error) {
        if (queryRunner.isTransactionActive) await queryRunner.rollbackTransaction();
        throw error;
    } finally {
        // Limpia la variable para que no la herede otra petición que reutilice la conexión del pool
        await queryRunner.query("SET @usuario_app = NULL").catch(() => undefined);
        await queryRunner.release();
    }

    const cambio = costoAnterior !== costoTotal;
    return {
        envio: await envioRepository.findSimple(envioId),
        auditoria: cambio ? await auditoriaEnvioRepository.findUltimaByEnvio(envioId) : null,
        cambio,
    };
};

// ---------------------------------------------------------------------
// Endpoint 4: POST /api/envios/:id/rastreo
// Inserta en historial_rastreo -> dispara after_insert_historial_rastreo,
// que pone el envío en ENTREGADO cuando estadoEvento = 'ENTREGADO'.
// ---------------------------------------------------------------------
export const registrarRastreo = async (idParam: unknown, body: any) => {
    const envioId = validarId(idParam, "id");
    const ubicacionActual = validarTexto(body?.ubicacionActual, "ubicacionActual", 150);
    const estadoEvento = validarEnum(body?.estadoEvento, "estadoEvento", ESTADOS_EVENTO);
    const observaciones = validarTextoOpcional(body?.observaciones, "observaciones", 255);
    const fecha = validarFechaOpcional(body?.fecha, "fecha");

    const envio = await envioRepository.findSimple(envioId);
    if (!envio) throw new HttpError(404, "Envío no encontrado");
    if (ESTADOS_CERRADOS.includes(envio.estado)) {
        throw new HttpError(400, `El envío ya está ${envio.estado}; no admite más eventos de rastreo`);
    }

    const estadoAnterior = envio.estado;

    const rastreo = await historialRastreoRepository.create({
        envioId,
        ubicacionActual,
        estadoEvento,
        observaciones,
        ...(fecha ? { fecha } : {}),
    });

    // Se vuelve a leer el envío para mostrar el cambio que hizo el trigger
    const envioActualizado = await envioRepository.findSimple(envioId);

    return {
        rastreo,
        envio: {
            envioId,
            estadoAnterior,
            estadoActual: envioActualizado?.estado,
            fechaEntrega: envioActualizado?.fechaEntrega ?? null,
        },
    };
};

// ---------------------------------------------------------------------
// Endpoint 5: GET /api/envios  (envíos activos, createQueryBuilder)
// ---------------------------------------------------------------------
export const listarEnviosActivos = async () => {
    return await envioRepository.findActivos();
};

// GET /api/envios/:id (apoyo para revisar el resultado de los demás endpoints)
export const obtenerEnvio = async (idParam: unknown) => {
    const envioId = validarId(idParam, "id");
    const envio = await envioRepository.findById(envioId);
    if (!envio) throw new HttpError(404, "Envío no encontrado");
    return {
        ...envio,
        auditorias: await auditoriaEnvioRepository.findByEnvio(envioId),
    };
};
