import { clienteRepository } from "../repository/ClienteRepository.js";
import { envioRepository } from "../repository/EnvioRepository.js";
import { HttpError } from "../utils/http-error.js";
import { validarId } from "../utils/validaciones.js";

// ---------------------------------------------------------------------
// Endpoint 6: GET /api/clientes/:id/envios
// Historial de envíos donde el cliente participa (remitente o destinatario).
// ---------------------------------------------------------------------
export const historialEnviosCliente = async (idParam: unknown) => {
    const clienteId = validarId(idParam, "id");

    const cliente = await clienteRepository.findById(clienteId);
    if (!cliente) throw new HttpError(404, "Cliente no encontrado");

    const envios = await envioRepository.findByCliente(clienteId);

    return {
        cliente,
        totalEnvios: envios.length,
        envios: envios.map((envio) => ({
            rol: envio.remitenteId === clienteId ? "REMITENTE" : "DESTINATARIO",
            ...envio,
        })),
    };
};
