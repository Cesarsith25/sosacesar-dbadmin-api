import { Entity, PrimaryGeneratedColumn, Column, OneToMany, Relation } from "typeorm";
import { Direccion } from "./Direccion.js";
import { Envio } from "./Envio.js";
import { decimalTransformer } from "../utils/decimal.transformer.js";

export const ESTADOS_CLIENTE = ["ACTIVO", "INACTIVO"] as const;
export type EstadoCliente = (typeof ESTADOS_CLIENTE)[number];

@Entity("clientes")
export class Cliente {
    @PrimaryGeneratedColumn({ name: "cliente_id" })
    clienteId!: number;

    @Column({ type: "varchar", length: 100, nullable: false })
    nombre!: string;

    @Column({ type: "varchar", length: 100, nullable: false, unique: true })
    email!: string;

    @Column({ type: "varchar", length: 20, nullable: true })
    telefono!: string | null;

    @Column({ type: "enum", enum: ESTADOS_CLIENTE, default: "ACTIVO" })
    estado!: EstadoCliente;

    @Column({ type: "decimal", precision: 10, scale: 2, name: "limite_credito", default: 0.00, transformer: decimalTransformer })
    limiteCredito!: number;

    @Column({ type: "datetime", name: "fecha_registro", default: () => "CURRENT_TIMESTAMP" })
    fechaRegistro!: Date;

    // Relación Uno a Muchos: Un cliente tiene muchas direcciones
    @OneToMany(() => Direccion, (direccion) => direccion.cliente)
    direcciones!: Relation<Direccion[]>;

    // Relación Uno a Muchos: Envíos donde el cliente es remitente
    @OneToMany(() => Envio, (envio) => envio.remitente)
    enviosEnviados!: Relation<Envio[]>;

    // Relación Uno a Muchos: Envíos donde el cliente es destinatario
    @OneToMany(() => Envio, (envio) => envio.destinatario)
    enviosRecibidos!: Relation<Envio[]>;
}
