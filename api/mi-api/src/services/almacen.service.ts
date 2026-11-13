import { almacenRepository } from "../repository/AlmacenRepository.js";
import { envioRepository } from "../repository/EnvioRepository.js";
import { paqueteRepository } from "../repository/PaqueteRepository.js";
import { HttpError } from "../utils/http-error.js";
import { validarId, validarNumero, validarTexto } from "../utils/validaciones.js";

// ---------------------------------------------------------------------
// Endpoint 3: POST /api/almacenes/:id/paquetes
// Inserta un paquete en el almacén -> dispara before_insert_paquete_almacen.
// Si el almacén está lleno, MySQL lanza SIGNAL SQLSTATE '45000'; el error
// sube al controlador, que lo traduce a HTTP 400.
// ---------------------------------------------------------------------
export const asignarPaquete = async (idParam: unknown, body: any) => {
    const almacenId = validarId(idParam, "id");
    const envioId = validarId(body?.envioId, "envioId");
    const pesoKg = validarNumero(body?.pesoKg, "pesoKg");
    const largoCm = validarNumero(body?.largoCm, "largoCm");
    const anchoCm = validarNumero(body?.anchoCm, "anchoCm");
    const altoCm = validarNumero(body?.altoCm, "altoCm");
    const contenido = validarTexto(body?.contenido, "contenido", 200);

    const almacen = await almacenRepository.findById(almacenId);
    if (!almacen) throw new HttpError(404, "Almacén no encontrado");

    const envio = await envioRepository.findSimple(envioId);
    if (!envio) throw new HttpError(404, "Envío no encontrado");
    if (envio.estado === "ENTREGADO" || envio.estado === "CANCELADO") {
        throw new HttpError(400, `No se pueden agregar paquetes a un envío ${envio.estado}`);
    }

    // INSERT -> trigger before_insert_paquete_almacen
    const paquete = await paqueteRepository.create({
        envioId, almacenId, pesoKg, largoCm, anchoCm, altoCm, contenido,
    });

    const ocupados = await almacenRepository.contarOcupados(almacenId);

    return {
        paquete,
        almacen: {
            almacenId: almacen.almacenId,
            nombre: almacen.nombre,
            capacidadMaxima: almacen.capacidadMaxima,
            ocupados,
            disponibles: almacen.capacidadMaxima - ocupados,
        },
    };
};
