# Examen U2 · LogiExpress (MySQL 8 + API REST TypeScript/TypeORM)

Sistema logístico con 7 tablas en 3FN, 2 procedimientos almacenados (se prueban en DBeaver), 3 triggers y una API con los 6 endpoints que pide el examen.

## Estructura

```text
ADM_Practica1_U2/
├── docker/
│   ├── logiexpress_db/
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   └── scripts/                 # se ejecutan en este orden al crear el contenedor
│   │       ├── 01_tablas.sql        # DDL de las 7 tablas (PK, FK, ENUM, DECIMAL, DATETIME)
│   │       ├── 02_valores.sql       # datos de prueba
│   │       ├── 03_procedimientos.sql
│   │       └── 04_triggers.sql
│   ├── logiexpress_examen.sql       # ENTREGABLE: los 4 scripts anteriores en un solo archivo
│   ├── pruebas_dbeaver.sql          # CALL de los procedures y pruebas de triggers
│   ├── stored_procedures.md         # (guía de clase)
│   └── views.md                     # (guía de clase)
└── api/
    ├── docs/                        # (guías de clase)
    └── mi-api/src/
        ├── config/        data-source.ts, db.ts
        ├── entity/        Cliente, Direccion, Almacen, Envio, Paquete, HistorialRastreo, AuditoriaEnvio
        ├── repository/    acceso a datos (Repository.find / createQueryBuilder)
        ├── services/      lógica de negocio y transacciones (QueryRunner)
        ├── controllers/   reciben la petición y responden JSON
        ├── routes/        envio, almacen, cliente
        ├── utils/         manejo de errores (45000 -> HTTP 400), validaciones, decimal
        ├── app.ts
        └── server.ts
```

## Cómo levantarlo

```bash
# 1. Base de datos (puerto 3307)
cd docker/logiexpress_db
docker compose up -d --build

# 2. API (puerto 3003)
cd ../../api/mi-api
npm install
npm run dev
```

`.env` de la API:

```env
PORT=3003
DB_HOST=localhost
DB_PORT=3307
DB_USER=root
DB_PASSWORD=secret
DB_NAME=logiexpress_db
```

> Si ya existía un volumen de una versión anterior, los scripts no se vuelven a ejecutar. Para recrear la BD desde cero: `docker compose down -v` y luego `docker compose up -d --build`.

## Modelo de datos (3FN)

| Tabla | Contenido | Relaciones |
|---|---|---|
| `clientes` | nombre, email, teléfono, estado (`ACTIVO`/`INACTIVO`), límite de crédito | — |
| `direcciones` | dirección de tipo `ORIGEN` o `DESTINO` | N:1 `clientes` |
| `almacenes` | nombre, ubicación, `capacidad_maxima` | — |
| `envios` | costo_total, fechas de registro/entrega, estado (`REGISTRADO`, `EN_TRANSITO`, `ENTREGADO`, `CANCELADO`) | remitente y destinatario → `clientes`; origen y destino → `direcciones` |
| `paquetes` | peso, largo/ancho/alto, contenido | N:1 `envios`, N:1 `almacenes` (opcional) |
| `historial_rastreo` | fecha, ubicación_actual, estado_evento, observaciones | N:1 `envios` |
| `auditoria_envios` | costo_anterior, costo_nuevo, usuario, fecha_modificacion | N:1 `envios` |

## Triggers

| Trigger | Tabla / momento | Qué hace |
|---|---|---|
| `after_update_envio_costo` | `envios` AFTER UPDATE | Si cambió `costo_total`, inserta OLD, NEW, usuario y fecha en `auditoria_envios`. El usuario sale de `@usuario_app` (lo define la API) o, si no existe, de `USER()`. |
| `before_insert_paquete_almacen` | `paquetes` BEFORE INSERT | Si el paquete va a un almacén lleno, lanza `SIGNAL SQLSTATE '45000'`. Solo cuentan los paquetes de envíos activos (`REGISTRADO`/`EN_TRANSITO`). |
| `after_insert_historial_rastreo` | `historial_rastreo` AFTER INSERT | Con `ENTREGADO`, pone el envío en `ENTREGADO` y guarda `fecha_entrega`. Además, un evento de movimiento pasa un envío `REGISTRADO` a `EN_TRANSITO`. |

