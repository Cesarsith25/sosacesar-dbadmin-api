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
