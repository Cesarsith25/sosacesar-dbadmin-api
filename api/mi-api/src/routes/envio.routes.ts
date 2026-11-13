import { Router } from "express";
import {
  createEnvio, updateCostoEnvio, createRastreo, getEnviosActivos, getEnvio,
} from "../controllers/envio.controller.js";

const router = Router();

router.post('/envios', createEnvio);                 // Endpoint 1
router.put('/envios/:id/costo', updateCostoEnvio);   // Endpoint 2 (trigger auditoría)
router.post('/envios/:id/rastreo', createRastreo);   // Endpoint 4 (trigger estado)
router.get('/envios', getEnviosActivos);             // Endpoint 5
router.get('/envios/:id', getEnvio);                 // Apoyo: detalle de un envío

export default router;
