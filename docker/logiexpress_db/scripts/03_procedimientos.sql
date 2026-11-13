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
