--------------------------------------------------------------------------------------------------------------
											--EJERCICIO 1--
--------------------------------------------------------------------------------------------------------------

--1.1. Calcula el promedio de temperatura.
SELECT avg(temperatura_grados)
FROM tiempo t;

--1.2. Obtén los municipios en los cuales coincidan las medias de la sensación térmica y de la temperatura. 
SELECT m.nombre, avg(t.temperatura_grados) AS media_temperatura, avg(t.sensacion_termica_grados) AS media_sensacion
FROM tiempo t 
NATURAL JOIN municipios m 
GROUP BY m.id_municipio 
having avg(t.temperatura_grados)=avg(t.sensacion_termica_grados);


--1.3. Obtén el local más cercano de cada municipio
CREATE TEMPORARY TABLE tabla1 as
SELECT id_municipio, min(distancia) AS min_dist
FROM lugares l
GROUP BY id_municipio;

SELECT m.nombre, t1.min_dist, l.nombre
FROM tabla1 t1
LEFT JOIN lugares l ON t1.id_municipio = l.id_municipio AND t1.min_dist=l.distancia
LEFT JOIN municipios m ON m.id_municipio = t1.id_municipio
ORDER BY m.nombre;


--1.4. Localiza los municipios que posean algún localizador a una distancia mayor de 2000 y que posean al menos 25 locales.
SELECT id_municipio, nombre
FROM municipios m 
WHERE id_municipio IN (SELECT DISTINCT (id_municipio)
						FROM lugares l
						WHERE id_municipio IN (SELECT id_municipio 
												FROM lugares l 
												WHERE distancia > 2000)
							AND id_municipio IN (SELECT id_municipio
													FROM lugares l 
													GROUP BY id_municipio 
													having count(id_municipio) > 25)
							);

--1.5. Teniendo en cuenta que el viento se considera leve con una velocidad media de entre 6 y 20 km/h, 
--moderado con una media de entre 21 y 40 km/h, fuerte con media de entre 41 y 70 km/h y muy fuerte entre 71 y 120 km/h. 
--Calcula cuántas rachas de cada tipo tenemos en cada uno de los días. Este ejercicio debes solucionarlo con la 
--sentencia CASE de SQL (no la hemos visto en clase, por lo que tendrás que buscar la documentación). 
						
SELECT fecha,
		count(CASE WHEN (velocidad_viento_km_h between 6 AND 20) THEN 1 END) AS rachas_leves,
	    count(CASE WHEN (velocidad_viento_km_h BETWEEN 21 AND 40) THEN 1 END) AS rachas_moderadas,
	    count(CASE WHEN (velocidad_viento_km_h BETWEEN 41 AND 70) THEN 1 END) AS rachas_fuertes,
	    count(CASE WHEN (velocidad_viento_km_h BETWEEN 71 AND 120) THEN 1 END) AS rachas_muy_fuertes
FROM tiempo t
GROUP BY fecha;


--------------------------------------------------------------------------------------------------------------
											--EJERCICIO 2--
--------------------------------------------------------------------------------------------------------------

--2.1. Crea una vista que muestre la información de los locales que tengan incluido el código postal en su dirección.
CREATE VIEW direcciones_postales AS
SELECT *
FROM lugares l
WHERE REGEXP_LIKE(direccion, '[0-9]{5}');


--2.2. Crea una vista con los locales que tienen más de una categoría asociada.
CREATE VIEW locales_varias_categorias AS
SELECT nombre, direccion, count(DISTINCT (id_categoria)) AS num_categorias
FROM lugares
GROUP BY nombre, direccion
HAVING count(DISTINCT (id_categoria))>1;

--2.3. Crea una vista que muestre el municipio con la temperatura más alta de cada día
CREATE VIEW municipios_temp_max AS
SELECT DISTINCT t.fecha, m.nombre, taux.temp_max, t.temperatura_grados 
FROM (SELECT fecha, max(temperatura_grados) AS temp_max
		FROM tiempo t
		GROUP BY fecha) AS taux
