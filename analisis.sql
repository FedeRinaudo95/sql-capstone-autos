-- Ejecutar después de estructura.sql, en capstone_project.
SET search_path TO autos_capstone, public;

-- 1. ¿Cuáles son los cinco clientes de mayor gasto?
-- Incluimos su tipo para evaluar si conviene una estrategia comercial de flotas.
SELECT c.id_cliente, c.nombre, c.tipo_cliente,
 COUNT(*) AS pedidos_completados, SUM(v.cantidad) AS unidades,
 SUM(v.venta_neta) AS gasto_total_usd
FROM ventas_validas v
JOIN clientes c ON c.id_cliente = v.id_cliente
GROUP BY c.id_cliente, c.nombre, c.tipo_cliente
ORDER BY gasto_total_usd DESC, c.id_cliente
LIMIT 5;

-- 2. ¿Cómo evolucionan las ventas por mes?
-- Mostramos también meses sin ventas, para no confundir ausencia con un salto temporal.
WITH meses AS (
 SELECT generate_series(DATE '2024-01-01', DATE '2025-12-01', INTERVAL '1 month')::DATE AS mes
)
SELECT m.mes, COUNT(v.id_pedido) AS pedidos,
 COALESCE(SUM(v.cantidad), 0) AS unidades,
 COALESCE(SUM(v.venta_neta), 0) AS ventas_usd
FROM meses m
LEFT JOIN ventas_validas v ON DATE_TRUNC('month', v.fecha_pedido)::DATE = m.mes
GROUP BY m.mes
ORDER BY m.mes;

-- 3. ¿Cuáles son los tres modelos menos vendidos?
-- Partimos del catálogo con LEFT JOIN para no ocultar modelos con cero ventas.
-- Se mide cantidad de vehículos, no cantidad de pedidos.
SELECT p.id_producto, p.marca, p.modelo,
 COALESCE(SUM(v.cantidad), 0) AS unidades_vendidas,
 COALESCE(SUM(v.venta_neta), 0) AS ventas_usd
FROM productos p
LEFT JOIN ventas_validas v ON v.id_producto = p.id_producto
GROUP BY p.id_producto, p.marca, p.modelo
ORDER BY unidades_vendidas, p.id_producto
LIMIT 3;

-- 4. ¿Qué pedidos tienen los mayores importes dentro de cada segmento?
-- RANK compara pedidos dentro de su segmento y conserva los empates.
-- Si hay empates puede haber más de tres filas por segmento.
WITH ranking AS (
 SELECT p.segmento, v.id_pedido, c.nombre AS cliente, p.marca, p.modelo,
 v.cantidad, v.venta_neta,
 RANK() OVER (PARTITION BY p.segmento ORDER BY v.venta_neta DESC) AS posicion
 FROM ventas_validas v
 JOIN productos p ON p.id_producto = v.id_producto
 JOIN clientes c ON c.id_cliente = v.id_cliente
)
SELECT * FROM ranking
WHERE posicion <= 3
ORDER BY segmento, posicion, id_pedido;

-- 5. ¿Qué marcas generan más ganancia bruta y qué margen tienen?
-- Restamos el costo de adquisición a las ventas después del descuento.
-- El margen se calcula sobre los totales, no promediando porcentajes de pedidos.
SELECT p.marca, SUM(v.cantidad) AS unidades,
 SUM(v.venta_neta) AS ventas_usd,
 SUM(v.costo_total) AS costos_usd,
 SUM(v.venta_neta - v.costo_total) AS ganancia_bruta_usd,
 ROUND(100.0 * SUM(v.venta_neta - v.costo_total)
  / NULLIF(SUM(v.venta_neta), 0), 2) AS margen_bruto_pct
FROM ventas_validas v
JOIN productos p ON p.id_producto = v.id_producto
GROUP BY p.marca
ORDER BY ganancia_bruta_usd DESC, p.marca;
