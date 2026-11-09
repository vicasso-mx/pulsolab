/*
 PulsoLAB: consultas didácticas para SQL Server.
 Requiere ejecutar primero BD_PulsoLAB.sql.
 Todas las consultas son de solo lectura. Cada bloque puede ejecutarse por separado.
 Datos sintéticos: las distribuciones no son resultados estadísticos reales.
*/
USE PulsoLAB;
GO

/* 01. WHERE filtra FILAS antes de mostrar el resultado. */
SELECT EncuestadoID, Nombre, ApellidoPaterno, Edad, MunicipioAlcaldia
FROM panel.Encuestados
WHERE Edad >= 60
ORDER BY Edad DESC, ApellidoPaterno;
GO

/* 02. AND: ambas condiciones deben cumplirse. */
SELECT EncuestadoID, Nombre, Sexo, Edad, EntidadFederativa
FROM panel.Encuestados
WHERE EntidadFederativa = N'Ciudad de México' AND Edad BETWEEN 18 AND 35
ORDER BY Edad;
GO

/* 03. OR, con paréntesis para fijar la prioridad lógica. */
SELECT EncuestadoID, Nombre, ApellidoPaterno, Edad, EntidadFederativa
FROM panel.Encuestados
WHERE (EntidadFederativa = N'Puebla' OR EntidadFederativa = N'Jalisco')
  AND Edad >= 30
ORDER BY EntidadFederativa, Edad;
GO

/* 04. INNER JOIN: solamente filas con correspondencia en ambas tablas. */
SELECT e.EncuestadoID, CONCAT(e.Nombre, N' ', e.ApellidoPaterno) AS Persona,
       a.Nombre AS Area, g.Nombre AS GradoEstudios
FROM panel.Encuestados AS e
INNER JOIN panel.Area AS a ON a.AreaID = e.AreaID
INNER JOIN panel.GradoEstudios AS g ON g.GradoEstudiosID = e.GradoEstudiosID
WHERE e.Edad >= 50
ORDER BY a.Nombre, Persona;
GO

/* 05. INNER JOIN de cinco tablas: quién contestó qué pregunta y cómo. */
SELECT TOP (100) enc.Titulo, CONCAT(e.Nombre, N' ', e.ApellidoPaterno) AS Persona,
       q.Numero, q.Texto, o.Etiqueta AS Respuesta
FROM instrumento.Encuesta AS enc
INNER JOIN levantamiento.Participacion AS p ON p.EncuestaID = enc.EncuestaID
INNER JOIN panel.Encuestados AS e ON e.EncuestadoID = p.EncuestadoID
INNER JOIN levantamiento.Respuesta AS r ON r.ParticipacionID = p.ParticipacionID
INNER JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
INNER JOIN instrumento.OpcionRespuesta AS o ON o.OpcionID = r.OpcionID
WHERE enc.Titulo = N'Movilidad cotidiana' AND q.TipoPreguntaID = 1
ORDER BY q.Numero, Persona;
GO

/* 06. LEFT JOIN: conserva todas las preguntas, incluso abiertas sin respuesta.
   El filtro de tipo está en ON para no perder preguntas sin correspondencia. */
SELECT q.Numero, q.Texto, COUNT(r.RespuestaID) AS RespuestasDeTexto
FROM instrumento.Pregunta AS q
LEFT JOIN levantamiento.Respuesta AS r
  ON r.PreguntaID = q.PreguntaID AND r.ValorTexto IS NOT NULL
WHERE q.EncuestaID = (SELECT EncuestaID FROM instrumento.Encuesta WHERE Titulo = N'Salud y acceso a servicios')
GROUP BY q.Numero, q.Texto
ORDER BY q.Numero;
GO

/* 07. LEFT JOIN: personas que no contestaron una encuesta específica. */
SELECT e.EncuestadoID, e.Nombre, e.ApellidoPaterno
FROM panel.Encuestados AS e
LEFT JOIN levantamiento.Participacion AS p
  ON p.EncuestadoID = e.EncuestadoID
 AND p.EncuestaID = (SELECT EncuestaID FROM instrumento.Encuesta WHERE Titulo = N'Conectividad digital')
