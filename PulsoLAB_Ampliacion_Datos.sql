/* PulsoLAB - ampliación didáctica para una base creada con la versión inicial.
   Agrega 100 encuestados, 3 áreas sin personas, 2 encuestas sin participantes,
   participantes variables y respuestas obligatorias pendientes.
   Cambia algunas respuestas preexistentes para simular cuestionarios parciales.
   Ejecutar UNA VEZ. Si la base ya contiene la ampliación, se detiene.
   BD_PulsoLAB.sql ya incluye estos datos: en una base creada con ese script
   no hace falta ejecutar este archivo y se detendrá con el error 51001.
*/
USE PulsoLAB;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF EXISTS (SELECT 1 FROM instrumento.Encuesta WHERE Titulo = N'Bienestar en personas mayores')
    THROW 51001, N'La ampliación ya fue aplicada.', 1;
 IF (SELECT COUNT(*) FROM panel.Encuestados) <> 200
    THROW 51002, N'Se esperaba la carga inicial de 200 encuestados; revise antes de ampliar.', 1;
 IF EXISTS (SELECT 1 FROM panel.Encuestados WHERE EncuestadoID > 200)
    THROW 51003, N'Ya existen identificadores posteriores al 200; revise antes de ampliar.', 1;
 ALTER TABLE panel.Encuestados ALTER COLUMN AreaID smallint NULL;

/* Ampliación didáctica: áreas sin personas, personas sin área y nuevas encuestas. */
INSERT panel.Area (Nombre, Descripcion) VALUES
 (N'Corredor industrial', N'Área pendiente de incorporación al padrón'),
 (N'Zona lacustre', N'Área pendiente de incorporación al padrón'),
 (N'Franja metropolitana', N'Área pendiente de incorporación al padrón');

/* El ÁreaID nulo significa que el registro todavía no fue clasificado.
   No se permite un ÁreaID inexistente: permanece la llave foránea. */
;WITH Nombres AS (
 SELECT f.Orden AS OrdenNombre, f.Nombre,
        s.Orden AS OrdenApellido, s.Paterno, s.Materno,
        (f.Orden - 1) * 10 + s.Orden AS n
 FROM (VALUES
  (1,N'Itzel'),(2,N'Fernanda'),(3,N'Beatriz'),(4,N'Karla'),(5,N'Norma'),
  (6,N'Arturo'),(7,N'Iván'),(8,N'Roberto'),(9,N'Omar'),(10,N'Andrés')
 ) AS f(Orden,Nombre)
 CROSS JOIN (VALUES
  (1,N'Aguilar',N'Velasco'),(2,N'Bautista',N'Camacho'),
  (3,N'Cervantes',N'Zamora'),(4,N'Domínguez',N'Acosta'),
  (5,N'Escobar',N'Trejo'),(6,N'Fuentes',N'Campos'),
  (7,N'Guerrero',N'Salinas'),(8,N'Herrera',N'Mejía'),
  (9,N'Ibarra',N'Contreras'),(10,N'Juárez',N'Valdez')
 ) AS s(Orden,Paterno,Materno)
), Asignados AS (
 SELECT *, CASE WHEN n <= 25 THEN 1
                WHEN n <= 45 THEN 2
                WHEN n <= 60 THEN 3
                WHEN n <= 70 THEN 4
                WHEN n <= 78 THEN 5
                WHEN n <= 85 THEN 6
                WHEN n <= 90 THEN 7
                WHEN n <= 92 THEN 8
                ELSE NULL END AS AreaAsignada
 FROM Nombres
)
INSERT panel.Encuestados
 (Nombre, ApellidoPaterno, ApellidoMaterno, Edad, Sexo, GradoEstudiosID,
  AreaID, EntidadFederativa, MunicipioAlcaldia, Ocupacion)
SELECT Nombre, Paterno, Materno,
       CONVERT(tinyint,20 + (n * 13 + COALESCE(AreaAsignada,11) * 7) % 61),
       CASE WHEN OrdenNombre <= 5 THEN 'M' ELSE 'H' END,
       CONVERT(tinyint,1 + (n * 3) % 8), AreaAsignada,
       CASE WHEN n % 4 = 0 THEN N'Estado de México' ELSE N'Ciudad de México' END,
       CASE WHEN n % 4 = 0 THEN N'Nezahualcóyotl'
            WHEN n % 3 = 0 THEN N'Xochimilco' ELSE N'Iztapalapa' END,
       CASE n % 5 WHEN 0 THEN N'Estudiante' WHEN 1 THEN N'Empleado/a'
            WHEN 2 THEN N'Comerciante' WHEN 3 THEN N'Docente'
            ELSE N'Trabajador/a independiente' END
