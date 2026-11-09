/*
 Base didáctica de encuestas, SQL Server 2016 SP1 o posterior.
 Datos ficticios. Los temas se inspiraron en áreas investigadas por INEGI;
 las preguntas, el diseño y las respuestas son originales y no representan
 cuestionarios oficiales, estimaciones ni una muestra probabilística.
 Referencias: https://www.inegi.org.mx/programas/ensu/
              https://www.inegi.org.mx/programas/endutih/2025/
 Ejecutar en una ventana nueva de SSMS con permisos CREATE DATABASE.
 La base PulsoLAB se crea si no existe. La carga exige que
 aún no existan tablas del modelo; repetirla no modifica datos previos.
 Esquemas: panel (personas), instrumento (cuestionarios),
           levantamiento (asignaciones y respuestas), analitica (vistas sin datos personales).
*/
USE master;
GO
IF DB_ID(N'PulsoLAB') IS NULL
    EXEC(N'CREATE DATABASE PulsoLAB');
GO
USE PulsoLAB;
GO
SET XACT_ABORT ON;
BEGIN TRY
IF OBJECT_ID(N'instrumento.Encuesta', N'U') IS NOT NULL OR OBJECT_ID(N'dbo.Encuesta', N'U') IS NOT NULL
    THROW 51000, N'El modelo ya existe. La carga no se repetirá.', 1;
BEGIN TRAN;

EXEC(N'CREATE SCHEMA panel AUTHORIZATION dbo');
EXEC(N'CREATE SCHEMA instrumento AUTHORIZATION dbo');
EXEC(N'CREATE SCHEMA levantamiento AUTHORIZATION dbo');
EXEC(N'CREATE SCHEMA analitica AUTHORIZATION dbo');

CREATE TABLE panel.Area (
 AreaID smallint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Area PRIMARY KEY,
 Nombre nvarchar(100) NOT NULL CONSTRAINT UQ_Area_Nombre UNIQUE,
 Descripcion nvarchar(250) NULL
);
CREATE TABLE panel.GradoEstudios (
 GradoEstudiosID tinyint NOT NULL CONSTRAINT PK_GradoEstudios PRIMARY KEY,
 Nombre nvarchar(80) NOT NULL CONSTRAINT UQ_GradoEstudios_Nombre UNIQUE
);
CREATE TABLE panel.Encuestados (
 EncuestadoID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Encuestados PRIMARY KEY,
 Nombre nvarchar(60) NOT NULL,
 ApellidoPaterno nvarchar(60) NOT NULL,
 ApellidoMaterno nvarchar(60) NOT NULL,
 Edad tinyint NOT NULL CONSTRAINT CK_Encuestados_Edad CHECK (Edad BETWEEN 18 AND 85),
 Sexo char(1) NOT NULL CONSTRAINT CK_Encuestados_Sexo CHECK (Sexo IN ('M','H','X')),
 GradoEstudiosID tinyint NOT NULL CONSTRAINT FK_Encuestados_GradoEstudios REFERENCES panel.GradoEstudios(GradoEstudiosID),
 AreaID smallint NULL CONSTRAINT FK_Encuestados_Area REFERENCES panel.Area(AreaID),
 EntidadFederativa nvarchar(80) NOT NULL,
 MunicipioAlcaldia nvarchar(100) NOT NULL,
 Ocupacion nvarchar(80) NOT NULL
);
CREATE TABLE instrumento.Encuesta (
 EncuestaID smallint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Encuesta PRIMARY KEY,
 Titulo nvarchar(150) NOT NULL CONSTRAINT UQ_Encuesta_Titulo UNIQUE,
 Objetivo nvarchar(300) NOT NULL,
 FechaInicio date NOT NULL,
 FechaFin date NOT NULL,
 CONSTRAINT CK_Encuesta_Fechas CHECK (FechaFin >= FechaInicio)
);
CREATE TABLE instrumento.TipoPregunta (
 TipoPreguntaID tinyint NOT NULL CONSTRAINT PK_TipoPregunta PRIMARY KEY,
 Nombre nvarchar(60) NOT NULL CONSTRAINT UQ_TipoPregunta_Nombre UNIQUE
);
CREATE TABLE instrumento.OpcionRespuesta (
 OpcionID tinyint NOT NULL,
 TipoPreguntaID tinyint NOT NULL CONSTRAINT FK_Opcion_Tipo REFERENCES instrumento.TipoPregunta(TipoPreguntaID),
 Etiqueta nvarchar(100) NOT NULL,
 ValorNumerico tinyint NULL,
 CONSTRAINT PK_Opcion PRIMARY KEY (OpcionID),
 CONSTRAINT UQ_Opcion_Tipo UNIQUE (OpcionID, TipoPreguntaID),
 CONSTRAINT UQ_Opcion_Etiqueta UNIQUE (TipoPreguntaID, Etiqueta)
);
CREATE TABLE instrumento.Pregunta (
 PreguntaID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pregunta PRIMARY KEY,
 EncuestaID smallint NOT NULL CONSTRAINT FK_Pregunta_Encuesta REFERENCES instrumento.Encuesta(EncuestaID),
 Numero smallint NOT NULL,
 Texto nvarchar(400) NOT NULL,
 TipoPreguntaID tinyint NOT NULL CONSTRAINT FK_Pregunta_Tipo REFERENCES instrumento.TipoPregunta(TipoPreguntaID),
 Obligatoria bit NOT NULL CONSTRAINT DF_Pregunta_Obligatoria DEFAULT (1),
 CONSTRAINT UQ_Pregunta_EncuestaNumero UNIQUE (EncuestaID, Numero),
 CONSTRAINT UQ_Pregunta_Compuesta UNIQUE (PreguntaID, EncuestaID, TipoPreguntaID)
);
CREATE TABLE levantamiento.Participacion (
 ParticipacionID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Participacion PRIMARY KEY,
 EncuestaID smallint NOT NULL CONSTRAINT FK_Participacion_Encuesta REFERENCES instrumento.Encuesta(EncuestaID),
 EncuestadoID int NOT NULL CONSTRAINT FK_Participacion_Encuestado REFERENCES panel.Encuestados(EncuestadoID),
 FechaRespuesta datetime2(0) NOT NULL,
 CONSTRAINT UQ_Participacion_EncuestaEncuestado UNIQUE (EncuestaID, EncuestadoID),
 CONSTRAINT UQ_Participacion_Compuesta UNIQUE (ParticipacionID, EncuestaID)
);
CREATE TABLE levantamiento.Respuesta (
 RespuestaID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Respuesta PRIMARY KEY,
 ParticipacionID int NOT NULL,
 EncuestaID smallint NOT NULL,
 PreguntaID int NOT NULL,
 TipoPreguntaID tinyint NOT NULL,
 OpcionID tinyint NULL,
 ValorEntero int NULL,
 ValorTexto nvarchar(500) NULL,
 CONSTRAINT FK_Respuesta_Participacion FOREIGN KEY (ParticipacionID, EncuestaID)
   REFERENCES levantamiento.Participacion(ParticipacionID, EncuestaID),
 CONSTRAINT FK_Respuesta_Pregunta FOREIGN KEY (PreguntaID, EncuestaID, TipoPreguntaID)
   REFERENCES instrumento.Pregunta(PreguntaID, EncuestaID, TipoPreguntaID),
 CONSTRAINT FK_Respuesta_Opcion FOREIGN KEY (OpcionID, TipoPreguntaID)
   REFERENCES instrumento.OpcionRespuesta(OpcionID, TipoPreguntaID),
 CONSTRAINT UQ_Respuesta_ParticipacionPregunta UNIQUE (ParticipacionID, PreguntaID),
 CONSTRAINT CK_Respuesta_Formato CHECK (
    (TipoPreguntaID IN (1,2,3) AND OpcionID IS NOT NULL AND ValorEntero IS NULL AND ValorTexto IS NULL)
 OR (TipoPreguntaID = 4 AND OpcionID IS NULL AND ValorEntero BETWEEN 0 AND 60 AND ValorTexto IS NULL)
 OR (TipoPreguntaID = 5 AND OpcionID IS NULL AND ValorEntero IS NULL AND LEN(LTRIM(RTRIM(ValorTexto))) > 0)
 )
);

CREATE TABLE levantamiento.AsignacionEncuesta (
 EncuestaID smallint NOT NULL CONSTRAINT FK_AsignacionEncuesta_Encuesta REFERENCES instrumento.Encuesta(EncuestaID),
 EncuestadoID int NOT NULL CONSTRAINT FK_AsignacionEncuesta_Encuestado REFERENCES panel.Encuestados(EncuestadoID),
 FechaAsignacionUTC datetime2(0) NOT NULL CONSTRAINT DF_AsignacionEncuesta_Fecha DEFAULT (SYSUTCDATETIME()),
 CONSTRAINT PK_AsignacionEncuesta PRIMARY KEY (EncuestaID, EncuestadoID)
);

INSERT INTO panel.Area (Nombre, Descripcion) VALUES
(N'Centro urbano', N'Área de residencia declarada: centro urbano'),
(N'Zona norte', N'Área de residencia declarada: zona norte'),
(N'Zona sur', N'Área de residencia declarada: zona sur'),
(N'Zona oriente', N'Área de residencia declarada: zona oriente'),
(N'Zona poniente', N'Área de residencia declarada: zona poniente'),
(N'Periferia urbana', N'Área de residencia declarada: periferia urbana'),
(N'Cabecera municipal', N'Área de residencia declarada: cabecera municipal'),
(N'Localidad semiurbana', N'Área de residencia declarada: localidad semiurbana'),
(N'Zona conurbada', N'Área de residencia declarada: zona conurbada'),
(N'Zona rural cercana', N'Área de residencia declarada: zona rural cercana');

INSERT INTO panel.GradoEstudios (GradoEstudiosID, Nombre) VALUES
(1, N'Primaria'),
(2, N'Secundaria'),
(3, N'Bachillerato'),
(4, N'Carrera técnica'),
(5, N'Licenciatura'),
(6, N'Especialidad'),
(7, N'Maestría'),
(8, N'Doctorado');

