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
