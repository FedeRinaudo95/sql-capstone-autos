# Análisis de ventas de autos con PostgreSQL

Proyecto final de SQL — Análisis Exploratorio de Datos (EDA).

## 1. Contexto y problema de negocio

Autos Centro es una concesionaria ficticia que comercializa vehículos a particulares y empresas. La gerencia necesita conocer qué clientes concentran el gasto, cómo cambian las ventas mensuales, qué modelos tienen menor salida y qué marcas aportan más ganancia bruta.

El objetivo es convertir registros de pedidos en información útil para orientar acciones comerciales y revisar la oferta de vehículos. Todo el análisis corresponde a **datos simulados**, no a una empresa real ni al mercado automotor argentino.

## 2. Archivos del repositorio

| Archivo | Contenido |
| --- | --- |
| `estructura.sql` | Cinco tablas, 1.177 registros en total, auditoría, limpieza y vista de ventas válidas. |
| `analisis.sql` | Cinco consultas de negocio comentadas. |
| `README.md` | Contexto, modelo, reglas, resultados e instrucciones. |
| `verificacion_vendedores.sql` | Comprobación de los pedidos por vendedor y sucursal. |

El dataset está incluido mediante `INSERT` en `estructura.sql`. No requiere un CSV, conexión a internet, librerías adicionales ni archivos externos.

## 3. Dataset y modelo relacional

- Período: 1 de enero de 2024 a 31 de diciembre de 2025.
- 150 clientes ficticios: 20 empresas y 130 particulares.
- 18 modelos de 8 marcas, en cuatro segmentos: Hatchback, Sedán, SUV y Pickup.
- 1.000 pedidos; un pedido corresponde a un solo modelo, con una o más unidades.
- 3 sucursales: Córdoba, Rosario y Mendoza.
- 6 vendedores: dos por sucursal.
- Moneda: USD nominales ficticios. No se convierten pesos ni se usan cotizaciones reales.
- Los importes son pedagógicos; no representan listas de precios de las marcas.

La generación utilizó una semilla fija (260926); los resultados se distribuyen como inserciones explícitas y no cambian al volver a crear la base. Las empresas tienen mayor probabilidad de compra y pueden adquirir entre una y tres unidades; los particulares compran una unidad. Dos modelos se dejan sin ventas y uno tiene menor probabilidad para demostrar el análisis del catálogo completo. Estos supuestos condicionan los hallazgos.

### Tablas del proyecto

| Tabla | Registros |
| --- | ---: |
| `clientes` | 150 |
| `productos` | 18 |
| `pedidos` | 1.000 |
| `sucursales` | 3 |
| `vendedores` | 6 |
| **Total** | **1.177** |

La vista `ventas_validas` no es una tabla adicional: muestra los pedidos que cumplen los criterios del análisis.

### Relaciones

| Tabla principal | Tabla relacionada | Relación | Clave |
| --- | --- | --- | --- |
| `clientes` | `pedidos` | Uno a muchos | `id_cliente` |
| `productos` | `pedidos` | Uno a muchos | `id_producto` |
| `sucursales` | `vendedores` | Uno a muchos | `id_sucursal` |
| `vendedores` | `pedidos` | Uno a muchos | `id_vendedor` |

Cada tabla tiene una clave primaria. `pedidos` incorpora claves foráneas a `clientes`, `productos` y `vendedores`; `vendedores` incorpora una clave foránea a `sucursales`. Los datos del cliente y del modelo se almacenan una sola vez. El precio de venta y el costo se guardan por operación porque pueden variar en el tiempo. No se necesita una tabla de detalle bajo la regla de un modelo por pedido; para pedidos con varios modelos sería necesaria.

### Diccionario de datos

| Tabla | Campos y significado |
| --- | --- |
| `clientes` | `id_cliente`: identificador; `nombre`: etiqueta ficticia; `provincia`, `ciudad`: ubicación; `tipo_cliente`: Empresa o Particular. |
| `productos` | `id_producto`: identificador; `marca`, `modelo`: vehículo; `segmento`: categoría; `combustible`, `transmision`: características; `precio_referencia`: valor orientativo del catálogo. |
| `pedidos` | `id_pedido`: identificador; `id_cliente`, `id_producto`, `id_vendedor`: relaciones; `fecha_pedido`: fecha de operación; `fecha_comprobante`: respaldo de la misma fecha; `cantidad`: unidades; `precio_unitario`: precio antes del descuento; `precio_unitario_comprobante`: respaldo del precio; `costo_unitario`: adquisición; `descuento`: proporción entre 0 y 1; `canal`: Sucursal, Web o Telefónico; `estado`: Completado, Cancelado o Pendiente. |
| `sucursales` | `id_sucursal`: identificador; `nombre`: nombre de la sede; `ciudad`, `provincia`: ubicación. |
| `vendedores` | `id_vendedor`: identificador; `nombre`: nombre ficticio; `id_sucursal`: sucursal a la que pertenece. |
| `pedidos`, auditoría | `fecha_original_nula`, `precio_original_nulo`, `descuento_original_nulo`: indicadores de los campos que faltaban antes de limpiar. |

