DROP DATABASE IF EXISTS crm_leads_udem;
CREATE DATABASE crm_leads_udem;

-- ============================================================
-- 1. LIMPIEZA DE TABLAS
-- Se borran primero las tablas que dependen de otras.
-- ============================================================

DROP TABLE IF EXISTS inscripcion;
DROP TABLE IF EXISTS seguimiento;
DROP TABLE IF EXISTS lead_programa;
DROP TABLE IF EXISTS lead;
DROP TABLE IF EXISTS asesor_admisiones;
DROP TABLE IF EXISTS programa_academico;
DROP TABLE IF EXISTS estado_lead;
DROP TABLE IF EXISTS canal_captacion;

-- ============================================================
-- 2. CREACION DE TABLAS
-- ============================================================

-- Tabla de canales por donde llegan los leads.
CREATE TABLE canal_captacion (
    id_canal SERIAL PRIMARY KEY,
    nombre_canal VARCHAR(60) NOT NULL UNIQUE,
    descripcion TEXT
);

-- Tabla de estados del proceso del lead.
CREATE TABLE estado_lead (
    id_estado SERIAL PRIMARY KEY,
    nombre_estado VARCHAR(40) NOT NULL UNIQUE,
    descripcion TEXT
);

-- Tabla de programas academicos.
CREATE TABLE programa_academico (
    id_programa SERIAL PRIMARY KEY,
    nombre_programa VARCHAR(120) NOT NULL UNIQUE,
    facultad VARCHAR(100) NOT NULL,
    nivel VARCHAR(30) NOT NULL CHECK (nivel IN ('pregrado', 'posgrado', 'tecnica')),
    modalidad VARCHAR(30) NOT NULL CHECK (modalidad IN ('presencial', 'virtual', 'hibrida')),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Tabla de asesores de admisiones.
CREATE TABLE asesor_admisiones (
    id_asesor SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    correo VARCHAR(120) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Tabla principal de leads o aspirantes.
CREATE TABLE lead (
    id_lead SERIAL PRIMARY KEY,
    nombres VARCHAR(80) NOT NULL,
    apellidos VARCHAR(80) NOT NULL,
    correo VARCHAR(120) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    ciudad VARCHAR(80),
    fecha_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    id_canal INT NOT NULL,
    id_estado INT NOT NULL,
    ultima_actualizacion TIMESTAMP,

    FOREIGN KEY (id_canal) REFERENCES canal_captacion(id_canal),
    FOREIGN KEY (id_estado) REFERENCES estado_lead(id_estado)
);

-- Tabla intermedia para la relacion muchos a muchos:
-- un lead puede interesarse en varios programas y un programa puede tener varios leads.
CREATE TABLE lead_programa (
    id_lead INT NOT NULL,
    id_programa INT NOT NULL,
    prioridad INT NOT NULL CHECK (prioridad BETWEEN 1 AND 5),
    fecha_interes DATE NOT NULL DEFAULT CURRENT_DATE,

    PRIMARY KEY (id_lead, id_programa),
    FOREIGN KEY (id_lead) REFERENCES lead(id_lead),
    FOREIGN KEY (id_programa) REFERENCES programa_academico(id_programa)
);

-- Tabla de seguimientos hechos por asesores.
CREATE TABLE seguimiento (
    id_seguimiento SERIAL PRIMARY KEY,
    id_lead INT NOT NULL,
    id_asesor INT NOT NULL,
    fecha_contacto DATE NOT NULL DEFAULT CURRENT_DATE,
    medio_contacto VARCHAR(40) NOT NULL CHECK (medio_contacto IN ('llamada', 'whatsapp', 'correo', 'presencial')),
    observacion TEXT NOT NULL,
    proxima_fecha_contacto DATE,

    FOREIGN KEY (id_lead) REFERENCES lead(id_lead),
    FOREIGN KEY (id_asesor) REFERENCES asesor_admisiones(id_asesor)
);

-- Tabla de inscripciones.
CREATE TABLE inscripcion (
    id_inscripcion SERIAL PRIMARY KEY,
    id_lead INT NOT NULL,
    id_programa INT NOT NULL,
    fecha_inscripcion DATE NOT NULL DEFAULT CURRENT_DATE,
    periodo_academico VARCHAR(10) NOT NULL,
    estado_inscripcion VARCHAR(30) NOT NULL CHECK (estado_inscripcion IN ('registrada', 'en revision', 'admitida', 'rechazada', 'matriculada')),
    valor_pagado NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (valor_pagado >= 0),

    FOREIGN KEY (id_lead) REFERENCES lead(id_lead),
    FOREIGN KEY (id_programa) REFERENCES programa_academico(id_programa),
    UNIQUE (id_lead, id_programa, periodo_academico)
);

-- ============================================================
-- 3. TRIGGER
-- Justificacion:
-- Cuando un lead se inscribe, su estado debe cambiar automaticamente
-- a "inscrito". Asi se evita hacerlo manualmente.
-- ============================================================

CREATE OR REPLACE FUNCTION actualizar_estado_a_inscrito()
RETURNS TRIGGER AS $$
DECLARE
    estado_inscrito INT;
BEGIN
    SELECT id_estado
    INTO estado_inscrito
    FROM estado_lead
    WHERE nombre_estado = 'inscrito';

    UPDATE lead
    SET id_estado = estado_inscrito,
        ultima_actualizacion = CURRENT_TIMESTAMP
    WHERE id_lead = NEW.id_lead;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lead_inscrito
AFTER INSERT ON inscripcion
FOR EACH ROW
EXECUTE FUNCTION actualizar_estado_a_inscrito();

-- ============================================================
-- 4. PROCEDIMIENTO ALMACENADO
-- Justificacion:
-- Este procedimiento permite registrar seguimientos de forma mas simple
-- sin escribir siempre el INSERT completo.
-- ============================================================

CREATE OR REPLACE PROCEDURE registrar_seguimiento(
    p_id_lead INT,
    p_id_asesor INT,
    p_medio_contacto VARCHAR,
    p_observacion TEXT,
    p_proxima_fecha_contacto DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
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
        p_medio_contacto,
        p_observacion,
        p_proxima_fecha_contacto
    );
END;
$$;

-- ============================================================
-- 5. INSERCION DE DATOS
-- ============================================================

INSERT INTO canal_captacion (nombre_canal, descripcion) VALUES
('sitio web', 'Formulario de la pagina institucional'),
('instagram', 'Campanas en Instagram'),
('facebook', 'Campanas en Facebook'),
('whatsapp', 'Contacto por WhatsApp'),
('feria universitaria', 'Evento presencial'),
('referido', 'Persona recomendada por estudiante'),
('llamada', 'Contacto telefonico'),
('correo', 'Correo electronico'),
('colegio', 'Visita a colegio'),
('tiktok', 'Campana en TikTok');

INSERT INTO estado_lead (nombre_estado, descripcion) VALUES
('nuevo', 'Lead recien registrado'),
('contactado', 'Ya se hizo primer contacto'),
('interesado', 'Mostro interes en un programa'),
('inscrito', 'Ya realizo inscripcion'),
('admitido', 'Fue admitido'),
('matriculado', 'Ya se matriculo'),
('descartado', 'No continua en el proceso');

INSERT INTO programa_academico (nombre_programa, facultad, nivel, modalidad, activo) VALUES
('Ingenieria de Sistemas', 'Ingenieria', 'pregrado', 'presencial', TRUE),
('Derecho', 'Derecho', 'pregrado', 'presencial', TRUE),
('Psicologia', 'Ciencias Sociales', 'pregrado', 'presencial', TRUE),
('Administracion de Empresas', 'Ciencias Economicas', 'pregrado', 'virtual', TRUE),
('Comunicacion Grafica', 'Comunicacion', 'pregrado', 'presencial', TRUE),
('Especializacion en Gerencia', 'Ciencias Economicas', 'posgrado', 'virtual', TRUE),
('Maestria en Educacion', 'Educacion', 'posgrado', 'hibrida', TRUE),
('Contaduria Publica', 'Ciencias Economicas', 'pregrado', 'presencial', TRUE),
('Ingenieria Financiera', 'Ingenieria', 'pregrado', 'presencial', TRUE),
('Tecnica en Desarrollo Web', 'Ingenieria', 'tecnica', 'virtual', TRUE);

INSERT INTO asesor_admisiones (nombre, correo, telefono, activo) VALUES
('Laura Gomez', 'laura.gomez@udem.edu.co', '3001111111', TRUE),
('Carlos Perez', 'carlos.perez@udem.edu.co', '3002222222', TRUE),
('Ana Ruiz', 'ana.ruiz@udem.edu.co', '3003333333', TRUE),
('Mateo Garcia', 'mateo.garcia@udem.edu.co', '3004444444', TRUE),
('Sofia Lopez', 'sofia.lopez@udem.edu.co', '3005555555', TRUE),
('Juan Torres', 'juan.torres@udem.edu.co', '3006666666', TRUE),
('Diana Mora', 'diana.mora@udem.edu.co', '3007777777', TRUE),
('Felipe Cano', 'felipe.cano@udem.edu.co', '3008888888', TRUE),
('Valentina Rios', 'valentina.rios@udem.edu.co', '3009999999', TRUE),
('Andres Mejia', 'andres.mejia@udem.edu.co', '3010000000', TRUE);

INSERT INTO lead (nombres, apellidos, correo, telefono, ciudad, fecha_registro, id_canal, id_estado) VALUES
('Maria', 'Lopez', 'maria.lopez@gmail.com', '3101001001', 'Medellin', '2026-03-01', 1, 1),
('Juan', 'Martinez', 'juan.martinez@gmail.com', '3101001002', 'Bello', '2026-03-05', 2, 1),
('Camila', 'Restrepo', 'camila.restrepo@hotmail.com', '3101001003', 'Envigado', '2026-03-10', 3, 2),
('Santiago', 'Mejia', 'santiago.mejia@gmail.com', '3101001004', 'Medellin', '2026-03-15', 4, 3),
('Daniela', 'Torres', 'daniela.torres@yahoo.com', '3101001005', 'Itagui', '2026-03-20', 5, 1),
('Sebastian', 'Cano', 'sebastian.cano@gmail.com', '3101001006', 'Medellin', '2026-04-01', 6, 2),
('Valeria', 'Mora', 'valeria.mora@gmail.com', '3101001007', 'Rionegro', '2026-04-03', 7, 3),
('Miguel', 'Suarez', 'miguel.suarez@hotmail.com', '3101001008', 'Medellin', '2026-04-10', 8, 1),
('Isabella', 'Rios', 'isabella.rios@gmail.com', '3101001009', 'Sabaneta', '2026-04-12', 9, 2),
('Nicolas', 'Castro', 'nicolas.castro@gmail.com', '3101001010', 'Medellin', '2026-04-18', 10, 1);

INSERT INTO lead_programa (id_lead, id_programa, prioridad, fecha_interes) VALUES
(1, 1, 1, '2026-03-01'),
(1, 10, 2, '2026-03-01'),
(2, 2, 1, '2026-03-05'),
(3, 3, 1, '2026-03-10'),
(4, 4, 1, '2026-03-15'),
(5, 5, 2, '2026-03-20'),
(6, 6, 1, '2026-04-01'),
(7, 7, 1, '2026-04-03'),
(8, 8, 1, '2026-04-10'),
(9, 9, 1, '2026-04-12'),
(10, 1, 2, '2026-04-18'),
(10, 4, 1, '2026-04-18');

-- Se usa el procedimiento para insertar seguimientos.
CALL registrar_seguimiento(1, 1, 'whatsapp', 'Se envio informacion del programa.', '2026-03-08');
CALL registrar_seguimiento(2, 2, 'llamada', 'No contesto, se programa nuevo contacto.', '2026-03-09');
CALL registrar_seguimiento(3, 3, 'correo', 'Solicito informacion de requisitos.', '2026-03-15');
CALL registrar_seguimiento(4, 4, 'whatsapp', 'Esta interesado en modalidad virtual.', '2026-03-20');
CALL registrar_seguimiento(5, 5, 'presencial', 'Asistio a feria universitaria.', '2026-03-25');
CALL registrar_seguimiento(6, 6, 'llamada', 'Desea conocer costos.', '2026-04-05');
CALL registrar_seguimiento(7, 7, 'correo', 'Se envio plan de estudios.', '2026-04-08');
CALL registrar_seguimiento(8, 8, 'whatsapp', 'Pregunta por inscripcion.', '2026-04-15');
CALL registrar_seguimiento(9, 9, 'llamada', 'Se explica proceso de admision.', '2026-04-18');
CALL registrar_seguimiento(10, 10, 'correo', 'Se envia enlace de inscripcion.', '2026-04-22');

-- Al insertar inscripciones, el trigger cambia el estado del lead a "inscrito".
INSERT INTO inscripcion (id_lead, id_programa, fecha_inscripcion, periodo_academico, estado_inscripcion, valor_pagado) VALUES
(1, 1, '2026-03-09', '2026-1', 'registrada', 180000),
(2, 2, '2026-03-12', '2026-1', 'registrada', 180000),
(3, 3, '2026-03-18', '2026-1', 'admitida', 180000),
(4, 4, '2026-03-22', '2026-1', 'registrada', 180000),
(5, 5, '2026-03-28', '2026-1', 'en revision', 180000),
(6, 6, '2026-04-06', '2026-1', 'admitida', 220000),
(7, 7, '2026-04-10', '2026-1', 'registrada', 220000),
(8, 8, '2026-04-16', '2026-1', 'rechazada', 180000),
(9, 9, '2026-04-20', '2026-1', 'registrada', 180000),
(10, 1, '2026-04-25', '2026-1', 'matriculada', 300000);

-- ============================================================
-- 6. CONSULTAS BASICAS
-- Requisito: SELECT, WHERE, ORDER BY, LIMIT, LIKE, BETWEEN.
-- ============================================================

-- 1. Leads de Medellin ordenados por fecha.
SELECT *
FROM lead
WHERE ciudad = 'Medellin'
ORDER BY fecha_registro DESC;

-- 2. Leads con correo de Gmail usando LIKE.
SELECT nombres, apellidos, correo
FROM lead
WHERE correo LIKE '%gmail.com%';

-- 3. Leads registrados entre dos fechas usando BETWEEN.
SELECT nombres, apellidos, fecha_registro
FROM lead
WHERE fecha_registro BETWEEN '2026-03-01' AND '2026-03-31';

-- 4. Programas activos de pregrado.
SELECT nombre_programa, facultad, modalidad
FROM programa_academico
WHERE activo = TRUE AND nivel = 'pregrado'
ORDER BY nombre_programa;

-- 5. Mostrar solo los 5 primeros leads.
SELECT id_lead, nombres, apellidos, ciudad
FROM lead
ORDER BY id_lead
LIMIT 5;

-- ============================================================
-- 7. CONSULTAS CON AGREGACION
-- Requisito: COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING.
-- ============================================================

-- 1. Cantidad de leads por canal.
SELECT c.nombre_canal, COUNT(l.id_lead) AS total_leads
FROM canal_captacion c
INNER JOIN lead l ON c.id_canal = l.id_canal
GROUP BY c.nombre_canal
HAVING COUNT(l.id_lead) >= 1;

-- 2. Cantidad de interesados por programa.
SELECT p.nombre_programa, COUNT(lp.id_lead) AS total_interesados
FROM programa_academico p
INNER JOIN lead_programa lp ON p.id_programa = lp.id_programa
GROUP BY p.nombre_programa
ORDER BY total_interesados DESC;

-- 3. Total, promedio, minimo y maximo pagado por periodo.
SELECT periodo_academico,
       SUM(valor_pagado) AS total_pagado,
       AVG(valor_pagado) AS promedio_pagado,
       MIN(valor_pagado) AS menor_pago,
       MAX(valor_pagado) AS mayor_pago
FROM inscripcion
GROUP BY periodo_academico;

-- ============================================================
-- 8. CONSULTAS CON JOINS
-- Requisito: minimo 3 consultas con INNER JOIN y LEFT JOIN.
-- ============================================================

-- 1. Leads con su canal y estado.
SELECT l.nombres, l.apellidos, c.nombre_canal, e.nombre_estado
FROM lead l
INNER JOIN canal_captacion c ON l.id_canal = c.id_canal
INNER JOIN estado_lead e ON l.id_estado = e.id_estado;

-- 2. Leads y programas de interes.
SELECT l.nombres, l.apellidos, p.nombre_programa, lp.prioridad
FROM lead l
INNER JOIN lead_programa lp ON l.id_lead = lp.id_lead
INNER JOIN programa_academico p ON lp.id_programa = p.id_programa
ORDER BY l.id_lead;

-- 3. Seguimientos con nombre del asesor.
SELECT l.nombres, l.apellidos, a.nombre AS asesor, s.medio_contacto, s.observacion
FROM seguimiento s
INNER JOIN lead l ON s.id_lead = l.id_lead
INNER JOIN asesor_admisiones a ON s.id_asesor = a.id_asesor;

-- 4. LEFT JOIN: leads aunque no tengan seguimientos.
SELECT l.nombres, l.apellidos, s.fecha_contacto, s.observacion
FROM lead l
LEFT JOIN seguimiento s ON l.id_lead = s.id_lead;

-- ============================================================
-- 9. OPERACION DE CONJUNTOS
-- Requisito: usar UNION, INTERSECT o EXCEPT.
-- ============================================================

-- UNION: une leads con inscripciones admitidas y matriculadas.
SELECT l.nombres, l.apellidos, i.estado_inscripcion
FROM lead l
INNER JOIN inscripcion i ON l.id_lead = i.id_lead
WHERE i.estado_inscripcion = 'admitida'

UNION

SELECT l.nombres, l.apellidos, i.estado_inscripcion
FROM lead l
INNER JOIN inscripcion i ON l.id_lead = i.id_lead
WHERE i.estado_inscripcion = 'matriculada';

-- ============================================================
-- 10. CONSULTAS PARA VERIFICAR TRIGGER Y PROCEDIMIENTO
-- ============================================================

-- Verificar que los leads con inscripcion quedaron en estado inscrito.
SELECT l.id_lead, l.nombres, l.apellidos, e.nombre_estado, l.ultima_actualizacion
FROM lead l
INNER JOIN estado_lead e ON l.id_estado = e.id_estado
ORDER BY l.id_lead;

-- Verificar seguimientos creados con el procedimiento.
SELECT *
FROM seguimiento
ORDER BY id_seguimiento;
