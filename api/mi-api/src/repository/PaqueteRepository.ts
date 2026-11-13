import { AppDataSource } from "../config/data-source.js";
import { Paquete } from "../entity/Paquete.js";

export class PaqueteRepository {
    private repository = AppDataSource.getRepository(Paquete);

    async findById(id: number): Promise<Paquete | null> {
        return await this.repository.findOne({
            where: { paqueteId: id },
            relations: { almacen: true },
        });
    }

    async findByEnvio(envioId: number): Promise<Paquete[]> {
        return await this.repository.find({ where: { envioId }, relations: { almacen: true } });
    }

    /** INSERT en paquetes -> dispara before_insert_paquete_almacen. */
    async create(paqueteData: Partial<Paquete>): Promise<Paquete> {
        const paquete = this.repository.create(paqueteData);
        return await this.repository.save(paquete);
    }
}

export const paqueteRepository = new PaqueteRepository();