Se utilizan `DATE` para fechas, `NUMERIC` para importes y descuentos, `INTEGER` para claves y cantidades, y `BOOLEAN` para auditoría. Las restricciones evitan cantidades y precios no positivos, descuentos fuera de rango y relaciones inexistentes.

### Asignación de vendedores

La asignación es simulada y cíclica: se utiliza `((id_pedido - 1) % 6) + 1` para distribuir los 1.000 pedidos entre los seis vendedores. No representa diferencias reales de desempeño comercial.

| Vendedor | Sucursal | Pedidos asignados |
| --- | --- | ---: |
| Ana Pérez | Autos Centro Córdoba | 167 |
| Lucas Gómez | Autos Centro Córdoba | 167 |
| María López | Autos Centro Rosario | 167 |
| Diego Fernández | Autos Centro Rosario | 167 |
| Carla Torres | Autos Centro Mendoza | 166 |
| Martín Ruiz | Autos Centro Mendoza | 166 |
| **Total** | | **1.000** |

Estos recuentos incluyen todos los estados de pedido; las cinco preguntas de negocio usan solamente las 884 ventas válidas. Cada vendedor permanece en la misma sucursal durante el período analizado. La sucursal del pedido se obtiene a través de su vendedor; no se duplica ese dato en `pedidos`.

## 4. Limpieza y criterios del análisis

La auditoría inicial detecta 10 fechas, 15 precios y 25 descuentos nulos. Estos faltantes fueron introducidos intencionalmente con fines didácticos; algunos coinciden en una misma fila.

1. Se conserva una marca de los campos originalmente nulos.
2. `COALESCE(fecha_pedido, fecha_comprobante)` recupera la fecha solo si existe respaldo de esa misma operación.
3. `COALESCE(precio_unitario, precio_unitario_comprobante)` recupera el precio histórico. No se utiliza el precio actual del catálogo.
4. `COALESCE(descuento, 0)` aplica la regla explícita del sistema simulado: un descuento vacío significa que no se concedió descuento.
5. Los campos sin respaldo siguen en `NULL`; los registros se conservan para revisión y se excluyen del análisis mediante la vista `ventas_validas`.

Se recuperan 8 fechas y 12 precios. Permanecen 2 fechas y 3 precios desconocidos en cinco pedidos distintos. No se imputan fechas actuales ni precios cero.

| Clasificación posterior | Pedidos |
| --- | ---: |
| Completados con información suficiente | 884 |
| Cancelados o pendientes | 111 |
| Completados con fecha o precio sin respaldo | 5 |
| **Total cargado** | **1.000** |

Las cinco consultas de negocio usan la misma vista. La población analizada representa el 88,4 % de los pedidos cargados; hay 1.292 unidades vendidas. El catálogo completo se conserva para identificar modelos sin ventas. Los nulos en agregaciones de modelos sin operaciones se convierten a cero porque allí sí significan ausencia de ventas.

### Definición de métricas

- **Venta neta de descuento** = cantidad × precio unitario × (1 − descuento).
- **Costo total** = cantidad × costo unitario.
- **Ganancia bruta** = venta neta de descuento − costo total.
- **Margen bruto (%)** = ganancia bruta total / ventas totales × 100.
- **Gasto del cliente** = suma de ventas válidas asociadas al cliente.

Los importes se redondean a dos decimales por pedido. “Neta” se refiere exclusivamente al descuento comercial. No se modelan impuestos, devoluciones, financiación ni gastos operativos; la ganancia bruta no equivale a utilidad neta. La cantidad vendida se mide en unidades, no en pedidos. `NULLIF` protege el cálculo del margen ante ventas totales iguales a cero.

## 5. Preguntas y hallazgos

### 1. ¿Cuáles son los cinco clientes con mayor gasto total?

Técnicas: `JOIN`, `GROUP BY`, `SUM`, `COUNT`, ordenamiento y `LIMIT`.

