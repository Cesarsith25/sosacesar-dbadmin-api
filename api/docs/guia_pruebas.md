# Guía de pruebas · Examen U2 LogiExpress

Esta guía explica cómo comprobar, punto por punto, que el proyecto cumple con el PDF del examen. Cada prueba dice **qué hacer**, **qué debes ver** y **cómo confirmarlo en DBeaver**.

> **Sigue el orden de la guía.** Los resultados esperados están calculados con los datos iniciales, y algunas pruebas cambian datos que usan las siguientes. Si algo no cuadra, reinicia la base (ver sección 0.3) y vuelve a empezar.

---

## 0. Preparación

### 0.1 Levantar la base de datos

```bash
cd docker/logiexpress_db
docker compose up -d --build
```

Espera unos 20 segundos la primera vez, porque MySQL ejecuta los 4 scripts de `scripts/`.

### 0.2 Conectar DBeaver

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `3307` |
| Base de datos | `logiexpress_db` |
| Usuario | `root` |
| Contraseña | `secret` |

> Si DBeaver muestra *"Public Key Retrieval is not allowed"*, ve a **Driver properties** y pon `allowPublicKeyRetrieval = true`.

### 0.3 Reiniciar la base desde cero (cuando lo necesites)

```bash
cd docker/logiexpress_db
docker compose down -v
docker compose up -d --build
```

El `-v` borra el volumen. Sin él, los scripts **no** se vuelven a ejecutar.

### 0.4 Levantar la API

```bash
cd api/mi-api
npm install
npm run dev
```

Debe aparecer:

```
Conexión exitosa a la base de datos logiexpress_db
Servidor corriendo en http://localhost:3003
```

### 0.5 Herramienta para las peticiones

Usa **Postman**, **Thunder Client** (extensión de VS Code) o similar. En todas las peticiones con body:

- Header: `Content-Type: application/json`
- Body: **raw → JSON**

Prueba rápida: `GET http://localhost:3003/api/status` debe responder `{"status":"OK", ...}`.

---

## Requisito 1 · DDL de las 7 tablas en 3FN (PK, FK, DATETIME, DECIMAL, ENUM)

**Archivo:** `docker/logiexpress_db/scripts/01_tablas.sql`, también incluido en `docker/logiexpress_examen.sql`.

### 1.1 Comprobar que existen exactamente 7 tablas

```sql
USE logiexpress_db;
SHOW TABLES;
```

Esperado: `almacenes`, `auditoria_envios`, `clientes`, `direcciones`, `envios`, `historial_rastreo`, `paquetes`.

### 1.2 Comprobar llaves primarias y foráneas

```sql
SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'logiexpress_db'
ORDER BY TABLE_NAME, CONSTRAINT_NAME;
```

Esperado:
- Cada tabla tiene su `PRIMARY` (por ejemplo `envio_id`, `paquete_id`).
- Hay FK como `fk_envios_remitente → clientes`, `fk_paquetes_almacenes → almacenes` y `fk_auditoria_envios → envios`.

### 1.3 Comprobar los tipos de datos

```sql
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'logiexpress_db'
  AND (DATA_TYPE IN ('datetime', 'decimal', 'enum'))
ORDER BY TABLE_NAME;
```

Esperado, entre otros:
- `envios.costo_total` → `decimal(10,2)`
- `envios.fecha_registro` → `datetime`
- `envios.estado` → `enum('REGISTRADO','EN_TRANSITO','ENTREGADO','CANCELADO')`
- `clientes.estado` → `enum('ACTIVO','INACTIVO')`

### 1.4 Cómo justificar la 3FN

- **1FN:** todos los valores son atómicos. Las dimensiones del paquete van en 3 columnas (`largo_cm`, `ancho_cm`, `alto_cm`) y no en un texto "40x30x20".
- **2FN:** todas las PK son simples (un solo campo autoincremental), así que no hay dependencias parciales.
- **3FN:** no hay dependencias transitivas. Los datos del cliente no se repiten en `envios`: solo se guardan `remitente_id` y `destinatario_id`. Las direcciones tampoco se repiten: se guardan `direccion_origen_id` y `direccion_destino_id`.

---

## Requisito 2 · Entidades TypeORM con relaciones

**Carpeta:** `api/mi-api/src/entity/`

### 2.1 Revisar los archivos

Deben existir `Cliente.ts`, `Direccion.ts`, `Envio.ts`, `Paquete.ts`, `Almacen.ts`, `HistorialRastreo.ts` y `AuditoriaEnvio.ts`, cada uno con `@Entity("nombre_tabla")`.

Relaciones que puedes señalar:

