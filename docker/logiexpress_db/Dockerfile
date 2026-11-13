# 1. Imagen base oficial de MySQL
FROM mysql:8.0

# 2. Copiamos los scripts SQL de inicialización al directorio especial.
# Los archivos .sql en esta carpeta se ejecutan en orden alfabético, por eso llevan prefijo numérico:
#   01 tablas -> 02 datos -> 03 procedimientos -> 04 triggers
COPY ./scripts/01_tablas.sql          /docker-entrypoint-initdb.d/
COPY ./scripts/02_valores.sql         /docker-entrypoint-initdb.d/
COPY ./scripts/03_procedimientos.sql  /docker-entrypoint-initdb.d/
COPY ./scripts/04_triggers.sql        /docker-entrypoint-initdb.d/
