/*
Análisis de consumo y comportamiento transaccional.

Objetivo:
Analizar consumo entre enero-junio 2023
para construir KPIs, validar calidad de datos
y segmentar clientes mediante métricas R/F/T.

Resultados:
Los outputs finales fueron exportados a Excel
y los resultados fueron plasmados en una ppt para visualización, storytelling y análisis ejecutivo.
*/



-------------------------------------------------------------------
----------------------- BASE ANALÍTICA -----------------------------
-------------------------------------------------------------------

/*
Creación de tabla analítica consolidada.

La tabla centraliza:
- información transaccional,
- segmentación de clientes,
- tipología de comercios,
- y métricas base para análisis posterior.

Esto para:
- evitar joins repetitivos,
- simplificar cálculos,
- y optimizar consultas.
*/


CREATE TABLE [11_E2].dbo.BaseConsumo_O1 (
    Mes DATE,
    ID_Cliente INT,
    Segmento_Actual VARCHAR(50),
    Tipo_Comercio VARCHAR(50),
    ID_Transaccion INT,
    Fecha_Compra DATE,
    Monto_RD NUMERIC(12,2)
);


/*
Construcción de la base analítica.

Se integran:
- transacciones,
- clientes,
- segmentos,
- y comercios.

Filtros aplicados:
- período ene-jun 2023
- únicamente clientes activos
*/


INSERT INTO [11_E2].dbo.BaseConsumo_O1 (
    Mes,
    ID_Cliente,
    Segmento_Actual,
    Tipo_Comercio,
    ID_Transaccion,
    Fecha_Compra,
    Monto_RD
)
    SELECT
	 -- Normalización temporal al primer día del mes
     -- para facilitar agregaciones mensuales
		DATEFROMPARTS(YEAR(T.Fecha_Compra), MONTH(T.Fecha_Compra), 1) AS Mes,
        CLI.ID_Cliente,
		S.Segmento_Actual,
        C.Tipo_Comercio,
        T.ID_Transaccion,
		T.Fecha_Compra,
        T.Monto_RD
    FROM E2_Transacciones T
    JOIN E2.dbo.E2_Clientes CLI
        ON T.ID_Cuenta = CLI.ID_Cuenta
    JOIN E2.dbo.E2_Segmentos S
        ON CLI.ID_Cliente = S.ID_Cliente
    JOIN E2.dbo.E2_Comercios C
        ON T.ID_Comercio = C.ID_Comercio
    WHERE 
        T.Fecha_Compra >= '2023-01-01'
        AND T.Fecha_Compra < '2023-07-01'
        AND CLI.Status_Cliente = 'Activo';


-- Validación rápida de la base analítica construida
SELECT *
FROM BaseConsumo_O1;


-----------------------------------------------------------------------
-----------------------KPIS-----------------------------------------
--------------------------------------------------------------------


--- KPI 1:
--- Cantidad de clientes únicos con al menos una transacción por mes, segmento y tipo de comercio
--- Se filtran únicamente clientes activos y transacciones dentro del período ene-jun 2023
--- Un cliente activo es aquel con al menos una transacción en el mes

SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(DISTINCT ID_Cliente) AS Clientes_Activos
FROM BaseConsumo_O1
GROUP BY Mes, Segmento_Actual, Tipo_Comercio
ORDER BY Mes;


---KPI 2: Transacciones totales
-- Cantidad total de transacciones registradas
-- por mes, segmento y tipo de comercio

SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(ID_Transaccion) AS Transacciones_Totales
FROM [11_E2].dbo.BaseConsumo_O1 
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


---KPI 3: Frecuencia promedio, cantidad promedio de transacciones realizadas por cliente activo.
-- Frecuencia promedio: cantidad total de transacciones / clientes únicos
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(ID_Transaccion) * 1.0 / COUNT(DISTINCT ID_Cliente) AS Frecuencia_Promedio
FROM [11_E2].dbo.BaseConsumo_O1 
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


