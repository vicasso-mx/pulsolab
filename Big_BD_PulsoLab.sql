/*
 Base didáctica de encuestas, SQL Server 2025 (17.x).
 Datos ficticios. Los temas se inspiraron en áreas investigadas por INEGI;
 las preguntas, el diseño y las respuestas son originales y no representan
 cuestionarios oficiales, estimaciones ni una muestra probabilística.
 Referencias: https://www.inegi.org.mx/programas/ensu/
              https://www.inegi.org.mx/programas/endutih/2025/
 Ejecutar en una ventana nueva de SSMS con permisos CREATE DATABASE.
 La base BigPulsoLAB se crea si no existe. La carga exige que
 aún no existan tablas del modelo; repetirla no modifica datos previos.
*/
USE master;
GO
IF DB_ID(N'BigPulsoLAB') IS NULL
    EXEC(N'CREATE DATABASE BigPulsoLAB');
GO
USE BigPulsoLAB;
GO
SET XACT_ABORT ON;
BEGIN TRY
IF OBJECT_ID(N'dbo.Encuesta', N'U') IS NOT NULL
    THROW 51000, N'El modelo ya existe. La carga no se repetirá.', 1;
BEGIN TRAN;

CREATE TABLE dbo.Area (
 AreaID smallint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Area PRIMARY KEY,
 Nombre nvarchar(100) NOT NULL CONSTRAINT UQ_Area_Nombre UNIQUE,
 Descripcion nvarchar(250) NULL
);
CREATE TABLE dbo.GradoEstudios (
 GradoEstudiosID tinyint NOT NULL CONSTRAINT PK_GradoEstudios PRIMARY KEY,
 Nombre nvarchar(80) NOT NULL CONSTRAINT UQ_GradoEstudios_Nombre UNIQUE
);
CREATE TABLE dbo.Encuestados (
 EncuestadoID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Encuestados PRIMARY KEY,
 Nombre nvarchar(60) NOT NULL,
 ApellidoPaterno nvarchar(60) NOT NULL,
 ApellidoMaterno nvarchar(60) NOT NULL,
 Edad tinyint NOT NULL CONSTRAINT CK_Encuestados_Edad CHECK (Edad BETWEEN 18 AND 85),
 Sexo char(1) NOT NULL CONSTRAINT CK_Encuestados_Sexo CHECK (Sexo IN ('M','H','X')),
 GradoEstudiosID tinyint NOT NULL CONSTRAINT FK_Encuestados_GradoEstudios REFERENCES dbo.GradoEstudios(GradoEstudiosID),
 AreaID smallint NULL CONSTRAINT FK_Encuestados_Area REFERENCES dbo.Area(AreaID),
 EntidadFederativa nvarchar(80) NOT NULL,
 MunicipioAlcaldia nvarchar(100) NOT NULL,
 Ocupacion nvarchar(80) NOT NULL
);
CREATE TABLE dbo.Encuesta (
 EncuestaID smallint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Encuesta PRIMARY KEY,
 Titulo nvarchar(150) NOT NULL CONSTRAINT UQ_Encuesta_Titulo UNIQUE,
 Objetivo nvarchar(300) NOT NULL,
 MetadatosXML xml NULL,
 FechaInicio date NOT NULL,
 FechaFin date NOT NULL,
 CONSTRAINT CK_Encuesta_Fechas CHECK (FechaFin >= FechaInicio)
);
CREATE TABLE dbo.TipoPregunta (
 TipoPreguntaID tinyint NOT NULL CONSTRAINT PK_TipoPregunta PRIMARY KEY,
 Nombre nvarchar(60) NOT NULL CONSTRAINT UQ_TipoPregunta_Nombre UNIQUE
);
CREATE TABLE dbo.OpcionRespuesta (
 OpcionID tinyint NOT NULL,
 TipoPreguntaID tinyint NOT NULL CONSTRAINT FK_Opcion_Tipo REFERENCES dbo.TipoPregunta(TipoPreguntaID),
 Etiqueta nvarchar(100) NOT NULL,
 ValorNumerico tinyint NULL,
 CriterioJSON json NULL,
 CONSTRAINT PK_Opcion PRIMARY KEY (OpcionID),
 CONSTRAINT UQ_Opcion_Tipo UNIQUE (OpcionID, TipoPreguntaID),
 CONSTRAINT UQ_Opcion_Etiqueta UNIQUE (TipoPreguntaID, Etiqueta)
);
CREATE TABLE dbo.Pregunta (
 PreguntaID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pregunta PRIMARY KEY,
 EncuestaID smallint NOT NULL CONSTRAINT FK_Pregunta_Encuesta REFERENCES dbo.Encuesta(EncuestaID),
 Numero smallint NOT NULL,
 Texto nvarchar(400) NOT NULL,
 TextoVector vector(384) NULL, -- Embedding de Texto; usar un modelo de 384 dimensiones.
 TipoPreguntaID tinyint NOT NULL CONSTRAINT FK_Pregunta_Tipo REFERENCES dbo.TipoPregunta(TipoPreguntaID),
 Obligatoria bit NOT NULL CONSTRAINT DF_Pregunta_Obligatoria DEFAULT (1),
 CONSTRAINT UQ_Pregunta_EncuestaNumero UNIQUE (EncuestaID, Numero),
 CONSTRAINT UQ_Pregunta_Compuesta UNIQUE (PreguntaID, EncuestaID, TipoPreguntaID)
);
CREATE TABLE dbo.Participacion (
 ParticipacionID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Participacion PRIMARY KEY,
 EncuestaID smallint NOT NULL CONSTRAINT FK_Participacion_Encuesta REFERENCES dbo.Encuesta(EncuestaID),
 EncuestadoID int NOT NULL CONSTRAINT FK_Participacion_Encuestado REFERENCES dbo.Encuestados(EncuestadoID),
 FechaRespuesta datetime2(0) NOT NULL,
 CONSTRAINT UQ_Participacion_EncuestaEncuestado UNIQUE (EncuestaID, EncuestadoID),
 CONSTRAINT UQ_Participacion_Compuesta UNIQUE (ParticipacionID, EncuestaID)
);
CREATE TABLE dbo.Respuesta (
 RespuestaID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Respuesta PRIMARY KEY,
 ParticipacionID int NOT NULL,
 EncuestaID smallint NOT NULL,
 PreguntaID int NOT NULL,
 TipoPreguntaID tinyint NOT NULL,
 OpcionID tinyint NULL,
 ValorEntero int NULL,
 ValorTexto nvarchar(500) NULL,
 CONSTRAINT FK_Respuesta_Participacion FOREIGN KEY (ParticipacionID, EncuestaID)
   REFERENCES dbo.Participacion(ParticipacionID, EncuestaID),
 CONSTRAINT FK_Respuesta_Pregunta FOREIGN KEY (PreguntaID, EncuestaID, TipoPreguntaID)
   REFERENCES dbo.Pregunta(PreguntaID, EncuestaID, TipoPreguntaID),
 CONSTRAINT FK_Respuesta_Opcion FOREIGN KEY (OpcionID, TipoPreguntaID)
   REFERENCES dbo.OpcionRespuesta(OpcionID, TipoPreguntaID),
 CONSTRAINT UQ_Respuesta_ParticipacionPregunta UNIQUE (ParticipacionID, PreguntaID),
 CONSTRAINT CK_Respuesta_Formato CHECK (
    (TipoPreguntaID IN (1,2,3) AND OpcionID IS NOT NULL AND ValorEntero IS NULL AND ValorTexto IS NULL)
 OR (TipoPreguntaID = 4 AND OpcionID IS NULL AND ValorEntero BETWEEN 0 AND 60 AND ValorTexto IS NULL)
 OR (TipoPreguntaID = 5 AND OpcionID IS NULL AND ValorEntero IS NULL AND LEN(LTRIM(RTRIM(ValorTexto))) > 0)
 )
);

