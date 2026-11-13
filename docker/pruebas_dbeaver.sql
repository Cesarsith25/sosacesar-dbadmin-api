-- =====================================================================
-- LogiExpress - Pruebas para ejecutar en DBeaver
-- Conexión: localhost:3307, usuario root, base logiexpress_db
-- Ejecuta cada bloque con Ctrl+Enter (o el script completo con Alt+X).
-- =====================================================================
USE logiexpress_db;

-- ---------------------------------------------------------------------
-- PROCEDURE 1: Reporte mensual de cliente (cliente, mes, año)
-- Con los datos iniciales, cliente 1 en octubre 2026 debe dar:
--   total_envios = 4, envios_entregados = 2, facturacion_total = 2690.00,
--   tiempo_promedio_entrega_horas = 42.75
-- ---------------------------------------------------------------------
CALL sp_reporte_mensual_cliente(1, 10, 2026);
CALL sp_reporte_mensual_cliente(3, 11, 2026);

-- Errores controlados (SIGNAL 45000)
-- CALL sp_reporte_mensual_cliente(99, 10, 2026);  -- cliente inexistente
-- CALL sp_reporte_mensual_cliente(1, 13, 2026);   -- mes inválido

-- ---------------------------------------------------------------------
-- PROCEDURE 2: Hoja de ruta de un envío (3 resultados: encabezado,
-- paquetes e historial cronológico)
-- ---------------------------------------------------------------------
CALL sp_obtener_hoja_ruta_envio(1);
CALL sp_obtener_hoja_ruta_envio(7);
-- CALL sp_obtener_hoja_ruta_envio(999);           -- envío inexistente

-- ---------------------------------------------------------------------
-- Verificar los objetos creados
-- ---------------------------------------------------------------------
SHOW TRIGGERS FROM logiexpress_db;
SHOW PROCEDURE STATUS WHERE Db = 'logiexpress_db';

-- ---------------------------------------------------------------------
-- (Opcional) Probar los triggers directamente en SQL sin dejar cambios.
-- La API los dispara solos; esto solo sirve para verlos en DBeaver.
-- ---------------------------------------------------------------------
START TRANSACTION;

-- after_update_envio_costo
SET @usuario_app = 'prueba.dbeaver';
UPDATE envios SET costo_total = costo_total + 50 WHERE envio_id = 3;
SET @usuario_app = NULL;
SELECT * FROM auditoria_envios WHERE envio_id = 3 ORDER BY auditoria_id DESC;

-- after_insert_historial_rastreo
INSERT INTO historial_rastreo (envio_id, ubicacion_actual, estado_evento, observaciones)
VALUES (3, 'León, Gto.', 'ENTREGADO', 'Prueba DBeaver');
SELECT envio_id, estado, fecha_entrega FROM envios WHERE envio_id = 3;

-- before_insert_paquete_almacen
-- (el almacén 3 tiene capacidad 3 y 2 paquetes activos: el 1er INSERT pasa,
--  el 2o falla con Error 1644 / SQLSTATE 45000)
INSERT INTO paquetes (envio_id, almacen_id, peso_kg, largo_cm, ancho_cm, alto_cm, contenido)
VALUES (8, 3, 1.00, 10, 10, 10, 'Prueba cabe');
INSERT INTO paquetes (envio_id, almacen_id, peso_kg, largo_cm, ancho_cm, alto_cm, contenido)
VALUES (8, 3, 1.00, 10, 10, 10, 'Prueba no cabe');

-- Si DBeaver se detiene en el error anterior, ejecuta esta línea a mano
-- para deshacer todas las pruebas del bloque:
ROLLBACK;
