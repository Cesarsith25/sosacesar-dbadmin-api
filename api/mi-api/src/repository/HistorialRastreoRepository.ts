import { AppDataSource } from "../config/data-source.js";
import { HistorialRastreo } from "../entity/HistorialRastreo.js";

export class HistorialRastreoRepository {
    private repository = AppDataSource.getRepository(HistorialRastreo);

    async findByEnvio(envioId: number): Promise<HistorialRastreo[]> {
        return await this.repository.find({
            where: { envioId },
            order: { fecha: "ASC", rastreoId: "ASC" },
        });
    }

    /** INSERT en historial_rastreo -> dispara after_insert_historial_rastreo. */
    async create(rastreoData: Partial<HistorialRastreo>): Promise<HistorialRastreo> {
        const rastreo = this.repository.create(rastreoData);
        const guardado = await this.repository.save(rastreo);
        // Se recarga para obtener la fecha asignada por MySQL (DEFAULT CURRENT_TIMESTAMP)
        return (await this.repository.findOneBy({ rastreoId: guardado.rastreoId })) ?? guardado;
    }
}

export const historialRastreoRepository = new HistorialRastreoRepository();
