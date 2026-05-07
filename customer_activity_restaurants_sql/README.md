# Customer Activity in Restaurants – SQL Analysis

## Objetivo

Resolver la siguiente pregunta de negocio:

> ¿Cuántos clientes únicos activos, entre 30 y 40 años, realizaron compras durante septiembre 2024 en comercios del tipo "Restaurante"?

El ejercicio fue desarrollado a partir de una estructura de tablas dada.

---

# Contexto del ejercicio

La estructura original planteaba tres tablas:

- CLIENTES
- TRANSACCIONES
- COMERCIO

con relaciones entre clientes, cuentas y transacciones.

A partir de esta estructura:
- se modeló una versión dimensional simplificada,
- se generaron datos dummy,
- y se construyó el query final para responder la pregunta de negocio.


# Estructura original del ejercicio

## Tabla: CLIENTES
- ID_Cliente
- ID_CUENTA
- Fecha_Nacimiento
- Sexo
- Status_Cliente

## Tabla: COMERCIO
- ID_COMERCIO 
- Nombre_Comercio
- Tipo_Comercio

## Tabla: TRANSACCIONES
- ID_Cuenta
- ID_TRANSACCION
- Fecha_Compra
- MontoRD
- ID_Comercio

Consideración importante:

> En la tabla de transacciones los clientes se duplican, debido a la cantidad de transacciones realizadas.

---

# Solución 

Para resolver el ejercicio se construyó un modelo dimensional básico compuesto por:

## Dimensiones
- DimClientes
- DimComercios

## Tabla de hechos
- FactTransacciones

El modelo permite:
- relacionar clientes y comercios,
- registrar múltiples transacciones por cliente,
- y realizar consultas analíticas de forma más eficiente.

---

# Query final

```sql
SELECT COUNT(DISTINCT(CLI.ID_CLIENTE)) AS Clientes_Unicos
FROM FactTransacciones AS Trans
JOIN DimComercios AS CO
    ON TRANS.ID_COMERCIO = CO.ID_COMERCIO
JOIN DimClientes AS CLI
    ON Trans.ID_Cuenta = CLI.ID_Cuenta
WHERE 
    Trans.Fecha_Compra >= '2024-09-01'
    AND Trans.Fecha_Compra < '2024-10-01'
    AND CO.Tipo_Comercio = 'Restaurante'
    AND CLI.Status_Cliente = 'Activo'
    AND CLI.Fecha_Nacimiento 
        BETWEEN '1986-01-09' AND '1996-01-09';
```

---

# Lógica aplicada

El análisis:

- filtra compras realizadas en septiembre 2024
- considera únicamente clientes activos
- filtra comercios tipo restaurante
- limita el análisis a clientes entre 30 y 40 años
- evita duplicados utilizando `COUNT(DISTINCT())`

Se utilizó un rango semiabierto de fechas:

```sql
Fecha_Compra >= '2024-09-01'
AND Fecha_Compra < '2024-10-01'
```
como buena práctica para filtros temporales.

---

# Estructura del proyecto

customer_activity_restaurants_sql/
│
├── README.md
│
├── business_question/
│   └── ejercicio_original.md
│       # Pregunta de negocio y estructura original de tablas
│
├── sql/
│   └── customer_activity_restaurants.sql
│       # Modelado, generación de datos dummy y query final
│
├── diagrams/
│   └── modelo_dimensional.png
│       # Modelo relacional simplificado
│
└── outputs/
    ├── resultado_query.png
        # Captura del query ejecutado en SQL Server

---

# Herramientas utilizadas
- SQL Server

---

# Nota

La información utilizada fue creada con fines educativos y de práctica analítica.
No representa datos reales de clientes o empresas.





