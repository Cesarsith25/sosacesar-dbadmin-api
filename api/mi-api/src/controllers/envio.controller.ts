import { Request, Response } from "express";
import {
  crearEnvio, actualizarCosto, registrarRastreo, listarEnviosActivos, obtenerEnvio,
} from "../services/envio.service.js";
import { responderError } from "../utils/http-error.js";

// POST /api/envios
export const createEnvio = async ( req:Request, resp:Response ) => {
  try {
    const envio = await crearEnvio(req.body);
    return resp.status(201).json({
      message: "Envío registrado con sus paquetes",
      status: 201,
      data: envio,
    });
  } catch (error) {
    return responderError(resp, error);
  }
};

// PUT /api/envios/:id/costo  -> trigger after_update_envio_costo
export const updateCostoEnvio = async ( req:Request, resp:Response ) => {
  try {
    const resultado = await actualizarCosto(req.params.id, req.body);
    return resp.json({
      message: resultado.cambio
        ? "Costo actualizado; el trigger after_update_envio_costo registró la auditoría"
        : "El costo es igual al actual; no se generó auditoría",
      status: 200,
      data: resultado,
    });
  } catch (error) {
    return responderError(resp, error);
  }
};

// POST /api/envios/:id/rastreo  -> trigger after_insert_historial_rastreo
export const createRastreo = async ( req:Request, resp:Response ) => {
  try {
    const resultado = await registrarRastreo(req.params.id, req.body);
    return resp.status(201).json({
      message: "Evento de rastreo registrado",
      status: 201,
      data: resultado,
    });
  } catch (error) {
    return responderError(resp, error);
  }
};

// GET /api/envios  (activos)
export const getEnviosActivos = async ( req:Request, resp:Response ) => {
  try {
    const envios = await listarEnviosActivos();
    return resp.json({
      message: "Envíos activos encontrados",
      status: 200,
      total: envios.length,
      data: envios,
    });
  } catch (error) {
    return responderError(resp, error);
  }
};

// GET /api/envios/:id
export const getEnvio = async ( req:Request, resp:Response ) => {
  try {
    const envio = await obtenerEnvio(req.params.id);
    return resp.json({ message: "Envío encontrado", status: 200, data: envio });
  } catch (error) {
    return responderError(resp, error);
  }
};