FROM Asignados;

/* Dos encuestas con cuestionario publicado y sin participantes. */
INSERT instrumento.Encuesta (Titulo, Objetivo, FechaInicio, FechaFin) VALUES
 (N'Bienestar en personas mayores', N'Explorar acceso a actividades y servicios; pendiente de levantamiento', '2026-07-01','2026-09-30'),
 (N'Participación cultural local', N'Explorar uso de actividades culturales; pendiente de levantamiento', '2026-07-01','2026-09-30');
INSERT instrumento.Pregunta (EncuestaID, Numero, Texto, TipoPreguntaID, Obligatoria)
SELECT enc.EncuestaID, q.Numero, q.Texto, q.TipoPreguntaID, q.Obligatoria
FROM instrumento.Encuesta AS enc
CROSS JOIN instrumento.Pregunta AS q
WHERE enc.Titulo IN (N'Bienestar en personas mayores',N'Participación cultural local')
  AND q.EncuestaID = (SELECT EncuestaID FROM instrumento.Encuesta WHERE Titulo = N'Salud y acceso a servicios');

/* Agrega 0, 2, 4, ... 18 participantes a las diez encuestas originales.
   Las 12 encuestas muestran desde 0 hasta 98 participaciones. */
;WITH N AS (
 SELECT TOP (18) ROW_NUMBER() OVER (ORDER BY object_id) AS n
 FROM sys.all_objects
)
INSERT levantamiento.Participacion (EncuestaID, EncuestadoID, FechaRespuesta)
SELECT enc.EncuestaID, 200 + ((enc.EncuestaID * 7 + n.n - 1) % 100) + 1,
       DATEADD(minute, n.n * 17,
               DATEADD(day, (enc.EncuestaID * 5 + n.n) % 70,
                       CONVERT(datetime2(0),'2026-04-01T10:00:00')))
FROM instrumento.Encuesta AS enc CROSS JOIN N AS n
WHERE enc.EncuestaID <= 10 AND n.n <= 2 * (enc.EncuestaID - 1);

/* Las personas nuevas responden igual que las originales. */
INSERT levantamiento.Respuesta
 (ParticipacionID, EncuestaID, PreguntaID, TipoPreguntaID, OpcionID, ValorEntero, ValorTexto)
SELECT p.ParticipacionID, p.EncuestaID, q.PreguntaID, q.TipoPreguntaID,
 CASE q.TipoPreguntaID
   WHEN 1 THEN CONVERT(tinyint,1 + (p.EncuestadoID + q.Numero * 3) % 5)
   WHEN 2 THEN CONVERT(tinyint,6 + (p.EncuestadoID + q.Numero) % 2)
   WHEN 3 THEN CONVERT(tinyint,8 + (p.EncuestadoID * 2 + q.Numero) % 5)
 END,
 CASE WHEN q.TipoPreguntaID = 4
      THEN CONVERT(int,(p.EncuestadoID * 3 + q.Numero * 7) % 13) END,
 CASE WHEN q.TipoPreguntaID = 5 THEN
      N'Mejorar la disponibilidad y el seguimiento de los servicios.' END
FROM levantamiento.Participacion AS p
JOIN instrumento.Pregunta AS q ON q.EncuestaID = p.EncuestaID
WHERE p.EncuestadoID > 200
  AND (q.TipoPreguntaID <> 5 OR (p.EncuestadoID + q.Numero) % 4 = 0);

/* Algunos cuestionarios están parcialmente contestados. El criterio cambia
   entre encuestas y conserva diferentes porcentajes de cobertura. */
DELETE r
FROM levantamiento.Respuesta AS r
JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
WHERE q.Obligatoria = 1
  AND r.EncuestaID BETWEEN 2 AND 10
  AND (r.ParticipacionID + q.Numero * 3) % (r.EncuestaID + 3) = 0;

 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT > 0 ROLLBACK;
 THROW;
END CATCH;
GO

/* Diagnóstico posterior a la ampliación. */
SELECT (SELECT COUNT(*) FROM panel.Encuestados) AS Encuestados,
       (SELECT COUNT(*) FROM panel.Encuestados WHERE AreaID IS NULL) AS SinArea,
       (SELECT COUNT(*) FROM instrumento.Encuesta) AS Encuestas;
SELECT enc.Titulo, COUNT(p.ParticipacionID) AS Participantes
FROM instrumento.Encuesta AS enc LEFT JOIN levantamiento.Participacion AS p
 ON p.EncuestaID = enc.EncuestaID
GROUP BY enc.EncuestaID, enc.Titulo ORDER BY enc.EncuestaID;
GO