INSERT INTO dbo.Area (Nombre, Descripcion) VALUES
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

INSERT INTO dbo.GradoEstudios (GradoEstudiosID, Nombre) VALUES
(1, N'Primaria'),
(2, N'Secundaria'),
(3, N'Bachillerato'),
(4, N'Carrera técnica'),
(5, N'Licenciatura'),
(6, N'Especialidad'),
(7, N'Maestría'),
(8, N'Doctorado');

INSERT INTO dbo.Encuestados (Nombre, ApellidoPaterno, ApellidoMaterno, Edad, Sexo, GradoEstudiosID, AreaID, EntidadFederativa, MunicipioAlcaldia, Ocupacion) VALUES
(N'María Fernanda', N'Hernández', N'Morales', 18, 'M', 1, 1, N'Ciudad de México', N'Iztapalapa', N'Empleado/a'),
(N'María Fernanda', N'García', N'Cruz', 37, 'M', 4, 8, N'Puebla', N'Puebla', N'Trabajador/a independiente'),
(N'María Fernanda', N'Martínez', N'Reyes', 56, 'M', 7, 5, N'Ciudad de México', N'Xochimilco', N'Profesional de salud'),
(N'María Fernanda', N'López', N'Ortiz', 75, 'M', 2, 2, N'Querétaro', N'Querétaro', N'Jubilado/a'),
(N'María Fernanda', N'González', N'Vargas', 30, 'M', 5, 9, N'Estado de México', N'Ecatepec de Morelos', N'Estudiante'),
(N'María Fernanda', N'Pérez', N'Jiménez', 49, 'M', 8, 6, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Técnico/a'),
(N'María Fernanda', N'Sánchez', N'Mendoza', 68, 'M', 3, 3, N'Nuevo León', N'Monterrey', N'Servidor/a público/a'),
(N'María Fernanda', N'Ramírez', N'Castillo', 23, 'M', 6, 10, N'Ciudad de México', N'Coyoacán', N'Comerciante'),
(N'María Fernanda', N'Flores', N'Navarro', 42, 'M', 1, 7, N'Guanajuato', N'León', N'Docente'),
(N'María Fernanda', N'Torres', N'Ríos', 61, 'M', 4, 4, N'Estado de México', N'Nezahualcóyotl', N'Persona dedicada al hogar'),
(N'Guadalupe', N'Hernández', N'Ortiz', 80, 'M', 7, 1, N'Yucatán', N'Mérida', N'Comerciante'),
(N'Guadalupe', N'García', N'Vargas', 35, 'M', 2, 8, N'Jalisco', N'Guadalajara', N'Docente'),
(N'Guadalupe', N'Martínez', N'Jiménez', 54, 'M', 5, 5, N'Ciudad de México', N'Coyoacán', N'Persona dedicada al hogar'),
(N'Guadalupe', N'López', N'Mendoza', 73, 'M', 8, 2, N'Guanajuato', N'León', N'Empleado/a'),
(N'Guadalupe', N'González', N'Castillo', 28, 'M', 3, 9, N'Estado de México', N'Nezahualcóyotl', N'Trabajador/a independiente'),
(N'Guadalupe', N'Pérez', N'Navarro', 47, 'M', 6, 6, N'Yucatán', N'Mérida', N'Profesional de salud'),
(N'Guadalupe', N'Sánchez', N'Ríos', 66, 'M', 1, 3, N'Jalisco', N'Guadalajara', N'Jubilado/a'),
(N'Guadalupe', N'Ramírez', N'Morales', 21, 'M', 4, 10, N'Ciudad de México', N'Iztapalapa', N'Estudiante'),
(N'Guadalupe', N'Flores', N'Cruz', 40, 'M', 7, 7, N'Puebla', N'Puebla', N'Técnico/a'),
(N'Guadalupe', N'Torres', N'Reyes', 59, 'M', 2, 4, N'Ciudad de México', N'Xochimilco', N'Servidor/a público/a'),
(N'Ana Sofía', N'Hernández', N'Mendoza', 78, 'M', 5, 1, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Ana Sofía', N'García', N'Castillo', 33, 'M', 8, 8, N'Estado de México', N'Ecatepec de Morelos', N'Técnico/a'),
(N'Ana Sofía', N'Martínez', N'Navarro', 52, 'M', 3, 5, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Servidor/a público/a'),
(N'Ana Sofía', N'López', N'Ríos', 71, 'M', 6, 2, N'Nuevo León', N'Monterrey', N'Comerciante'),
(N'Ana Sofía', N'González', N'Morales', 26, 'M', 1, 9, N'Ciudad de México', N'Xochimilco', N'Docente'),
(N'Ana Sofía', N'Pérez', N'Cruz', 45, 'M', 4, 6, N'Querétaro', N'Querétaro', N'Persona dedicada al hogar'),
(N'Ana Sofía', N'Sánchez', N'Reyes', 64, 'M', 7, 3, N'Estado de México', N'Ecatepec de Morelos', N'Empleado/a'),
(N'Ana Sofía', N'Ramírez', N'Ortiz', 19, 'M', 2, 10, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Trabajador/a independiente'),
(N'Ana Sofía', N'Flores', N'Vargas', 38, 'M', 5, 7, N'Nuevo León', N'Monterrey', N'Profesional de salud'),
(N'Ana Sofía', N'Torres', N'Jiménez', 57, 'M', 8, 4, N'Ciudad de México', N'Coyoacán', N'Jubilado/a'),
(N'Daniela', N'Hernández', N'Ríos', 76, 'M', 3, 1, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Daniela', N'García', N'Morales', 31, 'M', 6, 8, N'Estado de México', N'Nezahualcóyotl', N'Profesional de salud'),
(N'Daniela', N'Martínez', N'Cruz', 50, 'M', 1, 5, N'Yucatán', N'Mérida', N'Jubilado/a'),
(N'Daniela', N'López', N'Reyes', 69, 'M', 4, 2, N'Jalisco', N'Guadalajara', N'Estudiante'),
(N'Daniela', N'González', N'Ortiz', 24, 'M', 7, 9, N'Ciudad de México', N'Iztapalapa', N'Técnico/a'),
(N'Daniela', N'Pérez', N'Vargas', 43, 'M', 2, 6, N'Puebla', N'Puebla', N'Servidor/a público/a'),
(N'Daniela', N'Sánchez', N'Jiménez', 62, 'M', 5, 3, N'Estado de México', N'Nezahualcóyotl', N'Comerciante'),
(N'Daniela', N'Ramírez', N'Mendoza', 81, 'M', 8, 10, N'Yucatán', N'Mérida', N'Docente'),
(N'Daniela', N'Flores', N'Castillo', 36, 'M', 3, 7, N'Jalisco', N'Guadalajara', N'Persona dedicada al hogar'),
(N'Daniela', N'Torres', N'Navarro', 55, 'M', 6, 4, N'Ciudad de México', N'Iztapalapa', N'Empleado/a'),
(N'Ximena', N'Hernández', N'Reyes', 74, 'M', 1, 1, N'Puebla', N'Puebla', N'Docente'),
(N'Ximena', N'García', N'Ortiz', 29, 'M', 4, 8, N'Ciudad de México', N'Xochimilco', N'Persona dedicada al hogar'),
(N'Ximena', N'Martínez', N'Vargas', 48, 'M', 7, 5, N'Querétaro', N'Querétaro', N'Empleado/a'),
(N'Ximena', N'López', N'Jiménez', 67, 'M', 2, 2, N'Estado de México', N'Ecatepec de Morelos', N'Trabajador/a independiente'),
(N'Ximena', N'González', N'Mendoza', 22, 'M', 5, 9, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Profesional de salud'),
(N'Ximena', N'Pérez', N'Castillo', 41, 'M', 8, 6, N'Nuevo León', N'Monterrey', N'Jubilado/a'),
(N'Ximena', N'Sánchez', N'Navarro', 60, 'M', 3, 3, N'Ciudad de México', N'Coyoacán', N'Estudiante'),
(N'Ximena', N'Ramírez', N'Ríos', 79, 'M', 6, 10, N'Guanajuato', N'León', N'Técnico/a'),
(N'Ximena', N'Flores', N'Morales', 34, 'M', 1, 7, N'Estado de México', N'Ecatepec de Morelos', N'Servidor/a público/a'),
(N'Ximena', N'Torres', N'Cruz', 53, 'M', 4, 4, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Comerciante'),
(N'Valeria', N'Hernández', N'Jiménez', 72, 'M', 7, 1, N'Nuevo León', N'Monterrey', N'Técnico/a'),
(N'Valeria', N'García', N'Mendoza', 27, 'M', 2, 8, N'Ciudad de México', N'Coyoacán', N'Servidor/a público/a'),
(N'Valeria', N'Martínez', N'Castillo', 46, 'M', 5, 5, N'Guanajuato', N'León', N'Comerciante'),
(N'Valeria', N'López', N'Navarro', 65, 'M', 8, 2, N'Estado de México', N'Nezahualcóyotl', N'Docente'),
(N'Valeria', N'González', N'Ríos', 20, 'M', 3, 9, N'Yucatán', N'Mérida', N'Persona dedicada al hogar'),
(N'Valeria', N'Pérez', N'Morales', 39, 'M', 6, 6, N'Jalisco', N'Guadalajara', N'Empleado/a'),
(N'Valeria', N'Sánchez', N'Cruz', 58, 'M', 1, 3, N'Ciudad de México', N'Iztapalapa', N'Trabajador/a independiente'),
(N'Valeria', N'Ramírez', N'Reyes', 77, 'M', 4, 10, N'Puebla', N'Puebla', N'Profesional de salud'),
(N'Valeria', N'Flores', N'Ortiz', 32, 'M', 7, 7, N'Ciudad de México', N'Xochimilco', N'Jubilado/a'),
(N'Valeria', N'Torres', N'Vargas', 51, 'M', 2, 4, N'Querétaro', N'Querétaro', N'Estudiante'),
(N'Alejandra', N'Hernández', N'Navarro', 70, 'M', 5, 1, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'Alejandra', N'García', N'Ríos', 25, 'M', 8, 8, N'Ciudad de México', N'Iztapalapa', N'Jubilado/a'),
(N'Alejandra', N'Martínez', N'Morales', 44, 'M', 3, 5, N'Puebla', N'Puebla', N'Estudiante'),
(N'Alejandra', N'López', N'Cruz', 63, 'M', 6, 2, N'Ciudad de México', N'Xochimilco', N'Técnico/a'),
(N'Alejandra', N'González', N'Reyes', 18, 'M', 1, 9, N'Querétaro', N'Querétaro', N'Servidor/a público/a'),
(N'Alejandra', N'Pérez', N'Ortiz', 37, 'M', 4, 6, N'Estado de México', N'Ecatepec de Morelos', N'Comerciante'),
(N'Alejandra', N'Sánchez', N'Vargas', 56, 'M', 7, 3, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Docente'),
(N'Alejandra', N'Ramírez', N'Jiménez', 75, 'M', 2, 10, N'Nuevo León', N'Monterrey', N'Persona dedicada al hogar'),
(N'Alejandra', N'Flores', N'Mendoza', 30, 'M', 5, 7, N'Ciudad de México', N'Coyoacán', N'Empleado/a'),
(N'Alejandra', N'Torres', N'Castillo', 49, 'M', 8, 4, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Montserrat', N'Hernández', N'Cruz', 68, 'M', 3, 1, N'Estado de México', N'Nezahualcóyotl', N'Persona dedicada al hogar'),
(N'Montserrat', N'García', N'Reyes', 23, 'M', 6, 8, N'Yucatán', N'Mérida', N'Empleado/a'),
(N'Montserrat', N'Martínez', N'Ortiz', 42, 'M', 1, 5, N'Nuevo León', N'Monterrey', N'Trabajador/a independiente'),
(N'Montserrat', N'López', N'Vargas', 61, 'M', 4, 2, N'Ciudad de México', N'Coyoacán', N'Profesional de salud'),
(N'Montserrat', N'González', N'Jiménez', 80, 'M', 7, 9, N'Guanajuato', N'León', N'Jubilado/a'),
(N'Montserrat', N'Pérez', N'Mendoza', 35, 'M', 2, 6, N'Estado de México', N'Nezahualcóyotl', N'Estudiante'),
(N'Montserrat', N'Sánchez', N'Castillo', 54, 'M', 5, 3, N'Yucatán', N'Mérida', N'Técnico/a'),
(N'Montserrat', N'Ramírez', N'Navarro', 73, 'M', 8, 10, N'Jalisco', N'Guadalajara', N'Servidor/a público/a'),
(N'Montserrat', N'Flores', N'Ríos', 28, 'M', 3, 7, N'Ciudad de México', N'Iztapalapa', N'Comerciante'),
(N'Montserrat', N'Torres', N'Morales', 47, 'M', 6, 4, N'Puebla', N'Puebla', N'Docente'),
(N'Patricia', N'Hernández', N'Vargas', 66, 'M', 1, 1, N'Ciudad de México', N'Xochimilco', N'Servidor/a público/a'),
(N'Patricia', N'García', N'Jiménez', 21, 'M', 4, 8, N'Querétaro', N'Querétaro', N'Comerciante'),
(N'Patricia', N'Martínez', N'Mendoza', 40, 'M', 7, 5, N'Estado de México', N'Ecatepec de Morelos', N'Docente'),
(N'Patricia', N'López', N'Castillo', 59, 'M', 2, 2, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Persona dedicada al hogar'),
(N'Patricia', N'González', N'Navarro', 78, 'M', 5, 9, N'Puebla', N'Puebla', N'Empleado/a'),
(N'Patricia', N'Pérez', N'Ríos', 33, 'M', 8, 6, N'Ciudad de México', N'Xochimilco', N'Trabajador/a independiente'),
(N'Patricia', N'Sánchez', N'Morales', 52, 'M', 3, 3, N'Querétaro', N'Querétaro', N'Profesional de salud'),
(N'Patricia', N'Ramírez', N'Cruz', 71, 'M', 6, 10, N'Estado de México', N'Ecatepec de Morelos', N'Jubilado/a'),
(N'Patricia', N'Flores', N'Reyes', 26, 'M', 1, 7, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Estudiante'),
(N'Patricia', N'Torres', N'Ortiz', 45, 'M', 4, 4, N'Nuevo León', N'Monterrey', N'Técnico/a'),
(N'Rosa Elena', N'Hernández', N'Castillo', 64, 'M', 7, 1, N'Ciudad de México', N'Coyoacán', N'Jubilado/a'),
(N'Rosa Elena', N'García', N'Navarro', 19, 'M', 2, 8, N'Guanajuato', N'León', N'Estudiante'),
(N'Rosa Elena', N'Martínez', N'Ríos', 38, 'M', 5, 5, N'Estado de México', N'Nezahualcóyotl', N'Técnico/a'),
(N'Rosa Elena', N'López', N'Morales', 57, 'M', 8, 2, N'Yucatán', N'Mérida', N'Servidor/a público/a'),
(N'Rosa Elena', N'González', N'Cruz', 76, 'M', 3, 9, N'Jalisco', N'Guadalajara', N'Comerciante'),
(N'Rosa Elena', N'Pérez', N'Reyes', 31, 'M', 6, 6, N'Ciudad de México', N'Iztapalapa', N'Docente'),
(N'Rosa Elena', N'Sánchez', N'Ortiz', 50, 'M', 1, 3, N'Guanajuato', N'León', N'Persona dedicada al hogar'),
(N'Rosa Elena', N'Ramírez', N'Vargas', 69, 'M', 4, 10, N'Estado de México', N'Nezahualcóyotl', N'Empleado/a'),
(N'Rosa Elena', N'Flores', N'Jiménez', 24, 'M', 7, 7, N'Yucatán', N'Mérida', N'Trabajador/a independiente'),
(N'Rosa Elena', N'Torres', N'Mendoza', 43, 'M', 2, 4, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'José Luis', N'Hernández', N'Morales', 62, 'H', 5, 1, N'Ciudad de México', N'Iztapalapa', N'Empleado/a'),
(N'José Luis', N'García', N'Cruz', 81, 'H', 8, 8, N'Puebla', N'Puebla', N'Trabajador/a independiente'),
(N'José Luis', N'Martínez', N'Reyes', 36, 'H', 3, 5, N'Ciudad de México', N'Xochimilco', N'Profesional de salud'),
(N'José Luis', N'López', N'Ortiz', 55, 'H', 6, 2, N'Querétaro', N'Querétaro', N'Jubilado/a'),
(N'José Luis', N'González', N'Vargas', 74, 'H', 1, 9, N'Estado de México', N'Ecatepec de Morelos', N'Estudiante'),
(N'José Luis', N'Pérez', N'Jiménez', 29, 'H', 4, 6, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Técnico/a'),
(N'José Luis', N'Sánchez', N'Mendoza', 48, 'H', 7, 3, N'Nuevo León', N'Monterrey', N'Servidor/a público/a'),
(N'José Luis', N'Ramírez', N'Castillo', 67, 'H', 2, 10, N'Ciudad de México', N'Coyoacán', N'Comerciante'),
(N'José Luis', N'Flores', N'Navarro', 22, 'H', 5, 7, N'Querétaro', N'Querétaro', N'Docente'),
(N'José Luis', N'Torres', N'Ríos', 41, 'H', 8, 4, N'Estado de México', N'Ecatepec de Morelos', N'Persona dedicada al hogar'),
(N'Juan Carlos', N'Hernández', N'Ortiz', 60, 'H', 3, 1, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Comerciante'),
(N'Juan Carlos', N'García', N'Vargas', 79, 'H', 6, 8, N'Nuevo León', N'Monterrey', N'Docente'),
(N'Juan Carlos', N'Martínez', N'Jiménez', 34, 'H', 1, 5, N'Ciudad de México', N'Coyoacán', N'Persona dedicada al hogar'),
(N'Juan Carlos', N'López', N'Mendoza', 53, 'H', 4, 2, N'Guanajuato', N'León', N'Empleado/a'),
(N'Juan Carlos', N'González', N'Castillo', 72, 'H', 7, 9, N'Estado de México', N'Nezahualcóyotl', N'Trabajador/a independiente'),
(N'Juan Carlos', N'Pérez', N'Navarro', 27, 'H', 2, 6, N'Yucatán', N'Mérida', N'Profesional de salud'),
(N'Juan Carlos', N'Sánchez', N'Ríos', 46, 'H', 5, 3, N'Jalisco', N'Guadalajara', N'Jubilado/a'),
(N'Juan Carlos', N'Ramírez', N'Morales', 65, 'H', 8, 10, N'Ciudad de México', N'Iztapalapa', N'Estudiante'),
(N'Juan Carlos', N'Flores', N'Cruz', 20, 'H', 3, 7, N'Puebla', N'Puebla', N'Técnico/a'),
(N'Juan Carlos', N'Torres', N'Reyes', 39, 'H', 6, 4, N'Ciudad de México', N'Xochimilco', N'Servidor/a público/a'),
(N'Miguel Ángel', N'Hernández', N'Mendoza', 58, 'H', 1, 1, N'Yucatán', N'Mérida', N'Estudiante'),
(N'Miguel Ángel', N'García', N'Castillo', 77, 'H', 4, 8, N'Jalisco', N'Guadalajara', N'Técnico/a'),
(N'Miguel Ángel', N'Martínez', N'Navarro', 32, 'H', 7, 5, N'Ciudad de México', N'Iztapalapa', N'Servidor/a público/a'),
(N'Miguel Ángel', N'López', N'Ríos', 51, 'H', 2, 2, N'Puebla', N'Puebla', N'Comerciante'),
(N'Miguel Ángel', N'González', N'Morales', 70, 'H', 5, 9, N'Ciudad de México', N'Xochimilco', N'Docente'),
(N'Miguel Ángel', N'Pérez', N'Cruz', 25, 'H', 8, 6, N'Querétaro', N'Querétaro', N'Persona dedicada al hogar'),
(N'Miguel Ángel', N'Sánchez', N'Reyes', 44, 'H', 3, 3, N'Estado de México', N'Ecatepec de Morelos', N'Empleado/a'),
(N'Miguel Ángel', N'Ramírez', N'Ortiz', 63, 'H', 6, 10, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Trabajador/a independiente'),
(N'Miguel Ángel', N'Flores', N'Vargas', 18, 'H', 1, 7, N'Nuevo León', N'Monterrey', N'Profesional de salud'),
(N'Miguel Ángel', N'Torres', N'Jiménez', 37, 'H', 4, 4, N'Ciudad de México', N'Coyoacán', N'Jubilado/a'),
(N'Luis Fernando', N'Hernández', N'Ríos', 56, 'H', 7, 1, N'Guanajuato', N'León', N'Trabajador/a independiente'),
(N'Luis Fernando', N'García', N'Morales', 75, 'H', 2, 8, N'Estado de México', N'Nezahualcóyotl', N'Profesional de salud'),
(N'Luis Fernando', N'Martínez', N'Cruz', 30, 'H', 5, 5, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Jubilado/a'),
(N'Luis Fernando', N'López', N'Reyes', 49, 'H', 8, 2, N'Nuevo León', N'Monterrey', N'Estudiante'),
(N'Luis Fernando', N'González', N'Ortiz', 68, 'H', 3, 9, N'Ciudad de México', N'Coyoacán', N'Técnico/a'),
(N'Luis Fernando', N'Pérez', N'Vargas', 23, 'H', 6, 6, N'Guanajuato', N'León', N'Servidor/a público/a'),
(N'Luis Fernando', N'Sánchez', N'Jiménez', 42, 'H', 1, 3, N'Estado de México', N'Nezahualcóyotl', N'Comerciante'),
(N'Luis Fernando', N'Ramírez', N'Mendoza', 61, 'H', 4, 10, N'Yucatán', N'Mérida', N'Docente'),
(N'Luis Fernando', N'Flores', N'Castillo', 80, 'H', 7, 7, N'Jalisco', N'Guadalajara', N'Persona dedicada al hogar'),
(N'Luis Fernando', N'Torres', N'Navarro', 35, 'H', 2, 4, N'Ciudad de México', N'Iztapalapa', N'Empleado/a'),
(N'Ricardo', N'Hernández', N'Reyes', 54, 'H', 5, 1, N'Puebla', N'Puebla', N'Docente'),
(N'Ricardo', N'García', N'Ortiz', 73, 'H', 8, 8, N'Ciudad de México', N'Xochimilco', N'Persona dedicada al hogar'),
(N'Ricardo', N'Martínez', N'Vargas', 28, 'H', 3, 5, N'Querétaro', N'Querétaro', N'Empleado/a'),
(N'Ricardo', N'López', N'Jiménez', 47, 'H', 6, 2, N'Estado de México', N'Ecatepec de Morelos', N'Trabajador/a independiente'),
(N'Ricardo', N'González', N'Mendoza', 66, 'H', 1, 9, N'Ciudad de México', N'Iztapalapa', N'Profesional de salud'),
(N'Ricardo', N'Pérez', N'Castillo', 21, 'H', 4, 6, N'Puebla', N'Puebla', N'Jubilado/a'),
(N'Ricardo', N'Sánchez', N'Navarro', 40, 'H', 7, 3, N'Ciudad de México', N'Xochimilco', N'Estudiante'),
(N'Ricardo', N'Ramírez', N'Ríos', 59, 'H', 2, 10, N'Querétaro', N'Querétaro', N'Técnico/a'),
(N'Ricardo', N'Flores', N'Morales', 78, 'H', 5, 7, N'Estado de México', N'Ecatepec de Morelos', N'Servidor/a público/a'),
(N'Ricardo', N'Torres', N'Cruz', 33, 'H', 8, 4, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Comerciante'),
(N'Eduardo', N'Hernández', N'Jiménez', 52, 'H', 3, 1, N'Nuevo León', N'Monterrey', N'Técnico/a'),
(N'Eduardo', N'García', N'Mendoza', 71, 'H', 6, 8, N'Ciudad de México', N'Coyoacán', N'Servidor/a público/a'),
(N'Eduardo', N'Martínez', N'Castillo', 26, 'H', 1, 5, N'Guanajuato', N'León', N'Comerciante'),
(N'Eduardo', N'López', N'Navarro', 45, 'H', 4, 2, N'Estado de México', N'Nezahualcóyotl', N'Docente'),
(N'Eduardo', N'González', N'Ríos', 64, 'H', 7, 9, N'Yucatán', N'Mérida', N'Persona dedicada al hogar'),
(N'Eduardo', N'Pérez', N'Morales', 19, 'H', 2, 6, N'Jalisco', N'Guadalajara', N'Empleado/a'),
(N'Eduardo', N'Sánchez', N'Cruz', 38, 'H', 5, 3, N'Ciudad de México', N'Coyoacán', N'Trabajador/a independiente'),
(N'Eduardo', N'Ramírez', N'Reyes', 57, 'H', 8, 10, N'Guanajuato', N'León', N'Profesional de salud'),
(N'Eduardo', N'Flores', N'Ortiz', 76, 'H', 3, 7, N'Estado de México', N'Nezahualcóyotl', N'Jubilado/a'),
(N'Eduardo', N'Torres', N'Vargas', 31, 'H', 6, 4, N'Yucatán', N'Mérida', N'Estudiante'),
(N'Jorge', N'Hernández', N'Navarro', 50, 'H', 1, 1, N'Jalisco', N'Guadalajara', N'Profesional de salud'),
(N'Jorge', N'García', N'Ríos', 69, 'H', 4, 8, N'Ciudad de México', N'Iztapalapa', N'Jubilado/a'),
(N'Jorge', N'Martínez', N'Morales', 24, 'H', 7, 5, N'Puebla', N'Puebla', N'Estudiante'),
(N'Jorge', N'López', N'Cruz', 43, 'H', 2, 2, N'Ciudad de México', N'Xochimilco', N'Técnico/a'),
(N'Jorge', N'González', N'Reyes', 62, 'H', 5, 9, N'Querétaro', N'Querétaro', N'Servidor/a público/a'),
(N'Jorge', N'Pérez', N'Ortiz', 81, 'H', 8, 6, N'Estado de México', N'Ecatepec de Morelos', N'Comerciante'),
(N'Jorge', N'Sánchez', N'Vargas', 36, 'H', 3, 3, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Docente'),
(N'Jorge', N'Ramírez', N'Jiménez', 55, 'H', 6, 10, N'Nuevo León', N'Monterrey', N'Persona dedicada al hogar'),
(N'Jorge', N'Flores', N'Mendoza', 74, 'H', 1, 7, N'Ciudad de México', N'Xochimilco', N'Empleado/a'),
(N'Jorge', N'Torres', N'Castillo', 29, 'H', 4, 4, N'Querétaro', N'Querétaro', N'Trabajador/a independiente'),
(N'Carlos Alberto', N'Hernández', N'Cruz', 48, 'H', 7, 1, N'Estado de México', N'Ecatepec de Morelos', N'Persona dedicada al hogar'),
(N'Carlos Alberto', N'García', N'Reyes', 67, 'H', 2, 8, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Empleado/a'),
(N'Carlos Alberto', N'Martínez', N'Ortiz', 22, 'H', 5, 5, N'Nuevo León', N'Monterrey', N'Trabajador/a independiente'),
(N'Carlos Alberto', N'López', N'Vargas', 41, 'H', 8, 2, N'Ciudad de México', N'Coyoacán', N'Profesional de salud'),
(N'Carlos Alberto', N'González', N'Jiménez', 60, 'H', 3, 9, N'Guanajuato', N'León', N'Jubilado/a'),
(N'Carlos Alberto', N'Pérez', N'Mendoza', 79, 'H', 6, 6, N'Estado de México', N'Nezahualcóyotl', N'Estudiante'),
(N'Carlos Alberto', N'Sánchez', N'Castillo', 34, 'H', 1, 3, N'Yucatán', N'Mérida', N'Técnico/a'),
(N'Carlos Alberto', N'Ramírez', N'Navarro', 53, 'H', 4, 10, N'Jalisco', N'Guadalajara', N'Servidor/a público/a'),
(N'Carlos Alberto', N'Flores', N'Ríos', 72, 'H', 7, 7, N'Ciudad de México', N'Iztapalapa', N'Comerciante'),
(N'Carlos Alberto', N'Torres', N'Morales', 27, 'H', 2, 4, N'Puebla', N'Puebla', N'Docente'),
(N'Francisco Javier', N'Hernández', N'Vargas', 46, 'H', 5, 1, N'Estado de México', N'Nezahualcóyotl', N'Servidor/a público/a'),
(N'Francisco Javier', N'García', N'Jiménez', 65, 'H', 8, 8, N'Yucatán', N'Mérida', N'Comerciante'),
(N'Francisco Javier', N'Martínez', N'Mendoza', 20, 'H', 3, 5, N'Jalisco', N'Guadalajara', N'Docente'),
(N'Francisco Javier', N'López', N'Castillo', 39, 'H', 6, 2, N'Ciudad de México', N'Iztapalapa', N'Persona dedicada al hogar'),
(N'Francisco Javier', N'González', N'Navarro', 58, 'H', 1, 9, N'Puebla', N'Puebla', N'Empleado/a'),
(N'Francisco Javier', N'Pérez', N'Ríos', 77, 'H', 4, 6, N'Ciudad de México', N'Xochimilco', N'Trabajador/a independiente'),
(N'Francisco Javier', N'Sánchez', N'Morales', 32, 'H', 7, 3, N'Querétaro', N'Querétaro', N'Profesional de salud'),
(N'Francisco Javier', N'Ramírez', N'Cruz', 51, 'H', 2, 10, N'Estado de México', N'Ecatepec de Morelos', N'Jubilado/a'),
(N'Francisco Javier', N'Flores', N'Reyes', 70, 'H', 5, 7, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Estudiante'),
(N'Francisco Javier', N'Torres', N'Ortiz', 25, 'H', 8, 4, N'Nuevo León', N'Monterrey', N'Técnico/a'),
(N'Diego', N'Hernández', N'Castillo', 44, 'H', 3, 1, N'Ciudad de México', N'Coyoacán', N'Jubilado/a'),
(N'Diego', N'García', N'Navarro', 63, 'H', 6, 8, N'Guanajuato', N'León', N'Estudiante'),
(N'Diego', N'Martínez', N'Ríos', 18, 'H', 1, 5, N'Estado de México', N'Ecatepec de Morelos', N'Técnico/a'),
(N'Diego', N'López', N'Morales', 37, 'H', 4, 2, N'Veracruz de Ignacio de la Llave', N'Xalapa', N'Servidor/a público/a'),
(N'Diego', N'González', N'Cruz', 56, 'H', 7, 9, N'Nuevo León', N'Monterrey', N'Comerciante'),
(N'Diego', N'Pérez', N'Reyes', 75, 'H', 2, 6, N'Ciudad de México', N'Coyoacán', N'Docente'),
(N'Diego', N'Sánchez', N'Ortiz', 30, 'H', 5, 3, N'Guanajuato', N'León', N'Persona dedicada al hogar'),
(N'Diego', N'Ramírez', N'Vargas', 49, 'H', 8, 10, N'Estado de México', N'Nezahualcóyotl', N'Empleado/a'),
(N'Diego', N'Flores', N'Jiménez', 68, 'H', 3, 7, N'Yucatán', N'Mérida', N'Trabajador/a independiente'),
(N'Diego', N'Torres', N'Mendoza', 23, 'H', 6, 4, N'Jalisco', N'Guadalajara', N'Profesional de salud');

INSERT INTO dbo.Encuesta (Titulo, Objetivo, FechaInicio, FechaFin) VALUES
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

INSERT INTO dbo.TipoPregunta (TipoPreguntaID, Nombre) VALUES
(1, N'Escala de satisfacción de 1 a 5'),
(2, N'Sí o no'),
(3, N'Frecuencia mensual'),
(4, N'Número de ocasiones'),
(5, N'Texto abierto');

INSERT INTO dbo.OpcionRespuesta (OpcionID, TipoPreguntaID, Etiqueta, ValorNumerico) VALUES
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

/* Criterios de interpretación de cada opción. Para "Más de cinco",
   maximo = null significa que el rango no tiene límite superior.
   Los rangos describen opciones del cuestionario, no intervalos exhaustivos. */
UPDATE o
SET CriterioJSON = CAST(v.Documento AS json)
FROM dbo.OpcionRespuesta AS o
JOIN (VALUES
 (1, N'{"rango":{"minimo":1,"maximo":1},"interpretacion":"Valoración muy desfavorable","categoria":"Desfavorable","periodoReferencia":"Sin periodo fijo","requiereSeguimiento":true,"codigoVisual":"#B23A48"}'),
 (2, N'{"rango":{"minimo":2,"maximo":2},"interpretacion":"Valoración desfavorable","categoria":"Desfavorable","periodoReferencia":"Sin periodo fijo","requiereSeguimiento":true,"codigoVisual":"#DA7756"}'),
 (3, N'{"rango":{"minimo":3,"maximo":3},"interpretacion":"Valoración intermedia","categoria":"Neutral","periodoReferencia":"Sin periodo fijo","requiereSeguimiento":false,"codigoVisual":"#E0B44C"}'),
 (4, N'{"rango":{"minimo":4,"maximo":4},"interpretacion":"Valoración favorable","categoria":"Favorable","periodoReferencia":"Sin periodo fijo","requiereSeguimiento":false,"codigoVisual":"#7BAE7F"}'),
 (5, N'{"rango":{"minimo":5,"maximo":5},"interpretacion":"Valoración muy favorable","categoria":"Favorable","periodoReferencia":"Sin periodo fijo","requiereSeguimiento":false,"codigoVisual":"#3D8B68"}'),
 (6, N'{"rango":{"minimo":1,"maximo":1},"interpretacion":"La persona afirma conocer o disponer del servicio","categoria":"Afirmativa","periodoReferencia":"Sin periodo fijo","requiereSeguimiento":false,"codigoVisual":"#3D8B68"}'),
 (7, N'{"rango":{"minimo":0,"maximo":0},"interpretacion":"La persona no conoce o no dispone del servicio","categoria":"Negativa","periodoReferencia":"Sin periodo fijo","requiereSeguimiento":true,"codigoVisual":"#B23A48"}'),
 (8, N'{"rango":{"minimo":0,"maximo":0},"interpretacion":"No registró uso durante el último mes","categoria":"Sin uso","periodoReferencia":"Últimos 30 días","requiereSeguimiento":false,"codigoVisual":"#7B8794"}'),
 (9, N'{"rango":{"minimo":1,"maximo":1},"interpretacion":"Registró una ocasión durante el último mes","categoria":"Uso ocasional","periodoReferencia":"Últimos 30 días","requiereSeguimiento":false,"codigoVisual":"#80A7C8"}'),
 (10, N'{"rango":{"minimo":2,"maximo":2},"interpretacion":"Registró dos ocasiones durante el último mes","categoria":"Uso ocasional","periodoReferencia":"Últimos 30 días","requiereSeguimiento":false,"codigoVisual":"#6798C0"}'),
 (11, N'{"rango":{"minimo":4,"maximo":4},"interpretacion":"Registró cuatro ocasiones durante el último mes","categoria":"Uso recurrente","periodoReferencia":"Últimos 30 días","requiereSeguimiento":false,"codigoVisual":"#477BA5"}'),
 (12, N'{"rango":{"minimo":6,"maximo":null},"interpretacion":"Registró más de cinco ocasiones durante el último mes","categoria":"Uso frecuente","periodoReferencia":"Últimos 30 días","requiereSeguimiento":false,"codigoVisual":"#295D88"}')
) AS v(OpcionID, Documento) ON v.OpcionID = o.OpcionID
WHERE o.CriterioJSON IS NULL;

INSERT INTO dbo.Pregunta (EncuestaID, Numero, Texto, TipoPreguntaID, Obligatoria) VALUES
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
INSERT dbo.Participacion (EncuestaID, EncuestadoID, FechaRespuesta)
SELECT e.EncuestaID,
       ((e.EncuestaID - 1) * 17 + n.n * 7) % 200 + 1,
       DATEADD(minute, n.n * 19 + e.EncuestaID * 37,
               DATEADD(day, (n.n * 3 + e.EncuestaID * 5) % 70,
                       CONVERT(datetime2(0), '2026-04-01T09:00:00')))
FROM dbo.Encuesta AS e CROSS JOIN N AS n;

/* Una respuesta válida por pregunta y participación. Las 2 abiertas son opcionales:
   se contestan en alrededor de una de cada cuatro participaciones. */
INSERT dbo.Respuesta
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
FROM dbo.Participacion AS p
JOIN dbo.Pregunta AS q ON q.EncuestaID = p.EncuestaID
WHERE q.TipoPreguntaID <> 5 OR (p.EncuestadoID + q.Numero) % 4 = 0;


/* Ampliación didáctica: áreas sin personas, personas sin área y nuevas encuestas. */
INSERT dbo.Area (Nombre, Descripcion) VALUES
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
INSERT dbo.Encuestados
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
INSERT dbo.Encuesta (Titulo, Objetivo, FechaInicio, FechaFin) VALUES
 (N'Bienestar en personas mayores', N'Explorar acceso a actividades y servicios; pendiente de levantamiento', '2026-07-01','2026-09-30'),
 (N'Participación cultural local', N'Explorar uso de actividades culturales; pendiente de levantamiento', '2026-07-01','2026-09-30');
INSERT dbo.Pregunta (EncuestaID, Numero, Texto, TipoPreguntaID, Obligatoria)
SELECT enc.EncuestaID, q.Numero, q.Texto, q.TipoPreguntaID, q.Obligatoria
FROM dbo.Encuesta AS enc
CROSS JOIN dbo.Pregunta AS q
WHERE enc.Titulo IN (N'Bienestar en personas mayores',N'Participación cultural local')
  AND q.EncuestaID = (SELECT EncuestaID FROM dbo.Encuesta WHERE Titulo = N'Salud y acceso a servicios');

/* Agrega 0, 2, 4, ... 18 participantes a las diez encuestas originales.
   Las 12 encuestas muestran desde 0 hasta 98 participaciones. */
;WITH N AS (
 SELECT TOP (18) ROW_NUMBER() OVER (ORDER BY object_id) AS n
 FROM sys.all_objects
)
INSERT dbo.Participacion (EncuestaID, EncuestadoID, FechaRespuesta)
SELECT enc.EncuestaID, 200 + ((enc.EncuestaID * 7 + n.n - 1) % 100) + 1,
       DATEADD(minute, n.n * 17,
               DATEADD(day, (enc.EncuestaID * 5 + n.n) % 70,
                       CONVERT(datetime2(0),'2026-04-01T10:00:00')))
FROM dbo.Encuesta AS enc CROSS JOIN N AS n
WHERE enc.EncuestaID <= 10 AND n.n <= 2 * (enc.EncuestaID - 1);

/* Generación parametrizable de datos para pruebas analíticas.
   El valor controla cuántos encuestados sintéticos se agregan; cada uno
   participa en las 10 encuestas originales. Con 6,100 nuevos encuestados
   se agregan 61,000 participaciones y normalmente más de 1.2 millones
   de respuestas después de aplicar la cobertura parcial definida abajo.
   Ajuste el parámetro para escalar (hasta el límite int de ParticipacionID).
   Ejecútese solo como parte de la carga inicial, dentro de su transacción. */
DECLARE @NuevosEncuestados int = 6100;
DECLARE @FechaBase datetime2(0) = CONVERT(datetime2(0), '2026-04-01T09:00:00');
DECLARE @EncuestadosGenerados TABLE (EncuestadoID int NOT NULL PRIMARY KEY);

IF @NuevosEncuestados < 0
    THROW 51001, N'@NuevosEncuestados no puede ser negativo.', 1;

;WITH N AS (
    SELECT TOP (@NuevosEncuestados)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.Encuestados
    (Nombre, ApellidoPaterno, ApellidoMaterno, Edad, Sexo,
     GradoEstudiosID, AreaID, EntidadFederativa, MunicipioAlcaldia, Ocupacion)
OUTPUT inserted.EncuestadoID INTO @EncuestadosGenerados (EncuestadoID)
SELECT
    CASE (n - 1) % 12
      WHEN 0 THEN N'Andrea' WHEN 1 THEN N'Luis' WHEN 2 THEN N'Camila'
      WHEN 3 THEN N'Jorge' WHEN 4 THEN N'Renata' WHEN 5 THEN N'Diego'
      WHEN 6 THEN N'Paola' WHEN 7 THEN N'Emilio' WHEN 8 THEN N'Lucía'
      WHEN 9 THEN N'Mateo' WHEN 10 THEN N'Valentina' ELSE N'Santiago' END,
    CASE (n - 1) % 10
      WHEN 0 THEN N'Aguilar' WHEN 1 THEN N'Bautista' WHEN 2 THEN N'Cervantes'
      WHEN 3 THEN N'Domínguez' WHEN 4 THEN N'Escobar' WHEN 5 THEN N'Fuentes'
      WHEN 6 THEN N'Guerrero' WHEN 7 THEN N'Herrera' WHEN 8 THEN N'Ibarra'
      ELSE N'Juárez' END,
    CASE (n - 1) % 10
      WHEN 0 THEN N'Velasco' WHEN 1 THEN N'Camacho' WHEN 2 THEN N'Zamora'
      WHEN 3 THEN N'Acosta' WHEN 4 THEN N'Trejo' WHEN 5 THEN N'Campos'
      WHEN 6 THEN N'Salinas' WHEN 7 THEN N'Mejía' WHEN 8 THEN N'Contreras'
      ELSE N'Valdez' END,
    CONVERT(tinyint, 18 + (n * 17) % 68),
    CASE n % 3 WHEN 0 THEN 'M' WHEN 1 THEN 'H' ELSE 'X' END,
    CONVERT(tinyint, 1 + (n * 7) % 8),
    CONVERT(smallint, 1 + (n * 3) % 13),
    CASE n % 5 WHEN 0 THEN N'Ciudad de México' WHEN 1 THEN N'Estado de México'
      WHEN 2 THEN N'Puebla' WHEN 3 THEN N'Querétaro' ELSE N'Jalisco' END,
    CASE n % 6 WHEN 0 THEN N'Iztapalapa' WHEN 1 THEN N'Xochimilco'
      WHEN 2 THEN N'Nezahualcóyotl' WHEN 3 THEN N'Puebla'
      WHEN 4 THEN N'Querétaro' ELSE N'Guadalajara' END,
    CASE n % 6 WHEN 0 THEN N'Estudiante' WHEN 1 THEN N'Empleado/a'
      WHEN 2 THEN N'Comerciante' WHEN 3 THEN N'Docente'
      WHEN 4 THEN N'Trabajador/a independiente' ELSE N'Técnico/a' END
FROM N;

/* Cada persona generada participa una sola vez en cada encuesta original.
   El diseño satisface UQ_Participacion_EncuestaEncuestado y las FK. */
INSERT dbo.Participacion (EncuestaID, EncuestadoID, FechaRespuesta)
SELECT enc.EncuestaID, g.EncuestadoID,
       DATEADD(minute, (g.EncuestadoID % 1440),
         DATEADD(day, (g.EncuestadoID % 70), @FechaBase))
FROM dbo.Encuesta AS enc
CROSS JOIN @EncuestadosGenerados AS g
WHERE enc.EncuestaID BETWEEN 1 AND 10;
/* Las personas nuevas responden igual que las originales. */
INSERT dbo.Respuesta
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
FROM dbo.Participacion AS p
JOIN dbo.Pregunta AS q ON q.EncuestaID = p.EncuestaID
WHERE p.EncuestadoID > 200
  AND (q.TipoPreguntaID <> 5 OR (p.EncuestadoID + q.Numero) % 4 = 0);

/* Algunos cuestionarios están parcialmente contestados. El criterio cambia
   entre encuestas y conserva diferentes porcentajes de cobertura. */
DELETE r
FROM dbo.Respuesta AS r
JOIN dbo.Pregunta AS q ON q.PreguntaID = r.PreguntaID
WHERE q.Obligatoria = 1
  AND r.EncuestaID BETWEEN 2 AND 10
  AND (r.ParticipacionID + q.Numero * 3) % (r.EncuestaID + 3) = 0;

/* Metadatos editoriales originales y ficticios, estructurados como XML.
   FOR XML PATH(...), TYPE genera XML válido y escapa los caracteres especiales. */
;WITH Fuente AS (
 SELECT * FROM (VALUES
 (N'Salud y acceso a servicios', N'Dra. Mariana Salgado Cruz', N'Elena Rivas Mendoza', N'Dr. Héctor Lozano Pérez', N'Personas adultas residentes en México', N'Observatorio de Salud Comunitaria', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-20')),
 (N'Movilidad cotidiana', N'Arq. Luis Alberto Mejía', N'Sofía Ramírez Aguilar', N'Mtra. Gabriela Ortiz', N'Personas usuarias de transporte local', N'Unidad de Movilidad Urbana', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-21')),
 (N'Seguridad en la colonia', N'Mtra. Laura Hernández Vega', N'Iván Flores García', N'Lic. Patricia Núñez', N'Personas adultas de zonas urbanas', N'Observatorio de Convivencia Ciudadana', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-22')),
 (N'Educación y capacitación', N'Mtro. Daniel Torres Morales', N'Adriana Castillo Díaz', N'Dra. Carmen Villalobos', N'Personas interesadas en formación continua', N'Centro de Aprendizaje Comunitario', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-23')),
 (N'Condiciones laborales', N'Lic. Ximena Paredes Ríos', N'Tomás Salinas Hernández', N'Mtra. Verónica Álvarez', N'Personas económicamente activas', N'Unidad de Estudios Laborales', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-24')),
 (N'Conectividad digital', N'Ing. Fernanda Ruiz Campos', N'Jorge Velasco Núñez', N'Mtro. Raúl Cárdenas', N'Personas usuarias de servicios digitales', N'Laboratorio de Inclusión Digital', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-25')),
 (N'Agua y saneamiento', N'Ing. José Manuel Vázquez', N'Lucía Campos Mendoza', N'Dra. Isabel Acosta', N'Hogares con acceso a servicios públicos', N'Unidad de Gestión del Agua', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-26')),
 (N'Residuos y medio ambiente', N'Biól. Andrea Morales Cruz', N'Miguel Lara Pérez', N'Mtra. Estela Navarro', N'Personas responsables del manejo de residuos', N'Observatorio Ambiental Local', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-27')),
 (N'Trámites y atención ciudadana', N'Lic. Ricardo Bautista Flores', N'Norma Juárez Mejía', N'Dra. Leticia Medina', N'Personas usuarias de trámites públicos', N'Unidad de Servicios Ciudadanos', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-28')),
 (N'Espacios públicos y comunidad', N'Arq. Karla Domínguez', N'Roberto Ortega Silva', N'Mtra. Ana Lucía Fuentes', N'Personas usuarias de espacios comunitarios', N'Centro de Desarrollo Comunitario', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-03-29')),
 (N'Bienestar en personas mayores', N'Dra. Beatriz Cervantes', N'Paola Márquez Ríos', N'Dr. Ernesto Mejía', N'Personas de 60 años o más', N'Observatorio de Bienestar Comunitario', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-06-20')),
 (N'Participación cultural local', N'Mtra. Itzel Guerrero', N'Claudia Hernández Ortiz', N'Lic. Arturo Saldaña', N'Personas interesadas en actividades culturales', N'Centro de Cultura Comunitaria', '1.0', N'Aprobada', N'Digital', N'Levantamiento único', CONVERT(date, '2026-06-21'))
 ) AS v(Titulo, Autor, Editor, Aprobador, Audiencia, UnidadResponsable,
        VersionDocumento, EstadoPublicacion, CanalCaptura, Periodicidad, FechaPublicacion)
)
UPDATE enc
SET MetadatosXML = (
 SELECT (SELECT f.Autor, f.Editor, f.Aprobador
         FOR XML PATH('Publicadores'), TYPE),
        f.Audiencia, f.UnidadResponsable, f.VersionDocumento,
        f.EstadoPublicacion, f.CanalCaptura, f.Periodicidad,
        f.FechaPublicacion
 FOR XML PATH('Metadatos'), TYPE
)
FROM dbo.Encuesta AS enc
JOIN Fuente AS f ON f.Titulo = enc.Titulo
WHERE enc.MetadatosXML IS NULL;

CREATE INDEX IX_Encuestados_Area ON dbo.Encuestados (AreaID, GradoEstudiosID);
CREATE INDEX IX_Participacion_Encuestado ON dbo.Participacion (EncuestadoID, EncuestaID);
CREATE INDEX IX_Respuesta_PreguntaOpcion ON dbo.Respuesta (PreguntaID, OpcionID)
 INCLUDE (EncuestaID, ValorEntero);
COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT > 0 ROLLBACK;
 THROW;
END CATCH;
GO

/* Resumen verificable: 12 encuestas y 32 preguntas por encuesta. Con @NuevosEncuestados = 6100 se cargan 6400 encuestados y aproximadamente 61,890 participaciones; se esperan más de 1.2 millones de respuestas. Aumente el parámetro para generar varios millones. */
SELECT e.EncuestaID, e.Titulo,
       COUNT(DISTINCT q.PreguntaID) AS Preguntas,
       (SELECT COUNT(*) FROM dbo.Participacion p WHERE p.EncuestaID = e.EncuestaID) AS Participantes,
       (SELECT COUNT(*) FROM dbo.Respuesta r WHERE r.EncuestaID = e.EncuestaID) AS Respuestas
FROM dbo.Encuesta e JOIN dbo.Pregunta q ON q.EncuestaID = e.EncuestaID
GROUP BY e.EncuestaID, e.Titulo ORDER BY e.EncuestaID;
SELECT (SELECT COUNT(*) FROM dbo.Encuestados) AS Encuestados,
       (SELECT COUNT(*) FROM dbo.Participacion) AS Participaciones,
       (SELECT COUNT(*) FROM dbo.Respuesta) AS Respuestas;
GO



