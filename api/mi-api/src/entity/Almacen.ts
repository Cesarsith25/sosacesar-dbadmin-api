import { Entity, PrimaryGeneratedColumn, Column, OneToMany, Relation } from "typeorm";
import { Paquete } from "./Paquete.js";

@Entity("almacenes")
export class Almacen {
    @PrimaryGeneratedColumn({ name: "almacen_id" })
    almacenId!: number;

    @Column({ type: "varchar", length: 100, nullable: false, unique: true })
    nombre!: string;

    @Column({ type: "varchar", length: 150, nullable: false })
    ubicacion!: string;

    @Column({ type: "int", name: "capacidad_maxima", nullable: false })
    capacidadMaxima!: number;

    // Relación Uno a Muchos: Un almacén resguarda muchos paquetes
    @OneToMany(() => Paquete, (paquete) => paquete.almacen)
    paquetes!: Relation<Paquete[]>;
}
