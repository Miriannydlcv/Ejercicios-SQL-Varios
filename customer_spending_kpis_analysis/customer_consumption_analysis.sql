-----------------------------------------------------------------------
-----------------------KPIS-----------------------------------------
--------------------------------------------------------------------

------------BASE
CREATE TABLE E2.dbo.BaseConsumo_O1 (
    Mes DATE,
    ID_Cliente INT,
    Segmento_Actual VARCHAR(50),
    Tipo_Comercio VARCHAR(50),
    ID_Transaccion INT,
    Fecha_Compra DATE,
    Monto_RD NUMERIC(12,2)
);



INSERT INTO E2.dbo.BaseConsumo_O1 (
    Mes,
    ID_Cliente,
    Segmento_Actual,
    Tipo_Comercio,
    ID_Transaccion,
    Fecha_Compra,
    Monto_RD
)
    SELECT
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



SELECT *
FROM BaseConsumo_O1;


----KPI 1: Clientes activos (mes, segmento, tipo)
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(DISTINCT ID_Cliente) AS Clientes_Activos
FROM BaseConsumo_O1
GROUP BY Mes, Segmento_Actual, Tipo_Comercio
ORDER BY Mes;


---KPI 2: Transacciones totales
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(ID_Transaccion) AS Transacciones_Totales
FROM E2.dbo.BaseConsumo_O1 
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


---KPI 3: Frecuencia promedio
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(ID_Transaccion) * 1.0 / COUNT(DISTINCT ID_Cliente) AS Frecuencia_Promedio
FROM E2.dbo.BaseConsumo_O1 
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


---KPI 4: Ticket promedio
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    SUM(Monto_RD) / COUNT(*) AS Ticket_Promedio
FROM E2.dbo.BaseConsumo_O1 
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


---KPI 5: Participación por tipo de comercio

----Cantidad de transacciones
SELECT
    Mes,
    Segmento_Actual,
    Tipo_Comercio,
    COUNT(*) * 1.0 /
        SUM(COUNT(*)) OVER (PARTITION BY Mes, Segmento_Actual) 
        AS Participacion_Tipo
FROM E2.dbo.BaseConsumo_O1
GROUP BY Mes, Segmento_Actual, Tipo_Comercio;


-----------------------------------------------------------------------
-----------------------DQC-----------------------------------------
--------------------------------------------------------------------



-------------Regla 1: Fechas fuera de rango (ene–jun 2023)-----
--------------------------------------------------------------------

SELECT COUNT(*) AS Incidencias
FROM E2.dbo.E2_Transacciones
WHERE Fecha_Compra < '2023-01-01'
   OR Fecha_Compra >= '2023-07-01';

-------------Regla 2: Montos ≤ 0--------------------------
--------------------------------------------------------------------

SELECT COUNT(*) AS Incidencias
FROM E2.dbo.E2_Transacciones
WHERE Monto_RD <= 0;


-------------Regla 3: Clientes inactivos con transacciones
--------------------------------------------------------------------
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

----------Hacer campo edad
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

-----------------------------------------------------------------------
-----------------------R/F/T-----------------------------------------
--------------------------------------------------------------------


-------------------------------------------------------------
-------------RECENCIA, FRECUENCIA Y TICKET POR SEGMENTO----------------------------------------

WITH rft_cliente AS (
    SELECT
        c.ID_CLIENTE,
        s.SEGMENTO_ACTUAL,
        DATEDIFF(DAY, MAX(t.FECHA_COMPRA), '2023-06-30') AS Recencia,
        COUNT(*) AS Frecuencia,
        ROUND(SUM(t.MONTO_RD) / COUNT(*), 2) AS Ticket_Promedio
    FROM E2.dbo.E2_Transacciones t
    JOIN E2.dbo.E2_Clientes c ON t.ID_CUENTA = c.ID_CUENTA
    JOIN E2.dbo.E2_Segmentos s ON c.ID_CLIENTE = s.ID_CLIENTE
    WHERE t.FECHA_COMPRA BETWEEN '2023-01-01' AND '2023-06-30'
    GROUP BY c.ID_CLIENTE, s.SEGMENTO_ACTUAL
)

SELECT * FROM rft_cliente;







