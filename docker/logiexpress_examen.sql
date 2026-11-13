-- =====================================================================
-- EXAMEN U2 - LogiExpress (MySQL 8.x)
-- Archivo único de entrega: DDL (7 tablas 3FN) + datos + 2 procedures + 3 triggers
-- Generado uniendo docker/logiexpress_db/scripts/01..04 (misma fuente que usa Docker)
-- =====================================================================

-- =====================================================================
-- LogiExpress - Script DDL (MySQL 8.x)
-- 7 tablas en 3FN: clientes, direcciones, almacenes, envios, paquetes,
--                  historial_rastreo, auditoria_envios
-- =====================================================================

-- Asegura que los acentos se guarden correctamente (UTF-8)
SET NAMES utf8mb4;

-- 1. Crear la base de datos si no existe
CREATE DATABASE IF NOT EXISTS logiexpress_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 2. Seleccionar la base de datos para usarla
USE logiexpress_db;

-- ---------------------------------------------------------------------
-- Tabla 1: Clientes (remitentes y destinatarios)
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    cliente_id      INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100)  NOT NULL,
    email           VARCHAR(100)  NOT NULL,
    telefono        VARCHAR(20)   NULL,
    estado          ENUM('ACTIVO', 'INACTIVO') NOT NULL DEFAULT 'ACTIVO',
    limite_credito  DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    fecha_registro  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_clientes_email UNIQUE (email),
    CONSTRAINT chk_clientes_limite CHECK (limite_credito >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabla 2: Direcciones de origen y destino asociadas a cada cliente
-- ---------------------------------------------------------------------
CREATE TABLE direcciones (
    direccion_id        INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id          INT          NOT NULL,
    tipo                ENUM('ORIGEN', 'DESTINO') NOT NULL,
    calle               VARCHAR(150) NOT NULL,
    numero              VARCHAR(10)  NULL,
    colonia             VARCHAR(100) NULL,
    ciudad              VARCHAR(80)  NOT NULL,
    entidad_federativa  VARCHAR(80)  NOT NULL,
    codigo_postal       VARCHAR(10)  NOT NULL,
    CONSTRAINT fk_direcciones_clientes
        FOREIGN KEY (cliente_id) REFERENCES clientes(cliente_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabla 3: Almacenes (centros de distribución)
-- ---------------------------------------------------------------------
CREATE TABLE almacenes (
    almacen_id        INT AUTO_INCREMENT PRIMARY KEY,
    nombre            VARCHAR(100) NOT NULL,
    ubicacion         VARCHAR(150) NOT NULL,
    capacidad_maxima  INT          NOT NULL,
    CONSTRAINT uq_almacenes_nombre UNIQUE (nombre),
    CONSTRAINT chk_almacenes_capacidad CHECK (capacidad_maxima > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabla 4: Envíos (encabezado del envío)
--   remitente_id / destinatario_id -> clientes
--   direccion_origen_id / direccion_destino_id -> direcciones
-- ---------------------------------------------------------------------
CREATE TABLE envios (
    envio_id              INT AUTO_INCREMENT PRIMARY KEY,
    remitente_id          INT            NOT NULL,
    destinatario_id       INT            NOT NULL,
    direccion_origen_id   INT            NOT NULL,
    direccion_destino_id  INT            NOT NULL,
    costo_total           DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    fecha_registro        DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega         DATETIME       NULL,
    estado                ENUM('REGISTRADO', 'EN_TRANSITO', 'ENTREGADO', 'CANCELADO')
                          NOT NULL DEFAULT 'REGISTRADO',
    CONSTRAINT fk_envios_remitente
        FOREIGN KEY (remitente_id) REFERENCES clientes(cliente_id),
    CONSTRAINT fk_envios_destinatario
        FOREIGN KEY (destinatario_id) REFERENCES clientes(cliente_id),
    CONSTRAINT fk_envios_dir_origen
        FOREIGN KEY (direccion_origen_id) REFERENCES direcciones(direccion_id),
    CONSTRAINT fk_envios_dir_destino
        FOREIGN KEY (direccion_destino_id) REFERENCES direcciones(direccion_id),
    CONSTRAINT chk_envios_costo CHECK (costo_total >= 0),
    INDEX idx_envios_estado (estado),
    INDEX idx_envios_remitente_fecha (remitente_id, fecha_registro)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabla 5: Paquetes contenidos en un envío
--   almacen_id es NULL mientras el paquete no se asigna a un almacén
-- ---------------------------------------------------------------------
CREATE TABLE paquetes (
    paquete_id  INT AUTO_INCREMENT PRIMARY KEY,
    envio_id    INT           NOT NULL,
    almacen_id  INT           NULL,
    peso_kg     DECIMAL(8, 2) NOT NULL,
    largo_cm    DECIMAL(6, 2) NOT NULL,
    ancho_cm    DECIMAL(6, 2) NOT NULL,
    alto_cm     DECIMAL(6, 2) NOT NULL,
    contenido   VARCHAR(200)  NOT NULL,
    CONSTRAINT fk_paquetes_envios
        FOREIGN KEY (envio_id) REFERENCES envios(envio_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_paquetes_almacenes
        FOREIGN KEY (almacen_id) REFERENCES almacenes(almacen_id)
        ON DELETE SET NULL,
    CONSTRAINT chk_paquetes_medidas
        CHECK (peso_kg > 0 AND largo_cm > 0 AND ancho_cm > 0 AND alto_cm > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabla 6: Historial de rastreo (bitácora de seguimiento)
-- ---------------------------------------------------------------------
CREATE TABLE historial_rastreo (
    rastreo_id        INT AUTO_INCREMENT PRIMARY KEY,
    envio_id          INT          NOT NULL,
    fecha             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ubicacion_actual  VARCHAR(150) NOT NULL,
    estado_evento     ENUM('REGISTRADO', 'RECOLECTADO', 'EN_TRANSITO', 'EN_ALMACEN',
                           'EN_REPARTO', 'ENTREGADO', 'INCIDENCIA') NOT NULL,
    observaciones     VARCHAR(255) NULL,
    CONSTRAINT fk_rastreo_envios
        FOREIGN KEY (envio_id) REFERENCES envios(envio_id)
        ON DELETE CASCADE,
    INDEX idx_rastreo_envio_fecha (envio_id, fecha)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabla 7: Auditoría de cambios de costo (la llena el trigger
--          after_update_envio_costo)
-- ---------------------------------------------------------------------
CREATE TABLE auditoria_envios (
    auditoria_id        INT AUTO_INCREMENT PRIMARY KEY,
    envio_id            INT            NOT NULL,
    costo_anterior      DECIMAL(10, 2) NOT NULL,
    costo_nuevo         DECIMAL(10, 2) NOT NULL,
    usuario             VARCHAR(100)   NOT NULL,
    fecha_modificacion  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_auditoria_envios
        FOREIGN KEY (envio_id) REFERENCES envios(envio_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;


-- =====================================================================
-- LogiExpress - Datos iniciales
-- Se cargan ANTES de crear los triggers, por eso el estado de cada envío
-- y su fecha_entrega se capturan ya consistentes con su historial.
-- =====================================================================
USE logiexpress_db;

-- Asegura que los acentos se guarden correctamente (UTF-8)
SET NAMES utf8mb4;

-- Clientes
INSERT INTO clientes (cliente_id, nombre, email, telefono, estado, limite_credito, fecha_registro) VALUES
(1, 'Distribuidora Hernández',  'contacto@dhernandez.mx', '4421234567', 'ACTIVO',   50000.00, '2026-01-15 10:00:00'),
(2, 'María López Torres',       'maria.lopez@correo.mx',  '3339876543', 'ACTIVO',    5000.00, '2026-02-03 12:30:00'),
(3, 'Tecnología del Bajío SA',  'envios@tecbajio.mx',     '4775551122', 'ACTIVO',   80000.00, '2026-03-20 09:15:00'),
(4, 'Jorge Ramírez Sánchez',    'jorge.ramirez@correo.mx','5512349876', 'ACTIVO',    3000.00, '2026-05-11 17:45:00'),
(5, 'Comercial Ortega',         'ventas@cortega.mx',      '8181112233', 'INACTIVO', 10000.00, '2026-06-01 08:00:00');

-- Direcciones (origen / destino de cada cliente)
INSERT INTO direcciones (direccion_id, cliente_id, tipo, calle, numero, colonia, ciudad, entidad_federativa, codigo_postal) VALUES
(1, 1, 'ORIGEN',  'Av. Constituyentes',          '100',  'Centro',             'Querétaro',   'Querétaro',       '76000'),
(2, 2, 'DESTINO', 'Calle Hidalgo',               '25',   'Centro',             'Guadalajara', 'Jalisco',         '44100'),
(3, 2, 'ORIGEN',  'Av. Vallarta',                '3200', 'Vallarta Poniente',  'Guadalajara', 'Jalisco',         '44110'),
(4, 3, 'ORIGEN',  'Blvd. Adolfo López Mateos',   '1500', 'Jardines del Moral', 'León',        'Guanajuato',      '37160'),
(5, 3, 'DESTINO', 'Calle Madero',                '310',  'Centro',             'León',        'Guanajuato',      '37000'),
(6, 4, 'DESTINO', 'Av. Juárez',                  '45',   'Centro',             'Ciudad de México', 'Ciudad de México', '06000'),
(7, 1, 'DESTINO', 'Calle 5 de Mayo',             '18',   'Centro',             'Querétaro',   'Querétaro',       '76000'),
(8, 5, 'ORIGEN',  'Av. Constitución',            '900',  'Centro',             'Monterrey',   'Nuevo León',      '64000');

-- Almacenes (el almacén 3 tiene capacidad pequeña para probar el trigger)
INSERT INTO almacenes (almacen_id, nombre, ubicacion, capacidad_maxima) VALUES
(1, 'CEDIS Querétaro',       'Parque Industrial Benito Juárez, Querétaro, Qro.', 500),
(2, 'CEDIS Guadalajara',     'El Salto, Jalisco',                                 300),
(3, 'Almacén Express León',  'Blvd. Aeropuerto, León, Gto.',                        3);

-- Envíos
INSERT INTO envios (envio_id, remitente_id, destinatario_id, direccion_origen_id, direccion_destino_id,
                    costo_total, fecha_registro, fecha_entrega, estado) VALUES
(1, 1, 2, 1, 2,  850.00, '2026-10-02 09:00:00', '2026-10-04 15:30:00', 'ENTREGADO'),
(2, 1, 4, 1, 6, 1200.00, '2026-10-10 11:00:00', '2026-10-11 18:00:00', 'ENTREGADO'),
(3, 1, 3, 1, 5,  640.00, '2026-10-20 08:30:00', NULL,                  'EN_TRANSITO'),
(4, 1, 2, 1, 2,  300.00, '2026-10-25 13:00:00', NULL,                  'CANCELADO'),
(5, 2, 1, 3, 7,  450.00, '2026-11-03 10:00:00', NULL,                  'EN_TRANSITO'),
(6, 3, 4, 4, 6,  980.00, '2026-11-05 12:00:00', NULL,                  'EN_TRANSITO'),
(7, 3, 2, 4, 2, 1500.00, '2026-11-06 09:30:00', NULL,                  'EN_TRANSITO'),
(8, 1, 3, 1, 5,  720.00, '2026-11-08 16:00:00', NULL,                  'REGISTRADO');

-- Paquetes
-- Almacén 3 (capacidad 3): 2 paquetes de envíos activos (6 y 7) + 1 de un envío
-- ya ENTREGADO (2), que ya no ocupa espacio. Queda 1 lugar disponible.
INSERT INTO paquetes (paquete_id, envio_id, almacen_id, peso_kg, largo_cm, ancho_cm, alto_cm, contenido) VALUES
(1, 1, 2,     3.50, 40, 30, 20, 'Ropa y textiles'),
(2, 1, 2,     1.20, 30, 20, 10, 'Accesorios'),
(3, 2, 3,     8.00, 60, 40, 40, 'Electrodomésticos pequeños'),
(4, 3, 1,     2.00, 35, 25, 15, 'Documentos y papelería'),
(5, 4, NULL,  1.00, 20, 20, 10, 'Muestras comerciales'),
(6, 5, 2,     5.50, 50, 40, 30, 'Artesanías'),
(7, 6, 3,    12.00, 70, 50, 40, 'Refacciones automotrices'),
(8, 7, 3,     4.30, 45, 35, 25, 'Equipo de cómputo'),
(9, 8, NULL,  2.80, 40, 30, 20, 'Libros');

-- Historial de rastreo
INSERT INTO historial_rastreo (envio_id, fecha, ubicacion_actual, estado_evento, observaciones) VALUES
(1, '2026-10-02 09:00:00', 'Querétaro, Qro.',               'REGISTRADO',  'Envío registrado en sucursal'),
(1, '2026-10-02 14:00:00', 'Querétaro, Qro.',               'RECOLECTADO', 'Recolectado en domicilio del remitente'),
(1, '2026-10-03 08:00:00', 'Autopista 57D, Gto.',           'EN_TRANSITO', NULL),
(1, '2026-10-03 20:00:00', 'CEDIS Guadalajara',             'EN_ALMACEN',  NULL),
(1, '2026-10-04 09:00:00', 'Guadalajara, Jal.',             'EN_REPARTO',  'Asignado a ruta 12'),
(1, '2026-10-04 15:30:00', 'Guadalajara, Jal.',             'ENTREGADO',   'Recibió el titular'),
(2, '2026-10-10 11:00:00', 'Querétaro, Qro.',               'REGISTRADO',  'Envío registrado en sucursal'),
(2, '2026-10-10 16:00:00', 'Querétaro, Qro.',               'EN_TRANSITO', NULL),
(2, '2026-10-11 07:00:00', 'Almacén Express León',          'EN_ALMACEN',  'Transbordo'),
(2, '2026-10-11 10:00:00', 'Ciudad de México',              'EN_REPARTO',  NULL),
(2, '2026-10-11 18:00:00', 'Ciudad de México',              'ENTREGADO',   'Recibió familiar'),
(3, '2026-10-20 08:30:00', 'Querétaro, Qro.',               'REGISTRADO',  'Envío registrado en sucursal'),
(3, '2026-10-20 13:00:00', 'CEDIS Querétaro',               'EN_ALMACEN',  NULL),
(3, '2026-10-21 06:00:00', 'Carretera 45, Gto.',            'EN_TRANSITO', NULL),
(4, '2026-10-25 13:00:00', 'Querétaro, Qro.',               'REGISTRADO',  'Envío registrado en sucursal'),
(4, '2026-10-25 17:00:00', 'Querétaro, Qro.',               'INCIDENCIA',  'Cancelado a solicitud del cliente'),
(5, '2026-11-03 10:00:00', 'Guadalajara, Jal.',             'REGISTRADO',  'Envío registrado en sucursal'),
(5, '2026-11-03 15:00:00', 'CEDIS Guadalajara',             'EN_ALMACEN',  NULL),
(5, '2026-11-04 07:30:00', 'Autopista 80D, Jal.',           'EN_TRANSITO', NULL),
(6, '2026-11-05 12:00:00', 'León, Gto.',                    'REGISTRADO',  'Envío registrado en sucursal'),
(6, '2026-11-05 18:00:00', 'Almacén Express León',          'EN_ALMACEN',  NULL),
(7, '2026-11-06 09:30:00', 'León, Gto.',                    'REGISTRADO',  'Envío registrado en sucursal'),
(7, '2026-11-06 14:00:00', 'Almacén Express León',          'EN_ALMACEN',  NULL),
(7, '2026-11-07 06:00:00', 'Autopista 45D, Gto.',           'EN_TRANSITO', NULL),
(8, '2026-11-08 16:00:00', 'Querétaro, Qro.',               'REGISTRADO',  'Envío registrado en sucursal');

-- Auditoría previa (ajuste manual registrado antes de existir el trigger)
INSERT INTO auditoria_envios (envio_id, costo_anterior, costo_nuevo, usuario, fecha_modificacion) VALUES
(2, 1100.00, 1200.00, 'admin@logiexpress', '2026-10-10 12:00:00');


-- =====================================================================
-- LogiExpress - Procedimientos almacenados
-- Se ejecutan desde DBeaver con CALL (NO se llaman desde la API).
-- =====================================================================
USE logiexpress_db;

-- Asegura que los acentos se guarden correctamente (UTF-8)
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_reporte_mensual_cliente;
DROP PROCEDURE IF EXISTS sp_obtener_hoja_ruta_envio;

DELIMITER //

-- ---------------------------------------------------------------------
-- SP 1: Reporte mensual de un cliente (como remitente)
--   Uso: CALL sp_reporte_mensual_cliente(1, 10, 2026);
--   Resultado 1: resumen (facturación total, envíos entregados y tiempo
--                promedio de entrega).
--   Resultado 2: detalle de los envíos del periodo.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_reporte_mensual_cliente(
    IN p_cliente_id INT,
    IN p_mes        INT,
    IN p_anio       INT
)
BEGIN
    DECLARE v_inicio DATETIME;
    DECLARE v_fin    DATETIME;

    IF NOT EXISTS (SELECT 1 FROM clientes WHERE cliente_id = p_cliente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente indicado no existe';
    END IF;

    IF p_mes IS NULL OR p_mes NOT BETWEEN 1 AND 12 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El mes debe estar entre 1 y 12';
    END IF;

    -- Rango [primer día del mes, primer día del mes siguiente)
    SET v_inicio = DATE_ADD(MAKEDATE(p_anio, 1), INTERVAL (p_mes - 1) MONTH);
    SET v_fin    = DATE_ADD(v_inicio, INTERVAL 1 MONTH);

    -- Resultado 1: resumen del mes
    SELECT
        c.cliente_id,
        c.nombre                                              AS cliente,
        DATE_FORMAT(v_inicio, '%Y-%m')                        AS periodo,
        COUNT(e.envio_id)                                     AS total_envios,
        COALESCE(SUM(e.estado = 'ENTREGADO'), 0)              AS envios_entregados,
        COALESCE(SUM(e.estado IN ('REGISTRADO', 'EN_TRANSITO')), 0) AS envios_en_proceso,
        COALESCE(SUM(e.estado = 'CANCELADO'), 0)              AS envios_cancelados,
        COALESCE(SUM(CASE WHEN e.estado <> 'CANCELADO'
                          THEN e.costo_total END), 0.00)      AS facturacion_total,
        ROUND(AVG(CASE WHEN e.estado = 'ENTREGADO'
                       THEN TIMESTAMPDIFF(MINUTE, e.fecha_registro, e.fecha_entrega) END) / 60, 2)
                                                              AS tiempo_promedio_entrega_horas,
        ROUND(AVG(CASE WHEN e.estado = 'ENTREGADO'
                       THEN TIMESTAMPDIFF(MINUTE, e.fecha_registro, e.fecha_entrega) END) / 1440, 2)
                                                              AS tiempo_promedio_entrega_dias
    FROM clientes c
    LEFT JOIN envios e
           ON e.remitente_id = c.cliente_id
          AND e.fecha_registro >= v_inicio
          AND e.fecha_registro <  v_fin
    WHERE c.cliente_id = p_cliente_id
    GROUP BY c.cliente_id, c.nombre;

    -- Resultado 2: detalle de los envíos del mes
    SELECT
        e.envio_id,
        e.fecha_registro,
        e.fecha_entrega,
        e.estado,
        d.nombre        AS destinatario,
        e.costo_total,
        ROUND(TIMESTAMPDIFF(MINUTE, e.fecha_registro, e.fecha_entrega) / 60, 2) AS horas_entrega
    FROM envios e
    JOIN clientes d ON d.cliente_id = e.destinatario_id
    WHERE e.remitente_id = p_cliente_id
      AND e.fecha_registro >= v_inicio
      AND e.fecha_registro <  v_fin
    ORDER BY e.fecha_registro;
END //

-- ---------------------------------------------------------------------
-- SP 2: Hoja de ruta e historial de un envío
--   Uso: CALL sp_obtener_hoja_ruta_envio(1);
--   Resultado 1: datos generales, remitente y destinatario con direcciones.
--   Resultado 2: desglose de paquetes (peso, dimensiones, almacén).
--   Resultado 3: historial de rastreo en orden cronológico.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_obtener_hoja_ruta_envio(
    IN p_envio_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM envios WHERE envio_id = p_envio_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El envío indicado no existe';
    END IF;

    -- Resultado 1: encabezado, remitente y destinatario
    SELECT
        e.envio_id,
        e.estado,
        e.costo_total,
        e.fecha_registro,
        e.fecha_entrega,
        r.nombre    AS remitente,
        r.telefono  AS telefono_remitente,
        CONCAT_WS(', ', CONCAT_WS(' ', o.calle, o.numero), o.colonia, o.ciudad,
                  o.entidad_federativa, CONCAT('C.P. ', o.codigo_postal))  AS direccion_origen,
        d.nombre    AS destinatario,
        d.telefono  AS telefono_destinatario,
        CONCAT_WS(', ', CONCAT_WS(' ', ds.calle, ds.numero), ds.colonia, ds.ciudad,
                  ds.entidad_federativa, CONCAT('C.P. ', ds.codigo_postal)) AS direccion_destino
    FROM envios e
    JOIN clientes    r  ON r.cliente_id    = e.remitente_id
    JOIN clientes    d  ON d.cliente_id    = e.destinatario_id
    JOIN direcciones o  ON o.direccion_id  = e.direccion_origen_id
    JOIN direcciones ds ON ds.direccion_id = e.direccion_destino_id
    WHERE e.envio_id = p_envio_id;

    -- Resultado 2: desglose de paquetes
    SELECT
        p.paquete_id,
        p.contenido,
        p.peso_kg,
        CONCAT(p.largo_cm, ' x ', p.ancho_cm, ' x ', p.alto_cm, ' cm') AS dimensiones,
        ROUND(p.largo_cm * p.ancho_cm * p.alto_cm / 1000, 2)          AS volumen_litros,
        COALESCE(a.nombre, 'Sin asignar')                               AS almacen
    FROM paquetes p
    LEFT JOIN almacenes a ON a.almacen_id = p.almacen_id
    WHERE p.envio_id = p_envio_id
    ORDER BY p.paquete_id;

    -- Resultado 3: historial cronológico de rastreo
    SELECT
        h.rastreo_id,
        h.fecha,
        h.ubicacion_actual,
        h.estado_evento,
        h.observaciones
    FROM historial_rastreo h
    WHERE h.envio_id = p_envio_id
    ORDER BY h.fecha ASC, h.rastreo_id ASC;
END //

DELIMITER ;


-- =====================================================================
-- LogiExpress - Triggers
-- Se ejecutan automáticamente ante los INSERT/UPDATE que hace la API.
-- =====================================================================
USE logiexpress_db;

-- Asegura que los acentos se guarden correctamente (UTF-8)
SET NAMES utf8mb4;

DROP TRIGGER IF EXISTS after_update_envio_costo;
DROP TRIGGER IF EXISTS before_insert_paquete_almacen;
DROP TRIGGER IF EXISTS after_insert_historial_rastreo;

DELIMITER //

-- ---------------------------------------------------------------------
-- Falla 2: Ajustes de costo sin auditoría
-- Registra en auditoria_envios el costo anterior (OLD), el nuevo (NEW),
-- el usuario y la fecha. El usuario se toma de la variable de sesión
-- @usuario_app (la API la define antes del UPDATE); si no existe se usa
-- el usuario de la conexión MySQL (USER()).
-- ---------------------------------------------------------------------
CREATE TRIGGER after_update_envio_costo
AFTER UPDATE ON envios
FOR EACH ROW
BEGIN
    IF NOT (OLD.costo_total <=> NEW.costo_total) THEN
        INSERT INTO auditoria_envios
            (envio_id, costo_anterior, costo_nuevo, usuario, fecha_modificacion)
        VALUES
            (NEW.envio_id, OLD.costo_total, NEW.costo_total,
             COALESCE(NULLIF(@usuario_app, ''), USER()), NOW());
    END IF;
END //

-- ---------------------------------------------------------------------
-- Falla 1: Descontrol de capacidad
-- Antes de insertar un paquete en un almacén valida que haya espacio.
-- Ocupación = paquetes del almacén cuyos envíos siguen activos
-- (REGISTRADO / EN_TRANSITO); los ENTREGADOS o CANCELADOS ya no ocupan lugar.
-- El SELECT ... FOR UPDATE bloquea la fila del almacén para que dos
-- inserciones simultáneas no rebasen la capacidad.
-- ---------------------------------------------------------------------
CREATE TRIGGER before_insert_paquete_almacen
BEFORE INSERT ON paquetes
FOR EACH ROW
BEGIN
    DECLARE v_capacidad INT;
    DECLARE v_ocupados  INT;
    DECLARE v_nombre    VARCHAR(100);
    DECLARE v_mensaje   VARCHAR(255);

    IF NEW.almacen_id IS NOT NULL THEN
        SELECT capacidad_maxima, nombre
          INTO v_capacidad, v_nombre
          FROM almacenes
         WHERE almacen_id = NEW.almacen_id
         FOR UPDATE;

        IF v_capacidad IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El almacén indicado no existe';
        END IF;

        SELECT COUNT(*)
          INTO v_ocupados
          FROM paquetes p
          JOIN envios e ON e.envio_id = p.envio_id
         WHERE p.almacen_id = NEW.almacen_id
           AND e.estado IN ('REGISTRADO', 'EN_TRANSITO');

        IF v_ocupados >= v_capacidad THEN
            SET v_mensaje = CONCAT('Capacidad excedida: el almacén "', v_nombre,
                                   '" ya tiene ', v_ocupados, ' de ', v_capacidad,
                                   ' paquetes');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
    END IF;
END //

-- ---------------------------------------------------------------------
-- Falla 3: Inconsistencia de estado
-- Al registrar un evento 'ENTREGADO' en el rastreo, actualiza el estado
-- global del envío a 'ENTREGADO' y guarda la fecha de entrega.
-- (Adicional: un evento de movimiento sobre un envío REGISTRADO lo pasa
--  a EN_TRANSITO.)
-- ---------------------------------------------------------------------
CREATE TRIGGER after_insert_historial_rastreo
AFTER INSERT ON historial_rastreo
FOR EACH ROW
BEGIN
    IF NEW.estado_evento = 'ENTREGADO' THEN
        UPDATE envios
           SET estado        = 'ENTREGADO',
               fecha_entrega = NEW.fecha
         WHERE envio_id = NEW.envio_id;
    ELSEIF NEW.estado_evento IN ('RECOLECTADO', 'EN_TRANSITO', 'EN_ALMACEN', 'EN_REPARTO') THEN
        UPDATE envios
           SET estado = 'EN_TRANSITO'
         WHERE envio_id = NEW.envio_id
           AND estado   = 'REGISTRADO';
    END IF;
END //

DELIMITER ;


