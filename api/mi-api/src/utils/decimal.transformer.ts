import { ValueTransformer } from "typeorm";

/**
 * mysql2 devuelve las columnas DECIMAL como string ("850.00").
 * Este transformer las convierte a number al leer de la BD.
 */
export const decimalTransformer: ValueTransformer = {
    to: (value?: number | null) => value,
    from: (value?: string | null) => (value === null || value === undefined ? value : Number(value)),
};
