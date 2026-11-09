/* PulsoLAB - asignación de personas a encuestas.
   BD_PulsoLAB.sql ya crea este procedimiento; este archivo permite revisarlo o recrearlo. */
USE PulsoLAB;
GO

/* Asigna una persona a una encuesta sin registrar una respuesta.
   @AsignacionNueva = 1 si se creó, 0 si ya existía. La llave primaria
   compuesta impide duplicados; UPDLOCK/HOLDLOCK evita la carrera al consultar. */
CREATE OR ALTER PROCEDURE levantamiento.usp_AsignarEncuestadoAEncuesta
    @EncuestaID smallint,
    @EncuestadoID int,
    @AsignacionNueva bit = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM instrumento.Encuesta WHERE EncuestaID = @EncuestaID)
            THROW 51010, N'La encuesta indicada no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM panel.Encuestados WHERE EncuestadoID = @EncuestadoID)
            THROW 51011, N'El encuestado indicado no existe.', 1;

        IF EXISTS (
            SELECT 1
            FROM levantamiento.AsignacionEncuesta WITH (UPDLOCK, HOLDLOCK)
            WHERE EncuestaID = @EncuestaID AND EncuestadoID = @EncuestadoID
        )
        BEGIN
            SET @AsignacionNueva = 0;
        END
        ELSE
        BEGIN
            INSERT levantamiento.AsignacionEncuesta (EncuestaID, EncuestadoID)
            VALUES (@EncuestaID, @EncuestadoID);
            SET @AsignacionNueva = 1;
        END;

        COMMIT TRANSACTION;

        SELECT a.EncuestaID, enc.Titulo, a.EncuestadoID,
               e.Nombre, e.ApellidoPaterno, a.FechaAsignacionUTC,
               @AsignacionNueva AS AsignacionNueva
        FROM levantamiento.AsignacionEncuesta AS a
        JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = a.EncuestaID
        JOIN panel.Encuestados AS e ON e.EncuestadoID = a.EncuestadoID
        WHERE a.EncuestaID = @EncuestaID AND a.EncuestadoID = @EncuestadoID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