WHERE p.ParticipacionID IS NULL
ORDER BY e.ApellidoPaterno, e.Nombre;
GO

/* 08. RIGHT JOIN: conserva todas las áreas aunque no haya personas. */
SELECT a.Nombre AS Area, COUNT(e.EncuestadoID) AS Personas
FROM panel.Encuestados AS e
RIGHT JOIN panel.Area AS a ON a.AreaID = e.AreaID
GROUP BY a.AreaID, a.Nombre
ORDER BY a.Nombre;
GO

/* 09. FULL OUTER JOIN: conserva ambas listas, con o sin coincidencia.
   Aquí hay coincidencias en la carga; permite explicar NULL de ambos lados. */
SELECT a.Nombre AS Area, e.EncuestadoID, e.Nombre AS Persona
FROM panel.Area AS a
FULL OUTER JOIN panel.Encuestados AS e ON e.AreaID = a.AreaID
ORDER BY a.Nombre, e.EncuestadoID;
GO

/* 10. CROSS JOIN: matriz de encuesta × área, incluyendo combinaciones sin respuestas. */
SELECT enc.Titulo, a.Nombre AS Area, COUNT(p.ParticipacionID) AS Participaciones
FROM instrumento.Encuesta AS enc CROSS JOIN panel.Area AS a
LEFT JOIN panel.Encuestados AS e ON e.AreaID = a.AreaID
LEFT JOIN levantamiento.Participacion AS p ON p.EncuestadoID = e.EncuestadoID
 AND p.EncuestaID = enc.EncuestaID
GROUP BY enc.EncuestaID, enc.Titulo, a.AreaID, a.Nombre
ORDER BY enc.Titulo, a.Nombre;
GO

/* 11. Subconsulta escalar: mayor edad que el promedio general. */
SELECT EncuestadoID, Nombre, Edad
FROM panel.Encuestados
WHERE Edad > (SELECT AVG(CONVERT(decimal(10,2), Edad)) FROM panel.Encuestados)
ORDER BY Edad DESC;
GO

/* 12. Subconsulta IN: personas que respondieron al menos una encuesta de tema digital. */
SELECT e.EncuestadoID, e.Nombre, e.ApellidoPaterno
FROM panel.Encuestados AS e
WHERE e.EncuestadoID IN
 (SELECT p.EncuestadoID FROM levantamiento.Participacion AS p
  JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = p.EncuestaID
  WHERE enc.Titulo IN (N'Conectividad digital', N'Educación y capacitación'))
ORDER BY e.EncuestadoID;
GO

/* 13. EXISTS correlacionada: encuestas con alguna respuesta abierta. */
SELECT enc.EncuestaID, enc.Titulo
FROM instrumento.Encuesta AS enc
WHERE EXISTS
 (SELECT 1 FROM levantamiento.Respuesta AS r
  WHERE r.EncuestaID = enc.EncuestaID AND r.ValorTexto IS NOT NULL)
ORDER BY enc.EncuestaID;
GO

/* 14. NOT EXISTS: participantes que omitieron al menos una pregunta abierta. */
SELECT TOP (50) p.ParticipacionID, enc.Titulo, e.Nombre, e.ApellidoPaterno
FROM levantamiento.Participacion AS p
JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = p.EncuestaID
JOIN panel.Encuestados AS e ON e.EncuestadoID = p.EncuestadoID
WHERE EXISTS
 (SELECT 1 FROM instrumento.Pregunta AS q
  WHERE q.EncuestaID = p.EncuestaID AND q.TipoPreguntaID = 5
    AND NOT EXISTS
      (SELECT 1 FROM levantamiento.Respuesta AS r
       WHERE r.ParticipacionID = p.ParticipacionID AND r.PreguntaID = q.PreguntaID))
ORDER BY p.ParticipacionID;
GO

/* 15. Subconsulta correlacionada: edad superior al promedio de su propia área. */
SELECT e.Nombre, e.Edad, a.Nombre AS Area
FROM panel.Encuestados AS e
JOIN panel.Area AS a ON a.AreaID = e.AreaID
WHERE e.Edad >
 (SELECT AVG(CONVERT(decimal(10,2), x.Edad))
  FROM panel.Encuestados AS x WHERE x.AreaID = e.AreaID)
