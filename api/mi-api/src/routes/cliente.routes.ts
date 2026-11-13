import { Router } from "express";
import { getEnviosCliente } from "../controllers/cliente.controller.js";

const router = Router();

router.get('/clientes/:id/envios', getEnviosCliente); // Endpoint 6

export default router;