INSERT INTO panel.Encuestados (Nombre, ApellidoPaterno, ApellidoMaterno, Edad, Sexo, GradoEstudiosID, AreaID, EntidadFederativa, MunicipioAlcaldia, Ocupacion) VALUES
(N'Ricardo', N'Reyes', N'González', 72, 'H', 8, 9, N'Estado de México', N'Nezahualcóyotl', N'Trabajador/a independiente'),
(N'Jorge', N'Torres', N'López', 23, 'H', 6, 10, N'Estado de México', N'Ecatepec de Morelos', N'Técnico/a'),
(N'Ricardo', N'Ramírez', N'Flores', 70, 'H', 5, 3, N'Querétaro', N'Querétaro', N'Docente'),
(N'Francisco Javier', N'Mendoza', N'Pérez', 22, 'H', 5, 4, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Ana Sofía', N'Ríos', N'Mendoza', 69, 'M', 1, 9, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Estudiante'),
(N'José Luis', N'Cruz', N'Flores', 65, 'H', 8, 6, N'Estado de México', N'Nezahualcóyotl', N'Comerciante'),
(N'Luis Fernando', N'Sánchez', N'Navarro', 26, 'H', 4, 5, N'Guanajuato', N'León', N'Servidor/a público/a'),
(N'Patricia', N'González', N'Sánchez', 80, 'M', 7, 4, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Empleado/a'),
(N'Luis Fernando', N'Morales', N'Flores', 45, 'H', 3, 1, N'Ciudad de México', N'Xochimilco', N'Técnico/a'),
(N'Rosa Elena', N'Hernández', N'Hernández', 22, 'M', 4, 7, N'Yucatán', N'Mérida', N'Trabajador/a independiente'),
(N'Ximena', N'Martínez', N'Ríos', 66, 'M', 3, 9, N'Ciudad de México', N'Iztapalapa', N'Servidor/a público/a'),
(N'Guadalupe', N'Torres', N'Ríos', 25, 'M', 8, 6, N'Guanajuato', N'León', N'Empleado/a'),
(N'José Luis', N'García', N'Pérez', 79, 'H', 4, 10, N'Ciudad de México', N'Coyoacán', N'Empleado/a'),
(N'Valeria', N'Morales', N'Navarro', 82, 'M', 3, 6, N'Ciudad de México', N'Iztapalapa', N'Comerciante'),
(N'Guadalupe', N'González', N'González', 78, 'M', 2, 3, N'Estado de México', N'Nezahualcóyotl', N'Empleado/a'),
(N'Francisco Javier', N'Ortiz', N'Cruz', 53, 'H', 6, 2, N'Puebla', N'Puebla', N'Servidor/a público/a'),
(N'Daniela', N'Morales', N'Jiménez', 37, 'M', 4, 8, N'Estado de México', N'Ecatepec de Morelos', N'Trabajador/a independiente'),
(N'Rosa Elena', N'Vargas', N'González', 20, 'M', 8, 4, N'Ciudad de México', N'Coyoacán', N'Persona dedicada al hogar'),
(N'Rosa Elena', N'González', N'Cruz', 60, 'M', 7, 3, N'Jalisco', N'Guadalajara', N'Persona dedicada al hogar'),
(N'Carlos Alberto', N'Castillo', N'Navarro', 60, 'H', 4, 1, N'Puebla', N'Puebla', N'Profesional de salud'),
(N'Jorge', N'García', N'Sánchez', 35, 'H', 3, 3, N'Nuevo León', N'Monterrey', N'Profesional de salud'),
(N'Patricia', N'Castillo', N'Torres', 62, 'M', 6, 9, N'Estado de México', N'Ecatepec de Morelos', N'Servidor/a público/a'),
(N'Francisco Javier', N'Martínez', N'Sánchez', 59, 'H', 2, 2, N'Yucatán', N'Mérida', N'Estudiante'),
(N'Eduardo', N'López', N'González', 40, 'H', 5, 9, N'Querétaro', N'Querétaro', N'Técnico/a'),
(N'Valeria', N'Ortiz', N'Ramírez', 45, 'M', 8, 2, N'Guanajuato', N'León', N'Profesional de salud'),
(N'Alejandra', N'Torres', N'López', 47, 'M', 1, 1, N'Ciudad de México', N'Coyoacán', N'Estudiante'),
(N'Valeria', N'Hernández', N'Hernández', 35, 'M', 1, 6, N'Puebla', N'Puebla', N'Persona dedicada al hogar'),
(N'Daniela', N'Mendoza', N'Torres', 81, 'M', 6, 6, N'Querétaro', N'Querétaro', N'Jubilado/a'),
(N'José Luis', N'Ríos', N'Sánchez', 81, 'H', 2, 7, N'Jalisco', N'Guadalajara', N'Servidor/a público/a'),
(N'Ana Sofía', N'Ortiz', N'Vargas', 48, 'M', 3, 1, N'Ciudad de México', N'Coyoacán', N'Persona dedicada al hogar'),
(N'Valeria', N'Castillo', N'Ríos', 61, 'M', 4, 8, N'Jalisco', N'Guadalajara', N'Servidor/a público/a'),
(N'Eduardo', N'Cruz', N'Ríos', 54, 'H', 7, 9, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Jubilado/a'),
(N'Rosa Elena', N'Flores', N'Mendoza', 36, 'M', 6, 7, N'Estado de México', N'Nezahualcóyotl', N'Técnico/a'),
(N'Daniela', N'Martínez', N'Pérez', 31, 'M', 3, 3, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Profesional de salud'),
(N'Patricia', N'Pérez', N'García', 71, 'M', 7, 6, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Ximena', N'Cruz', N'Flores', 31, 'M', 6, 1, N'Yucatán', N'Mérida', N'Docente'),
(N'Ricardo', N'Mendoza', N'Ramírez', 80, 'H', 1, 4, N'Estado de México', N'Ecatepec de Morelos', N'Persona dedicada al hogar'),
(N'Francisco Javier', N'Mendoza', N'Castillo', 72, 'H', 1, 2, N'Ciudad de México', N'Coyoacán', N'Técnico/a'),
(N'María Fernanda', N'Vargas', N'Castillo', 73, 'M', 3, 6, N'Ciudad de México', N'Coyoacán', N'Servidor/a público/a'),
(N'Carlos Alberto', N'López', N'Castillo', 66, 'H', 3, 4, N'Ciudad de México', N'Iztapalapa', N'Empleado/a'),
(N'Eduardo', N'Vargas', N'Mendoza', 23, 'H', 4, 1, N'Guanajuato', N'León', N'Persona dedicada al hogar'),
(N'Francisco Javier', N'Hernández', N'García', 75, 'H', 7, 1, N'Ciudad de México', N'Xochimilco', N'Trabajador/a independiente'),
(N'Juan Carlos', N'Ríos', N'González', 67, 'H', 2, 3, N'Nuevo León', N'Monterrey', N'Comerciante'),
(N'Daniela', N'Sánchez', N'López', 56, 'M', 2, 4, N'Jalisco', N'Guadalajara', N'Jubilado/a'),
(N'Eduardo', N'Pérez', N'Ríos', 19, 'H', 6, 6, N'Ciudad de México', N'Coyoacán', N'Profesional de salud'),
(N'Eduardo', N'Sánchez', N'Pérez', 35, 'H', 2, 10, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'Montserrat', N'Morales', N'Ramírez', 73, 'M', 5, 5, N'Puebla', N'Puebla', N'Jubilado/a'),
(N'Valeria', N'López', N'Flores', 84, 'M', 5, 9, N'Ciudad de México', N'Xochimilco', N'Jubilado/a'),
(N'Francisco Javier', N'Mendoza', N'García', 54, 'H', 7, 8, N'Querétaro', N'Querétaro', N'Docente'),
(N'Patricia', N'Navarro', N'Torres', 18, 'M', 6, 1, N'Guanajuato', N'León', N'Servidor/a público/a'),
(N'Miguel Ángel', N'Mendoza', N'Reyes', 55, 'H', 8, 8, N'Nuevo León', N'Monterrey', N'Profesional de salud'),
(N'Diego', N'García', N'Vargas', 80, 'H', 1, 6, N'Yucatán', N'Mérida', N'Jubilado/a'),
(N'Ximena', N'Ríos', N'Jiménez', 29, 'M', 8, 6, N'Puebla', N'Puebla', N'Jubilado/a'),
(N'Patricia', N'Reyes', N'Flores', 44, 'M', 7, 5, N'Jalisco', N'Guadalajara', N'Jubilado/a'),
(N'Jorge', N'Reyes', N'Castillo', 71, 'H', 1, 1, N'Nuevo León', N'Monterrey', N'Empleado/a'),
(N'Luis Fernando', N'Navarro', N'Ríos', 40, 'H', 1, 8, N'Nuevo León', N'Monterrey', N'Jubilado/a'),
(N'Valeria', N'Ortiz', N'Vargas', 68, 'M', 8, 8, N'Estado de México', N'Nezahualcóyotl', N'Profesional de salud'),
(N'José Luis', N'García', N'Cruz', 45, 'H', 7, 7, N'Ciudad de México', N'Xochimilco', N'Empleado/a'),
(N'Ricardo', N'López', N'Torres', 78, 'H', 7, 4, N'Nuevo León', N'Monterrey', N'Trabajador/a independiente'),
(N'Daniela', N'Morales', N'Mendoza', 78, 'M', 4, 6, N'Nuevo León', N'Monterrey', N'Estudiante'),
(N'Montserrat', N'Jiménez', N'Pérez', 47, 'M', 3, 7, N'Ciudad de México', N'Xochimilco', N'Comerciante'),
(N'Valeria', N'Cruz', N'Pérez', 66, 'M', 7, 9, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Valeria', N'Castillo', N'Hernández', 37, 'M', 7, 8, N'Jalisco', N'Guadalajara', N'Docente'),
(N'Patricia', N'Mendoza', N'Martínez', 39, 'M', 8, 7, N'Jalisco', N'Guadalajara', N'Servidor/a público/a'),
(N'Jorge', N'Sánchez', N'Navarro', 53, 'H', 1, 2, N'Ciudad de México', N'Coyoacán', N'Persona dedicada al hogar'),
(N'Jorge', N'González', N'García', 52, 'H', 3, 2, N'Nuevo León', N'Monterrey', N'Trabajador/a independiente'),
(N'Diego', N'Jiménez', N'Reyes', 58, 'H', 6, 9, N'Jalisco', N'Guadalajara', N'Docente'),
(N'Francisco Javier', N'Mendoza', N'Ramírez', 68, 'H', 4, 6, N'Guanajuato', N'León', N'Estudiante'),
(N'Diego', N'Pérez', N'Morales', 48, 'H', 6, 10, N'Ciudad de México', N'Coyoacán', N'Persona dedicada al hogar'),
(N'Diego', N'Pérez', N'Vargas', 62, 'H', 7, 2, N'Ciudad de México', N'Iztapalapa', N'Servidor/a público/a'),
(N'Miguel Ángel', N'Cruz', N'Torres', 75, 'H', 5, 7, N'Querétaro', N'Querétaro', N'Servidor/a público/a'),
(N'José Luis', N'Ríos', N'Mendoza', 24, 'H', 6, 6, N'Estado de México', N'Nezahualcóyotl', N'Profesional de salud'),
(N'Miguel Ángel', N'Castillo', N'Hernández', 80, 'H', 1, 2, N'Puebla', N'Puebla', N'Persona dedicada al hogar'),
(N'Ricardo', N'Hernández', N'López', 19, 'H', 3, 5, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Diego', N'Hernández', N'Sánchez', 46, 'H', 6, 3, N'Estado de México', N'Ecatepec de Morelos', N'Servidor/a público/a'),
(N'Diego', N'Sánchez', N'Ramírez', 24, 'H', 1, 10, N'Yucatán', N'Mérida', N'Servidor/a público/a'),
(N'Ricardo', N'Reyes', N'Mendoza', 65, 'H', 7, 4, N'Ciudad de México', N'Iztapalapa', N'Jubilado/a'),
(N'Ana Sofía', N'Castillo', N'García', 82, 'M', 5, 3, N'Guanajuato', N'León', N'Docente'),
(N'José Luis', N'González', N'Torres', 25, 'H', 6, 2, N'Guanajuato', N'León', N'Técnico/a'),
(N'Alejandra', N'Ortiz', N'Martínez', 65, 'M', 4, 9, N'Ciudad de México', N'Iztapalapa', N'Profesional de salud'),
(N'Miguel Ángel', N'Ramírez', N'Sánchez', 42, 'H', 7, 10, N'Yucatán', N'Mérida', N'Servidor/a público/a'),
(N'Alejandra', N'Reyes', N'Ríos', 26, 'M', 4, 10, N'Ciudad de México', N'Iztapalapa', N'Técnico/a'),
(N'Ximena', N'Hernández', N'Vargas', 46, 'M', 7, 2, N'Ciudad de México', N'Xochimilco', N'Trabajador/a independiente'),
(N'Luis Fernando', N'Cruz', N'Castillo', 83, 'H', 1, 4, N'Estado de México', N'Nezahualcóyotl', N'Estudiante'),
(N'Jorge', N'Ríos', N'Hernández', 28, 'H', 1, 10, N'Puebla', N'Puebla', N'Trabajador/a independiente'),
(N'Daniela', N'López', N'Torres', 51, 'M', 6, 7, N'Puebla', N'Puebla', N'Profesional de salud'),
(N'Eduardo', N'Martínez', N'Sánchez', 19, 'H', 2, 4, N'Puebla', N'Puebla', N'Comerciante'),
(N'Daniela', N'Jiménez', N'González', 85, 'M', 6, 7, N'Ciudad de México', N'Xochimilco', N'Comerciante'),
(N'Miguel Ángel', N'López', N'Flores', 21, 'H', 6, 8, N'Nuevo León', N'Monterrey', N'Docente'),
(N'Jorge', N'Torres', N'González', 68, 'H', 2, 5, N'Querétaro', N'Querétaro', N'Comerciante'),
(N'Eduardo', N'Morales', N'Reyes', 66, 'H', 3, 4, N'Yucatán', N'Mérida', N'Comerciante'),
(N'Carlos Alberto', N'González', N'Castillo', 19, 'H', 7, 3, N'Estado de México', N'Ecatepec de Morelos', N'Comerciante'),
(N'María Fernanda', N'Ramírez', N'Ramírez', 82, 'M', 7, 2, N'Ciudad de México', N'Xochimilco', N'Técnico/a'),
(N'Rosa Elena', N'Jiménez', N'Torres', 55, 'M', 8, 8, N'Querétaro', N'Querétaro', N'Persona dedicada al hogar'),
(N'María Fernanda', N'Morales', N'Ortiz', 81, 'M', 7, 5, N'Jalisco', N'Guadalajara', N'Docente'),
(N'José Luis', N'Mendoza', N'Ramírez', 34, 'H', 2, 2, N'Ciudad de México', N'Iztapalapa', N'Técnico/a'),
(N'Montserrat', N'Castillo', N'Mendoza', 48, 'M', 1, 6, N'Guanajuato', N'León', N'Servidor/a público/a'),
(N'Guadalupe', N'Jiménez', N'Pérez', 81, 'M', 8, 8, N'Estado de México', N'Nezahualcóyotl', N'Persona dedicada al hogar'),
(N'Ricardo', N'Ramírez', N'Ramírez', 85, 'H', 2, 1, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Comerciante'),
(N'Carlos Alberto', N'Castillo', N'González', 42, 'H', 5, 9, N'Estado de México', N'Ecatepec de Morelos', N'Técnico/a'),
(N'Daniela', N'Pérez', N'Sánchez', 61, 'M', 3, 5, N'Yucatán', N'Mérida', N'Trabajador/a independiente'),
(N'Patricia', N'Torres', N'López', 37, 'M', 6, 7, N'Querétaro', N'Querétaro', N'Persona dedicada al hogar'),
(N'Jorge', N'Pérez', N'Navarro', 66, 'H', 8, 2, N'Estado de México', N'Nezahualcóyotl', N'Estudiante'),
(N'Luis Fernando', N'Cruz', N'Vargas', 27, 'H', 4, 3, N'Ciudad de México', N'Xochimilco', N'Empleado/a'),
(N'Jorge', N'Castillo', N'Mendoza', 67, 'H', 4, 5, N'Yucatán', N'Mérida', N'Comerciante'),
(N'María Fernanda', N'Torres', N'Sánchez', 75, 'M', 4, 4, N'Estado de México', N'Nezahualcóyotl', N'Empleado/a'),
(N'Rosa Elena', N'Vargas', N'García', 58, 'M', 1, 4, N'Ciudad de México', N'Xochimilco', N'Profesional de salud'),
(N'Ricardo', N'Pérez', N'García', 40, 'H', 8, 8, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Ana Sofía', N'Hernández', N'Pérez', 21, 'M', 7, 2, N'Estado de México', N'Nezahualcóyotl', N'Docente'),
(N'Montserrat', N'Morales', N'Cruz', 68, 'M', 1, 7, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'Montserrat', N'Reyes', N'Hernández', 85, 'M', 4, 8, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Jorge', N'Ramírez', N'Navarro', 23, 'H', 1, 5, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'Diego', N'Ortiz', N'Cruz', 30, 'H', 8, 7, N'Ciudad de México', N'Iztapalapa', N'Jubilado/a'),
(N'Ximena', N'Hernández', N'García', 47, 'M', 2, 9, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Comerciante'),
(N'Jorge', N'González', N'Morales', 52, 'H', 2, 5, N'Estado de México', N'Ecatepec de Morelos', N'Técnico/a'),
(N'Carlos Alberto', N'Castillo', N'García', 25, 'H', 7, 1, N'Ciudad de México', N'Iztapalapa', N'Persona dedicada al hogar'),
(N'Montserrat', N'González', N'García', 35, 'M', 8, 4, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Miguel Ángel', N'Jiménez', N'Ramírez', 45, 'H', 5, 9, N'Ciudad de México', N'Xochimilco', N'Estudiante'),
(N'Rosa Elena', N'Pérez', N'Ríos', 37, 'M', 2, 6, N'Puebla', N'Puebla', N'Comerciante'),
(N'Juan Carlos', N'Jiménez', N'González', 46, 'H', 7, 10, N'Estado de México', N'Nezahualcóyotl', N'Servidor/a público/a'),
(N'Diego', N'Morales', N'Hernández', 66, 'H', 7, 8, N'Nuevo León', N'Monterrey', N'Estudiante'),
(N'Francisco Javier', N'Hernández', N'Vargas', 62, 'H', 4, 9, N'Ciudad de México', N'Iztapalapa', N'Profesional de salud'),
(N'Carlos Alberto', N'Morales', N'García', 25, 'H', 7, 2, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Jorge', N'Morales', N'López', 47, 'H', 7, 3, N'Estado de México', N'Nezahualcóyotl', N'Jubilado/a'),
(N'Luis Fernando', N'Cruz', N'García', 81, 'H', 5, 10, N'Estado de México', N'Ecatepec de Morelos', N'Docente'),
(N'Diego', N'Pérez', N'Ortiz', 21, 'H', 5, 7, N'Yucatán', N'Mérida', N'Empleado/a'),
(N'Miguel Ángel', N'Martínez', N'Jiménez', 54, 'H', 1, 7, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Jubilado/a'),
(N'Ricardo', N'Ortiz', N'Mendoza', 34, 'H', 1, 9, N'Ciudad de México', N'Iztapalapa', N'Comerciante'),
(N'Alejandra', N'Morales', N'Castillo', 47, 'M', 2, 8, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Jubilado/a'),
(N'Ana Sofía', N'Hernández', N'Vargas', 72, 'M', 8, 4, N'Nuevo León', N'Monterrey', N'Técnico/a'),
(N'Jorge', N'Ríos', N'Castillo', 34, 'H', 1, 5, N'Ciudad de México', N'Coyoacán', N'Estudiante'),
(N'Miguel Ángel', N'Sánchez', N'Ortiz', 75, 'H', 7, 3, N'Guanajuato', N'León', N'Técnico/a'),
(N'María Fernanda', N'Mendoza', N'Martínez', 18, 'M', 3, 3, N'Ciudad de México', N'Xochimilco', N'Persona dedicada al hogar'),
(N'Ricardo', N'Mendoza', N'Sánchez', 53, 'H', 5, 5, N'Querétaro', N'Querétaro', N'Servidor/a público/a'),
(N'Diego', N'Castillo', N'Cruz', 75, 'H', 6, 9, N'Estado de México', N'Ecatepec de Morelos', N'Trabajador/a independiente'),
(N'Eduardo', N'Castillo', N'Ramírez', 84, 'H', 3, 8, N'Jalisco', N'Guadalajara', N'Técnico/a'),
(N'Carlos Alberto', N'Jiménez', N'Vargas', 65, 'H', 6, 7, N'Querétaro', N'Querétaro', N'Jubilado/a'),
(N'Francisco Javier', N'Pérez', N'Flores', 36, 'H', 2, 6, N'Nuevo León', N'Monterrey', N'Profesional de salud'),
(N'Carlos Alberto', N'Pérez', N'Flores', 83, 'H', 3, 2, N'Ciudad de México', N'Iztapalapa', N'Persona dedicada al hogar'),
(N'Luis Fernando', N'García', N'Mendoza', 73, 'H', 6, 9, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Guadalupe', N'López', N'González', 57, 'M', 7, 9, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Alejandra', N'Ríos', N'Sánchez', 23, 'M', 6, 3, N'Guanajuato', N'León', N'Estudiante'),
(N'Jorge', N'Morales', N'Mendoza', 85, 'H', 6, 7, N'Estado de México', N'Nezahualcóyotl', N'Docente'),
(N'Guadalupe', N'González', N'Cruz', 55, 'M', 4, 9, N'Ciudad de México', N'Xochimilco', N'Jubilado/a'),
(N'Eduardo', N'López', N'Navarro', 50, 'H', 6, 6, N'Ciudad de México', N'Xochimilco', N'Estudiante'),
(N'Juan Carlos', N'Castillo', N'Ríos', 61, 'H', 3, 1, N'Ciudad de México', N'Xochimilco', N'Comerciante'),
(N'Rosa Elena', N'López', N'Mendoza', 75, 'M', 2, 10, N'Querétaro', N'Querétaro', N'Docente'),
(N'Rosa Elena', N'Castillo', N'Jiménez', 63, 'M', 7, 9, N'Ciudad de México', N'Xochimilco', N'Profesional de salud'),
(N'Daniela', N'Pérez', N'Ríos', 65, 'M', 8, 2, N'Estado de México', N'Nezahualcóyotl', N'Comerciante'),
(N'María Fernanda', N'Flores', N'García', 69, 'M', 3, 10, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Trabajador/a independiente'),
(N'Rosa Elena', N'López', N'Vargas', 31, 'M', 4, 9, N'Estado de México', N'Nezahualcóyotl', N'Estudiante'),
(N'Montserrat', N'Morales', N'Mendoza', 65, 'M', 2, 9, N'Ciudad de México', N'Coyoacán', N'Jubilado/a'),
(N'Alejandra', N'Torres', N'Mendoza', 68, 'M', 5, 6, N'Yucatán', N'Mérida', N'Jubilado/a'),
(N'Eduardo', N'Morales', N'Ramírez', 22, 'H', 8, 10, N'Jalisco', N'Guadalajara', N'Empleado/a'),
(N'Guadalupe', N'López', N'Ramírez', 77, 'M', 6, 9, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'Ricardo', N'Martínez', N'Vargas', 60, 'H', 6, 1, N'Ciudad de México', N'Coyoacán', N'Servidor/a público/a'),
(N'Valeria', N'Jiménez', N'Hernández', 49, 'M', 8, 10, N'Yucatán', N'Mérida', N'Jubilado/a'),
(N'Rosa Elena', N'Sánchez', N'Flores', 72, 'M', 7, 10, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'Guadalupe', N'García', N'Hernández', 83, 'M', 7, 10, N'Yucatán', N'Mérida', N'Empleado/a'),
(N'Valeria', N'Navarro', N'Navarro', 38, 'M', 8, 9, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Ana Sofía', N'Torres', N'González', 38, 'M', 3, 4, N'Querétaro', N'Querétaro', N'Empleado/a'),
(N'Luis Fernando', N'Jiménez', N'Sánchez', 73, 'H', 7, 7, N'Querétaro', N'Querétaro', N'Comerciante'),
(N'Alejandra', N'Pérez', N'Flores', 49, 'M', 4, 3, N'Estado de México', N'Ecatepec de Morelos', N'Profesional de salud'),
(N'Ricardo', N'Martínez', N'Reyes', 35, 'H', 1, 1, N'Yucatán', N'Mérida', N'Empleado/a'),
(N'Montserrat', N'Castillo', N'Cruz', 39, 'M', 2, 7, N'Ciudad de México', N'Coyoacán', N'Estudiante'),
(N'Francisco Javier', N'Jiménez', N'Jiménez', 63, 'H', 4, 10, N'Ciudad de México', N'Xochimilco', N'Técnico/a'),
(N'Miguel Ángel', N'González', N'Torres', 33, 'H', 3, 2, N'Querétaro', N'Querétaro', N'Servidor/a público/a'),
(N'Daniela', N'Hernández', N'Ríos', 48, 'M', 3, 6, N'Estado de México', N'Nezahualcóyotl', N'Empleado/a'),
(N'Juan Carlos', N'Morales', N'Hernández', 54, 'H', 4, 4, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Empleado/a'),
(N'Alejandra', N'Morales', N'Flores', 47, 'M', 2, 3, N'Estado de México', N'Nezahualcóyotl', N'Técnico/a'),
(N'Diego', N'Hernández', N'Flores', 48, 'H', 2, 1, N'Yucatán', N'Mérida', N'Comerciante'),
(N'Jorge', N'Morales', N'García', 83, 'H', 7, 5, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Servidor/a público/a'),
(N'Montserrat', N'Mendoza', N'Flores', 32, 'M', 1, 2, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Carlos Alberto', N'Torres', N'Torres', 53, 'H', 6, 3, N'Guanajuato', N'León', N'Empleado/a'),
(N'Daniela', N'Torres', N'Navarro', 43, 'M', 4, 5, N'Estado de México', N'Nezahualcóyotl', N'Empleado/a'),
(N'Francisco Javier', N'Castillo', N'Castillo', 28, 'H', 4, 1, N'Ciudad de México', N'Coyoacán', N'Comerciante'),
(N'Juan Carlos', N'Flores', N'Vargas', 38, 'H', 5, 2, N'Ciudad de México', N'Iztapalapa', N'Comerciante'),
(N'Luis Fernando', N'González', N'Martínez', 39, 'H', 8, 2, N'Puebla', N'Puebla', N'Docente'),
(N'Eduardo', N'Ríos', N'Ramírez', 55, 'H', 7, 9, N'Estado de México', N'Nezahualcóyotl', N'Comerciante'),
(N'Rosa Elena', N'Castillo', N'Hernández', 81, 'M', 7, 6, N'Estado de México', N'Nezahualcóyotl', N'Técnico/a'),
(N'Daniela', N'Hernández', N'Navarro', 47, 'M', 8, 2, N'Ciudad de México', N'Coyoacán', N'Trabajador/a independiente'),
(N'Ana Sofía', N'Hernández', N'Ortiz', 58, 'M', 6, 2, N'Ciudad de México', N'Iztapalapa', N'Técnico/a'),
(N'Patricia', N'González', N'Pérez', 64, 'M', 2, 5, N'Jalisco', N'Guadalajara', N'Servidor/a público/a'),
(N'Francisco Javier', N'García', N'Cruz', 29, 'H', 1, 9, N'Estado de México', N'Ecatepec de Morelos', N'Persona dedicada al hogar'),
(N'Eduardo', N'González', N'García', 84, 'H', 8, 6, N'Yucatán', N'Mérida', N'Técnico/a'),
(N'Rosa Elena', N'Reyes', N'Cruz', 41, 'M', 4, 7, N'Jalisco', N'Guadalajara', N'Jubilado/a'),
(N'Valeria', N'García', N'Castillo', 22, 'M', 3, 8, N'Nuevo León', N'Monterrey', N'Servidor/a público/a'),
(N'Francisco Javier', N'Flores', N'Pérez', 31, 'H', 8, 10, N'Ciudad de México', N'Xochimilco', N'Comerciante'),
(N'Guadalupe', N'Vargas', N'López', 28, 'M', 4, 1, N'Yucatán', N'Mérida', N'Servidor/a público/a'),
(N'Francisco Javier', N'Pérez', N'Jiménez', 19, 'H', 3, 6, N'Ciudad de México', N'Iztapalapa', N'Comerciante'),
(N'José Luis', N'Jiménez', N'Hernández', 80, 'H', 2, 2, N'Estado de México', N'Ecatepec de Morelos', N'Estudiante'),
(N'María Fernanda', N'Ramírez', N'Jiménez', 71, 'M', 2, 4, N'Jalisco', N'Guadalajara', N'Técnico/a'),
(N'Guadalupe', N'Reyes', N'Torres', 30, 'M', 4, 6, N'Estado de México', N'Nezahualcóyotl', N'Empleado/a'),
(N'Juan Carlos', N'Ortiz', N'González', 74, 'H', 5, 10, N'Guanajuato', N'León', N'Técnico/a'),
(N'Francisco Javier', N'Ortiz', N'Mendoza', 43, 'H', 2, 2, N'Jalisco', N'Guadalajara', N'Trabajador/a independiente'),
(N'Francisco Javier', N'Cruz', N'Castillo', 82, 'H', 2, 1, N'Guanajuato', N'León', N'Servidor/a público/a'),
(N'Jorge', N'Ortiz', N'Flores', 32, 'H', 4, 4, N'Nuevo León', N'Monterrey', N'Jubilado/a'),
(N'María Fernanda', N'Sánchez', N'López', 51, 'M', 1, 9, N'Estado de México', N'Nezahualcóyotl', N'Docente'),
(N'Jorge', N'Castillo', N'Ortiz', 23, 'H', 4, 2, N'Yucatán', N'Mérida', N'Comerciante'),
(N'Miguel Ángel', N'Ríos', N'Vargas', 46, 'H', 6, 4, N'Jalisco', N'Guadalajara', N'Profesional de salud');

INSERT INTO instrumento.Encuesta (Titulo, Objetivo, FechaInicio, FechaFin) VALUES
(N'Salud y acceso a servicios', N'Experiencia de personas adultas con prevención y atención médica', '2026-04-01', '2026-06-30'),
(N'Movilidad cotidiana', N'Traslados habituales y transporte local', '2026-04-01', '2026-06-30'),
(N'Seguridad en la colonia', N'Percepción y hábitos de prevención', '2026-04-01', '2026-06-30'),
(N'Educación y capacitación', N'Acceso a oportunidades educativas y formación', '2026-04-01', '2026-06-30'),
(N'Condiciones laborales', N'Condiciones y oportunidades de trabajo', '2026-04-01', '2026-06-30'),
(N'Conectividad digital', N'Acceso y uso de tecnologías', '2026-04-01', '2026-06-30'),
(N'Agua y saneamiento', N'Disponibilidad y calidad percibida de servicios', '2026-04-01', '2026-06-30'),
(N'Residuos y medio ambiente', N'Prácticas ambientales y servicios urbanos', '2026-04-01', '2026-06-30'),
(N'Trámites y atención ciudadana', N'Experiencias con servicios y canales de atención', '2026-04-01', '2026-06-30'),
(N'Espacios públicos y comunidad', N'Uso y mantenimiento de equipamiento comunitario', '2026-04-01', '2026-06-30');

INSERT INTO instrumento.TipoPregunta (TipoPreguntaID, Nombre) VALUES
(1, N'Escala de satisfacción de 1 a 5'),
(2, N'Sí o no'),
(3, N'Frecuencia mensual'),
(4, N'Número de ocasiones'),
(5, N'Texto abierto');

INSERT INTO instrumento.OpcionRespuesta (OpcionID, TipoPreguntaID, Etiqueta, ValorNumerico) VALUES
(1, 1, N'Muy insatisfactoria', 1),
(2, 1, N'Insatisfactoria', 2),
(3, 1, N'Ni satisfactoria ni insatisfactoria', 3),
(4, 1, N'Satisfactoria', 4),
(5, 1, N'Muy satisfactoria', 5),
(6, 2, N'Sí', 1),
(7, 2, N'No', 0),
(8, 3, N'Nunca', 0),
(9, 3, N'Una vez al mes', 1),
(10, 3, N'Dos veces al mes', 2),
(11, 3, N'Cuatro veces al mes', 4),
(12, 3, N'Más de cinco veces al mes', 6);

INSERT INTO instrumento.Pregunta (EncuestaID, Numero, Texto, TipoPreguntaID, Obligatoria) VALUES
(1, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de consulta médica en su localidad?', 1, 1),
(1, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó consulta médica?', 3, 1),
(1, 3, N'¿Conoce alguna opción o servicio relacionado con consulta médica en su localidad?', 2, 1),
(1, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con consulta médica?', 4, 1),
(1, 5, N'¿Qué tan fácil le resulta acceder a consulta médica cuando lo necesita?', 1, 1),
(1, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de atención en clínica pública en su localidad?', 1, 1),
(1, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó atención en clínica pública?', 3, 1),
(1, 8, N'¿Conoce alguna opción o servicio relacionado con atención en clínica pública en su localidad?', 2, 1),
(1, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con atención en clínica pública?', 4, 1),
(1, 10, N'¿Qué tan fácil le resulta acceder a atención en clínica pública cuando lo necesita?', 1, 1),
(1, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de vacunación en su localidad?', 1, 1),
(1, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó vacunación?', 3, 1),
(1, 13, N'¿Conoce alguna opción o servicio relacionado con vacunación en su localidad?', 2, 1),
(1, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con vacunación?', 4, 1),
(1, 15, N'¿Qué tan fácil le resulta acceder a vacunación cuando lo necesita?', 1, 1),
(1, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de medicamentos recetados en su localidad?', 1, 1),
(1, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó medicamentos recetados?', 3, 1),
(1, 18, N'¿Conoce alguna opción o servicio relacionado con medicamentos recetados en su localidad?', 2, 1),
(1, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con medicamentos recetados?', 4, 1),
(1, 20, N'¿Qué tan fácil le resulta acceder a medicamentos recetados cuando lo necesita?', 1, 1),
(1, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de salud mental en su localidad?', 1, 1),
(1, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó salud mental?', 3, 1),
(1, 23, N'¿Conoce alguna opción o servicio relacionado con salud mental en su localidad?', 2, 1),
(1, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con salud mental?', 4, 1),
(1, 25, N'¿Qué tan fácil le resulta acceder a salud mental cuando lo necesita?', 1, 1),
(1, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de prevención de enfermedades en su localidad?', 1, 1),
(1, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó prevención de enfermedades?', 3, 1),
(1, 28, N'¿Conoce alguna opción o servicio relacionado con prevención de enfermedades en su localidad?', 2, 1),
(1, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con prevención de enfermedades?', 4, 1),
(1, 30, N'¿Qué tan fácil le resulta acceder a prevención de enfermedades cuando lo necesita?', 1, 1),
(1, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(1, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(2, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de transporte público en su localidad?', 1, 1),
(2, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó transporte público?', 3, 1),
(2, 3, N'¿Conoce alguna opción o servicio relacionado con transporte público en su localidad?', 2, 1),
(2, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con transporte público?', 4, 1),
(2, 5, N'¿Qué tan fácil le resulta acceder a transporte público cuando lo necesita?', 1, 1),
(2, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de tiempos de traslado en su localidad?', 1, 1),
(2, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó tiempos de traslado?', 3, 1),
(2, 8, N'¿Conoce alguna opción o servicio relacionado con tiempos de traslado en su localidad?', 2, 1),
(2, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con tiempos de traslado?', 4, 1),
(2, 10, N'¿Qué tan fácil le resulta acceder a tiempos de traslado cuando lo necesita?', 1, 1),
(2, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de seguridad vial en su localidad?', 1, 1),
(2, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó seguridad vial?', 3, 1),
(2, 13, N'¿Conoce alguna opción o servicio relacionado con seguridad vial en su localidad?', 2, 1),
(2, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con seguridad vial?', 4, 1),
(2, 15, N'¿Qué tan fácil le resulta acceder a seguridad vial cuando lo necesita?', 1, 1),
(2, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de banquetas y cruces en su localidad?', 1, 1),
(2, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó banquetas y cruces?', 3, 1),
(2, 18, N'¿Conoce alguna opción o servicio relacionado con banquetas y cruces en su localidad?', 2, 1),
(2, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con banquetas y cruces?', 4, 1),
(2, 20, N'¿Qué tan fácil le resulta acceder a banquetas y cruces cuando lo necesita?', 1, 1),
(2, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de transporte accesible en su localidad?', 1, 1),
(2, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó transporte accesible?', 3, 1),
(2, 23, N'¿Conoce alguna opción o servicio relacionado con transporte accesible en su localidad?', 2, 1),
(2, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con transporte accesible?', 4, 1),
(2, 25, N'¿Qué tan fácil le resulta acceder a transporte accesible cuando lo necesita?', 1, 1),
(2, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de ciclovías en su localidad?', 1, 1),
(2, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó ciclovías?', 3, 1),
(2, 28, N'¿Conoce alguna opción o servicio relacionado con ciclovías en su localidad?', 2, 1),
(2, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con ciclovías?', 4, 1),
(2, 30, N'¿Qué tan fácil le resulta acceder a ciclovías cuando lo necesita?', 1, 1),
(2, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(2, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(3, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de alumbrado público en su localidad?', 1, 1),
(3, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó alumbrado público?', 3, 1),
(3, 3, N'¿Conoce alguna opción o servicio relacionado con alumbrado público en su localidad?', 2, 1),
(3, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con alumbrado público?', 4, 1),
(3, 5, N'¿Qué tan fácil le resulta acceder a alumbrado público cuando lo necesita?', 1, 1),
(3, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de vigilancia en la colonia en su localidad?', 1, 1),
(3, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó vigilancia en la colonia?', 3, 1),
(3, 8, N'¿Conoce alguna opción o servicio relacionado con vigilancia en la colonia en su localidad?', 2, 1),
(3, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con vigilancia en la colonia?', 4, 1),
(3, 10, N'¿Qué tan fácil le resulta acceder a vigilancia en la colonia cuando lo necesita?', 1, 1),
(3, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de espacios de convivencia en su localidad?', 1, 1),
(3, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó espacios de convivencia?', 3, 1),
(3, 13, N'¿Conoce alguna opción o servicio relacionado con espacios de convivencia en su localidad?', 2, 1),
(3, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con espacios de convivencia?', 4, 1),
(3, 15, N'¿Qué tan fácil le resulta acceder a espacios de convivencia cuando lo necesita?', 1, 1),
(3, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de denuncia de incidentes en su localidad?', 1, 1),
(3, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó denuncia de incidentes?', 3, 1),
(3, 18, N'¿Conoce alguna opción o servicio relacionado con denuncia de incidentes en su localidad?', 2, 1),
(3, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con denuncia de incidentes?', 4, 1),
(3, 20, N'¿Qué tan fácil le resulta acceder a denuncia de incidentes cuando lo necesita?', 1, 1),
(3, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de transporte nocturno en su localidad?', 1, 1),
(3, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó transporte nocturno?', 3, 1),
(3, 23, N'¿Conoce alguna opción o servicio relacionado con transporte nocturno en su localidad?', 2, 1),
(3, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con transporte nocturno?', 4, 1),
(3, 25, N'¿Qué tan fácil le resulta acceder a transporte nocturno cuando lo necesita?', 1, 1),
(3, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de confianza en autoridades en su localidad?', 1, 1),
(3, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó confianza en autoridades?', 3, 1),
(3, 28, N'¿Conoce alguna opción o servicio relacionado con confianza en autoridades en su localidad?', 2, 1),
(3, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con confianza en autoridades?', 4, 1),
(3, 30, N'¿Qué tan fácil le resulta acceder a confianza en autoridades cuando lo necesita?', 1, 1),
(3, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(3, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(4, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de cursos de actualización en su localidad?', 1, 1),
(4, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó cursos de actualización?', 3, 1),
(4, 3, N'¿Conoce alguna opción o servicio relacionado con cursos de actualización en su localidad?', 2, 1),
(4, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con cursos de actualización?', 4, 1),
(4, 5, N'¿Qué tan fácil le resulta acceder a cursos de actualización cuando lo necesita?', 1, 1),
(4, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de educación en línea en su localidad?', 1, 1),
(4, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó educación en línea?', 3, 1),
(4, 8, N'¿Conoce alguna opción o servicio relacionado con educación en línea en su localidad?', 2, 1),
(4, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con educación en línea?', 4, 1),
(4, 10, N'¿Qué tan fácil le resulta acceder a educación en línea cuando lo necesita?', 1, 1),
(4, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de bibliotecas públicas en su localidad?', 1, 1),
(4, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó bibliotecas públicas?', 3, 1),
(4, 13, N'¿Conoce alguna opción o servicio relacionado con bibliotecas públicas en su localidad?', 2, 1),
(4, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con bibliotecas públicas?', 4, 1),
(4, 15, N'¿Qué tan fácil le resulta acceder a bibliotecas públicas cuando lo necesita?', 1, 1),
(4, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de capacitación para el empleo en su localidad?', 1, 1),
(4, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó capacitación para el empleo?', 3, 1),
(4, 18, N'¿Conoce alguna opción o servicio relacionado con capacitación para el empleo en su localidad?', 2, 1),
(4, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con capacitación para el empleo?', 4, 1),
(4, 20, N'¿Qué tan fácil le resulta acceder a capacitación para el empleo cuando lo necesita?', 1, 1),
(4, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de habilidades digitales en su localidad?', 1, 1),
(4, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó habilidades digitales?', 3, 1),
(4, 23, N'¿Conoce alguna opción o servicio relacionado con habilidades digitales en su localidad?', 2, 1),
(4, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con habilidades digitales?', 4, 1),
(4, 25, N'¿Qué tan fácil le resulta acceder a habilidades digitales cuando lo necesita?', 1, 1),
(4, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de apoyos educativos en su localidad?', 1, 1),
(4, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó apoyos educativos?', 3, 1),
(4, 28, N'¿Conoce alguna opción o servicio relacionado con apoyos educativos en su localidad?', 2, 1),
(4, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con apoyos educativos?', 4, 1),
(4, 30, N'¿Qué tan fácil le resulta acceder a apoyos educativos cuando lo necesita?', 1, 1),
(4, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(4, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(5, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de búsqueda de empleo en su localidad?', 1, 1),
(5, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó búsqueda de empleo?', 3, 1),
(5, 3, N'¿Conoce alguna opción o servicio relacionado con búsqueda de empleo en su localidad?', 2, 1),
(5, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con búsqueda de empleo?', 4, 1),
(5, 5, N'¿Qué tan fácil le resulta acceder a búsqueda de empleo cuando lo necesita?', 1, 1),
(5, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de capacitación laboral en su localidad?', 1, 1),
(5, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó capacitación laboral?', 3, 1),
(5, 8, N'¿Conoce alguna opción o servicio relacionado con capacitación laboral en su localidad?', 2, 1),
(5, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con capacitación laboral?', 4, 1),
(5, 10, N'¿Qué tan fácil le resulta acceder a capacitación laboral cuando lo necesita?', 1, 1),
(5, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de seguridad en el trabajo en su localidad?', 1, 1),
(5, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó seguridad en el trabajo?', 3, 1),
(5, 13, N'¿Conoce alguna opción o servicio relacionado con seguridad en el trabajo en su localidad?', 2, 1),
(5, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con seguridad en el trabajo?', 4, 1),
(5, 15, N'¿Qué tan fácil le resulta acceder a seguridad en el trabajo cuando lo necesita?', 1, 1),
(5, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de horarios de trabajo en su localidad?', 1, 1),
(5, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó horarios de trabajo?', 3, 1),
(5, 18, N'¿Conoce alguna opción o servicio relacionado con horarios de trabajo en su localidad?', 2, 1),
(5, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con horarios de trabajo?', 4, 1),
(5, 20, N'¿Qué tan fácil le resulta acceder a horarios de trabajo cuando lo necesita?', 1, 1),
(5, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de ingresos laborales en su localidad?', 1, 1),
(5, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó ingresos laborales?', 3, 1),
(5, 23, N'¿Conoce alguna opción o servicio relacionado con ingresos laborales en su localidad?', 2, 1),
(5, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con ingresos laborales?', 4, 1),
(5, 25, N'¿Qué tan fácil le resulta acceder a ingresos laborales cuando lo necesita?', 1, 1),
(5, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de transporte al trabajo en su localidad?', 1, 1),
(5, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó transporte al trabajo?', 3, 1),
(5, 28, N'¿Conoce alguna opción o servicio relacionado con transporte al trabajo en su localidad?', 2, 1),
(5, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con transporte al trabajo?', 4, 1),
(5, 30, N'¿Qué tan fácil le resulta acceder a transporte al trabajo cuando lo necesita?', 1, 1),
(5, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(5, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(6, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de internet en el hogar en su localidad?', 1, 1),
(6, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó internet en el hogar?', 3, 1),
(6, 3, N'¿Conoce alguna opción o servicio relacionado con internet en el hogar en su localidad?', 2, 1),
(6, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con internet en el hogar?', 4, 1),
(6, 5, N'¿Qué tan fácil le resulta acceder a internet en el hogar cuando lo necesita?', 1, 1),
(6, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de telefonía móvil en su localidad?', 1, 1),
(6, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó telefonía móvil?', 3, 1),
(6, 8, N'¿Conoce alguna opción o servicio relacionado con telefonía móvil en su localidad?', 2, 1),
(6, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con telefonía móvil?', 4, 1),
(6, 10, N'¿Qué tan fácil le resulta acceder a telefonía móvil cuando lo necesita?', 1, 1),
(6, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de trámites en línea en su localidad?', 1, 1),
(6, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó trámites en línea?', 3, 1),
(6, 13, N'¿Conoce alguna opción o servicio relacionado con trámites en línea en su localidad?', 2, 1),
(6, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con trámites en línea?', 4, 1),
(6, 15, N'¿Qué tan fácil le resulta acceder a trámites en línea cuando lo necesita?', 1, 1),
(6, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de seguridad digital en su localidad?', 1, 1),
(6, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó seguridad digital?', 3, 1),
(6, 18, N'¿Conoce alguna opción o servicio relacionado con seguridad digital en su localidad?', 2, 1),
(6, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con seguridad digital?', 4, 1),
(6, 20, N'¿Qué tan fácil le resulta acceder a seguridad digital cuando lo necesita?', 1, 1),
(6, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de banca digital en su localidad?', 1, 1),
(6, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó banca digital?', 3, 1),
(6, 23, N'¿Conoce alguna opción o servicio relacionado con banca digital en su localidad?', 2, 1),
(6, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con banca digital?', 4, 1),
(6, 25, N'¿Qué tan fácil le resulta acceder a banca digital cuando lo necesita?', 1, 1),
(6, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de aprendizaje por internet en su localidad?', 1, 1),
(6, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó aprendizaje por internet?', 3, 1),
(6, 28, N'¿Conoce alguna opción o servicio relacionado con aprendizaje por internet en su localidad?', 2, 1),
(6, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con aprendizaje por internet?', 4, 1),
(6, 30, N'¿Qué tan fácil le resulta acceder a aprendizaje por internet cuando lo necesita?', 1, 1),
(6, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(6, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(7, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de suministro de agua en su localidad?', 1, 1),
(7, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó suministro de agua?', 3, 1),
(7, 3, N'¿Conoce alguna opción o servicio relacionado con suministro de agua en su localidad?', 2, 1),
(7, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con suministro de agua?', 4, 1),
(7, 5, N'¿Qué tan fácil le resulta acceder a suministro de agua cuando lo necesita?', 1, 1),
(7, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de calidad del agua en su localidad?', 1, 1),
(7, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó calidad del agua?', 3, 1),
(7, 8, N'¿Conoce alguna opción o servicio relacionado con calidad del agua en su localidad?', 2, 1),
(7, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con calidad del agua?', 4, 1),
(7, 10, N'¿Qué tan fácil le resulta acceder a calidad del agua cuando lo necesita?', 1, 1),
(7, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de reparación de fugas en su localidad?', 1, 1),
(7, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó reparación de fugas?', 3, 1),
(7, 13, N'¿Conoce alguna opción o servicio relacionado con reparación de fugas en su localidad?', 2, 1),
(7, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con reparación de fugas?', 4, 1),
(7, 15, N'¿Qué tan fácil le resulta acceder a reparación de fugas cuando lo necesita?', 1, 1),
(7, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de drenaje de la vivienda en su localidad?', 1, 1),
(7, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó drenaje de la vivienda?', 3, 1),
(7, 18, N'¿Conoce alguna opción o servicio relacionado con drenaje de la vivienda en su localidad?', 2, 1),
(7, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con drenaje de la vivienda?', 4, 1),
(7, 20, N'¿Qué tan fácil le resulta acceder a drenaje de la vivienda cuando lo necesita?', 1, 1),
(7, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de información sobre cortes en su localidad?', 1, 1),
(7, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó información sobre cortes?', 3, 1),
(7, 23, N'¿Conoce alguna opción o servicio relacionado con información sobre cortes en su localidad?', 2, 1),
(7, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con información sobre cortes?', 4, 1),
(7, 25, N'¿Qué tan fácil le resulta acceder a información sobre cortes cuando lo necesita?', 1, 1),
(7, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de ahorro de agua en su localidad?', 1, 1),
(7, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó ahorro de agua?', 3, 1),
(7, 28, N'¿Conoce alguna opción o servicio relacionado con ahorro de agua en su localidad?', 2, 1),
(7, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con ahorro de agua?', 4, 1),
(7, 30, N'¿Qué tan fácil le resulta acceder a ahorro de agua cuando lo necesita?', 1, 1),
(7, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(7, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(8, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de recolección de basura en su localidad?', 1, 1),
(8, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó recolección de basura?', 3, 1),
(8, 3, N'¿Conoce alguna opción o servicio relacionado con recolección de basura en su localidad?', 2, 1),
(8, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con recolección de basura?', 4, 1),
(8, 5, N'¿Qué tan fácil le resulta acceder a recolección de basura cuando lo necesita?', 1, 1),
(8, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de separación de residuos en su localidad?', 1, 1),
(8, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó separación de residuos?', 3, 1),
(8, 8, N'¿Conoce alguna opción o servicio relacionado con separación de residuos en su localidad?', 2, 1),
(8, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con separación de residuos?', 4, 1),
(8, 10, N'¿Qué tan fácil le resulta acceder a separación de residuos cuando lo necesita?', 1, 1),
(8, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de centros de reciclaje en su localidad?', 1, 1),
(8, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó centros de reciclaje?', 3, 1),
(8, 13, N'¿Conoce alguna opción o servicio relacionado con centros de reciclaje en su localidad?', 2, 1),
(8, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con centros de reciclaje?', 4, 1),
(8, 15, N'¿Qué tan fácil le resulta acceder a centros de reciclaje cuando lo necesita?', 1, 1),
(8, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de limpieza de calles en su localidad?', 1, 1),
(8, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó limpieza de calles?', 3, 1),
(8, 18, N'¿Conoce alguna opción o servicio relacionado con limpieza de calles en su localidad?', 2, 1),
(8, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con limpieza de calles?', 4, 1),
(8, 20, N'¿Qué tan fácil le resulta acceder a limpieza de calles cuando lo necesita?', 1, 1),
(8, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de áreas verdes en su localidad?', 1, 1),
(8, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó áreas verdes?', 3, 1),
(8, 23, N'¿Conoce alguna opción o servicio relacionado con áreas verdes en su localidad?', 2, 1),
(8, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con áreas verdes?', 4, 1),
(8, 25, N'¿Qué tan fácil le resulta acceder a áreas verdes cuando lo necesita?', 1, 1),
(8, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de reducción de plásticos en su localidad?', 1, 1),
(8, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó reducción de plásticos?', 3, 1),
(8, 28, N'¿Conoce alguna opción o servicio relacionado con reducción de plásticos en su localidad?', 2, 1),
(8, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con reducción de plásticos?', 4, 1),
(8, 30, N'¿Qué tan fácil le resulta acceder a reducción de plásticos cuando lo necesita?', 1, 1),
(8, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(8, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(9, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de actas y certificados en su localidad?', 1, 1),
(9, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó actas y certificados?', 3, 1),
(9, 3, N'¿Conoce alguna opción o servicio relacionado con actas y certificados en su localidad?', 2, 1),
(9, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con actas y certificados?', 4, 1),
(9, 5, N'¿Qué tan fácil le resulta acceder a actas y certificados cuando lo necesita?', 1, 1),
(9, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de pagos de servicios en su localidad?', 1, 1),
(9, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó pagos de servicios?', 3, 1),
(9, 8, N'¿Conoce alguna opción o servicio relacionado con pagos de servicios en su localidad?', 2, 1),
(9, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con pagos de servicios?', 4, 1),
(9, 10, N'¿Qué tan fácil le resulta acceder a pagos de servicios cuando lo necesita?', 1, 1),
(9, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de citas por internet en su localidad?', 1, 1),
(9, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó citas por internet?', 3, 1),
(9, 13, N'¿Conoce alguna opción o servicio relacionado con citas por internet en su localidad?', 2, 1),
(9, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con citas por internet?', 4, 1),
(9, 15, N'¿Qué tan fácil le resulta acceder a citas por internet cuando lo necesita?', 1, 1),
(9, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de atención en ventanilla en su localidad?', 1, 1),
(9, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó atención en ventanilla?', 3, 1),
(9, 18, N'¿Conoce alguna opción o servicio relacionado con atención en ventanilla en su localidad?', 2, 1),
(9, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con atención en ventanilla?', 4, 1),
(9, 20, N'¿Qué tan fácil le resulta acceder a atención en ventanilla cuando lo necesita?', 1, 1),
(9, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de orientación telefónica en su localidad?', 1, 1),
(9, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó orientación telefónica?', 3, 1),
(9, 23, N'¿Conoce alguna opción o servicio relacionado con orientación telefónica en su localidad?', 2, 1),
(9, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con orientación telefónica?', 4, 1),
(9, 25, N'¿Qué tan fácil le resulta acceder a orientación telefónica cuando lo necesita?', 1, 1),
(9, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de seguimiento de solicitudes en su localidad?', 1, 1),
(9, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó seguimiento de solicitudes?', 3, 1),
(9, 28, N'¿Conoce alguna opción o servicio relacionado con seguimiento de solicitudes en su localidad?', 2, 1),
(9, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con seguimiento de solicitudes?', 4, 1),
(9, 30, N'¿Qué tan fácil le resulta acceder a seguimiento de solicitudes cuando lo necesita?', 1, 1),
(9, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(9, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0),
(10, 1, N'¿Qué tan satisfactoria considera la atención o disponibilidad de parques públicos en su localidad?', 1, 1),
(10, 2, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó parques públicos?', 3, 1),
(10, 3, N'¿Conoce alguna opción o servicio relacionado con parques públicos en su localidad?', 2, 1),
(10, 4, N'Durante el último mes, ¿cuántas veces tuvo contacto con parques públicos?', 4, 1),
(10, 5, N'¿Qué tan fácil le resulta acceder a parques públicos cuando lo necesita?', 1, 1),
(10, 6, N'¿Qué tan satisfactoria considera la atención o disponibilidad de centros deportivos en su localidad?', 1, 1),
(10, 7, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó centros deportivos?', 3, 1),
(10, 8, N'¿Conoce alguna opción o servicio relacionado con centros deportivos en su localidad?', 2, 1),
(10, 9, N'Durante el último mes, ¿cuántas veces tuvo contacto con centros deportivos?', 4, 1),
(10, 10, N'¿Qué tan fácil le resulta acceder a centros deportivos cuando lo necesita?', 1, 1),
(10, 11, N'¿Qué tan satisfactoria considera la atención o disponibilidad de centros culturales en su localidad?', 1, 1),
(10, 12, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó centros culturales?', 3, 1),
(10, 13, N'¿Conoce alguna opción o servicio relacionado con centros culturales en su localidad?', 2, 1),
(10, 14, N'Durante el último mes, ¿cuántas veces tuvo contacto con centros culturales?', 4, 1),
(10, 15, N'¿Qué tan fácil le resulta acceder a centros culturales cuando lo necesita?', 1, 1),
(10, 16, N'¿Qué tan satisfactoria considera la atención o disponibilidad de mercados públicos en su localidad?', 1, 1),
(10, 17, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó mercados públicos?', 3, 1),
(10, 18, N'¿Conoce alguna opción o servicio relacionado con mercados públicos en su localidad?', 2, 1),
(10, 19, N'Durante el último mes, ¿cuántas veces tuvo contacto con mercados públicos?', 4, 1),
(10, 20, N'¿Qué tan fácil le resulta acceder a mercados públicos cuando lo necesita?', 1, 1),
(10, 21, N'¿Qué tan satisfactoria considera la atención o disponibilidad de actividades comunitarias en su localidad?', 1, 1),
(10, 22, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó actividades comunitarias?', 3, 1),
(10, 23, N'¿Conoce alguna opción o servicio relacionado con actividades comunitarias en su localidad?', 2, 1),
(10, 24, N'Durante el último mes, ¿cuántas veces tuvo contacto con actividades comunitarias?', 4, 1),
(10, 25, N'¿Qué tan fácil le resulta acceder a actividades comunitarias cuando lo necesita?', 1, 1),
(10, 26, N'¿Qué tan satisfactoria considera la atención o disponibilidad de accesibilidad de espacios en su localidad?', 1, 1),
(10, 27, N'Durante el último mes, ¿con qué frecuencia utilizó o consultó accesibilidad de espacios?', 3, 1),
(10, 28, N'¿Conoce alguna opción o servicio relacionado con accesibilidad de espacios en su localidad?', 2, 1),
(10, 29, N'Durante el último mes, ¿cuántas veces tuvo contacto con accesibilidad de espacios?', 4, 1),
(10, 30, N'¿Qué tan fácil le resulta acceder a accesibilidad de espacios cuando lo necesita?', 1, 1),
(10, 31, N'¿Cuál es el principal cambio que propondría para mejorar los servicios relacionados con esta encuesta?', 5, 0),
(10, 32, N'¿Desea agregar algún comentario sobre su experiencia reciente?', 5, 0);


/* 80 personas distintas por encuesta; cada persona puede contestar varias encuestas. */
;WITH N AS (
 SELECT TOP (80) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
 FROM sys.all_objects
)
INSERT levantamiento.Participacion (EncuestaID, EncuestadoID, FechaRespuesta)
SELECT e.EncuestaID,
       ((e.EncuestaID - 1) * 17 + n.n * 7) % 200 + 1,
       DATEADD(minute, n.n * 19 + e.EncuestaID * 37,
               DATEADD(day, (n.n * 3 + e.EncuestaID * 5) % 70,
                       CONVERT(datetime2(0), '2026-04-01T09:00:00')))
FROM instrumento.Encuesta AS e CROSS JOIN N AS n;

/* Una respuesta válida por pregunta y participación. Las 2 abiertas son opcionales:
   se contestan en alrededor de una de cada cuatro participaciones. */
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
   CASE (p.EncuestadoID + q.Numero) % 6
     WHEN 0 THEN N'Ampliar horarios y comunicar cambios con anticipación.'
     WHEN 1 THEN N'Mejorar la atención y reducir tiempos de espera.'
     WHEN 2 THEN N'Mantener actualizada la información disponible al público.'
     WHEN 3 THEN N'Ofrecer opciones accesibles para distintos grupos de edad.'
     WHEN 4 THEN N'Dar seguimiento a las solicitudes realizadas.'
     ELSE N'Por ahora no tengo otra sugerencia específica.'
   END END
FROM levantamiento.Participacion AS p
JOIN instrumento.Pregunta AS q ON q.EncuestaID = p.EncuestaID
WHERE q.TipoPreguntaID <> 5 OR (p.EncuestadoID + q.Numero) % 4 = 0;


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

CREATE INDEX IX_Encuestados_Area ON panel.Encuestados (AreaID, GradoEstudiosID);
CREATE INDEX IX_Participacion_Encuestado ON levantamiento.Participacion (EncuestadoID, EncuestaID);
CREATE INDEX IX_Respuesta_PreguntaOpcion ON levantamiento.Respuesta (PreguntaID, OpcionID)
 INCLUDE (EncuestaID, ValorEntero);
CREATE INDEX IX_Respuesta_Encuesta_Tipo ON levantamiento.Respuesta (EncuestaID, TipoPreguntaID)
 INCLUDE (OpcionID, ValorEntero);
COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT > 0 ROLLBACK;
 THROW;
END CATCH;
GO

/* Devuelve el título de una encuesta por su identificador.
   Si el ID no existe, devuelve NULL. */
CREATE OR ALTER FUNCTION instrumento.ufn_NombreEncuesta
(
    @EncuestaID smallint
)
RETURNS nvarchar(150)
AS
BEGIN
    DECLARE @Nombre nvarchar(150);

    SELECT @Nombre = Titulo
    FROM instrumento.Encuesta
    WHERE EncuestaID = @EncuestaID;

    RETURN @Nombre;
END;
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

/* Una fila por respuesta cerrada o numérica, con demografía agregada. */
CREATE OR ALTER VIEW analitica.vw_RespuestaLarga
AS
SELECT r.RespuestaID, r.ParticipacionID, r.EncuestaID, enc.Titulo AS Encuesta,
       r.PreguntaID, q.Numero, q.Texto AS Pregunta, q.Obligatoria,
       r.TipoPreguntaID, tp.Nombre AS TipoPregunta,
       r.OpcionID, o.Etiqueta,
       COALESCE(CONVERT(int, o.ValorNumerico), r.ValorEntero) AS Valor,
       p.FechaRespuesta, e.Sexo,
       CASE WHEN e.Edad < 30 THEN N'18-29'
            WHEN e.Edad < 45 THEN N'30-44'
            WHEN e.Edad < 60 THEN N'45-59'
            ELSE N'60+' END AS GrupoEdad,
       g.Nombre AS GradoEstudios, a.Nombre AS Area, e.EntidadFederativa
FROM levantamiento.Respuesta AS r
JOIN levantamiento.Participacion AS p ON p.ParticipacionID = r.ParticipacionID
JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = r.EncuestaID
JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
JOIN instrumento.TipoPregunta AS tp ON tp.TipoPreguntaID = r.TipoPreguntaID
JOIN panel.Encuestados AS e ON e.EncuestadoID = p.EncuestadoID
JOIN panel.GradoEstudios AS g ON g.GradoEstudiosID = e.GradoEstudiosID
LEFT JOIN panel.Area AS a ON a.AreaID = e.AreaID
LEFT JOIN instrumento.OpcionRespuesta AS o ON o.OpcionID = r.OpcionID
WHERE r.ValorTexto IS NULL;
GO

/* Cobertura de preguntas obligatorias, incluidas encuestas sin participantes. */
CREATE OR ALTER VIEW analitica.vw_CoberturaEncuesta
AS
WITH Participantes AS (
    SELECT EncuestaID, COUNT(*) AS Total
    FROM levantamiento.Participacion
    GROUP BY EncuestaID
), Obligatorias AS (
    SELECT EncuestaID, COUNT(*) AS Total
    FROM instrumento.Pregunta
    WHERE Obligatoria = 1
    GROUP BY EncuestaID
), Respondidas AS (
    SELECT r.EncuestaID, COUNT(*) AS Total
    FROM levantamiento.Respuesta AS r
    JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
    WHERE q.Obligatoria = 1
    GROUP BY r.EncuestaID
)
SELECT enc.EncuestaID, enc.Titulo AS Encuesta,
       COALESCE(pa.Total, 0) AS Participantes,
       COALESCE(ob.Total, 0) AS PreguntasObligatorias,
       COALESCE(pa.Total, 0) * COALESCE(ob.Total, 0) AS ObligatoriasEsperadas,
       COALESCE(re.Total, 0) AS ObligatoriasRespondidas,
       CONVERT(decimal(5,2), 100.0 * re.Total
           / NULLIF(COALESCE(pa.Total, 0) * COALESCE(ob.Total, 0), 0)) AS CoberturaPorcentaje
FROM instrumento.Encuesta AS enc
LEFT JOIN Participantes AS pa ON pa.EncuestaID = enc.EncuestaID
LEFT JOIN Obligatorias AS ob ON ob.EncuestaID = enc.EncuestaID
LEFT JOIN Respondidas AS re ON re.EncuestaID = enc.EncuestaID;
GO

/* Distribución por pregunta y opción observada; en preguntas numéricas, el promedio. */
CREATE OR ALTER VIEW analitica.vw_ResultadoPregunta
AS
SELECT enc.EncuestaID, enc.Titulo AS Encuesta,
       q.PreguntaID, q.Numero, q.Texto AS Pregunta, tp.Nombre AS TipoPregunta,
       o.OpcionID, o.Etiqueta, o.ValorNumerico,
       COUNT(*) AS Respuestas,
       CONVERT(decimal(5,2), 100.0 * COUNT(*)
           / SUM(COUNT(*)) OVER (PARTITION BY q.PreguntaID)) AS Porcentaje,
       CONVERT(decimal(10,2), AVG(CONVERT(decimal(10,2), r.ValorEntero))) AS PromedioValor
FROM levantamiento.Respuesta AS r
JOIN instrumento.Pregunta AS q ON q.PreguntaID = r.PreguntaID
JOIN instrumento.Encuesta AS enc ON enc.EncuestaID = r.EncuestaID
JOIN instrumento.TipoPregunta AS tp ON tp.TipoPreguntaID = r.TipoPreguntaID
LEFT JOIN instrumento.OpcionRespuesta AS o ON o.OpcionID = r.OpcionID
WHERE r.ValorTexto IS NULL
GROUP BY enc.EncuestaID, enc.Titulo, q.PreguntaID, q.Numero, q.Texto, tp.Nombre,
         o.OpcionID, o.Etiqueta, o.ValorNumerico;
GO

/* Roles por esquema. Solo rol_analista puede leer la capa analítica sin ver datos personales. */
IF DATABASE_PRINCIPAL_ID(N'rol_analista') IS NULL CREATE ROLE rol_analista AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_captura') IS NULL CREATE ROLE rol_captura AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_diseno') IS NULL CREATE ROLE rol_diseno AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_padron') IS NULL CREATE ROLE rol_padron AUTHORIZATION dbo;

GRANT SELECT ON SCHEMA::analitica TO rol_analista;

GRANT SELECT, INSERT, UPDATE ON SCHEMA::levantamiento TO rol_captura;
GRANT EXECUTE ON SCHEMA::levantamiento TO rol_captura;
GRANT SELECT ON SCHEMA::instrumento TO rol_captura;

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::instrumento TO rol_diseno;
GRANT EXECUTE ON SCHEMA::instrumento TO rol_diseno;

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::panel TO rol_padron;
GO
/* Resumen verificable: 300 encuestados, 12 encuestas,
   32 preguntas por encuesta; participación variable y dos encuestas sin respuesta. */
SELECT e.EncuestaID, e.Titulo,
       COUNT(DISTINCT q.PreguntaID) AS Preguntas,
       (SELECT COUNT(*) FROM levantamiento.Participacion p WHERE p.EncuestaID = e.EncuestaID) AS Participantes,
       (SELECT COUNT(*) FROM levantamiento.Respuesta r WHERE r.EncuestaID = e.EncuestaID) AS Respuestas
FROM instrumento.Encuesta e JOIN instrumento.Pregunta q ON q.EncuestaID = e.EncuestaID
GROUP BY e.EncuestaID, e.Titulo ORDER BY e.EncuestaID;
SELECT (SELECT COUNT(*) FROM panel.Encuestados) AS Encuestados,
       (SELECT COUNT(*) FROM levantamiento.Participacion) AS Participaciones,
       (SELECT COUNT(*) FROM levantamiento.Respuesta) AS Respuestas;
GO
