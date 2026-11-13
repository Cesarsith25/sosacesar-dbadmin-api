import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn, Relation } from "typeorm";
import { Cliente } from "./Cliente.js";
import { Direccion } from "./Direccion.js";
import { Paquete } from "./Paquete.js";
import { HistorialRastreo } from "./HistorialRastreo.js";
import { AuditoriaEnvio } from "./AuditoriaEnvio.js";
import { decimalTransformer } from "../utils/decimal.transformer.js";

export const ESTADOS_ENVIO = ["REGISTRADO", "EN_TRANSITO", "ENTREGADO", "CANCELADO"] as const;
export type EstadoEnvio = (typeof ESTADOS_ENVIO)[number];

@Entity("envios")
export class Envio {
    @PrimaryGeneratedColumn({ name: "envio_id" })
    envioId!: number;

    @Column({ type: "int", name: "remitente_id" })
    remitenteId!: number;

    @Column({ type: "int", name: "destinatario_id" })
    destinatarioId!: number;

    @Column({ type: "int", name: "direccion_origen_id" })
    direccionOrigenId!: number;

    @Column({ type: "int", name: "direccion_destino_id" })
    direccionDestinoId!: number;

    @Column({ type: "decimal", precision: 10, scale: 2, name: "costo_total", default: 0.00, transformer: decimalTransformer })
    costoTotal!: number;

    @Column({ type: "datetime", name: "fecha_registro", default: () => "CURRENT_TIMESTAMP" })
    fechaRegistro!: Date;

    @Column({ type: "datetime", name: "fecha_entrega", nullable: true })
    fechaEntrega!: Date | null;

    @Column({ type: "enum", enum: ESTADOS_ENVIO, default: "REGISTRADO" })
    estado!: EstadoEnvio;

    // Relación Muchos a Uno: Cliente que envía
    @ManyToOne(() => Cliente, (cliente) => cliente.enviosEnviados)
    @JoinColumn({ name: "remitente_id" })
    remitente!: Relation<Cliente>;

    // Relación Muchos a Uno: Cliente que recibe
    @ManyToOne(() => Cliente, (cliente) => cliente.enviosRecibidos)
    @JoinColumn({ name: "destinatario_id" })
    destinatario!: Relation<Cliente>;

    // Relación Muchos a Uno: Dirección de origen
    @ManyToOne(() => Direccion)
    @JoinColumn({ name: "direccion_origen_id" })
    direccionOrigen!: Relation<Direccion>;

    // Relación Muchos a Uno: Dirección de destino
    @ManyToOne(() => Direccion)
    @JoinColumn({ name: "direccion_destino_id" })
    direccionDestino!: Relation<Direccion>;

    // Relación Uno a Muchos: Paquetes del envío
    @OneToMany(() => Paquete, (paquete) => paquete.envio)
    paquetes!: Relation<Paquete[]>;

    // Relación Uno a Muchos: Bitácora de rastreo
    @OneToMany(() => HistorialRastreo, (rastreo) => rastreo.envio)
    historial!: Relation<HistorialRastreo[]>;

    // Relación Uno a Muchos: Cambios de costo auditados
    @OneToMany(() => AuditoriaEnvio, (auditoria) => auditoria.envio)
    auditorias!: Relation<AuditoriaEnvio[]>;
}