---KPI 4: Ticket promedio: monto promedio consumido por transacción.
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    SUM(Monto_RD) / COUNT(*) AS Ticket_Promedio
FROM [11_E2].dbo.BaseConsumo_O1 
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


---KPI 5: Participación por tipo de comercio, peso relativo de cada categoría sobre el total transaccional del segmento en cada mes.

----Cantidad de transacciones
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(*) * 1.0 /
        SUM(COUNT(*)) OVER (PARTITION BY Mes, Segmento_Actual) 
        AS Participacion_Tipo
FROM [11_E2].dbo.BaseConsumo_O1
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


---------------------------

SELECT
    Mes,
    Tipo_Comercio,
    COUNT(*) * 1.0 /
        SUM(COUNT(*)) OVER (PARTITION BY Tipo_Comercio) 
        AS Participacion_comercio
FROM [11_E2].dbo.BaseConsumo_O1
GROUP BY Mes, Tipo_Comercio;




-----------------------------------------------------------------------
-----------------------DQC-----------------------------------------
--------------------------------------------------------------------

/*
DQC - Data Quality Checks

Validaciones aplicadas para identificar:
- inconsistencias,
- registros inválidos,
- relaciones incompletas,
- y anomalías operativas.
*/


-------------Regla 1: Fechas fuera de rango (ene–jun 2023)-----
--------------------------------------------------------------------

SELECT COUNT(*) AS Incidencias
FROM E2.dbo.E2_Transacciones
WHERE Fecha_Compra < '2023-01-01'
   OR Fecha_Compra >= '2023-07-01';

-------------Regla 2: Montos montos inválidos o inconsistentes (monto ≤ 0)--------------------------
--------------------------------------------------------------------

SELECT COUNT(*) AS Incidencias
FROM E2.dbo.E2_Transacciones
WHERE Monto_RD <= 0;


-------------Regla 3: Clientes inactivos con transacciones
--------------------------------------------------------------------

/*
Clientes marcados como inactivos
que continúan registrando transacciones.

Posible indicador de:
- problemas operativos,
- errores de actualización,
- o inconsistencias de negocio.
*/

SELECT DISTINCT(ID_CLIENTE) AS Incidencias, MAX(T.fECHA_COMPRA) AS ULtimafecha
FROM E2.dbo.E2_Transacciones AS T
JOIN E2.dbo.E2_Clientes C
ON T.ID_CUENTA = C.ID_CUENTA
WHERE 
C.status_cliente = 'Inactivo'
AND T.FECHA_COMPRA >= '2023-01-01'
AND T.FECHA_COMPRA <  '2023-07-01'
group by ID_CLIENTE
order by ULtimafecha desc 


----para calcular % sobre total, Clientes únicos con ≥1 transacción en ene–jun 2023 (independientemente de su status)
-- Base utilizada para calcular porcentaje de incidencias
SELECT COUNT(DISTINCT C.ID_CLIENTE) AS Total_Clientes_Con_Transacciones
FROM E2.dbo.E2_Transacciones T
JOIN E2.dbo.E2_Clientes C
    ON T.ID_CUENTA = C.ID_CUENTA
WHERE T.FECHA_COMPRA >= '2023-01-01'
  AND T.FECHA_COMPRA <  '2023-07-01';



-------------Claves huérfanas (clientes sin segmento)--------------------------
--------------------------------------------------------------------
SELECT COUNT(*) AS Incidencias
FROM E2.dbo.E2_Clientes C
LEFT JOIN E2.dbo.E2_Segmentos S
    ON C.ID_Cliente = S.ID_Cliente
WHERE S.ID_Cliente IS NULL;


-------------cuentas huérfanas en transacciones--------------------------
--------------------------------------------------------------------
SELECT 
    COUNT(*) AS Incidencias
FROM E2.dbo.E2_Transacciones t
LEFT JOIN E2.dbo.E2_Clientes c
    ON t.ID_Cuenta = c.ID_Cuenta
