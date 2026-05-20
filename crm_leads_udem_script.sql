-- ============================================================
-- TRABAJO FINAL - MODELOS DE DATOS 2026-1
-- Sistema CRM de Leads y Aspirantes - Universidad de Medellin
-- Entregable 2: Script SQL completo para PostgreSQL
-- ============================================================
-- Recomendacion de ejecucion:
--   1. Ejecutar desde psql conectado a una base distinta, por ejemplo:
--      psql -U postgres -f crm_leads_udem_script.sql
--   2. Si usa pgAdmin, ejecute primero CREATE DATABASE, conectese a
--      crm_leads_udem y luego ejecute desde la seccion 1.
-- ============================================================

-- ============================================================
-- 0. CREACION DE BASE DE DATOS
-- ============================================================

DROP DATABASE IF EXISTS crm_leads_udem;
CREATE DATABASE crm_leads_udem;

-- Comando propio de psql para conectarse a la base creada.
\connect crm_leads_udem

SET client_encoding = 'UTF8';
SET datestyle = 'ISO, DMY';

-- ============================================================
-- 1. LIMPIEZA PREVIA DE OBJETOS
-- ============================================================

DROP TABLE IF EXISTS inscripcion CASCADE;
DROP TABLE IF EXISTS seguimiento CASCADE;
DROP TABLE IF EXISTS lead_programa CASCADE;
DROP TABLE IF EXISTS lead CASCADE;
DROP TABLE IF EXISTS asesor_admisiones CASCADE;
DROP TABLE IF EXISTS programa_academico CASCADE;
DROP TABLE IF EXISTS estado_lead CASCADE;
DROP TABLE IF EXISTS canal_captacion CASCADE;

DROP PROCEDURE IF EXISTS sp_registrar_seguimiento_lead(
    INT,
    INT,
    VARCHAR,
    TEXT,
    DATE
);

DROP FUNCTION IF EXISTS fn_actualizar_estado_lead_inscrito() CASCADE;

-- ============================================================
-- 2. DDL - CREACION DE TABLAS Y RESTRICCIONES
-- Orden respetando dependencias: catalogos, entidades y tablas transaccionales.
-- ============================================================

CREATE TABLE canal_captacion (
    id_canal      SERIAL PRIMARY KEY,
    nombre_canal  VARCHAR(60) NOT NULL UNIQUE,
    descripcion   TEXT
);

CREATE TABLE estado_lead (
    id_estado      SERIAL PRIMARY KEY,
    nombre_estado  VARCHAR(40) NOT NULL UNIQUE,
    descripcion    TEXT,
    CONSTRAINT chk_estado_lead_nombre
        CHECK (LOWER(nombre_estado) IN (
            'nuevo',
            'contactado',
            'interesado',
            'inscrito',
            'admitido',
            'matriculado',
            'descartado'
        ))
);

CREATE TABLE programa_academico (
    id_programa      SERIAL PRIMARY KEY,
    nombre_programa  VARCHAR(120) NOT NULL,
    facultad         VARCHAR(100) NOT NULL,
    nivel            VARCHAR(30) NOT NULL,
    modalidad        VARCHAR(30) NOT NULL,
    activo           BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_programa_nombre UNIQUE (nombre_programa),
    CONSTRAINT chk_programa_nivel
        CHECK (LOWER(nivel) IN (
            'pregrado',
            'posgrado',
            'tecnica',
            'tecnologica',
            'educacion continua'
        )),
    CONSTRAINT chk_programa_modalidad
        CHECK (LOWER(modalidad) IN (
            'presencial',
            'virtual',
            'hibrida'
        ))
);

CREATE TABLE asesor_admisiones (
    id_asesor  SERIAL PRIMARY KEY,
    nombre     VARCHAR(120) NOT NULL,
    correo     VARCHAR(120) NOT NULL UNIQUE,
    telefono   VARCHAR(20),
    cargo      VARCHAR(80),
    activo     BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_asesor_correo
        CHECK (correo LIKE '%@%')
);

