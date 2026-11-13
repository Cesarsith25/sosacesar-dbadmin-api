import { AppDataSource } from "../config/data-source.js";
import { Direccion } from "../entity/Direccion.js";

export class DireccionRepository {
    private repository = AppDataSource.getRepository(Direccion);

    async findById(id: number): Promise<Direccion | null> {
        return await this.repository.findOne({ where: { direccionId: id } });
    }

    async findByCliente(clienteId: number): Promise<Direccion[]> {
        return await this.repository.find({ where: { clienteId } });
    }
}

export const direccionRepository = new DireccionRepository();
