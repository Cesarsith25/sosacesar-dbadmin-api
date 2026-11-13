import { Router } from "express";
import { createPaqueteEnAlmacen } from "../controllers/almacen.controller.js";

const router = Router();

router.post('/almacenes/:id/paquetes', createPaqueteEnAlmacen); // Endpoint 3 (trigger capacidad)

export default router;
