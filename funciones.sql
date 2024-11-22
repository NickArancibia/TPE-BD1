-- TABLE CREATION

create table futbolista(
        nombre varchar(50) not null,
        posicion varchar(50) not null,
        edad int not null,
        altura float,
        pie varchar(20),
        fichado date,
        equipo_anterior varchar(50),
        valor_mercado int,
        equipo varchar(50),
        primary key(nombre)
);

create table dorsal(
        jugador varchar(50) not null,
        dorsal int not null,
        foreign key(jugador) references futbolista(nombre),
        primary key(jugador)
);

-- 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 

-- FUNCTIONS

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
            posibles_dorsales := ARRAY[]::INTEGER[];
    END CASE;

	SELECT ARRAY_AGG(dorsal)
    INTO dorsales_usados
    FROM futbolista f JOIN dorsal d ON f.nombre = d.jugador
    WHERE f.equipo = aequipo;

	IF dorsales_usados IS NULL THEN
		dorsales_usados := ARRAY[]::INTEGER[];
	END IF;

	FOREACH posible_dorsal IN ARRAY posibles_dorsales LOOP
		IF NOT posible_dorsal = ANY(dorsales_usados) THEN
            RETURN posible_dorsal;
        END IF;
	END LOOP;

	FOR posible_dorsal IN 13..99 LOOP
		IF NOT posible_dorsal = ANY(dorsales_usados) THEN
            RETURN posible_dorsal;
        END IF;
	END LOOP;
	RAISE EXCEPTION 'No hay dorsales disponibles';
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
    WHERE pie = tipo_pie AND fichado >= fecha_inicio AND valor_mercado is not NULL 
	AND altura IS NOT NULL AND pie IS NOT NULL
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
$$ LANGUAGE PLPGSQL
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE FUNCTION analisis_equipos(
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
    SELECT
        f.equipo::TEXT AS variable, 
        MIN(f.fichado)::TEXT AS fecha,
        COUNT(*)::INT AS qty,
        AVG(edad)::DECIMAL(5, 2) AS prom_edad,
        AVG(altura)::DECIMAL(3, 2) AS prom_alt,
        MAX(f.valor_mercado)::INT AS valor,
        ROW_NUMBER() OVER (ORDER BY MAX(f.valor_mercado) DESC)::INT AS num_fila
    FROM 
        dorsal d JOIN futbolista f ON d.jugador = f.nombre
    WHERE 
        f.fichado >= fecha_inicio
		AND valor_mercado IS NOT NULL
		AND altura IS NOT NULL
    GROUP BY 
        f.equipo
    ORDER BY 
        MAX(f.valor_mercado) DESC;
END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE FUNCTION analisis_dorsales(
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
DECLARE
	MINDORSAL CONSTANT INT := 1;
	MAXDORSAL CONSTANT INT := 12;
BEGIN
    RETURN QUERY
    SELECT
        'Dorsal: ' || d.dorsal AS variable, 
        MIN(f.fichado)::TEXT AS fecha,
        COUNT(*)::INT AS qty,
        AVG(edad)::DECIMAL(5, 2) AS prom_edad,
        AVG(altura)::DECIMAL(3, 2) AS prom_alt,
        MAX(f.valor_mercado)::INT AS valor,
        ROW_NUMBER() OVER (ORDER BY MAX(f.valor_mercado) DESC)::INT AS num_fila
    FROM 
        dorsal d JOIN futbolista f ON d.jugador = f.nombre
    WHERE 
        d.dorsal BETWEEN MINDORSAL AND MAXDORSAL
        AND f.fichado >= fecha_inicio
		AND valor_mercado IS NOT NULL
		AND altura IS NOT NULL
    GROUP BY 
        d.dorsal
    ORDER BY 
        MAX(f.valor_mercado) DESC;
END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;

create or replace function analisis_jugadores(
	fecha_inicio futbolista.fichado%type
) RETURNS VOID AS $$
	DECLARE
		cantDatos INT := (SELECT COUNT(*) 
							FROM futbolista f JOIN dorsal d ON f.nombre = d.jugador
							WHERE f.fichado >= fecha_inicio
						 );
		CPies CURSOR FOR SELECT * FROM analisis_pies(fecha_inicio);
		CEquipos CURSOR FOR SELECT * FROM analisis_equipos(fecha_inicio);
		CDorsales CURSOR FOR SELECT * FROM analisis_dorsales(fecha_inicio);
		pie_record RECORD;
		equipo_record RECORD;
		dorsal_record RECORD;
	BEGIN
		IF cantDatos = 0 THEN
			RETURN;
		END IF;
		OPEN CPies;
		OPEN CEquipos;
		OPEN CDorsales;
		RAISE INFO '-----------------------------------------------------------------------------------------------';
		RAISE INFO '--------------------------------ANALISIS DE JUGADORES Y EQUIPOS--------------------------------';
		RAISE INFO '-----------------------------------------------------------------------------------------------';
		RAISE INFO '-----------------------------------------------------------------------------------------------';
		RAISE INFO 'Variable-----------------------------Fecha------Qty--Prom_Edad--Prom_Alt--Valor------------#---';
		
		LOOP
			FETCH CPies INTO pie_record;
			EXIT WHEN NOT FOUND;
			RAISE INFO '%	    %      %    %       %    %      %',
				pie_record.variable || repeat('.', 30 - LENGTH(pie_record.variable)),
				pie_record.fecha,
				pie_record.qty,
				pie_record.prom_edad,
				pie_record.prom_alt,
				pie_record.valor::TEXT || repeat(' ', 11 - LENGTH(pie_record.valor::TEXT)),
				pie_record.num_fila;
		END LOOP;
		RAISE INFO '-----------------------------------------------------------------------------------------------';
		LOOP
			FETCH CEquipos INTO equipo_record;
			EXIT WHEN NOT FOUND;
			RAISE INFO '%	    %      %    %       %    %      %',
				equipo_record.variable || repeat('.', 30 - LENGTH(equipo_record.variable)),
				equipo_record.fecha,
				equipo_record.qty,
				equipo_record.prom_edad,
				equipo_record.prom_alt,
				equipo_record.valor::TEXT || repeat(' ', 11 - LENGTH(equipo_record.valor::TEXT)),
				equipo_record.num_fila;
		END LOOP;
		RAISE INFO '-----------------------------------------------------------------------------------------------';
		LOOP
			FETCH CDorsales INTO dorsal_record;
			EXIT WHEN NOT FOUND;
			RAISE INFO '%	    %   %    %       %    %      %',
				dorsal_record.variable || repeat('.', 30 - LENGTH(dorsal_record.variable)),
				dorsal_record.fecha,
				dorsal_record.qty,
				dorsal_record.prom_edad,
				dorsal_record.prom_alt,
				dorsal_record.valor || repeat(' ', 11 - LENGTH(dorsal_record.valor::TEXT)),
				dorsal_record.num_fila;
		END LOOP;
		RAISE INFO '-----------------------------------------------------------------------------------------------';
		CLOSE CDorsales;
		CLOSE CEquipos;
		CLOSE CPies;
	END
$$ LANGUAGE PLPGSQL;

-- 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 === 0 

-- TRIGGERS

CREATE OR REPLACE FUNCTION checkDependency() RETURNS VOID AS $$
DECLARE uniqueCounter INT;
BEGIN
        SELECT coalesce(max(num), 0) into uniqueCounter
        FROM    (SELECT count(*) num
                FROM futbolista join dorsal on futbolista.nombre = dorsal.jugador
                GROUP BY futbolista.equipo, dorsal.dorsal) as nums;
        IF uniqueCounter >= 2 THEN
                RAISE EXCEPTION 'La operación viola la dependencia equipo, dorsal -> jugador';
        END IF;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION insertDorsalForFutbolista() RETURNS Trigger AS $$
BEGIN
        RAISE NOTICE 'Nuevo nombre: %', new.nombre;
        INSERT INTO dorsal values(new.nombre, nextDorsal(new.posicion, new.equipo));
        PERFORM checkDependency();
        RETURN new;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION checkDependencyTrigger() RETURNS Trigger AS $$
BEGIN
        PERFORM checkDependency();
        RETURN new;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER futbolistaInsertTrigger
AFTER INSERT ON futbolista
FOR EACH ROW EXECUTE PROCEDURE insertDorsalForFutbolista();

CREATE OR REPLACE TRIGGER futbolistaUpdateTrigger
AFTER UPDATE ON futbolista
EXECUTE PROCEDURE checkDependencyTrigger();

CREATE OR REPLACE TRIGGER dorsalInsertTrigger
AFTER INSERT ON dorsal
EXECUTE PROCEDURE checkDependencyTrigger();

CREATE OR REPLACE TRIGGER dorsalUpdateTrigger
AFTER UPDATE ON dorsal
EXECUTE PROCEDURE checkDependencyTrigger();