LEFT JOIN tiempo t ON t.fecha = taux.fecha AND t.temperatura_grados = taux.temp_max
LEFT JOIN municipios m ON m.id_municipio = t.id_municipio 
ORDER BY t.fecha;


--2.4. Crea una vista con los municipios en los que haya una probabilidad de precipitación mayor del 100% durante mínimo 7 horas.
CREATE VIEW lluvia_7horas as
SELECT id_municipio, fecha, count(DISTINCT(hora))
FROM tiempo
WHERE probabilidad_tormenta_porcentaje > 85
GROUP BY id_municipio, fecha 
HAVING count(DISTINCT(hora))>6;


--2.5. Obtén una lista con los parques de los municipios que tengan algún castillo.				
CREATE VIEW lugares_parque_monumento as
SELECT nombre
FROM (	SELECT *
		FROM lugares l 
		WHERE nombre IN (SELECT nombre 
							FROM lugares l 
							GROUP BY nombre
							HAVING count(DISTINCT id_categoria)>1)
			AND id_categoria IN (SELECT id_categoria 
								FROM categoria c 
								WHERE nombre = 'Monument' OR nombre = 'Park'))
GROUP BY nombre
HAVING count(DISTINCT id_categoria)>1;

--------------------------------------------------------------------------------------------------------------
											--EJERCICIO 3--
--------------------------------------------------------------------------------------------------------------

--3.1. Crea una tabla temporal que muestre cuántos días han pasado desde que se obtuvo la información de la tabla AEMET.
CREATE TEMPORARY TABLE dias_transcurridos AS 
SELECT fecha, EXTRACT(DAY FROM (CURRENT_TIMESTAMP - fecha)) AS dias_transcurridos
FROM tiempo t
GROUP BY fecha;

--3.2. Crea una tabla temporal que muestre los locales que tienen más de una categoría asociada e indica el conteo de las mismas
CREATE TEMPORARY TABLE locales_varias_categorias AS 
SELECT nombre, direccion, count(DISTINCT (id_categoria)) AS num_categorias
FROM lugares
GROUP BY nombre, direccion
HAVING count(DISTINCT (id_categoria))>1;


--3.3. Crea una tabla temporal que muestre los tipos de cielo para los cuales la probabilidad de precipitación promedio del día es mayor a 1.
SELECT t.id_municipio, t.fecha, hora, ec.nombre, media_precipitacion_dia
FROM tiempo t
INNER join( SELECT id_municipio, fecha, avg(precipitacion_mm) AS media_precipitacion_dia
			FROM tiempo t 
			GROUP BY fecha, id_municipio 
			HAVING avg(precipitacion_mm)>1) AS t2 ON t.id_municipio=t2.id_municipio AND t.fecha=t2.fecha
INNER JOIN estado_cielo ec ON ec.id_cielo = t.id_cielo;


--3.4. Crea una tabla temporal que muestre el tipo de cielo más y menos repetido por municipio.
CREATE TEMPORARY TABLE tablita1 as
SELECT id_municipio, ec.nombre, count(ec.nombre)
FROM tiempo t 
NATURAL JOIN estado_cielo ec 
GROUP BY id_municipio, ec.nombre
ORDER BY id_municipio, count(ec.nombre) desc;

CREATE TEMPORARY TABLE tablita2 as
SELECT id_municipio, max(count), min(count)
FROM (SELECT id_municipio, ec.nombre, count(ec.nombre)
		FROM tiempo t 
		NATURAL JOIN estado_cielo ec 
		GROUP BY id_municipio, ec.nombre
		ORDER BY id_municipio, count(ec.nombre) desc) AS taux2
GROUP BY id_municipio;

CREATE TEMPORARY TABLE cielo_max_mini AS 
SELECT t1.id_municipio, m.nombre AS nombre_municipio, t1.nombre, count, max, min
FROM tablita1 t1
INNER JOIN tablita2 t2 ON t1.id_municipio = t2.id_municipio
INNER JOIN municipios m ON t1.id_municipio = m.id_municipio
WHERE count = max OR count = min;


