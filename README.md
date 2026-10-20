# PulsoLAB

Base de datos didáctica para practicar encuestas y relaciones en SQL Server. El proyecto contiene el script de creación y carga de datos, consultas y objetos auxiliares, además del diagrama del esquema.

> Los datos son ficticios. Las referencias temáticas a encuestas públicas no significan que estas tablas, preguntas o resultados sean oficiales ni representativos.

## Versión estable

La versión de referencia es **v1.0.0.0**. Para obtener el script principal no necesitas instalar Git ni clonar el repositorio: abre el enlace RAW directo:

[Descargar BD_PulsoLab.sql (RAW, v1.0.0.0)](https://raw.githubusercontent.com/vicasso-mx/pulsolab/refs/tags/v1.0.0.0/BD_PulsoLab.sql)

El navegador mostrará el contenido SQL sin la interfaz de GitHub. Desde esa página, usa la opción de guardar del navegador para conservarlo como `BD_PulsoLab.sql`.

## Contenido de la carpeta

| Archivo | Para qué sirve |
| --- | --- |
| [BD_PulsoLab.sql (RAW)](https://raw.githubusercontent.com/vicasso-mx/pulsolab/refs/tags/v1.0.0.0/BD_PulsoLab.sql) | Script principal descargable directamente desde el navegador. Crea la base `PulsoLAB`, construye el esquema, carga datos de ejemplo, crea índices y objetos de apoyo, y muestra consultas de resumen. Incluye los vectores temáticos demo. |
| [Diagrama_BD_PulsoLab.png](Diagrama_BD_PulsoLab.png) | Diagrama visual de tablas, columnas, claves y relaciones. Imagen PNG de 3840 × 2160 (16:9). |
| [CrearFuncionesEscalares.sql](CrearFuncionesEscalares.sql) | Crea las funciones `dbo.ObtenerNombreEncuesta` y `dbo.ObtenerNombreEncuestado`; también incluye una consulta de ejemplo sobre `dbo.Encuestados`. |
| [CrearVista.sql](CrearVista.sql) | Crea la vista `dbo.VerResultados`, que presenta encuesta, persona, pregunta, opción seleccionada y fecha de respuesta. |
| [vistaVerResultados.sql](vistaVerResultados.sql) | Ejecuta consultas de ejemplo sobre `dbo.VerResultados` y `dbo.ObtenerNombreEncuestado`. Requiere que ya existan la vista y la función. |
| [AsignarEncuesta.sql](AsignarEncuesta.sql) | Crea el procedimiento `dbo.AsignarEncuesta`, que valida la encuesta y la persona y registra su participación en `dbo.Participacion`. |

## Esquema

El modelo contiene estas tablas:

- **Catálogos:** `Area`, `GradoEstudios`, `TipoPregunta` y `OpcionRespuesta`.
- **Encuestas:** `Encuesta` y `Pregunta`.
- **Personas y participación:** `Encuestados`, `Participacion` y `AsignacionEncuesta`.
- **Respuestas:** `Respuesta`.
- **Vectores de demostración:** `PreguntaVectoresDemo`.

Las claves foráneas conectan encuestas con preguntas y participaciones, personas con participaciones y asignaciones, y preguntas/opciones con las respuestas. `Pregunta.TextoVector` almacena un vector didáctico de 384 dimensiones. `PreguntaVectoresDemo` guarda cuatro vectores temáticos manuales de tres dimensiones.

La carga principal incluye 300 personas ficticias, 12 encuestas y 32 preguntas por encuesta, además de participaciones y respuestas de ejemplo. La tabla de personas incluye apellidos maternos nulos y algunos nombres con espacios iniciales o finales para practicar consultas y limpieza de texto.

## Requisitos

- SQL Server 2025 (17.x), por el uso del tipo `vector` y de `json`.
- SQL Server Management Studio u otra herramienta que ejecute scripts T-SQL y reconozca el separador `GO`.
- Permisos para crear la base de datos `PulsoLAB` si todavía no existe.

## Orden de ejecución

1. Abre [BD_PulsoLab.sql](BD_PulsoLab.sql) en una ventana nueva de consulta y ejecútalo completo. El script crea `PulsoLAB` si hace falta y luego crea las tablas y carga los datos.
2. Después de la carga, ejecuta [CrearFuncionesEscalares.sql](CrearFuncionesEscalares.sql) y [CrearVista.sql](CrearVista.sql) para agregar las funciones y la vista auxiliares. También puedes ejecutar [AsignarEncuesta.sql](AsignarEncuesta.sql) para crear su procedimiento.
3. Ejecuta [vistaVerResultados.sql](vistaVerResultados.sql) para ver ejemplos de consulta. Necesita la vista y la función de nombre de persona creadas en el paso anterior.

`BD_PulsoLab.sql` no está diseñado para cargarse dos veces: si detecta que ya existe `dbo.Encuesta`, detiene la ejecución con el error 51000 en lugar de duplicar o reemplazar los datos.

## Notas sobre los procedimientos

`BD_PulsoLab.sql` crea `dbo.usp_AsignarEncuestadoAEncuesta`, que registra una asignación en `dbo.AsignacionEncuesta` y evita insertar una ya existente. El archivo [AsignarEncuesta.sql](AsignarEncuesta.sql) define otro procedimiento, `dbo.AsignarEncuesta`, que registra una participación en `dbo.Participacion`; son operaciones distintas.
