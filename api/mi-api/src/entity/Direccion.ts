import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Relation } from "typeorm";
import { Cliente } from "./Cliente.js";

export const TIPOS_DIRECCION = ["ORIGEN", "DESTINO"] as const;
export type TipoDireccion = (typeof TIPOS_DIRECCION)[number];

@Entity("direcciones")
export class Direccion {
    @PrimaryGeneratedColumn({ name: "direccion_id" })
    direccionId!: number;

    @Column({ type: "int", name: "cliente_id" })
    clienteId!: number;

    @Column({ type: "enum", enum: TIPOS_DIRECCION })
    tipo!: TipoDireccion;

    @Column({ type: "varchar", length: 150, nullable: false })
    calle!: string;

    @Column({ type: "varchar", length: 10, nullable: true })
    numero!: string | null;

    @Column({ type: "varchar", length: 100, nullable: true })
    colonia!: string | null;

    @Column({ type: "varchar", length: 80, nullable: false })
    ciudad!: string;

    @Column({ type: "varchar", length: 80, name: "entidad_federativa", nullable: false })
    entidadFederativa!: string;

    @Column({ type: "varchar", length: 10, name: "codigo_postal", nullable: false })
    codigoPostal!: string;

    // Relación Muchos a Uno: Muchas direcciones pertenecen a un cliente
    @ManyToOne(() => Cliente, (cliente) => cliente.direcciones, { onDelete: "CASCADE" })
    @JoinColumn({ name: "cliente_id" })
    cliente!: Relation<Cliente>;
}