CREATE TABLE lead (
    id_lead               SERIAL PRIMARY KEY,
    nombres               VARCHAR(80) NOT NULL,
    apellidos             VARCHAR(80) NOT NULL,
    correo                VARCHAR(120) NOT NULL UNIQUE,
    telefono              VARCHAR(20),
    ciudad                VARCHAR(80),
    fecha_registro        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_canal              INT NOT NULL,
    id_estado             INT NOT NULL,
    ultima_actualizacion  TIMESTAMP,
    CONSTRAINT fk_lead_canal
        FOREIGN KEY (id_canal)
        REFERENCES canal_captacion (id_canal)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_lead_estado
        FOREIGN KEY (id_estado)
        REFERENCES estado_lead (id_estado)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_lead_correo
        CHECK (correo LIKE '%@%')
);

CREATE TABLE lead_programa (
    id_lead        INT NOT NULL,
    id_programa    INT NOT NULL,
    prioridad      INT NOT NULL,
    fecha_interes  DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_lead_programa
        PRIMARY KEY (id_lead, id_programa),
    CONSTRAINT fk_lead_programa_lead
        FOREIGN KEY (id_lead)
        REFERENCES lead (id_lead)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_lead_programa_programa
        FOREIGN KEY (id_programa)
        REFERENCES programa_academico (id_programa)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_lead_programa_prioridad
        CHECK (prioridad BETWEEN 1 AND 5)
);

CREATE TABLE seguimiento (
    id_seguimiento          SERIAL PRIMARY KEY,
    id_lead                 INT NOT NULL,
    id_asesor               INT NOT NULL,
    fecha_contacto          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    medio_contacto          VARCHAR(40) NOT NULL,
    observacion             TEXT NOT NULL,
    proxima_fecha_contacto  DATE,
    CONSTRAINT fk_seguimiento_lead
        FOREIGN KEY (id_lead)
        REFERENCES lead (id_lead)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_seguimiento_asesor
        FOREIGN KEY (id_asesor)
        REFERENCES asesor_admisiones (id_asesor)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_seguimiento_medio
        CHECK (LOWER(medio_contacto) IN (
            'llamada',
            'whatsapp',
            'correo',
            'presencial',
            'redes sociales',
            'videollamada'
        ))
);

