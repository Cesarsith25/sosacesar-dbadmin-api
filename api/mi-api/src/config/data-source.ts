import "reflect-metadata";
import { DataSource } from "typeorm";
import { Cliente } from "../entity/Cliente.js";
import { Direccion } from "../entity/Direccion.js";
import { Almacen } from "../entity/Almacen.js";
import { Envio } from "../entity/Envio.js";
import { Paquete } from "../entity/Paquete.js";
import { HistorialRastreo } from "../entity/HistorialRastreo.js";
import { AuditoriaEnvio } from "../entity/AuditoriaEnvio.js";

export const AppDataSource = new DataSource({
    type: "mysql", // O "mariadb"
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    synchronize: false, // Se mantiene false: las tablas, triggers y procedures se crean con los scripts SQL
    logging: true,
    entities: [Cliente, Direccion, Almacen, Envio, Paquete, HistorialRastreo, AuditoriaEnvio],
    subscribers: [],
    migrations: [],
});