| Cliente | Tipo | Pedidos | Unidades | Gasto (USD) |
| --- | --- | --- | --- | --- |
| Cliente ficticio 009 | Empresa | 23 | 51 | 1.505.980,20 |
| Cliente ficticio 018 | Empresa | 28 | 54 | 1.467.558,00 |
| Cliente ficticio 008 | Empresa | 24 | 53 | 1.443.990,60 |
| Cliente ficticio 012 | Empresa | 23 | 44 | 1.333.409,40 |
| Cliente ficticio 002 | Empresa | 24 | 45 | 1.332.965,40 |

El Cliente ficticio 009 lidera con USD 1.505.980,20. Los cinco principales clientes son empresas y concentran el **19,32 %** de la facturación válida. Para esta concesionaria simulada tendría sentido evaluar atención comercial para flotas y seguimiento de cuentas empresariales. El resultado es coherente con la generación, que asigna más compras y unidades a empresas; no demuestra que todos los mercados tengan ese comportamiento.

### 2. ¿Cómo evolucionan las ventas totales por mes?

Técnicas: CTE (`WITH`), `generate_series`, `DATE_TRUNC`, `LEFT JOIN` y agregaciones. El calendario garantiza 24 meses, incluso si alguno no tuviera ventas.

| Mes | Pedidos | Unidades | Ventas (USD) |
| --- | --- | --- | --- |
| 2024-01 | 39 | 53 | 1.391.102,40 |
| 2024-02 | 34 | 41 | 1.208.780,00 |
| 2024-03 | 32 | 49 | 1.415.035,40 |
| 2024-04 | 44 | 64 | 1.748.889,80 |
| 2024-05 | 40 | 56 | 1.602.125,00 |
| 2024-06 | 32 | 50 | 1.516.371,80 |
| 2024-07 | 32 | 52 | 1.567.692,20 |
| 2024-08 | 40 | 63 | 1.722.900,40 |
| 2024-09 | 30 | 38 | 1.019.029,60 |
| 2024-10 | 32 | 53 | 1.426.353,40 |
| 2024-11 | 42 | 62 | 1.740.282,00 |
| 2024-12 | 43 | 59 | 1.614.487,20 |
| 2025-01 | 34 | 44 | 1.196.059,00 |
| 2025-02 | 33 | 46 | 1.127.291,60 |
| 2025-03 | 43 | 54 | 1.530.946,80 |
| 2025-04 | 33 | 43 | 1.262.154,40 |
| 2025-05 | 38 | 56 | 1.807.842,40 |
| 2025-06 | 37 | 61 | 1.735.133,40 |
| 2025-07 | 43 | 62 | 1.892.891,00 |
| 2025-08 | 40 | 60 | 1.822.523,60 |
| 2025-09 | 28 | 41 | 963.838,80 |
| 2025-10 | 39 | 64 | 1.943.025,60 |
| 2025-11 | 45 | 76 | 2.072.007,20 |
| 2025-12 | 31 | 45 | 1.333.430,60 |

Noviembre de 2025 registra el mayor importe: **USD 2.072.007,20**, con 76 unidades. Septiembre de 2025 presenta el menor: **USD 963.838,80**, con 41 unidades. Las ventas pasan de USD 17.973.049,20 en 2024 a USD 18.687.144,40 en 2025, una variación de **3,97 %**.

Estos resultados permiten identificar meses para revisar. Dos años de datos simulados no bastan para afirmar una estacionalidad, ni atribuir cambios a campañas o a causas económicas. Antes de ajustar personal o stock, se necesitaría contrastar con más períodos e información comercial.

### 3. ¿Cuáles son los tres modelos menos vendidos?

Técnicas: `LEFT JOIN`, `COALESCE`, `SUM`, `GROUP BY` y `LIMIT`. En caso de empate se ordena también por el identificador del modelo para obtener tres filas reproducibles.

| Marca | Modelo | Unidades |
| --- | --- | --- |
| Nissan | Sentra | 0 |
| Nissan | X-Trail | 0 |
| Peugeot | 2008 | 9 |

Nissan Sentra y Nissan X-Trail no registran ventas válidas; Peugeot 2008 registra nueve unidades. Son candidatos para revisar disponibilidad, fecha de incorporación al catálogo y acciones comerciales. **No puede afirmarse que haya sobrestock o baja demanda** porque el dataset no contiene inventario ni períodos de disponibilidad. Los dos modelos sin ventas se incorporaron intencionalmente para comprobar el `LEFT JOIN`.

### 4. ¿Qué pedidos tienen los mayores importes dentro de cada segmento?

