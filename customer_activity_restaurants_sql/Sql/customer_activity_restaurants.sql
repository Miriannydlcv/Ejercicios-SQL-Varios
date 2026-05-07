/*
Objetivo:
Simular un entorno transaccional simple para responder una consulta de negocio:

"Cantidad de clientes únicos activos, entre 30 y 40 años,
que realizaron compras en restaurantes durante septiembre 2024"

El script incluye:
- Creación de una base de datos simulada
- Modelado dimensional (clientes, comercios y transacciones)
- Inserción de datos dummy
- Query final para responder la pregunta de negocio
*/


------------------------------------------------------------------
---------------------- 1. CREACIÓN BD -----------------------------
------------------------------------------------------------------

-- Creación de la base de datos
IF NOT EXISTS ( -- Validación para evitar recrear objetos existentes
    SELECT 1 
    FROM sys.databases 
    WHERE name = '[09_TransaccionesVF]'
)
BEGIN
    CREATE DATABASE [09_TransaccionesVF];
END;
GO



------------------------------------------------------------------
---------------------- 2. DIMENSIONES -----------------------------
------------------------------------------------------------------



USE [09_TransaccionesVF];
GO

-- Dimensión de comercios:
-- almacena información descriptiva de los establecimientos
-- utilizada para clasificar transacciones por tipo de comercio

IF NOT EXISTS (
    SELECT 1 FROM sys.tables 
    WHERE name = 'DimComercios' AND schema_id = SCHEMA_ID('dbo')
)
BEGIN
    CREATE TABLE [09_TransaccionesVF].dbo.DimComercios (
        ID_Comercio INT IDENTITY(3001,1) 
            CONSTRAINT PK_DimComercios PRIMARY KEY,
        Nombre_Comercio VARCHAR(100),
        Tipo_Comercio VARCHAR(60)
    );
END;


--Añadir valores dummy dimensión Comercios
-- Inserción de datos dummy para simular distintos tipos de comercios

INSERT INTO [09_TransaccionesVF].dbo.DimComercios (Nombre_Comercio, Tipo_Comercio)
VALUES
('Restaurante El Sabor', 'Restaurante'),
('Restaurante La Mesa', 'Restaurante'),
('Restaurante Buen Gusto', 'Restaurante'),
('Supermercado Central', 'Supermercado'),
('Supermercado Nacional', 'Supermercado'),
('Café Aroma', 'Cafetería'),
('Café Express', 'Cafetería');


-- Verificación Comercioss
SELECT * FROM [09_TransaccionesVF].dbo.DimComercios;


-- Dimensión de clientes:
-- contiene atributos demográficos y estado del cliente
-- utilizados para segmentación y filtros analíticos

IF NOT EXISTS (
    SELECT 1 FROM sys.tables 
    WHERE name = 'DimClientes' AND schema_id = SCHEMA_ID('dbo')
)
BEGIN
    CREATE TABLE [09_TransaccionesVF].dbo.DimClientes (
        ID_Cuenta INT IDENTITY(200001,1) CONSTRAINT PK_DimClientes PRIMARY KEY,
        ID_Cliente INT,
        Fecha_Nacimiento DATE,
        Sexo CHAR(1),
        Status_Cliente VARCHAR(20) NOT NULL
    );
END;


--Añadir valores dummy dimensión Clientes
-- Generación de clientes ficticios:
-- se crean edades, sexo y estatus de forma programática
-- para facilitar pruebas del query analítico

INSERT INTO DimClientes (ID_Cliente, Fecha_Nacimiento, Sexo, Status_Cliente)
SELECT 
    30001 + v.ID_Cliente AS ID_Cliente,
    DATEADD(YEAR, - (20 + v.ID_Cliente % 40), GETDATE()) AS Fecha_Nacimiento,
    CASE WHEN v.ID_Cliente % 2 = 0 THEN 'F' ELSE 'M' END AS Sexo,
    CASE WHEN v.ID_Cliente <= 28 THEN 'Activo' ELSE 'Inactivo' END AS Status_Cliente
FROM (
    SELECT 1 AS ID_Cliente UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
    UNION ALL SELECT 8
    UNION ALL SELECT 8
    UNION ALL SELECT 9
    UNION ALL SELECT 10
    UNION ALL SELECT 10
    UNION ALL SELECT 11
    UNION ALL SELECT 12
    UNION ALL SELECT 13
    UNION ALL SELECT 14
    UNION ALL SELECT 15
    UNION ALL SELECT 16
    UNION ALL SELECT 17
    UNION ALL SELECT 18
    UNION ALL SELECT 19
    UNION ALL SELECT 20
    UNION ALL SELECT 21
    UNION ALL SELECT 22
    UNION ALL SELECT 23
    UNION ALL SELECT 24
    UNION ALL SELECT 25
    UNION ALL SELECT 26
    UNION ALL SELECT 27
    UNION ALL SELECT 28
    UNION ALL SELECT 29
    UNION ALL SELECT 30
) v;