WHERE c.ID_Cuenta IS NULL;



-------------Regla 4: Edades imposibles (<18 o >80)
--------------------------------------------------------------------

/*
Creación de variable derivada:
Edad del cliente al cierre del período analizado.
*/
ALTER TABLE E2.dbo.E2_Clientes
ADD Edad INT;

UPDATE E2.dbo.E2_Clientes
SET Edad =
    DATEDIFF(YEAR, Fecha_Nacimiento, '2023-06-30')
    - CASE 
        WHEN DATEADD(YEAR, DATEDIFF(YEAR, Fecha_Nacimiento, '2023-06-30'), Fecha_Nacimiento) > '2023-06-30'
        THEN 1 
        ELSE 0 
      END;

select *
FROM E2.dbo.E2_Clientes
order by edad 

-------------Edades imposibles
--------------------------------------------------------------------
/*
Validación de edades fuera de parámetros razonables.

Rango esperado:
18 a 80 años.
*/

SELECT COUNT(*) AS Incidencias
FROM E2.dbo.E2_Clientes
WHERE Edad < 18
   OR Edad > 80
   OR Edad IS NULL;




SELECT COUNT(*) AS Incidencias
FROM E2.dbo.E2_Transacciones AS T
JOIN E2.dbo.E2_Clientes C
ON T.ID_CUENTA = C.ID_CUENTA
WHERE 
C.status_cliente = 'Inactivo'
AND T.Fecha_Compra >= '2023-06-01'
AND T.Fecha_Compra < '2023-06-31';


--------------------------------------------------------------------
-- Regla DQC: Validar cuentas asignadas a más de un cliente
-- Una misma cuenta no debería pertenecer a múltiples clientes
--------------------------------------------------------------------

SELECT
    ID_Cuenta,
    COUNT(DISTINCT ID_Cliente) AS Cantidad_Clientes
FROM [11_E2].dbo.E2_Clientes
GROUP BY ID_Cuenta
HAVING COUNT(DISTINCT ID_Cliente) > 1;


--------------------------------------------------------------------
-- Regla DQC: Validar transacciones asociadas a múltiples cuentas
-- Una misma transacción no debería estar vinculada
-- a más de una cuenta
--------------------------------------------------------------------

SELECT
    ID_Transaccion,
    COUNT(DISTINCT ID_Cuenta) AS Cantidad_Cuentas
FROM [11_E2].dbo.E2_Transacciones
GROUP BY ID_Transaccion
HAVING COUNT(DISTINCT ID_Cuenta) > 1;



-----------------------------------------------------------------------
-----------------------R/F/T-----------------------------------------
--------------------------------------------------------------------

/*
R/F/T:
- Recencia
- Frecuencia
- Ticket promedio

Métricas utilizadas para segmentación
y análisis de comportamiento de clientes.
*/

-- CTE para consolidar métricas R/F/T por cliente

WITH rft_cliente AS (
    SELECT
        c.ID_CLIENTE,
        s.SEGMENTO_ACTUAL,
        DATEDIFF(DAY, MAX(t.FECHA_COMPRA), '2023-06-30') AS Recencia,-- Días desde última compra hasta 2023-06-30
        COUNT(*) AS Frecuencia,
        ROUND(SUM(t.MONTO_RD) / COUNT(*), 2) AS Ticket_Promedio
    FROM E2.dbo.E2_Transacciones t
    JOIN E2.dbo.E2_Clientes c ON t.ID_CUENTA = c.ID_CUENTA
    JOIN E2.dbo.E2_Segmentos s ON c.ID_CLIENTE = s.ID_CLIENTE
    WHERE t.FECHA_COMPRA BETWEEN '2023-01-01' AND '2023-06-30'
    GROUP BY c.ID_CLIENTE, s.SEGMENTO_ACTUAL
)

SELECT * FROM rft_cliente; -- Resultado final de métricas R/F/T