| Entidad | `@ManyToOne` | `@OneToMany` |
|---|---|---|
| `Cliente` | — | `direcciones`, `enviosEnviados`, `enviosRecibidos` |
| `Envio` | `remitente`, `destinatario`, `direccionOrigen`, `direccionDestino` | `paquetes`, `historial`, `auditorias` |
| `Paquete` | `envio`, `almacen` | — |
| `Almacen` | — | `paquetes` |
| `Direccion`, `HistorialRastreo`, `AuditoriaEnvio` | `cliente` / `envio` | — |

### 2.2 Comprobar que compila

```bash
cd api/mi-api
npm run build
```

Esperado: termina sin errores y se crea la carpeta `dist/`.

### 2.3 Comprobar que el mapeo funciona

Si los endpoints de los requisitos 6 a 10 devuelven datos con sus relaciones (por ejemplo `remitente` y `paquetes` dentro de cada envío), las entidades están bien mapeadas.

---

## Requisito 3 · `sp_reporte_mensual_cliente` (solo DBeaver)

**Archivo:** `docker/logiexpress_db/scripts/03_procedimientos.sql`

> En DBeaver, cada `CALL` devuelve una o varias pestañas de resultados en la parte inferior.

### 3.1 Cliente 1, octubre 2026

```sql
CALL sp_reporte_mensual_cliente(1, 10, 2026);
```

Resultado 1 (resumen):

| Columna | Valor esperado |
|---|---|
| `cliente` | Distribuidora Hernández |
| `periodo` | 2026-10 |
| `total_envios` | 4 |
| `envios_entregados` | 2 |
| `envios_en_proceso` | 1 |
| `envios_cancelados` | 1 |
| `facturacion_total` | 2690.00 (850 + 1200 + 640; los cancelados no cuentan) |
| `tiempo_promedio_entrega_horas` | 42.75 (envío 1: 54.5 h, envío 2: 31 h) |
| `tiempo_promedio_entrega_dias` | 1.78 |

Resultado 2 (detalle): 4 filas, de los envíos 1 a 4.

### 3.2 Cliente 3, noviembre 2026

```sql
CALL sp_reporte_mensual_cliente(3, 11, 2026);
```

Esperado: `total_envios = 2`, `envios_entregados = 0`, `facturacion_total = 2480.00`. El tiempo promedio sale `NULL` porque todavía no hay entregas.

### 3.3 Validación de parámetros

```sql
CALL sp_reporte_mensual_cliente(99, 10, 2026);
CALL sp_reporte_mensual_cliente(1, 13, 2026);
```

Esperado: `Error 1644 (45000): El cliente indicado no existe` y `El mes debe estar entre 1 y 12`.

---

## Requisito 4 · `sp_obtener_hoja_ruta_envio` (solo DBeaver)

```sql
CALL sp_obtener_hoja_ruta_envio(1);
```

Esperado, en 3 pestañas de resultados:

1. **Encabezado (1 fila):** estado `ENTREGADO`, remitente *Distribuidora Hernández* con su dirección de Querétaro, destinatario *María López Torres* con su dirección de Guadalajara.
2. **Paquetes (2 filas):** *Ropa y textiles* (3.50 kg, `40.00 x 30.00 x 20.00 cm`) y *Accesorios*, ambos en *CEDIS Guadalajara*.
3. **Historial (6 filas)** en orden cronológico: `REGISTRADO → RECOLECTADO → EN_TRANSITO → EN_ALMACEN → EN_REPARTO → ENTREGADO`.

Envío inexistente:

```sql
CALL sp_obtener_hoja_ruta_envio(999);
```

Esperado: `Error 1644 (45000): El envío indicado no existe`.

### 4.1 Comprobar que los procedures NO se llaman desde la API

En VS Code, busca `sp_` o `CALL` dentro de `api/mi-api/src`.

Esperado: **0 resultados**. Solo se ejecutan desde DBeaver, como pide el PDF.

---

## Requisito 5 · Los 3 triggers existen

```sql
SELECT TRIGGER_NAME, ACTION_TIMING, EVENT_MANIPULATION, EVENT_OBJECT_TABLE
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'logiexpress_db';
```

Esperado:

| TRIGGER_NAME | ACTION_TIMING | EVENT_MANIPULATION | EVENT_OBJECT_TABLE |
|---|---|---|---|
| `after_update_envio_costo` | AFTER | UPDATE | envios |
| `before_insert_paquete_almacen` | BEFORE | INSERT | paquetes |
| `after_insert_historial_rastreo` | AFTER | INSERT | historial_rastreo |

El funcionamiento de cada trigger se prueba **desde la API** en los requisitos 7, 8 y 9.

---

