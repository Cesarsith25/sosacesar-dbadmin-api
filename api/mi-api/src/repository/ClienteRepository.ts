import { AppDataSource } from "../config/data-source.js";
import { Cliente } from "../entity/Cliente.js";

export class ClienteRepository {
    private repository = AppDataSource.getRepository(Cliente);

    async findAll(): Promise<Cliente[]> {
        return await this.repository.find({ order: { nombre: "ASC" } });
    }

    async findById(id: number): Promise<Cliente | null> {
        return await this.repository.findOne({
            where: { clienteId: id },
        });
    }
}

export const clienteRepository = new ClienteRepository();