Técnicas: dos `JOIN`, CTE y `RANK() OVER (PARTITION BY ...)`. Se muestran posiciones hasta la tercera y se conservan empates.

| Segmento | Pedido | Modelo | Unidades | Importe (USD) | Posición |
| --- | --- | --- | --- | --- | --- |
| Hatchback | 312 | Volkswagen Polo | 3 | 71.677,20 | 1 |
| Hatchback | 493 | Volkswagen Polo | 3 | 71.677,20 | 1 |
| Hatchback | 315 | Peugeot 208 | 3 | 70.214,40 | 3 |
| Hatchback | 605 | Volkswagen Polo | 3 | 70.214,40 | 3 |
| Pickup | 679 | Volkswagen Amarok | 3 | 142.140,00 | 1 |
| Pickup | 458 | Ford Ranger | 3 | 139.050,00 | 2 |
| Pickup | 906 | Volkswagen Amarok | 3 | 137.503,20 | 3 |
| SUV | 724 | Ford Territory | 3 | 114.480,00 | 1 |
| SUV | 882 | Ford Territory | 3 | 109.900,80 | 2 |
| SUV | 195 | Ford Territory | 3 | 109.015,20 | 3 |
| Sedán | 302 | Toyota Corolla | 3 | 85.860,00 | 1 |
| Sedán | 629 | Toyota Corolla | 3 | 85.860,00 | 1 |
| Sedán | 676 | Toyota Corolla | 3 | 81.761,40 | 3 |

El pedido 679, de tres Volkswagen Amarok, alcanza **USD 142.140,00**, el mayor importe entre los líderes de segmento. Todos los pedidos mostrados corresponden a tres unidades, por lo que la cantidad comprada influye en la posición: el ranking no mide solamente el precio unitario ni la popularidad del modelo.

Hatchback tiene dos pedidos en posición 1 y dos en posición 3. `RANK()` asigna la misma posición a los empates y deja saltos; por eso el resultado puede superar tres filas por segmento.

### 5. ¿Qué marcas generan más ganancia bruta y qué margen tienen?

Técnicas: `JOIN`, agregaciones, operaciones numéricas, `ROUND` y `NULLIF`.

| Marca | Ventas (USD) | Ganancia bruta (USD) | Margen (%) |
| --- | --- | --- | --- |
| Toyota | 9.638.173,20 | 1.583.006,10 | 16,42 |
| Ford | 6.920.904,60 | 1.121.030,10 | 16,20 |
| Volkswagen | 6.688.026,80 | 1.051.929,80 | 15,73 |
| Chevrolet | 4.396.065,40 | 721.776,40 | 16,42 |
| Fiat | 3.963.456,20 | 605.240,50 | 15,27 |
| Renault | 2.875.512,80 | 446.677,60 | 15,53 |
| Peugeot | 2.178.054,60 | 356.994,80 | 16,39 |

Toyota lidera la ganancia bruta con **USD 1.583.006,10** y un margen de **16,42 %**. Ford ocupa el segundo lugar en ganancia absoluta. Toyota y Chevrolet muestran un margen de 16,42 % al redondear a dos decimales, aunque sus ganancias totales son distintas. Conviene evaluar juntos volumen, ganancia y margen al decidir acciones comerciales.

Nissan no aparece en esta consulta porque no tiene ventas válidas. Su margen es indefinido, no cero; los modelos sin ventas ya se incluyen en la pregunta 3.

## 6. Conclusión general

Los 884 pedidos válidos generan **USD 36.660.193,60** en ventas y **USD 5.886.655,30** de ganancia bruta. El análisis propone priorizar la revisión de cuentas empresariales, monitorear la evolución mensual, investigar modelos sin salida y evaluar marcas por ganancia y margen.

La limpieza evita que pedidos incompletos o no finalizados alteren las métricas. Las recomendaciones son hipótesis de gestión para el caso simulado; no constituyen conclusiones sobre ventas reales de vehículos. Para ampliar el proyecto se podrían incorporar inventario, devoluciones, gastos, fechas de alta de modelos y campañas comerciales.

## 7. Cómo ejecutar en PostgreSQL y pgAdmin

Se necesita una instalación de PostgreSQL y una conexión operativa desde pgAdmin. Los archivos están en UTF-8.

1. Conectarse al servidor y abrir una herramienta de consultas sobre la base `postgres`.
2. Ejecutar **por separado**, con autocommit habilitado y fuera de una transacción:

```sql
CREATE DATABASE capstone_project;
```

