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
