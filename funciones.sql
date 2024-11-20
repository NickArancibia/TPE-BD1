CREATE OR REPLACE FUNCTION nextDorsal(
	apos futbolista.posicion%type,
	aequipo futbolista.equipo%type
) RETURNS INT AS $$
DECLARE
	posibles_dorsales INT[];
	dorsales_usados INT[];
	posible_dorsal INT;
BEGIN
	CASE 
        WHEN apos = 'Portero' THEN posibles_dorsales := ARRAY[1, 12];
        WHEN apos = 'Defensa' OR apos = 'Defensa central' THEN posibles_dorsales := ARRAY[2, 6];
        WHEN apos = 'Lateral izquierdo' THEN posibles_dorsales := ARRAY[3];
        WHEN apos = 'Lateral derecho' THEN posibles_dorsales := ARRAY[4];
        WHEN apos = 'Pivote' THEN posibles_dorsales := ARRAY[5];
        WHEN apos = 'Mediocentro' OR apos = 'Centrocampista' OR 
             apos = 'Interior derecho' OR apos = 'Interior izquierdo' THEN posibles_dorsales := ARRAY[8];
        WHEN apos = 'Mediocentro ofensivo' OR apos = 'Mediapunta' THEN posibles_dorsales := ARRAY[10];
        WHEN apos = 'Extremo derecho' OR apos = 'Extremo izquierdo' THEN posibles_dorsales := ARRAY[7, 11];
        WHEN apos = 'Delantero' OR apos = 'Delantero centro' THEN posibles_dorsales := ARRAY[9];
        ELSE 
            posibles_dorsales := ARRAY[13];
    END CASE;

	SELECT ARRAY_AGG(dorsal)
    INTO dorsales_usados
    FROM futbolista f NATURAL JOIN dorsal
    WHERE f.equipo = aequipo;

	FOREACH posible_dorsal IN ARRAY posibles_dorsales LOOP
		IF dorsales_usados IS NULL OR NOT posible_dorsal = ANY(dorsales_usados) THEN
            RETURN posible_dorsal;
        END IF;
	END LOOP;

	FOR posible_dorsal IN 13..99 LOOP
		IF posible_dorsal = ANY(dorsales_usados) THEN
            RETURN posible_dorsal;
        END IF;
	END LOOP;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION analisis_pie(
    fecha_inicio futbolista.fichado%type,
    tipo_pie futbolista.pie%type
) RETURNS TABLE (
    variable TEXT,
    fecha TEXT,
    qty INT,
    prom_edad DECIMAL(5,2),
    prom_alt DECIMAL(3,2),
    valor INT,
	num_fila INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'Pie: ' || tipo_pie::TEXT AS variable,
        TO_CHAR(DATE_TRUNC('month', fichado), 'YYYY-MM') AS fecha,
        COUNT(*)::INT AS qty,
        AVG(edad)::DECIMAL(5, 2) AS prom_edad,
        AVG(altura)::DECIMAL(3, 2) AS prom_alt,
        MAX(valor_mercado)::INT AS valor,
	 	ROW_NUMBER() OVER (ORDER BY DATE_TRUNC('month', fichado))::INT AS num_fila
    FROM futbolista
    WHERE pie = tipo_pie AND fichado >= fecha_inicio
    GROUP BY DATE_TRUNC('month', fichado)
    ORDER BY DATE_TRUNC('month', fichado);
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION analisis_pies(
    fecha_inicio futbolista.fichado%type
) RETURNS TABLE (
    variable TEXT,
    fecha TEXT,
    qty INT,
    prom_edad DECIMAL(5,2),
    prom_alt DECIMAL(3,2),
    valor INT,
	num_fila INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM analisis_pie(fecha_inicio, 'derecho')
    UNION ALL
    SELECT * FROM analisis_pie(fecha_inicio, 'izquierdo');
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION analisis_dorsales(
    fecha_inicio futbolista.fichado%type
) RETURNS TABLE (
    variable INT,
    fecha TEXT,
    qty INT,
    prom_edad DECIMAL(5,2),
    prom_altura DECIMAL(3,2),
    valor INT,
    num_fila INT
) AS $$
DECLARE
	MINDORSAL CONSTANT INT := 1;
	MAXDORSAL CONSTANT INT := 12;
BEGIN
    RETURN QUERY
    SELECT
        d.dorsal AS variable, 
        MIN(f.fichado)::TEXT AS fecha,
        COUNT(*)::INT AS qty,
        AVG(edad)::DECIMAL(5, 2) AS prom_edad,
        AVG(altura)::DECIMAL(3, 2) AS prom_altura,
        MAX(f.valor_mercado)::INT AS valor,
        ROW_NUMBER() OVER (ORDER BY MAX(f.valor_mercado) DESC)::INT AS num_fila
    FROM 
        dorsal d JOIN futbolista f ON d.nombre = f.nombre
    WHERE 
        d.dorsal BETWEEN MINDORSAL AND MAXDORSAL
        AND f.fichado >= fecha_inicio
    GROUP BY 
        d.dorsal
    ORDER BY 
        MAX(f.valor_mercado) DESC;
END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;