CREATE TABLE inscripcion (
    id_inscripcion      SERIAL PRIMARY KEY,
    id_lead             INT NOT NULL,
    id_programa         INT NOT NULL,
    fecha_inscripcion   DATE NOT NULL DEFAULT CURRENT_DATE,
    periodo_academico   VARCHAR(10) NOT NULL,
    estado_inscripcion  VARCHAR(30) NOT NULL,
    valor_pagado        NUMERIC(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_inscripcion_lead
        FOREIGN KEY (id_lead)
        REFERENCES lead (id_lead)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inscripcion_programa
        FOREIGN KEY (id_programa)
        REFERENCES programa_academico (id_programa)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT uq_inscripcion_lead_programa_periodo
        UNIQUE (id_lead, id_programa, periodo_academico),
    CONSTRAINT chk_inscripcion_estado
        CHECK (LOWER(estado_inscripcion) IN (
            'registrada',
            'en revision',
            'admitida',
            'rechazada',
            'matriculada'
        )),
    CONSTRAINT chk_inscripcion_valor_pagado
        CHECK (valor_pagado >= 0)
);

-- Indices utiles para consultas frecuentes.
CREATE INDEX idx_lead_id_canal ON lead (id_canal);
CREATE INDEX idx_lead_id_estado ON lead (id_estado);
CREATE INDEX idx_lead_ciudad ON lead (ciudad);
CREATE INDEX idx_seguimiento_id_lead ON seguimiento (id_lead);
CREATE INDEX idx_inscripcion_periodo ON inscripcion (periodo_academico);

-- ============================================================
-- 3. TRIGGER
-- Requisito 2.9: al crear una inscripcion, actualizar el estado del lead
-- a "inscrito" y registrar la fecha de actualizacion.
-- ============================================================

CREATE OR REPLACE FUNCTION fn_actualizar_estado_lead_inscrito()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_inscrito INT;
BEGIN
    SELECT id_estado
    INTO v_id_estado_inscrito
    FROM estado_lead
    WHERE LOWER(nombre_estado) = 'inscrito';

    IF v_id_estado_inscrito IS NULL THEN
        RAISE EXCEPTION 'No existe el estado inscrito en la tabla estado_lead';
    END IF;

    UPDATE lead
    SET id_estado = v_id_estado_inscrito,
        ultima_actualizacion = CURRENT_TIMESTAMP
    WHERE id_lead = NEW.id_lead;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_actualizar_estado_lead_inscrito
AFTER INSERT ON inscripcion
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_estado_lead_inscrito();

-- ============================================================
-- 4. PROCEDIMIENTO ALMACENADO
-- Requisito 2.10: registrar seguimiento de un lead de forma controlada.
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_registrar_seguimiento_lead(
    p_id_lead INT,
    p_id_asesor INT,
    p_medio_contacto VARCHAR,
    p_observacion TEXT,
    p_proxima_fecha_contacto DATE DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_nuevo INT;
    v_id_estado_contactado INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM lead WHERE id_lead = p_id_lead) THEN
        RAISE EXCEPTION 'El lead con id % no existe', p_id_lead;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM asesor_admisiones
        WHERE id_asesor = p_id_asesor
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'El asesor con id % no existe o no esta activo', p_id_asesor;
    END IF;

    IF p_observacion IS NULL OR LENGTH(TRIM(p_observacion)) = 0 THEN
        RAISE EXCEPTION 'La observacion del seguimiento es obligatoria';
    END IF;

    INSERT INTO seguimiento (
        id_lead,
        id_asesor,
        medio_contacto,
        observacion,
        proxima_fecha_contacto
    )
    VALUES (
        p_id_lead,
        p_id_asesor,
        LOWER(TRIM(p_medio_contacto)),
        p_observacion,
        p_proxima_fecha_contacto
    );

    SELECT id_estado INTO v_id_estado_nuevo
    FROM estado_lead
    WHERE LOWER(nombre_estado) = 'nuevo';

    SELECT id_estado INTO v_id_estado_contactado
    FROM estado_lead
    WHERE LOWER(nombre_estado) = 'contactado';

    -- Si el lead estaba en estado nuevo, el seguimiento lo pasa a contactado.
    UPDATE lead
    SET id_estado = CASE
            WHEN id_estado = v_id_estado_nuevo THEN v_id_estado_contactado
            ELSE id_estado
        END,
        ultima_actualizacion = CURRENT_TIMESTAMP
    WHERE id_lead = p_id_lead;
END;
$$;

-- ============================================================
-- 5. DML - INSERCION DE DATOS DE PRUEBA
-- Incluye datos suficientes para probar tablas principales, joins,
-- agregaciones, trigger y procedimiento.
-- ============================================================

INSERT INTO canal_captacion (id_canal, nombre_canal, descripcion) VALUES
(1, 'sitio web', 'Formulario principal del sitio web institucional'),
(2, 'redes sociales', 'Campanas y mensajes desde Instagram, Facebook o TikTok'),
(3, 'feria universitaria', 'Eventos presenciales con colegios y aspirantes'),
(4, 'whatsapp', 'Contacto directo por linea de WhatsApp'),
(5, 'llamada', 'Llamadas entrantes o salientes'),
(6, 'correo', 'Solicitudes recibidas por correo electronico'),
(7, 'referido', 'Lead recomendado por estudiante, egresado o empleado'),
(8, 'colegio aliado', 'Base de datos entregada por instituciones aliadas');

SELECT setval(pg_get_serial_sequence('canal_captacion', 'id_canal'), (SELECT MAX(id_canal) FROM canal_captacion));

INSERT INTO estado_lead (id_estado, nombre_estado, descripcion) VALUES
(1, 'nuevo', 'Lead registrado sin contacto inicial'),
(2, 'contactado', 'Lead que ya tuvo al menos un contacto'),
(3, 'interesado', 'Lead que confirma interes en uno o varios programas'),
(4, 'inscrito', 'Lead que registro una inscripcion formal'),
(5, 'admitido', 'Aspirante admitido por la universidad'),
(6, 'matriculado', 'Aspirante que realizo matricula'),
(7, 'descartado', 'Lead que no continua en el proceso');

SELECT setval(pg_get_serial_sequence('estado_lead', 'id_estado'), (SELECT MAX(id_estado) FROM estado_lead));

INSERT INTO programa_academico (
    id_programa,
    nombre_programa,
    facultad,
    nivel,
    modalidad,
    activo
) VALUES
(1, 'Ingenieria de Sistemas', 'Facultad de Ingenierias', 'pregrado', 'presencial', TRUE),
(2, 'Administracion de Empresas', 'Facultad de Ciencias Economicas y Administrativas', 'pregrado', 'presencial', TRUE),
(3, 'Derecho', 'Facultad de Derecho', 'pregrado', 'presencial', TRUE),
(4, 'Psicologia', 'Facultad de Ciencias Sociales y Humanas', 'pregrado', 'presencial', TRUE),
(5, 'Comunicacion y Relaciones Corporativas', 'Facultad de Comunicacion', 'pregrado', 'presencial', TRUE),
(6, 'Maestria en Administracion', 'Facultad de Ciencias Economicas y Administrativas', 'posgrado', 'hibrida', TRUE),
(7, 'Especializacion en Gerencia de Proyectos', 'Facultad de Ingenierias', 'posgrado', 'virtual', TRUE),
(8, 'Contaduria Publica', 'Facultad de Ciencias Economicas y Administrativas', 'pregrado', 'virtual', TRUE),
(9, 'Ingenieria Ambiental', 'Facultad de Ingenierias', 'pregrado', 'presencial', TRUE),
(10, 'Marketing Digital', 'Educacion Continua', 'tecnica', 'virtual', TRUE);

SELECT setval(pg_get_serial_sequence('programa_academico', 'id_programa'), (SELECT MAX(id_programa) FROM programa_academico));

INSERT INTO asesor_admisiones (
    id_asesor,
    nombre,
    correo,
    telefono,
    cargo,
    activo
) VALUES
(1, 'Laura Restrepo', 'laura.restrepo@udem.edu.co', '6041110001', 'Asesora de admisiones', TRUE),
(2, 'Carlos Mejia', 'carlos.mejia@udem.edu.co', '6041110002', 'Asesor de admisiones', TRUE),
(3, 'Natalia Gomez', 'natalia.gomez@udem.edu.co', '6041110003', 'Asesora de admisiones', TRUE),
(4, 'Andres Torres', 'andres.torres@udem.edu.co', '6041110004', 'Asesor de admisiones', TRUE),
(5, 'Sofia Ramirez', 'sofia.ramirez@udem.edu.co', '6041110005', 'Coordinadora de admisiones', TRUE),
(6, 'Daniela Munoz', 'daniela.munoz@udem.edu.co', '6041110006', 'Asesora de admisiones', TRUE),
(7, 'Juan Pablo Cano', 'juan.cano@udem.edu.co', '6041110007', 'Asesor de admisiones', TRUE),
(8, 'Manuela Rios', 'manuela.rios@udem.edu.co', '6041110008', 'Asesora de admisiones', TRUE),
(9, 'Felipe Arango', 'felipe.arango@udem.edu.co', '6041110009', 'Asesor de admisiones', TRUE),
(10, 'Camila Salazar', 'camila.salazar@udem.edu.co', '6041110010', 'Asesora de admisiones', TRUE);

SELECT setval(pg_get_serial_sequence('asesor_admisiones', 'id_asesor'), (SELECT MAX(id_asesor) FROM asesor_admisiones));

INSERT INTO lead (
    id_lead,
    nombres,
    apellidos,
    correo,
    telefono,
    ciudad,
    fecha_registro,
    id_canal,
    id_estado
) VALUES
(1, 'Maria Camila', 'Perez Gomez', 'maria.perez@gmail.com', '3001112233', 'Medellin', '2026-02-10 08:30:00', 1, 1),
(2, 'Juan Esteban', 'Lopez Ruiz', 'juan.lopez@hotmail.com', '3002223344', 'Envigado', '2026-02-12 09:15:00', 2, 2),
(3, 'Valentina', 'Garcia Torres', 'valentina.garcia@gmail.com', '3003334455', 'Bello', '2026-02-15 11:20:00', 3, 3),
(4, 'Sebastian', 'Martinez Cano', 'sebastian.martinez@outlook.com', '3004445566', 'Medellin', '2026-03-01 14:00:00', 4, 1),
(5, 'Isabela', 'Rodriguez Mesa', 'isabela.rodriguez@gmail.com', '3005556677', 'Itagui', '2026-03-05 10:45:00', 1, 2),
(6, 'Santiago', 'Henao Mora', 'santiago.henao@yahoo.com', '3006667788', 'Rionegro', '2026-03-10 16:10:00', 5, 3),
(7, 'Daniela', 'Vargas Restrepo', 'daniela.vargas@gmail.com', '3007778899', 'Medellin', '2026-03-15 12:30:00', 6, 7),
(8, 'Mateo', 'Quintero Perez', 'mateo.quintero@gmail.com', '3008889900', 'La Estrella', '2026-03-20 15:05:00', 7, 1),
(9, 'Salome', 'Cardona Gil', 'salome.cardona@icloud.com', '3011112233', 'Medellin', '2026-04-02 08:40:00', 8, 2),
(10, 'Tomas', 'Ceballos Arias', 'tomas.ceballos@gmail.com', '3012223344', 'Sabaneta', '2026-04-08 09:50:00', 2, 3),
(11, 'Manuela', 'Osorio Marin', 'manuela.osorio@hotmail.com', '3013334455', 'Medellin', '2026-04-11 13:25:00', 1, 1),
(12, 'Alejandro', 'Castro Duque', 'alejandro.castro@gmail.com', '3014445566', 'Caldas', '2026-04-18 17:15:00', 3, 2);

SELECT setval(pg_get_serial_sequence('lead', 'id_lead'), (SELECT MAX(id_lead) FROM lead));

INSERT INTO lead_programa (
    id_lead,
    id_programa,
    prioridad,
    fecha_interes
) VALUES
(1, 1, 1, '2026-02-10'),
(1, 7, 2, '2026-02-11'),
(2, 2, 1, '2026-02-12'),
(2, 8, 3, '2026-02-13'),
(3, 3, 1, '2026-02-15'),
(3, 4, 2, '2026-02-16'),
(4, 4, 1, '2026-03-01'),
(4, 5, 2, '2026-03-02'),
(5, 5, 1, '2026-03-05'),
(5, 10, 3, '2026-03-06'),
(6, 6, 1, '2026-03-10'),
(6, 7, 2, '2026-03-11'),
(7, 9, 1, '2026-03-15'),
(8, 8, 1, '2026-03-20'),
(8, 2, 2, '2026-03-21'),
(9, 1, 1, '2026-04-02'),
(9, 9, 2, '2026-04-03'),
(10, 10, 1, '2026-04-08'),
(11, 3, 1, '2026-04-11'),
(12, 2, 1, '2026-04-18');

-- Inserciones usando el procedimiento almacenado.
CALL sp_registrar_seguimiento_lead(1, 1, 'whatsapp', 'Se informa sobre requisitos de Ingenieria de Sistemas.', CURRENT_DATE + 5);
CALL sp_registrar_seguimiento_lead(2, 2, 'llamada', 'El lead solicita informacion sobre plan de estudios y horarios.', CURRENT_DATE + 4);
CALL sp_registrar_seguimiento_lead(3, 3, 'correo', 'Se envia informacion sobre proceso de admision a Derecho.', CURRENT_DATE + 3);
CALL sp_registrar_seguimiento_lead(4, 4, 'whatsapp', 'Se agenda llamada para resolver dudas sobre Psicologia.', CURRENT_DATE + 6);
CALL sp_registrar_seguimiento_lead(5, 5, 'videollamada', 'Reunion virtual para explicar opciones de financiacion.', CURRENT_DATE + 7);
CALL sp_registrar_seguimiento_lead(6, 6, 'llamada', 'Interesado en maestria, pregunta por homologaciones.', CURRENT_DATE + 8);
CALL sp_registrar_seguimiento_lead(7, 7, 'correo', 'Lead indica que aplazara el proceso para otro semestre.', NULL);
CALL sp_registrar_seguimiento_lead(8, 8, 'redes sociales', 'Contacto inicial desde campana de Instagram.', CURRENT_DATE + 5);
CALL sp_registrar_seguimiento_lead(9, 9, 'presencial', 'Atencion en feria universitaria con informacion de becas.', CURRENT_DATE + 10);
CALL sp_registrar_seguimiento_lead(10, 10, 'whatsapp', 'Solicita enlace de inscripcion para Marketing Digital.', CURRENT_DATE + 2);
CALL sp_registrar_seguimiento_lead(1, 2, 'llamada', 'Segundo contacto: confirma interes y pide simulacion de horario.', CURRENT_DATE + 9);
CALL sp_registrar_seguimiento_lead(3, 4, 'whatsapp', 'Confirma documentacion para continuar proceso.', CURRENT_DATE + 4);
CALL sp_registrar_seguimiento_lead(5, 1, 'correo', 'Se envia recordatorio para finalizar inscripcion.', CURRENT_DATE + 6);
CALL sp_registrar_seguimiento_lead(9, 3, 'llamada', 'Aspirante confirma disponibilidad para entrevista.', CURRENT_DATE + 3);
CALL sp_registrar_seguimiento_lead(12, 5, 'whatsapp', 'Se orienta sobre requisitos de Administracion de Empresas.', CURRENT_DATE + 5);

INSERT INTO inscripcion (
    id_inscripcion,
    id_lead,
    id_programa,
    fecha_inscripcion,
    periodo_academico,
    estado_inscripcion,
    valor_pagado
) VALUES
(1, 1, 1, '2026-03-01', '2026-1', 'registrada', 180000),
(2, 2, 2, '2026-03-03', '2026-1', 'en revision', 180000),
(3, 3, 3, '2026-03-08', '2026-1', 'registrada', 180000),
(4, 4, 4, '2026-03-12', '2026-1', 'registrada', 180000),
(5, 5, 5, '2026-03-18', '2026-1', 'en revision', 180000),
(6, 6, 6, '2026-03-22', '2026-1', 'registrada', 250000),
(7, 8, 8, '2026-04-02', '2026-2', 'registrada', 180000),
(8, 9, 1, '2026-04-05', '2026-2', 'registrada', 180000),
(9, 10, 10, '2026-04-10', '2026-2', 'registrada', 120000),
(10, 12, 2, '2026-04-20', '2026-2', 'en revision', 180000);

SELECT setval(pg_get_serial_sequence('inscripcion', 'id_inscripcion'), (SELECT MAX(id_inscripcion) FROM inscripcion));

-- Actualizaciones posteriores al trigger para simular avance real del proceso.
UPDATE inscripcion
SET estado_inscripcion = 'admitida'
WHERE id_lead IN (3, 6);

UPDATE inscripcion
SET estado_inscripcion = 'matriculada'
WHERE id_lead = 9;

UPDATE lead
SET id_estado = (SELECT id_estado FROM estado_lead WHERE nombre_estado = 'admitido'),
    ultima_actualizacion = CURRENT_TIMESTAMP
WHERE id_lead IN (3, 6);

UPDATE lead
SET id_estado = (SELECT id_estado FROM estado_lead WHERE nombre_estado = 'matriculado'),
    ultima_actualizacion = CURRENT_TIMESTAMP
WHERE id_lead = 9;

-- ============================================================
-- 6. CONSULTAS BASICAS
-- Requisito 2.5: minimo 5 consultas con SELECT, WHERE, ORDER BY,
-- LIMIT, LIKE y BETWEEN.
-- ============================================================

-- 6.1 Leads de Medellin ordenados por fecha de registro.
SELECT
    id_lead,
    nombres,
    apellidos,
    correo,
    ciudad,
    fecha_registro
FROM lead
WHERE ciudad = 'Medellin'
ORDER BY fecha_registro DESC
LIMIT 10;

-- 6.2 Leads cuyo correo contiene el dominio gmail.com.
SELECT
    id_lead,
    nombres,
    apellidos,
    correo
FROM lead
WHERE correo LIKE '%gmail.com%'
ORDER BY apellidos ASC;

-- 6.3 Leads registrados entre dos fechas.
SELECT
    id_lead,
    nombres,
    apellidos,
    ciudad,
    fecha_registro
FROM lead
WHERE fecha_registro BETWEEN '2026-03-01' AND '2026-04-30'
ORDER BY fecha_registro ASC;

-- 6.4 Programas activos de pregrado.
SELECT
    id_programa,
    nombre_programa,
    facultad,
    modalidad
FROM programa_academico
WHERE activo = TRUE
  AND nivel = 'pregrado'
ORDER BY facultad, nombre_programa
LIMIT 5;

-- 6.5 Seguimientos realizados por WhatsApp o llamada con proxima fecha.
SELECT
    id_seguimiento,
    id_lead,
    id_asesor,
    medio_contacto,
    observacion,
    proxima_fecha_contacto
FROM seguimiento
WHERE medio_contacto IN ('whatsapp', 'llamada')
  AND proxima_fecha_contacto IS NOT NULL
ORDER BY proxima_fecha_contacto ASC
LIMIT 10;

-- ============================================================
-- 7. CONSULTAS CON AGREGACION
-- Requisito 2.6: COUNT, SUM, AVG, MIN, MAX, GROUP BY y HAVING.
-- ============================================================

-- 7.1 Cantidad de leads por canal de captacion.
SELECT
    c.nombre_canal,
    COUNT(l.id_lead) AS total_leads
FROM canal_captacion c
LEFT JOIN lead l ON l.id_canal = c.id_canal
GROUP BY c.nombre_canal
HAVING COUNT(l.id_lead) >= 1
ORDER BY total_leads DESC;

-- 7.2 Programas con mas leads interesados.
SELECT
    p.nombre_programa,
    COUNT(lp.id_lead) AS total_interesados,
    MIN(lp.fecha_interes) AS primer_interes,
    MAX(lp.fecha_interes) AS ultimo_interes
FROM programa_academico p
JOIN lead_programa lp ON lp.id_programa = p.id_programa
GROUP BY p.nombre_programa
HAVING COUNT(lp.id_lead) >= 2
ORDER BY total_interesados DESC, p.nombre_programa;

-- 7.3 Resumen de pagos por periodo academico.
SELECT
    periodo_academico,
    COUNT(id_inscripcion) AS total_inscripciones,
    SUM(valor_pagado) AS total_recaudado,
    AVG(valor_pagado) AS promedio_pagado,
    MIN(valor_pagado) AS pago_minimo,
    MAX(valor_pagado) AS pago_maximo
FROM inscripcion
GROUP BY periodo_academico
HAVING SUM(valor_pagado) > 0
ORDER BY periodo_academico;

-- ============================================================
-- 8. CONSULTAS CON JOINS
-- Requisito 2.7: minimo 3 consultas usando INNER JOIN y LEFT JOIN.
-- ============================================================

-- 8.1 INNER JOIN: leads con canal y estado actual.
SELECT
    l.id_lead,
    l.nombres || ' ' || l.apellidos AS nombre_completo,
    l.correo,
    c.nombre_canal,
    e.nombre_estado
FROM lead l
INNER JOIN canal_captacion c ON c.id_canal = l.id_canal
INNER JOIN estado_lead e ON e.id_estado = l.id_estado
ORDER BY l.id_lead;

-- 8.2 INNER JOIN: relacion N:M entre leads y programas academicos.
SELECT
    l.id_lead,
    l.nombres || ' ' || l.apellidos AS nombre_completo,
    p.nombre_programa,
    p.nivel,
    lp.prioridad,
    lp.fecha_interes
FROM lead l
INNER JOIN lead_programa lp ON lp.id_lead = l.id_lead
INNER JOIN programa_academico p ON p.id_programa = lp.id_programa
ORDER BY l.id_lead, lp.prioridad;

-- 8.3 LEFT JOIN: leads sin seguimientos registrados.
SELECT
    l.id_lead,
    l.nombres || ' ' || l.apellidos AS nombre_completo,
    l.correo,
    s.id_seguimiento
FROM lead l
LEFT JOIN seguimiento s ON s.id_lead = l.id_lead
WHERE s.id_seguimiento IS NULL
ORDER BY l.id_lead;

-- 8.4 JOIN adicional: inscripciones con lead, programa y estado del proceso.
SELECT
    i.id_inscripcion,
    l.nombres || ' ' || l.apellidos AS nombre_completo,
    p.nombre_programa,
    i.periodo_academico,
    i.estado_inscripcion,
    i.valor_pagado
FROM inscripcion i
INNER JOIN lead l ON l.id_lead = i.id_lead
INNER JOIN programa_academico p ON p.id_programa = i.id_programa
ORDER BY i.fecha_inscripcion DESC;

-- ============================================================
-- 9. OPERACIONES DE CONJUNTOS
-- Requisito 2.8: consulta con UNION.
-- ============================================================

SELECT
    l.id_lead,
    l.nombres || ' ' || l.apellidos AS nombre_completo,
    'lead inscrito' AS grupo_reporte
FROM lead l
INNER JOIN estado_lead e ON e.id_estado = l.id_estado
WHERE e.nombre_estado = 'inscrito'

UNION

SELECT
    l.id_lead,
    l.nombres || ' ' || l.apellidos AS nombre_completo,
    'lead admitido' AS grupo_reporte
FROM lead l
INNER JOIN estado_lead e ON e.id_estado = l.id_estado
WHERE e.nombre_estado = 'admitido'
ORDER BY id_lead;

-- ============================================================
-- 10. CONSULTAS DE VERIFICACION DE TRIGGER Y PROCEDIMIENTO
-- ============================================================

-- 10.1 Verificar que los leads con inscripcion fueron actualizados por trigger
-- o por el avance posterior del proceso.
SELECT
    l.id_lead,
    l.nombres || ' ' || l.apellidos AS nombre_completo,
    e.nombre_estado,
    l.ultima_actualizacion
FROM lead l
INNER JOIN estado_lead e ON e.id_estado = l.id_estado
WHERE l.id_lead IN (
    SELECT DISTINCT id_lead
    FROM inscripcion
)
ORDER BY l.id_lead;

-- 10.2 Verificar seguimientos creados mediante el procedimiento almacenado.
SELECT
    s.id_seguimiento,
    l.nombres || ' ' || l.apellidos AS lead,
    a.nombre AS asesor,
    s.medio_contacto,
    s.fecha_contacto,
    s.proxima_fecha_contacto
FROM seguimiento s
INNER JOIN lead l ON l.id_lead = s.id_lead
INNER JOIN asesor_admisiones a ON a.id_asesor = s.id_asesor
ORDER BY s.id_seguimiento;

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
