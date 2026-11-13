import { Request, Response } from "express";
import { asignarPaquete } from "../services/almacen.service.js";
import { responderError } from "../utils/http-error.js";

// POST /api/almacenes/:id/paquetes  -> trigger before_insert_paquete_almacen
// Si el trigger lanza SIGNAL SQLSTATE '45000', responderError devuelve HTTP 400.
export const createPaqueteEnAlmacen = async ( req:Request, resp:Response ) => {
  try {
    const resultado = await asignarPaquete(req.params.id, req.body);
    return resp.status(201).json({
      message: "Paquete asignado al almacén",
      status: 201,
      data: resultado,
    });
  } catch (error) {
    return responderError(resp, error);
  }
};