ORDER BY a.Nombre, e.Edad DESC;
GO

/* 16. Subconsulta derivada: porcentaje de respuestas Sí por encuesta. */
SELECT x.Titulo, x.Total, x.Si,
       CONVERT(decimal(5,2),100.0 * x.Si / NULLIF(x.Total,0)) AS PorcentajeSi
FROM (
 SELECT enc.Titulo, COUNT(*) AS Total,
        SUM(CASE WHEN r.OpcionID = 6 THEN 1 ELSE 0 END) AS Si
 FROM instrumento.Encuesta AS enc
 JOIN levantamiento.Respuesta AS r ON r.EncuestaID = enc.EncuestaID
 WHERE r.TipoPreguntaID = 2
 GROUP BY enc.EncuestaID, enc.Titulo
) AS x
ORDER BY PorcentajeSi DESC;
GO

/* 17. CTE: resumen de participación por encuesta. */
;WITH Participantes AS (
 SELECT EncuestaID, COUNT(*) AS Total
 FROM levantamiento.Participacion GROUP BY EncuestaID
)
SELECT enc.Titulo, p.Total
FROM instrumento.Encuesta AS enc JOIN Participantes AS p ON p.EncuestaID = enc.EncuestaID
ORDER BY enc.Titulo;
GO

/* 18. Dos CTE: cobertura de respuestas obligatorias por encuesta. */
;WITH Esperadas AS (
 SELECT p.EncuestaID, COUNT_BIG(*) AS Total
 FROM levantamiento.Participacion AS p
 JOIN instrumento.Pregunta AS q ON q.EncuestaID = p.EncuestaID AND q.Obligatoria = 1
 GROUP BY p.EncuestaID
), Respondidas AS (
 SELECT r.EncuestaID, COUNT_BIG(*) AS Total
 FROM levantamiento.Respuesta AS r JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
 WHERE q.Obligatoria = 1 GROUP BY r.EncuestaID
)
SELECT enc.Titulo, es.Total AS ObligatoriasEsperadas, rs.Total AS Respondidas,
       CONVERT(decimal(5,2),100.0 * rs.Total / NULLIF(es.Total,0)) AS CoberturaPorcentaje
FROM instrumento.Encuesta AS enc
JOIN Esperadas AS es ON es.EncuestaID = enc.EncuestaID
JOIN Respondidas AS rs ON rs.EncuestaID = enc.EncuestaID
ORDER BY enc.Titulo;
GO

/* 19. CTE y ROW_NUMBER: personas con más encuestas respondidas. */
;WITH Conteos AS (
 SELECT e.EncuestadoID, e.Nombre, e.ApellidoPaterno, COUNT(p.ParticipacionID) AS Total
 FROM panel.Encuestados AS e
 LEFT JOIN levantamiento.Participacion AS p ON p.EncuestadoID = e.EncuestadoID
 GROUP BY e.EncuestadoID, e.Nombre, e.ApellidoPaterno
), Ordenados AS (
 SELECT *, ROW_NUMBER() OVER (ORDER BY Total DESC, EncuestadoID) AS Posicion
 FROM Conteos
)
SELECT Posicion, Nombre, ApellidoPaterno, Total
FROM Ordenados WHERE Posicion <= 20 ORDER BY Posicion;
GO

/* 20. CTE y agregación: promedio de satisfacción por encuesta. */
;WITH Satisfaccion AS (
 SELECT r.EncuestaID, COUNT(*) AS Respuestas,
        AVG(CONVERT(decimal(10,2),o.ValorNumerico)) AS Promedio
 FROM levantamiento.Respuesta AS r
 JOIN instrumento.OpcionRespuesta AS o ON o.OpcionID = r.OpcionID
 WHERE r.TipoPreguntaID = 1
 GROUP BY r.EncuestaID
)
SELECT enc.Titulo, s.Respuestas, CONVERT(decimal(5,2),s.Promedio) AS PromedioDeUnoACinco
FROM Satisfaccion AS s JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = s.EncuestaID
ORDER BY s.Promedio DESC, enc.Titulo;
GO

