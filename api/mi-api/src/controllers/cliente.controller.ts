import { Request, Response } from "express";
import { historialEnviosCliente } from "../services/cliente.service.js";
import { responderError } from "../utils/http-error.js";

// GET /api/clientes/:id/envios
export const getEnviosCliente = async ( req:Request, resp:Response ) => {
  try {
    const resultado = await historialEnviosCliente(req.params.id);
    return resp.json({
      message: "Historial de envíos del cliente",
      status: 200,
      data: resultado,
    });
  } catch (error) {
    return responderError(resp, error);
  }
};
