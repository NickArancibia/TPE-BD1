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