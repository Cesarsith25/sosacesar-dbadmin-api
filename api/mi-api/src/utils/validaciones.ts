import { HttpError } from "./http-error.js";

/** Valida un id de ruta o de body (entero positivo). */
export const validarId = (valor: unknown, campo: string): number => {
    const numero = Number(valor);
    if (!Number.isInteger(numero) || numero <= 0) {
        throw new HttpError(400, `${campo} debe ser un entero positivo`);
    }
    return numero;
};

/** Valida un número > 0 (o >= 0 si permitirCero). */
export const validarNumero = (valor: unknown, campo: string, permitirCero = false): number => {
    const numero = typeof valor === "string" && valor.trim() !== "" ? Number(valor) : valor;
    if (typeof numero !== "number" || !Number.isFinite(numero) || numero < 0 || (!permitirCero && numero === 0)) {
        throw new HttpError(400, `${campo} debe ser un número ${permitirCero ? "mayor o igual a 0" : "mayor a 0"}`);
    }
    return numero;
};

/** Valida un texto obligatorio con longitud máxima. */
export const validarTexto = (valor: unknown, campo: string, max: number): string => {
    if (typeof valor !== "string" || valor.trim() === "") {
        throw new HttpError(400, `${campo} es obligatorio`);
    }
    if (valor.trim().length > max) {
        throw new HttpError(400, `${campo} no puede exceder ${max} caracteres`);
    }
    return valor.trim();
};

/** Valida un texto opcional; devuelve null si no viene. */
export const validarTextoOpcional = (valor: unknown, campo: string, max: number): string | null => {
    if (valor === undefined || valor === null || valor === "") return null;
    return validarTexto(valor, campo, max);
};

/** Valida que el valor pertenezca a un ENUM. */
export const validarEnum = <T extends string>(valor: unknown, campo: string, opciones: readonly T[]): T => {
    if (typeof valor !== "string" || !opciones.includes(valor as T)) {
        throw new HttpError(400, `${campo} debe ser uno de: ${opciones.join(", ")}`);
    }
    return valor as T;
};

/** Valida una fecha opcional (ISO 8601). */
export const validarFechaOpcional = (valor: unknown, campo: string): Date | undefined => {
    if (valor === undefined || valor === null || valor === "") return undefined;
    const fecha = new Date(String(valor));
    if (Number.isNaN(fecha.getTime())) {
        throw new HttpError(400, `${campo} no es una fecha válida (usa formato ISO, ej. 2026-11-11T10:30:00)`);
    }
    return fecha;
};
