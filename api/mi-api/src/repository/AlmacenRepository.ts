import { AppDataSource } from "../config/data-source.js";
import { Almacen } from "../entity/Almacen.js";
import { Paquete } from "../entity/Paquete.js";

export class AlmacenRepository {
    private repository = AppDataSource.getRepository(Almacen);

    async findAll(): Promise<Almacen[]> {
        return await this.repository.find({ order: { almacenId: "ASC" } });
    }

    async findById(id: number): Promise<Almacen | null> {
        return await this.repository.findOne({ where: { almacenId: id } });
    }

    /**
     * Paquetes que ocupan lugar en el almacén: los de envíos activos
     * (mismo criterio que usa el trigger before_insert_paquete_almacen).
     */
    async contarOcupados(almacenId: number): Promise<number> {
        return await AppDataSource.getRepository(Paquete)
            .createQueryBuilder("paquete")
            .innerJoin("paquete.envio", "envio")
            .where("paquete.almacenId = :almacenId", { almacenId })
            .andWhere("envio.estado IN (:...estados)", { estados: ["REGISTRADO", "EN_TRANSITO"] })
            .getCount();
    }
}

export const almacenRepository = new AlmacenRepository();
