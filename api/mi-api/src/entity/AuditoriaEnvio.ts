import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Relation } from "typeorm";
import { Envio } from "./Envio.js";
import { decimalTransformer } from "../utils/decimal.transformer.js";

// Esta tabla la llena el trigger after_update_envio_costo; la API solo la consulta.
@Entity("auditoria_envios")
export class AuditoriaEnvio {
    @PrimaryGeneratedColumn({ name: "auditoria_id" })
    auditoriaId!: number;

    @Column({ type: "int", name: "envio_id" })
    envioId!: number;

    @Column({ type: "decimal", precision: 10, scale: 2, name: "costo_anterior", transformer: decimalTransformer })
    costoAnterior!: number;

    @Column({ type: "decimal", precision: 10, scale: 2, name: "costo_nuevo", transformer: decimalTransformer })
    costoNuevo!: number;

    @Column({ type: "varchar", length: 100, nullable: false })
    usuario!: string;

    @Column({ type: "datetime", name: "fecha_modificacion", default: () => "CURRENT_TIMESTAMP" })
    fechaModificacion!: Date;

    // Relación Muchos a Uno: Muchos registros de auditoría pertenecen a un envío
    @ManyToOne(() => Envio, (envio) => envio.auditorias, { onDelete: "CASCADE" })
    @JoinColumn({ name: "envio_id" })
    envio!: Relation<Envio>;
}
