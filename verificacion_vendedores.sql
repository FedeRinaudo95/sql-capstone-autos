-- Verificación complementaria: incluye los 1000 pedidos de todos los estados.
-- Resultado esperado: seis filas; 167 pedidos para vendedores 1 a 4 y 166 para 5 y 6.
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
