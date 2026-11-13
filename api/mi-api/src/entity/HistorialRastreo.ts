import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Relation } from "typeorm";
import { Envio } from "./Envio.js";

export const ESTADOS_EVENTO = [
    "REGISTRADO", "RECOLECTADO", "EN_TRANSITO", "EN_ALMACEN", "EN_REPARTO", "ENTREGADO", "INCIDENCIA",
] as const;
export type EstadoEvento = (typeof ESTADOS_EVENTO)[number];

@Entity("historial_rastreo")
export class HistorialRastreo {
    @PrimaryGeneratedColumn({ name: "rastreo_id" })
    rastreoId!: number;

    @Column({ type: "int", name: "envio_id" })
    envioId!: number;

    @Column({ type: "datetime", default: () => "CURRENT_TIMESTAMP" })
    fecha!: Date;

    @Column({ type: "varchar", length: 150, name: "ubicacion_actual", nullable: false })
    ubicacionActual!: string;

    @Column({ type: "enum", enum: ESTADOS_EVENTO, name: "estado_evento" })
    estadoEvento!: EstadoEvento;

    @Column({ type: "varchar", length: 255, nullable: true })
    observaciones!: string | null;

    // Relación Muchos a Uno: Muchos eventos de rastreo pertenecen a un envío
    @ManyToOne(() => Envio, (envio) => envio.historial, { onDelete: "CASCADE" })
    @JoinColumn({ name: "envio_id" })
    envio!: Relation<Envio>;
}