## Requisito 6 · `POST /api/envios`

### 6.1 Antes de probar

```sql
SELECT COUNT(*) FROM envios;   -- debe dar 8
```

### 6.2 Caso exitoso

`POST http://localhost:3003/api/envios`

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

Esperado: **201**, con `envioId: 9`, `estado: "REGISTRADO"`, 2 paquetes y 1 evento en `historial` (`REGISTRADO`).

En DBeaver:

```sql
SELECT * FROM envios   WHERE envio_id = 9;
SELECT * FROM paquetes WHERE envio_id = 9;
```

### 6.3 Validaciones (deben responder 400)

**Remitente inactivo:** el cliente 5 está `INACTIVO`.

```json
{ "remitenteId": 5, "destinatarioId": 1, "direccionOrigenId": 8, "direccionDestinoId": 7, "costoTotal": 100,
  "paquetes": [ { "pesoKg": 1, "largoCm": 10, "anchoCm": 10, "altoCm": 10, "contenido": "x" } ] }
```

**Sin paquetes:**

```json
{ "remitenteId": 1, "destinatarioId": 2, "direccionOrigenId": 1, "direccionDestinoId": 2, "costoTotal": 100, "paquetes": [] }
```

Esperado: **400**, con mensajes *"El remitente está INACTIVO..."* y *"paquetes debe ser un arreglo con al menos un paquete"*.

---

## Requisito 7 · `PUT /api/envios/:id/costo` (trigger de auditoría)

### 7.1 Antes de probar

```sql
SELECT * FROM auditoria_envios;   -- 1 fila (la del envío 2, de los datos iniciales)
```

### 7.2 Cambiar el costo con usuario

`PUT http://localhost:3003/api/envios/3/costo`

```json
{ "costoTotal": 699.50, "usuario": "tu.nombre" }
```

Esperado: **200**, y en `data.auditoria`:

```json
{ "costoAnterior": 640, "costoNuevo": 699.5, "usuario": "tu.nombre", ... }
```

### 7.3 Mismo costo (no debe auditar)

Repite la misma petición.

Esperado: **200**, con `"cambio": false` y `"auditoria": null`.

### 7.4 Sin usuario

```json
{ "costoTotal": 720 }
```

Esperado: **200**, con `usuario` igual al usuario de MySQL (algo como `root@172.x.x.x` o `root@192.168.x.x`, según tu Docker).

En DBeaver:

```sql
SELECT * FROM auditoria_envios ORDER BY auditoria_id;
```

Esperado: 3 filas. Las 2 nuevas las creó el **trigger**; la API nunca inserta en esta tabla.

---

## Requisito 8 · `POST /api/almacenes/:id/paquetes` (trigger de capacidad → HTTP 400)

El almacén 3 (*Almacén Express León*) tiene `capacidad_maxima = 3` y 2 paquetes de envíos activos. Le queda **1 lugar**.

### 8.1 Antes de probar

```sql
SELECT p.paquete_id, e.estado
FROM paquetes p JOIN envios e ON e.envio_id = p.envio_id
WHERE p.almacen_id = 3;
```

Verás 3 paquetes, pero uno es de un envío `ENTREGADO` y ya no ocupa lugar.

### 8.2 Primer paquete (sí cabe)

`POST http://localhost:3003/api/almacenes/3/paquetes`

```json
{ "envioId": 8, "pesoKg": 1.5, "largoCm": 30, "anchoCm": 20, "altoCm": 10, "contenido": "Repuestos" }
```

Esperado: **201**, con `"ocupados": 3, "disponibles": 0`.

### 8.3 Segundo paquete (no cabe) ← punto clave del examen

Envía la **misma petición** otra vez.

Esperado: **400 Bad Request**

```json
{
  "message": "Capacidad excedida: el almacén \"Almacén Express León\" ya tiene 3 de 3 paquetes",
  "status": 400,
  "error": "TRIGGER_45000"
}
```

El mensaje viene del `SIGNAL SQLSTATE '45000'` del trigger. La API lo captura en `src/utils/http-error.ts` (función `responderError`).

En DBeaver, el segundo paquete **no** se guardó:

```sql
SELECT COUNT(*) FROM paquetes WHERE almacen_id = 3;   -- 4, no 5
```

### 8.4 Bonus: el trigger también protege el `POST /api/envios` (rollback)

`POST http://localhost:3003/api/envios` con un paquete dirigido al almacén lleno:

```json
{
  "remitenteId": 2, "destinatarioId": 1, "direccionOrigenId": 3, "direccionDestinoId": 7, "costoTotal": 100,
  "paquetes": [ { "pesoKg": 1, "largoCm": 10, "anchoCm": 10, "altoCm": 10, "contenido": "x", "almacenId": 3 } ]
}
```

