/* PulsoLAB - demostración de búsqueda vectorial.
   Requiere SQL Server 2025 (tipo vector) y haber ejecutado BD_PulsoLAB.sql.
   Se puede repetir sin duplicar filas. */
USE PulsoLAB;
GO

IF OBJECT_ID(N'instrumento.PreguntaVectoresDemo', N'U') IS NULL
    CREATE TABLE instrumento.PreguntaVectoresDemo (
        PreguntaID int NOT NULL CONSTRAINT PK_PreguntaVectoresDemo PRIMARY KEY,
        VectorTema vector(3) NOT NULL,
        CONSTRAINT FK_PreguntaVectoresDemo_Pregunta FOREIGN KEY (PreguntaID)
            REFERENCES instrumento.Pregunta(PreguntaID)
    );


GO

INSERT INTO instrumento.PreguntaVectoresDemo (PreguntaID, VectorTema)
SELECT q.PreguntaID, CAST(v.VectorManual AS vector(3))
FROM (VALUES
    (N'Salud y acceso a servicios',  1, N'[0.95,0.10,0.10]'),
    (N'Seguridad en la colonia',     1, N'[0.10,0.95,0.15]'),
    (N'Movilidad cotidiana',         1, N'[0.10,0.20,0.95]'),
    (N'Agua y saneamiento',          1, N'[0.75,0.10,0.15]')
) AS v(Titulo, Numero, VectorManual)
JOIN instrumento.Encuesta AS e ON e.Titulo = v.Titulo
JOIN instrumento.Pregunta AS q ON q.EncuestaID = e.EncuestaID AND q.Numero = v.Numero
WHERE NOT EXISTS
      (SELECT 1 FROM instrumento.PreguntaVectoresDemo AS d
       WHERE d.PreguntaID = q.PreguntaID);




SELECT e.Titulo, q.Numero, q.Texto, d.VectorTema
FROM instrumento.PreguntaVectoresDemo AS d
JOIN instrumento.Pregunta AS q ON q.PreguntaID = d.PreguntaID
JOIN instrumento.Encuesta AS e ON e.EncuestaID = q.EncuestaID
ORDER BY e.EncuestaID;
GO