/* 21. GROUP BY sin HAVING: todas las áreas, con conteo y edad promedio. */
SELECT a.Nombre AS Area, COUNT(*) AS Personas,
       CONVERT(decimal(5,1),AVG(CONVERT(decimal(10,2),e.Edad))) AS EdadPromedio
FROM panel.Encuestados AS e JOIN panel.Area AS a ON a.AreaID = e.AreaID
GROUP BY a.AreaID, a.Nombre
ORDER BY Personas DESC;
GO

/* 22. GROUP BY y HAVING: solamente áreas con 20 o más personas.
   HAVING evalúa el grupo después de agregar. */
SELECT a.Nombre AS Area, COUNT(*) AS Personas
FROM panel.Encuestados AS e JOIN panel.Area AS a ON a.AreaID = e.AreaID
GROUP BY a.AreaID, a.Nombre
HAVING COUNT(*) >= 20
ORDER BY Personas DESC;
GO

/* 23. WHERE + GROUP BY, sin HAVING: se agrupan solo las personas de 40+.
   Las áreas sin personas elegibles desaparecen del resultado. */
SELECT a.Nombre AS Area, COUNT(*) AS PersonasDe40OMas,
       MIN(e.Edad) AS EdadMinima, MAX(e.Edad) AS EdadMaxima
FROM panel.Encuestados AS e JOIN panel.Area AS a ON a.AreaID = e.AreaID
WHERE e.Edad >= 40
GROUP BY a.AreaID, a.Nombre
ORDER BY PersonasDe40OMas DESC;
GO

/* 24. WHERE + GROUP BY + HAVING: primero personas de 40+,
   después solo áreas con 8 o más de esas personas. */
SELECT a.Nombre AS Area, COUNT(*) AS PersonasDe40OMas
FROM panel.Encuestados AS e JOIN panel.Area AS a ON a.AreaID = e.AreaID
WHERE e.Edad >= 40
GROUP BY a.AreaID, a.Nombre
HAVING COUNT(*) >= 8
ORDER BY PersonasDe40OMas DESC;
GO

/* 25. Diferencia práctica: WHERE filtra RESPUESTAS individuales de 4 o 5;
   HAVING exige al menos 100 respuestas favorables por encuesta. */
SELECT enc.Titulo, COUNT(*) AS Favorables
FROM levantamiento.Respuesta AS r
JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = r.EncuestaID
JOIN instrumento.OpcionRespuesta AS o ON o.OpcionID = r.OpcionID
WHERE r.TipoPreguntaID = 1 AND o.ValorNumerico >= 4
GROUP BY enc.EncuestaID, enc.Titulo
HAVING COUNT(*) >= 100
ORDER BY Favorables DESC;
GO

/* 26. Sin HAVING: distribución de opciones para una pregunta concreta. */
SELECT q.Texto, o.Etiqueta, COUNT(*) AS VecesElegida
FROM levantamiento.Respuesta AS r
JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
JOIN instrumento.OpcionRespuesta AS o ON o.OpcionID = r.OpcionID
WHERE q.EncuestaID = 1 AND q.Numero = 1
GROUP BY q.PreguntaID, q.Texto, o.OpcionID, o.Etiqueta
ORDER BY o.OpcionID;
GO

/* 27. Agregados numéricos con WHERE y HAVING:
   filtra ocasiones de 1+ y conserva preguntas con promedio de 6+. */
SELECT enc.Titulo, q.Numero, q.Texto, COUNT(*) AS Respuestas,
       CONVERT(decimal(5,2),AVG(CONVERT(decimal(10,2),r.ValorEntero))) AS PromedioOcasiones
FROM levantamiento.Respuesta AS r
JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = r.EncuestaID
WHERE r.TipoPreguntaID = 4 AND r.ValorEntero >= 1
GROUP BY enc.EncuestaID, enc.Titulo, q.PreguntaID, q.Numero, q.Texto
HAVING AVG(CONVERT(decimal(10,2),r.ValorEntero)) >= 6
ORDER BY PromedioOcasiones DESC;
GO
