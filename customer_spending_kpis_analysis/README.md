## Customer Spending KPIs Analysis – SQL + Excel

#### Objetivo

Analizar el consumo de clientes entre enero y junio 2023 para:

- entender el comportamiento de segmentos y tipo de comercio,
- detectar anomalías operativas,
- construir KPIs de negocio,

El ejercicio fue desarrollado a partir de una estructura de datos dada.

---

### Contexto del ejercicio

El ejercicio parte de un dataset transaccional con información de:

clientes,
transacciones,
segmentos,
y comercios.

El análisis incluye:

KPIs mensuales,
controles de calidad de datos (DQC),
métricas R/F/T,
análisis de comportamiento,
e insights accionables con recomendaciones.

---

### Solución

Para resolver el ejercicio se construyó una tabla consolidada mediante:

- joins entre tablas transaccionales y dimensiones,
- filtrado temporal,
- cálculos agregados,
- window functions,
- y segmentación de clientes.

Posteriormente:

- los KPIs fueron exportados a Excel,
- y los resultados finales presentados en PowerPoint.

---

### Principales insights

- Restaurantes mostró crecimiento transversal en todos los segmentos.
- Supermercados mantuvo liderazgo en volumen, pero perdió participación relativa.
- Electrónica presentó mayor crecimiento en valor transaccional.
- El segmento Masivo concentró el mayor impacto operativo y comercial.

Los insights completos se encuentran en la presentación.


---

### Herramientas utilizadas

- SQL Server
- Excel
- PowerPoint

---

### Estructura del proyecto

customer_spending_kpis_analysis/  
│  
├── README.md  
│  
├── business_question/  
│   └── business_requirements.xlsx    
│      # Objetivos, entregables y definiciones del ejercicio  
│  
├── sql/  
│   └── customer_consumption_analysis.sql  
│       # Construcción de base analítica, KPIs, DQC y R/F/T  
│   
├──excel/  
│ └──customer_consumption_kpis.xlsx    
│      # KPIs, tablas dinámicas y outputs numéricos  
│  
├──presentación/  
│ └──customer_consumption_storytelling.pptx  
│ # Storytelling, insights y recomendaciones    
│   
│ └── customer_consumption_storytelling.pdf    
│ # ppt en formato pdf    
│   
├── outputs_imágenes/       
│  ├──DQC/   
│    └── dqc_summary.png   # Evidencia de resultados DQC    
│ ├──Queries # capturas de consultas ejecutadas    
│ └──Gráficos # gráficos utilizados    

---

#### Nota

La información utilizada fue creada con fines educativos y de práctica analítica.  
No representa datos reales de clientes o empresas.