--Columna edad
ALTER TABLE DimClientes
ADD Edad INT;

UPDATE DimClientes
SET Edad = DATEDIFF(YEAR, Fecha_Nacimiento, GETDATE())
           - CASE 
                WHEN DATEADD(YEAR, DATEDIFF(YEAR, Fecha_Nacimiento, GETDATE()), Fecha_Nacimiento) > GETDATE()
                THEN 1
                ELSE 0
             END;


-- Verificación clientes
SELECT * FROM [09_TransaccionesVF].dbo.DimClientes
order by edad desc;


------------------------------------------------------------------
---------------------- 3. TABLA DE HECHOS -------------------------
------------------------------------------------------------------

-- Creación de tabla de hechos y establecimiento de claves primarias y foráneas
-- Tabla de hechos:
-- almacena el detalle transaccional de compras realizadas
-- conectando clientes y comercios mediante claves foráneas

IF NOT EXISTS (
    SELECT 1 FROM sys.tables 
    WHERE name = 'FactTransacciones' AND schema_id = SCHEMA_ID('dbo')
)
BEGIN
CREATE TABLE [09_TransaccionesVF].dbo.FactTransacciones (
    ID_Transaccion INT IDENTITY(10000001,1) PRIMARY KEY, -- Clave primaria para la tabla de hechos
    ID_Comercio INT, -- Clave foránea referencia a DimComercios
    ID_Cuenta INT, -- Clave foránea referencia a DimClientes
    Fecha_Compra DATE,
    MontoRD DECIMAL(18,2),
    CONSTRAINT FK_FactTransacciones_DimComercios FOREIGN KEY (ID_Comercio)
        REFERENCES [09_TransaccionesVF].dbo.DimComercios (ID_COMERCIO),
    CONSTRAINT FK_FactTransacciones_DimClientes FOREIGN KEY (ID_Cuenta)
        REFERENCES [09_TransaccionesVF].dbo.DimClientes (ID_Cuenta)
    );
END;


------------------------------------------------------------------
---------------------- 4. CARGA DUMMY -----------------------------
------------------------------------------------------------------

--Añadir valores dummy tabla de hechos [09_TransaccionesVF]
INSERT INTO FactTransacciones (ID_Cuenta, ID_Comercio, Fecha_Compra, MontoRD)
SELECT TOP (200)
    c.ID_Cuenta,
    co.ID_Comercio,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 90, '2024-07-01'),
    ABS(CHECKSUM(NEWID())) % 5000 + 100
FROM DimClientes c
CROSS JOIN DimComercios co
ORDER BY NEWID();
-- CROSS JOIN utilizado para generar múltiples combinaciones
-- cliente-comercio y simular volumen transaccional



---Validación
SELECT FORMAT(Fecha_Compra, 'yyyy-MM') AS Mes, COUNT(*) 
FROM [09_TransaccionesVF].dbo.FactTransacciones
GROUP BY FORMAT(Fecha_Compra, 'yyyy-MM');


-- Verificación de las tablas
SELECT * FROM [09_TransaccionesVF].dbo.DimClientes;
SELECT * FROM [09_TransaccionesVF].dbo.DimComercios;
SELECT * FROM [09_TransaccionesVF].dbo.FactTransacciones;


------------------------------------------------------------------
----------------------Consulta SQL

---QA

-- Validación rápida:
-- verificar clientes únicos existentes en la dimensión
SELECT Distinct(ID_Cliente) FROM [09_TransaccionesVF].dbo.DimClientes;


------------------------------------------------------------------
---------------------- 5. QUERY FINAL -----------------------------
------------------------------------------------------------------

--CONTEO
SELECT COUNT(DISTINCT(CLI.ID_CLIENTE)) AS  Clientes_Unicos
FROM [09_TransaccionesVF].dbo.FactTransacciones AS Trans
JOIN [09_TransaccionesVF].dbo.DimComercios AS CO
ON TRANS.ID_COMERCIO = CO.ID_COMERCIO
JOIN [09_TransaccionesVF].dbo.DimClientes AS CLI
ON  Trans.ID_Cuenta = CLI.ID_Cuenta
WHERE 
Trans.Fecha_Compra >= '2024-09-01' 
AND Trans.Fecha_Compra < '2024-10-01' --compras durante el mes de septiembre 2024 -- Se utiliza rango semiabierto para evitar problemas
-- con timestamps y mejorar performance frente a MONTH()
AND CO.Tipo_Comercio = 'Restaurante' --compras en comercios del tipo “Restaurantes”
AND CLI.Status_Cliente = 'Activo' --Clientes Activos
AND CLI.Fecha_Nacimiento BETWEEN '1986-01-09' AND '1996-01-09' --Clientes en rango etario entre 30 y 40 anios