## Procedimientos (solo en DBeaver)

```sql
CALL sp_reporte_mensual_cliente(1, 10, 2026);  -- facturación, entregados y tiempo promedio de entrega
CALL sp_obtener_hoja_ruta_envio(1);            -- encabezado + paquetes + historial cronológico
```

Con los datos de prueba, el reporte del cliente 1 de octubre 2026 da 4 envíos, 2 entregados, facturación de $2,690.00 y 42.75 h de promedio de entrega. En `docker/pruebas_dbeaver.sql` hay más casos.

## Endpoints

Todas las respuestas tienen el formato `{ message, status, data }`.

### 1. `POST /api/envios`: registrar un envío con sus paquetes

Se guarda en una sola transacción (QueryRunner): envío, paquetes y primer evento de rastreo. Si algún paquete trae `almacenId` y el trigger de capacidad lo rechaza, se deshace todo y se responde **400**.

```json
{
  "remitenteId": 2,
  "destinatarioId": 1,
  "direccionOrigenId": 3,
  "direccionDestinoId": 7,
  "costoTotal": 530,
  "paquetes": [
    { "pesoKg": 3, "largoCm": 40, "anchoCm": 30, "altoCm": 20, "contenido": "Caja A", "almacenId": 2 },
    { "pesoKg": 1, "largoCm": 20, "anchoCm": 20, "altoCm": 10, "contenido": "Caja B" }
  ]
}
```

Validaciones: el remitente debe estar `ACTIVO`, el origen debe ser una dirección `ORIGEN` del remitente y el destino una dirección `DESTINO` del destinatario.

### 2. `PUT /api/envios/:id/costo`: cambiar el costo (dispara la auditoría)

```json
{ "costoTotal": 699.50, "usuario": "cesar.sosa" }
```

`usuario` es opcional. La respuesta incluye el registro que creó el trigger en `auditoria_envios`.

### 3. `POST /api/almacenes/:id/paquetes`: asignar un paquete a un almacén (dispara la validación de capacidad)

```json
{ "envioId": 8, "pesoKg": 1.5, "largoCm": 30, "anchoCm": 20, "altoCm": 10, "contenido": "Repuestos" }
```

Si el almacén está lleno:

```json
{
  "message": "Capacidad excedida: el almacén \"Almacén Express León\" ya tiene 3 de 3 paquetes",
  "status": 400,
  "error": "TRIGGER_45000"
}
```

Para probarlo: el almacén 3 tiene capacidad 3 y 2 lugares ocupados, así que el primer POST pasa y el segundo regresa 400.

### 4. `POST /api/envios/:id/rastreo`: agregar un evento de rastreo (dispara el cambio de estado)

```json
{ "ubicacionActual": "León, Gto.", "estadoEvento": "ENTREGADO", "observaciones": "Recibió recepción" }
```

`estadoEvento` acepta `REGISTRADO`, `RECOLECTADO`, `EN_TRANSITO`, `EN_ALMACEN`, `EN_REPARTO`, `ENTREGADO` o `INCIDENCIA`. `fecha` es opcional (ISO). La respuesta muestra `estadoAnterior` y `estadoActual` del envío.

### 5. `GET /api/envios`: envíos activos

Devuelve los envíos `REGISTRADO` y `EN_TRANSITO` con remitente, destinatario, direcciones, paquetes y almacén. Se construye con `createQueryBuilder()`.

### 6. `GET /api/clientes/:id/envios`: historial de un cliente

Devuelve los envíos donde el cliente es remitente o destinatario (`rol`). Se construye con `Repository.find()`.

### Extra: `GET /api/envios/:id`

Muestra el detalle completo de un envío (paquetes, historial y auditorías). Sirve para revisar el efecto de los triggers.

## Códigos de error

| Caso | HTTP |
|---|---|
| Trigger con `SIGNAL SQLSTATE '45000'` | 400 |
| Datos inválidos o JSON mal formado | 400 |
| Envío, cliente o almacén inexistente | 404 |
| Error no controlado | 500 |