3. Abrir una nueva herramienta de consultas conectada a **`capstone_project`**. Crear la base no cambia automáticamente la conexión de la pestaña anterior.
4. Abrir `estructura.sql` y ejecutar el archivo completo. Crea el esquema `autos_capstone`, las tablas, los datos, la limpieza y la vista. El bloque original se ejecuta en una transacción; el bloque agregado al final incorpora `sucursales`, `vendedores` y su relación con `pedidos` en una segunda transacción.
5. Revisar las salidas de auditoría antes y después de la limpieza. Al finalizar deben existir cinco tablas, 1.000 pedidos y 884 ventas válidas.
6. Abrir `analisis.sql` sobre la misma base. Ejecutar primero la línea `SET search_path TO autos_capstone, public;` y luego cada consulta completa, incluyendo su CTE cuando corresponda. También se puede ejecutar todo el archivo.
7. Comparar los resultados con las tablas de este README.

Comprobación rápida:

```sql
SELECT COUNT(*) AS clientes FROM autos_capstone.clientes;  -- 150
SELECT COUNT(*) AS productos FROM autos_capstone.productos; -- 18
SELECT COUNT(*) AS pedidos FROM autos_capstone.pedidos; -- 1000
SELECT COUNT(*) AS sucursales FROM autos_capstone.sucursales; -- 3
SELECT COUNT(*) AS vendedores FROM autos_capstone.vendedores; -- 6
SELECT COUNT(*) AS pedidos_validos FROM autos_capstone.ventas_validas; -- 884
```

**Reejecución:** `analisis.sql` se puede ejecutar todas las veces necesarias. `estructura.sql` se ejecuta una sola vez por esquema: deliberadamente no borra datos existentes. Si ya existe `autos_capstone`, utilizar una base nueva y vacía. Ante un error dentro de la transacción, ejecutar `ROLLBACK;` antes de continuar. Si `capstone_project` ya existe, no volver a ejecutar `CREATE DATABASE`; comprobar primero si su esquema está libre.

Alternativa con la terminal, utilizando el usuario de PostgreSQL correspondiente:

```bash
psql -U postgres -d postgres -c "CREATE DATABASE capstone_project;"
psql -U postgres -d capstone_project -v ON_ERROR_STOP=1 -f estructura.sql
psql -U postgres -d capstone_project -v ON_ERROR_STOP=1 -f analisis.sql
```

### Verificación de vendedores y sucursales

Esta consulta puede guardarse como `verificacion_vendedores.sql`. Es una comprobación complementaria y no reemplaza ninguna de las cinco preguntas de negocio.

```sql
SELECT
    v.nombre AS vendedor,
    s.nombre AS sucursal,
    COUNT(p.id_pedido) AS cantidad_pedidos
FROM autos_capstone.vendedores v
JOIN autos_capstone.sucursales s
    ON v.id_sucursal = s.id_sucursal
LEFT JOIN autos_capstone.pedidos p
    ON p.id_vendedor = v.id_vendedor
GROUP BY v.id_vendedor, v.nombre, s.nombre
ORDER BY v.id_vendedor;
```

### Validación realizada

La versión completa de cinco tablas, las cinco consultas de negocio y la verificación de vendedores se ejecutaron desde cero en PGlite, un motor PostgreSQL integrado basado en WebAssembly. Se verificaron los recuentos, los 24 meses y que los `JOIN` conservan 884 pedidos distintos sin multiplicar filas. Además, se recalcularon ventas y ganancia con aritmética decimal en Python y coincidieron con SQL; los totales por mes y por marca también coinciden. En pgAdmin se comprobó mediante capturas que la ampliación muestra seis vendedores, sus tres sucursales y los 1.000 pedidos distribuidos como indica este documento. La ejecución completa en una base vacía confirmó cinco tablas, 1.000 pedidos, 884 ventas válidas y la distribución esperada entre los seis vendedores. Las cinco consultas devolvieron respectivamente 5, 24, 3, 13 y 7 filas, y se comprobaron los totales de ventas y ganancia bruta.

## 8. Entrega en GitHub

Crear un repositorio público, por ejemplo `sql-capstone-autos`, y descomprimir el paquete y subir **los cuatro archivos en la raíz**: `estructura.sql`, `analisis.sql`, `README.md` y `verificacion_vendedores.sql`. No es necesario subir el ZIP. Verificar que el README se visualice y compartir el enlace del repositorio como entrega.

El repositorio debe publicarse desde la cuenta de la estudiante. Los archivos preparados no implican que ya esté publicado.
