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
FROM [11_E2].dbo.E2_Transacciones
WHERE Fecha_Compra < '2023-01-01'
   OR Fecha_Compra >= '2023-07-01';

--------------- Regla 2: Montos inválidos (≤0)--------------------------
--------------------------------------------------------------------

SELECT COUNT(*) AS Incidencias
FROM [11_E2].dbo.E2_Transacciones
WHERE Monto_RD <= 0;


-------------Regla 3: Clientes inactivos con actividad transaccional
--cantidad (#) clientes afectados
--------------------------------------------------------------------

/*
Clientes marcados como inactivos
que continúan registrando transacciones.
*/

SELECT 
    COUNT(DISTINCT CLI.ID_CLIENTE) AS Incidencias
FROM [11_E2].dbo.E2_Transacciones AS Trans
JOIN [11_E2].dbo.E2_Clientes AS CLI
    ON Trans.ID_Cuenta = CLI.ID_Cuenta
WHERE Trans.Fecha_Compra >= '2023-01-01'
    AND Trans.Fecha_Compra < '2023-07-01'
    AND CLI.Status_Cliente = 'Inactivo'


----para calcular % sobre total, Clientes únicos con ≥1 transacción en ene–jun 2023 (independientemente de su status)
-- Base utilizada para calcular porcentaje de incidencias
SELECT COUNT(DISTINCT C.ID_CLIENTE) AS Total_Clientes_Con_Transacciones
FROM [11_E2].dbo.E2_Transacciones T
JOIN [11_E2].dbo.E2_Clientes C
    ON T.ID_CUENTA = C.ID_CUENTA
WHERE T.FECHA_COMPRA >= '2023-01-01'
  AND T.FECHA_COMPRA <  '2023-07-01';



-----------Regla 4: Transacciones originadas por clientes inactivos
--cantidad (#) transacciones (incidencias)
--------------------------------------------------------------------

SELECT COUNT(*) AS Incidencias
FROM [11_E2].dbo.E2_Transacciones AS T
JOIN [11_E2].dbo.E2_Clientes C
ON T.ID_CUENTA = C.ID_CUENTA
WHERE 
C.status_cliente = 'Inactivo'
AND T.Fecha_Compra >= '2023-01-01'
AND T.Fecha_Compra < '2023-07-01';


----para calcular % sobre total, Transacciones únicas en ene–jun 2023 (independientemente del status del cliente que provienen las transacciones)
-- Base utilizada para calcular porcentaje de incidencias
SELECT COUNT(*) AS Total_Transacciones
FROM [11_E2].dbo.E2_Transacciones T
WHERE T.Fecha_Compra >= '2023-01-01'
  AND T.Fecha_Compra < '2023-07-01';


-------------Regla 5: Edades imposibles (<18 o >80)
--clientes con edades imposibles
--------------------------------------------------------------------

SELECT
    COUNT(DISTINCT CLI.ID_CLIENTE) AS Incidencias
FROM [11_E2].dbo.E2_Transacciones AS Trans
JOIN [11_E2].dbo.E2_Clientes AS CLI
    ON Trans.ID_Cuenta = CLI.ID_Cuenta
WHERE
Trans.Fecha_Compra >= '2023-01-01'
AND Trans.Fecha_Compra < '2023-07-01'
AND
(
    DATEDIFF(YEAR, CLI.Fecha_Nacimiento, Trans.Fecha_Compra)
    - CASE
        WHEN DATEADD(
            YEAR,
            DATEDIFF(YEAR, CLI.Fecha_Nacimiento, Trans.Fecha_Compra),
            CLI.Fecha_Nacimiento
        ) > Trans.Fecha_Compra
        THEN 1
        ELSE 0
    END < 18

    OR

    DATEDIFF(YEAR, CLI.Fecha_Nacimiento, Trans.Fecha_Compra)
    - CASE
        WHEN DATEADD(
            YEAR,
            DATEDIFF(YEAR, CLI.Fecha_Nacimiento, Trans.Fecha_Compra),
            CLI.Fecha_Nacimiento
        ) > Trans.Fecha_Compra
        THEN 1
        ELSE 0
    END > 80
)



----para calcular % sobre total, Clientes únicos en ene–jun 2023 (independientemente de la edad del cliente al momento de la transacción)
-- Base utilizada para calcular porcentaje de incidencias
SELECT COUNT(DISTINCT C.ID_CLIENTE) AS Total_Clientes
FROM [11_E2].dbo.E2_Transacciones T
JOIN [11_E2].dbo.E2_Clientes C
ON T.ID_CUENTA = C.ID_CUENTA
WHERE T.Fecha_Compra >= '2023-01-01'
AND T.Fecha_Compra < '2023-07-01';



/*
Análisis de consumo y comportamiento transaccional.

Objetivo:
Analizar consumo entre enero-junio 2023
para construir KPIs, validar calidad de datos
y segmentar clientes mediante métricas R/F/T.

Resultados:
Los outputs finales fueron exportados a Excel
y los resultados fueron plasmados en una ppt para visualización y storytelling .
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

--Basado en las anomalías detectadas en la sección DQC hacemos las correciones de lugar
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
    DATEFROMPARTS(
        YEAR(T.Fecha_Compra),
        MONTH(T.Fecha_Compra),
        1
    ) AS Mes,

    CLI.ID_Cliente,
    S.Segmento_Actual,
    C.Tipo_Comercio,
    T.ID_Transaccion,
    T.Fecha_Compra,
    T.Monto_RD

FROM [11_E2].dbo.E2_Transacciones T

JOIN [11_E2].dbo.E2_Clientes CLI
    ON T.ID_Cuenta = CLI.ID_Cuenta

JOIN [11_E2].dbo.E2_Segmentos S
    ON CLI.ID_Cliente = S.ID_Cliente

JOIN [11_E2].dbo.E2_Comercios C
    ON T.ID_Comercio = C.ID_Comercio

WHERE
    -- Período análisis
    T.Fecha_Compra >= '2023-01-01'
    AND T.Fecha_Compra < '2023-07-01'

    -- Monto válido
    AND T.Monto_RD > 0

    -- Edad válida al momento de la transacción
    AND (
        DATEDIFF(
            YEAR,
            CLI.Fecha_Nacimiento,
            T.Fecha_Compra
        )
        - CASE
            WHEN DATEADD(
                YEAR,
                DATEDIFF(
                    YEAR,
                    CLI.Fecha_Nacimiento,
                    T.Fecha_Compra
                ),
                CLI.Fecha_Nacimiento
            ) > T.Fecha_Compra
            THEN 1
            ELSE 0
          END
    ) BETWEEN 18 AND 80;




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


--Monto total por segmento-comercio
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    SUM(Monto_RD) Monto_total
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




-----------------------------------------------------------------------
-----------------------R/F/T-------------------------------------------
--------------------------------------------------------------------

/*
R/F/T:
- Recencia
- Frecuencia
- Ticket promedio

Calculado sobre la tabla analítica limpia
(BaseConsumo_O1), luego de aplicar DQC.
*/

-- CTE para consolidar métricas R/F/T por cliente

WITH rft_cliente AS (

    SELECT
        B.ID_Cliente,
        B.Segmento_Actual,

        -- Días desde la última compra hasta 30-jun-2023
        DATEDIFF(
            DAY,
            MAX(B.Fecha_Compra),
            '2023-06-30'
        ) AS Recencia,

        -- Número total de transacciones
        COUNT(*) AS Frecuencia,

        -- Ticket promedio
        ROUND(AVG(B.Monto_RD), 2) AS Ticket_Promedio

    FROM [11_E2].dbo.BaseConsumo_O1 B

    GROUP BY
        B.ID_Cliente,
        B.Segmento_Actual
)

SELECT *
FROM rft_cliente
ORDER BY Frecuencia DESC; -- Resultado final de métricas R/F/T



-----------------------------------------------------------------------
-----------------------R/F/T POR SEGMENTO-----------------------------
--------------------------------------------------------------------

/*
R/F/T por segmento:

- Recencia:
  Promedio de días desde la última compra del cliente
  hasta 2023-06-30.

- Frecuencia:
  Promedio de transacciones por cliente
  durante ene-jun 2023.

- Ticket promedio:
  Promedio del ticket promedio de los clientes.
*/

WITH rft_cliente AS (

    SELECT
        B.ID_Cliente,
        B.Segmento_Actual,

        -- Días desde última compra
        DATEDIFF(
            DAY,
            MAX(B.Fecha_Compra),
            '2023-06-30'
        ) AS Recencia,

        -- Número de transacciones del cliente
        COUNT(*) AS Frecuencia,

        -- Ticket promedio del cliente
        ROUND(AVG(B.Monto_RD), 2) AS Ticket_Promedio

    FROM [11_E2].dbo.BaseConsumo_O1 B

    GROUP BY
        B.ID_Cliente,
        B.Segmento_Actual
)

SELECT
    Segmento_Actual,

    -- Recencia promedio del segmento
    ROUND(AVG(Recencia), 2) AS Recencia_Promedio,

    -- Frecuencia promedio del segmento
    ROUND(AVG(Frecuencia), 2) AS Frecuencia_Promedio,

    -- Ticket promedio del segmento
    ROUND(AVG(Ticket_Promedio), 2) AS Ticket_Promedio,

    -- Cantidad de clientes del segmento
    COUNT(ID_Cliente) AS Clientes

FROM rft_cliente

GROUP BY Segmento_Actual

ORDER BY Ticket_Promedio DESC;









---OTROS---------------------------------
--Otras verificaciones

---Validar si salen un comercio está asociados a más de un 'idcomercio' en la tabla de comercios
--------------------------------------------------------------------

SELECT DISTINCT(nombre_comercio), count(distinct(id_Comercio)) AS recuento__ids_asociados
FROM [11_E2].dbo.E2_Comercios
GROUP BY NOMBRE_COMERCIO
ORDER BY recuento__ids_asociados desc


---- Validar si salen clientes en más de un 'status_clientes' 'idcliente' vinculados a más de un 'status_clientes' en la tabla de segmentos
--------------------------------------------------------------------
SELECT DISTINCT(ID_CLIENTE), count(distinct(STATUS_CLIENTE)) AS recuento__status_asociados
FROM [11_E2].dbo.E2_Segmentos
GROUP BY ID_CLIENTE
ORDER BY recuento__status_asociados desc


---Validar si salen clientes asociados a más de un segmento actual 'idcliente' vinculados a más de un 'segmento_actual' en la tabla de segmentos
-- un cliente no debería salir vinculado a más de un segmento
--------------------------------------------------------------------
SELECT DISTINCT(ID_CLIENTE), count(distinct(SEGMENTO_ACTUAL)) AS recuento__segmentos_asociados
FROM [11_E2].dbo.E2_Segmentos
GROUP BY ID_CLIENTE
ORDER BY recuento__segmentos_asociados desc


---Validar clientes repetidos 'idcliente' en la tabla de clientes
-- un cliente no debería salir más de una vez en la tabla de cliente (primary key)
--------------------------------------------------------------------
SELECT DISTINCT(ID_CLIENTE), count(distinct(ID_CLIENTE)) AS recuento__ids_repetidos
FROM [11_E2].dbo.E2_Clientes
GROUP BY ID_CLIENTE
ORDER BY recuento__ids_repetidos desc


----Validar cuentas asignadas a más de un cliente
-- Una misma cuenta no debería pertenecer a múltiples clientes
--------------------------------------------------------------------
SELECT
    ID_Cuenta,
    COUNT(DISTINCT ID_Cliente) AS Cantidad_Clientes
FROM [11_E2].dbo.E2_Clientes
GROUP BY ID_Cuenta
HAVING COUNT(DISTINCT ID_Cliente) > 1;


--- Validar transacciones asociadas a múltiples cuentas
-- Una misma transacción no debería estar vinculada a más de una cuenta
--------------------------------------------------------------------
SELECT
    ID_Transaccion,
    COUNT(DISTINCT ID_Cuenta) AS Cantidad_Cuentas
FROM [11_E2].dbo.E2_Transacciones
GROUP BY ID_Transaccion
HAVING COUNT(DISTINCT ID_Cuenta) > 1;


-----Validar transacciones asociadas a un mismo 'idtransaccion'
-- más de una transacción no debería estar vinculada a un mismo 'idtransaccion'
--------------------------------------------------------------------
SELECT DISTINCT(ID_TRANSACCION), count(distinct(ID_TRANSACCION)) AS recuento__ids_repetidos
FROM [11_E2].dbo.E2_Transacciones
GROUP BY ID_TRANSACCION
ORDER BY recuento__ids_repetidos desc

-------------Claves huérfanas (clientes sin segmento)--------------------------
--------------------------------------------------------------------
SELECT COUNT(*) AS Incidencias
FROM [11_E2].dbo.E2_Clientes C
LEFT JOIN [11_E2].dbo.E2_Segmentos S
    ON C.ID_Cliente = S.ID_Cliente
WHERE S.ID_Cliente IS NULL;


-------------cuentas huérfanas en transacciones--------------------------
--------------------------------------------------------------------
SELECT 
    COUNT(*) AS Incidencias
FROM [11_E2].dbo.E2_Transacciones t
LEFT JOIN [11_E2].dbo.E2_Clientes c
    ON t.ID_Cuenta = c.ID_Cuenta
WHERE c.ID_Cuenta IS NULL;



