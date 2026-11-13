import { Response } from "express";
import { QueryFailedError } from "typeorm";

/**
 * Error controlado que lanzan los servicios (404, 400, ...).
 */
export class HttpError extends Error {
    constructor(public readonly status: number, message: string) {
        super(message);
        this.name = "HttpError";
    }
}

interface MysqlDriverError extends Error {
    code?: string;      // ej. 'ER_SIGNAL_EXCEPTION'
    errno?: number;     // ej. 1644
    sqlState?: string;  // ej. '45000'
    sqlMessage?: string;
}

const getDriverError = (error: unknown): MysqlDriverError | null => {
    if (error instanceof QueryFailedError) {
        return error.driverError as MysqlDriverError;
    }
    return null;
};

/**
 * true si el error viene de un SIGNAL SQLSTATE '45000' lanzado por un trigger.
 */
export const esErrorDeTrigger = (error: unknown): boolean => {
    return getDriverError(error)?.sqlState === "45000";
};

/**
 * Convierte cualquier error en una respuesta JSON con el código HTTP adecuado.
 *  - HttpError                 -> su propio status
 *  - SIGNAL SQLSTATE '45000'   -> 400 Bad Request (mensaje del trigger)
 *  - FK inexistente            -> 400 Bad Request
 *  - Otro                      -> 500
 */
export const responderError = (resp: Response, error: unknown) => {
    if (error instanceof HttpError) {
        return resp.status(error.status).json({ message: error.message, status: error.status });
    }

    const driverError = getDriverError(error);

    if (driverError?.sqlState === "45000") {
        return resp.status(400).json({
            message: driverError.sqlMessage ?? driverError.message,
            status: 400,
            error: "TRIGGER_45000",
        });
    }

    if (driverError?.code === "ER_NO_REFERENCED_ROW_2") {
        return resp.status(400).json({
            message: "Alguna referencia (FK) no existe en la base de datos",
            status: 400,
        });
    }

    if (driverError?.code === "ER_CHECK_CONSTRAINT_VIOLATED") {
        return resp.status(400).json({
            message: driverError.sqlMessage ?? "Los datos no cumplen las restricciones de la tabla",
            status: 400,
        });
    }

    console.error(error);
    return resp.status(500).json({ message: "Error interno del servidor", status: 500 });
};
