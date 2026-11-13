import express, { Request, Response, NextFunction } from 'express';
import envioRoutes from './routes/envio.routes.js';
import almacenRoutes from './routes/almacen.routes.js';
import clienteRoutes from './routes/cliente.routes.js';

const app = express();

// Middleware para parsear JSON
app.use(express.json());
app.use('/api/', envioRoutes);
app.use('/api/', almacenRoutes);
app.use('/api/', clienteRoutes);

// Ruta de prueba/salud
app.get('/api/status', (req: Request, res: Response) => {
  res.json({ status: 'OK', message: 'API LogiExpress funcionando correctamente' });
});

app.get('/', (req: Request, res: Response) => {
  res.json({ message: 'API LogiExpress funcionando', docs: '/api/status' });
});

// Ruta no encontrada
app.use((req: Request, res: Response) => {
  res.status(404).json({ message: `Ruta ${req.method} ${req.originalUrl} no encontrada`, status: 404 });
});

// JSON mal formado u otro error no controlado
app.use((err: any, req: Request, res: Response, _next: NextFunction) => {
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({ message: 'El cuerpo de la petición no es un JSON válido', status: 400 });
  }
  console.error(err);
  return res.status(500).json({ message: 'Error interno del servidor', status: 500 });
});

export default app;
