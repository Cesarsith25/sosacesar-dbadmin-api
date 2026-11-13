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
