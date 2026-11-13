import { AppDataSource } from "../config/data-source.js";
import { AuditoriaEnvio } from "../entity/AuditoriaEnvio.js";

export class AuditoriaEnvioRepository {
    private repository = AppDataSource.getRepository(AuditoriaEnvio);

    async findByEnvio(envioId: number): Promise<AuditoriaEnvio[]> {
        return await this.repository.find({
            where: { envioId },
            order: { auditoriaId: "DESC" },
        });
    }

    /** Último registro que dejó el trigger after_update_envio_costo. */
    async findUltimaByEnvio(envioId: number): Promise<AuditoriaEnvio | null> {
        return await this.repository.findOne({
            where: { envioId },
            order: { auditoriaId: "DESC" },
        });
    }
}

export const auditoriaEnvioRepository = new AuditoriaEnvioRepository();
