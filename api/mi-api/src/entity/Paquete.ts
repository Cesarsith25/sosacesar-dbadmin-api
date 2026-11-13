import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Relation } from "typeorm";
import { Envio } from "./Envio.js";
import { Almacen } from "./Almacen.js";
import { decimalTransformer } from "../utils/decimal.transformer.js";

@Entity("paquetes")
export class Paquete {
    @PrimaryGeneratedColumn({ name: "paquete_id" })
    paqueteId!: number;

    @Column({ type: "int", name: "envio_id" })
    envioId!: number;

    @Column({ type: "int", name: "almacen_id", nullable: true })
    almacenId!: number | null;

    @Column({ type: "decimal", precision: 8, scale: 2, name: "peso_kg", transformer: decimalTransformer })
    pesoKg!: number;

    @Column({ type: "decimal", precision: 6, scale: 2, name: "largo_cm", transformer: decimalTransformer })
    largoCm!: number;

    @Column({ type: "decimal", precision: 6, scale: 2, name: "ancho_cm", transformer: decimalTransformer })
    anchoCm!: number;

    @Column({ type: "decimal", precision: 6, scale: 2, name: "alto_cm", transformer: decimalTransformer })
    altoCm!: number;

    @Column({ type: "varchar", length: 200, nullable: false })
    contenido!: string;

    // Relación Muchos a Uno: Muchos paquetes pertenecen a un envío
    @ManyToOne(() => Envio, (envio) => envio.paquetes, { onDelete: "CASCADE" })
    @JoinColumn({ name: "envio_id" })
    envio!: Relation<Envio>;

    // Relación Muchos a Uno: Paquete resguardado en un almacén (opcional)
    @ManyToOne(() => Almacen, (almacen) => almacen.paquetes, { onDelete: "SET NULL", nullable: true })
    @JoinColumn({ name: "almacen_id" })
    almacen!: Relation<Almacen | null>;
}
