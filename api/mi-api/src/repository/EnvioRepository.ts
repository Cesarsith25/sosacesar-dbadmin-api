import { AppDataSource } from "../config/data-source.js";
import { Envio } from "../entity/Envio.js";

export class EnvioRepository {
    private repository = AppDataSource.getRepository(Envio);

    /**
     * Envíos activos (REGISTRADO / EN_TRANSITO) con cliente, direcciones y paquetes.
     * Usa createQueryBuilder.
     */
    async findActivos(): Promise<Envio[]> {
        return await this.repository
            .createQueryBuilder("envio")
            .innerJoinAndSelect("envio.remitente", "remitente")
            .innerJoinAndSelect("envio.destinatario", "destinatario")
            .innerJoinAndSelect("envio.direccionOrigen", "origen")
            .innerJoinAndSelect("envio.direccionDestino", "destino")
            .leftJoinAndSelect("envio.paquetes", "paquete")
            .leftJoinAndSelect("paquete.almacen", "almacen")
            .where("envio.estado IN (:...estados)", { estados: ["REGISTRADO", "EN_TRANSITO"] })
            .orderBy("envio.fechaRegistro", "DESC")
            .addOrderBy("paquete.paqueteId", "ASC")
            .getMany();
    }

    async findById(id: number): Promise<Envio | null> {
        return await this.repository.findOne({
            where: { envioId: id },
            relations: {
                remitente: true,
                destinatario: true,
                direccionOrigen: true,
                direccionDestino: true,
                paquetes: { almacen: true },
                historial: true,
            },
            order: { paquetes: { paqueteId: "ASC" }, historial: { fecha: "ASC", rastreoId: "ASC" } },
        });
    }

    /** Solo la fila de envios, sin relaciones (para validaciones rápidas). */
    async findSimple(id: number): Promise<Envio | null> {
        return await this.repository.findOne({ where: { envioId: id } });
    }

    /**
     * Historial de envíos donde el cliente es remitente O destinatario.
     * Usa Repository.find() con un arreglo en where (OR).
     */
    async findByCliente(clienteId: number): Promise<Envio[]> {
        return await this.repository.find({
            where: [{ remitenteId: clienteId }, { destinatarioId: clienteId }],
            relations: { remitente: true, destinatario: true, paquetes: true },
            order: { fechaRegistro: "DESC", paquetes: { paqueteId: "ASC" } },
        });
    }
}

export const envioRepository = new EnvioRepository();