--------------------------------------------------------------------------------------------------------------
											--EJERCICIO 4--
--------------------------------------------------------------------------------------------------------------

--4.1. Necesitamos comprobar si hay algún municipio en el cual no tenga ningún local registrado.
SELECT nombre
FROM municipios m 
WHERE id_municipio IN (SELECT m.id_municipio
						FROM municipios m 
						LEFT JOIN lugares l ON l.id_municipio = m.id_municipio
						GROUP BY m.id_municipio
						HAVING count(DISTINCT id_lugar)<1);

--4.2. Averigua si hay alguna fecha en la que el cielo se encuente "Muy nuboso con tormenta".
SELECT nombre, fecha
FROM municipios m 
INNER JOIN (SELECT id_municipio, fecha
			FROM tiempo t 
			natural JOIN estado_cielo ec
			WHERE nombre = 'Muy nuboso con tormenta') 
		AS tabli ON tabli.id_municipio=m.id_municipio;

--4.3. Encuentra los días en los que los avisos sean diferentes a "Sin riesgo".
	-- Esta columna no existe

--4.4. Selecciona el municipio con mayor número de locales.
SELECT nombre
FROM municipios m 
WHERE id_municipio = (SELECT id_municipio
						FROM lugares l 
						GROUP BY id_municipio
						ORDER BY count(id_lugar) DESC
						LIMIT 1);		


--4.5. Obtén los municipios cuya media de sensación térmica sea mayor que la media total.
SELECT nombre
FROM municipios m 
WHERE id_municipio IN (SELECT DISTINCT id_municipio 
						FROM tiempo t 
						WHERE sensacion_termica_grados > (SELECT avg(sensacion_termica_grados)
															FROM tiempo t)
						);


--4.6. Selecciona los municipios con más de dos fuentes.
SELECT nombre
FROM municipios m 
WHERE id_municipio IN (SELECT id_municipio
						FROM (SELECT * 
								FROM lugares l 
								WHERE id_categoria = (SELECT id_categoria 
												FROM categoria c 
												WHERE nombre = 'Fountain')) AS taux3
						GROUP BY id_municipio
						HAVING count(id_lugar)>1);
					

--4.7. Localiza la dirección de todos los estudios de cine que estén abiertod en el municipio de "Madrid".				
SELECT nombre, direccion 
FROM lugares l 
WHERE id_municipio = (SELECT id_municipio 
						FROM municipios m 
						WHERE nombre = 'madrid')
		AND id_categoria = (SELECT id_categoria 
							FROM categoria c 
							WHERE nombre = 'Film Studio')
		AND id_apertura IN (SELECT id_apertura 
							FROM horario_apertura ha 
							WHERE nombre ='VeryLikelyOpen' OR nombre='LikelyOpen');
					

--4.8. Encuentra la máxima temperatura para cada tipo de cielo.
SELECT ec.nombre, max_temperatura
FROM (SELECT id_cielo, max(temperatura_grados) AS max_temperatura
		FROM tiempo t 
		GROUP BY id_cielo) AS t
inner JOIN estado_cielo ec ON t.id_cielo = ec.id_cielo;


--4.9. Muestra el número de locales por categoría que muy probablemente se encuentren abiertos.
SELECT c.nombre, num_locales_abiertos
FROM (SELECT id_categoria, count(l.id_lugar) AS num_locales_abiertos
		FROM (SELECT id_lugar 
				FROM lugares l 
				WHERE id_categoria = (SELECT id_apertura 
										FROM horario_apertura ha 
										WHERE nombre ='VeryLikelyOpen')) AS t1
		LEFT JOIN lugares l ON l.id_lugar = t1.id_lugar
		GROUP BY id_categoria) AS t
INNER JOIN categoria c ON c.id_categoria = t.id_categoria;