Esperado: **400** con el mensaje del trigger.

```sql
SELECT COUNT(*) FROM envios;   -- sigue en 9: se hizo rollback de todo el envío
```

---

## Requisito 9 · `POST /api/envios/:id/rastreo` (trigger de estado)

> Haz esta prueba **después** del requisito 8, porque usa el envío 8.

### 9.1 Antes de probar

```sql
SELECT envio_id, estado, fecha_entrega FROM envios WHERE envio_id = 8;
-- REGISTRADO, fecha_entrega NULL
```

### 9.2 Evento de movimiento

`POST http://localhost:3003/api/envios/8/rastreo`

```json
{ "ubicacionActual": "Querétaro, Qro.", "estadoEvento": "RECOLECTADO" }
```

Esperado: **201**, con `"estadoAnterior": "REGISTRADO", "estadoActual": "EN_TRANSITO"`.

### 9.3 Evento ENTREGADO ← punto clave del examen

```json
{ "ubicacionActual": "León, Gto.", "estadoEvento": "ENTREGADO", "observaciones": "Recibió recepción" }
```

Esperado: **201**, con `"estadoAnterior": "EN_TRANSITO", "estadoActual": "ENTREGADO"` y `fechaEntrega` con fecha.

En DBeaver:

```sql
SELECT envio_id, estado, fecha_entrega FROM envios WHERE envio_id = 8;
-- ENTREGADO y fecha_entrega llena: lo hizo el trigger, la API solo insertó en historial_rastreo
```

### 9.4 Validaciones

- Repetir cualquier evento sobre el envío 8 → **400** *"El envío ya está ENTREGADO..."*
- `"estadoEvento": "VOLANDO"` → **400**, con la lista de valores permitidos.
- `POST /api/envios/999/rastreo` → **404**.

---

## Requisito 10 · Consultas relacionales

### 10.1 `GET /api/envios` (envíos activos, `createQueryBuilder`)

`GET http://localhost:3003/api/envios`

Esperado: **200**. Cada envío tiene `estado` `REGISTRADO` o `EN_TRANSITO` (nunca `ENTREGADO` ni `CANCELADO`) e incluye `remitente`, `destinatario`, `direccionOrigen`, `direccionDestino` y `paquetes`.

El campo `total` debe coincidir con:

```sql
SELECT COUNT(*) FROM envios WHERE estado IN ('REGISTRADO', 'EN_TRANSITO');
```

Código: `src/repository/EnvioRepository.ts → findActivos()`.

### 10.2 `GET /api/clientes/:id/envios` (historial, `Repository.find()`)

`GET http://localhost:3003/api/clientes/1/envios`

Esperado: **200**, con los datos del cliente y la lista de envíos. Cada envío trae `rol` (`REMITENTE` o `DESTINATARIO`).

`totalEnvios` debe coincidir con:

```sql
SELECT COUNT(*) FROM envios WHERE remitente_id = 1 OR destinatario_id = 1;
```

`GET http://localhost:3003/api/clientes/99/envios` → **404** *"Cliente no encontrado"*.

Código: `src/repository/EnvioRepository.ts → findByCliente()`.

---

## Checklist final

| # | Requisito | Prueba | ✔ |
|---|---|---|---|
| 1 | DDL 7 tablas 3FN | `SHOW TABLES` = 7, PK/FK/tipos correctos | ☐ |
| 2 | Entidades TypeORM | 7 archivos en `entity/`, `npm run build` sin errores | ☐ |
| 3 | SP reporte mensual | `CALL (1,10,2026)` → 2690.00 y 42.75 h | ☐ |
| 4 | SP hoja de ruta | `CALL (1)` → 3 resultados, 6 eventos en orden | ☐ |
| 5 | 3 triggers | Aparecen en `information_schema.TRIGGERS` | ☐ |
| 6 | POST /api/envios | 201, envío + paquetes + rastreo inicial | ☐ |
| 7 | PUT costo | Fila nueva en `auditoria_envios` con OLD/NEW/usuario | ☐ |
| 8 | POST paquete en almacén | 1.º → 201, 2.º → **400** `TRIGGER_45000` | ☐ |
| 9 | POST rastreo | ENTREGADO → envío pasa a `ENTREGADO` | ☐ |
| 10 | GET envíos / historial | Solo activos; `total` coincide con SQL | ☐ |
| — | Entregables | `docker/logiexpress_examen.sql` + `.zip` del proyecto sin `node_modules` | ☐ |

> Al terminar, si quieres dejar la base como al inicio, ejecuta la sección **0.3**.
