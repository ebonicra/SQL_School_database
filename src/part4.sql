-- Запускать через консоль, иначе RAISE не выводит

DROP TABLE IF EXISTS TableName_1 CASCADE;
CREATE TABLE TableName_1 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(10)
);
INSERT INTO tablename_1(name) VALUES ('ebonicra');

DROP TABLE IF EXISTS TableName_2 CASCADE;
CREATE TABLE TableName_2 (
    id SERIAL PRIMARY KEY,
    description TEXT
);
INSERT INTO tablename_2(description) VALUES ('is the most beautiful girl:)');

DROP TABLE IF EXISTS TestTable_1 CASCADE;
CREATE TABLE TestTable_1 (
    id SERIAL PRIMARY KEY,
    value INT
);
INSERT INTO testtable_1(value) VALUES (100);




-- 1) Create a stored procedure that, without destroying the database, destroys all those tables 
-- in the current database whose names begin with the phrase 'TableName'.

DROP PROCEDURE IF EXISTS drop_table_name();
CREATE OR REPLACE PROCEDURE drop_table_name(tablename VARCHAR) 
AS $$
    BEGIN
        FOR tablename IN (SELECT table_name
                          FROM information_schema.tables
                          WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
                            AND table_name LIKE concat(tablename, '%')) LOOP
            EXECUTE concat('drop table ', tablename);
        END LOOP;
    END;
$$ LANGUAGE plpgsql;

-- SELECT tablename FROM pg_tables WHERE schemaname = 'public';
-- CALL drop_table_name('tablename');
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public';






-- 2) Create a stored procedure with an output parameter that outputs a list of names and 
-- parameters of all scalar user's SQL functions in the current database. 
-- Do not output function names without parameters. The names and the list of parameters must be in one string. 
-- The output parameter returns the number of functions found.

CREATE OR REPLACE FUNCTION get_name(get_id BIGINT) RETURNS VARCHAR(10) 
AS $$
    DECLARE 
        result_name VARCHAR(10);
        table_exists BOOLEAN;
    BEGIN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'tablename_1' AND table_schema = 'public'
        ) INTO table_exists;
        IF table_exists THEN
            SELECT t.name INTO result_name FROM tablename_1 t WHERE t.id = get_id;
            RETURN result_name;
        ELSE RAISE EXCEPTION 'Error: tablename_test1 does not exist';
        END IF;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_description(get_id BIGINT) RETURNS TEXT 
AS $$
    DECLARE 
        result_text TEXT;
        table_exists BOOLEAN;
    BEGIN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'tablename_2' AND table_schema = 'public'
        ) INTO table_exists;
        IF table_exists THEN
            SELECT t.description INTO result_text FROM tablename_test2 t WHERE t.id = get_id;
            RETURN result_text;
        ELSE RAISE EXCEPTION 'Error: tablename_2 does not exist';
        END IF;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_value(get_id BIGINT) RETURNS TEXT 
AS $$
    DECLARE 
        result_value INT;
        table_exists BOOLEAN;
    BEGIN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'testtable_1' AND table_schema = 'public'
        ) INTO table_exists;
        IF table_exists THEN
            SELECT t.value INTO result_value FROM testtable t WHERE t.id = get_id;
            RETURN result_value;
        ELSE RAISE EXCEPTION 'Error: testtable_1 does not exist';
        END IF;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE get_all_functions(OUT num_functions INT) 
AS $$
    DECLARE
        function_name TEXT := '';
        function_list TEXT := '';
        param_type TEXT := '';
        temp_row RECORD;
    BEGIN
        num_functions := 0;
        CREATE TEMP TABLE IF NOT EXISTS temp_functions AS
            SELECT 
                routine_name AS "function_name",
                data_type AS "param_type"
            FROM 
                information_schema.routines
            WHERE 
                routine_type = 'FUNCTION'
                AND specific_schema = 'public'
                AND routine_schema = current_schema()
                AND routine_name NOT LIKE 'pg_%'
                AND data_type IS NOT NULL;
        SELECT COUNT(*) INTO num_functions FROM temp_functions;
        FOR temp_row IN (
            SELECT * FROM temp_functions
        ) 
        LOOP
            function_list := function_list || temp_row.function_name || '(' || temp_row.param_type || '), ';
        END LOOP;
        function_list := SUBSTRING(function_list, 1, LENGTH(function_list) - 2);
        RAISE NOTICE '%', function_list;
        DROP TABLE temp_functions;
    END;
$$ LANGUAGE plpgsql;


-- DO $$
--     DECLARE
--          n INT DEFAULT 0;
--     BEGIN
--         CALL get_all_functions(n);
--         RAISE NOTICE 'amount of functions found: - %', n;
--     END
-- $$;







-- 3) Create a stored procedure with output parameter, which destroys all SQL DML triggers in the current database. 
-- The output parameter returns the number of destroyed triggers.

CREATE OR REPLACE FUNCTION check_value_testtable() RETURNS TRIGGER 
AS $$
    BEGIN
        IF NEW.value <= 0 THEN
            RAISE EXCEPTION 'Value should be positive';
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_value
BEFORE UPDATE ON testtable_1
FOR EACH ROW
EXECUTE FUNCTION check_value_testtable();



CREATE OR REPLACE PROCEDURE destroy_triggers(OUT num INT) 
AS $$
    DECLARE
        trg   TEXT;
        tables TEXT;
    BEGIN
        num := 0;
        FOR trg, tables IN (SELECT DISTINCT trigger_name, event_object_table
                                    FROM information_schema.triggers
                                    WHERE trigger_schema = 'public')
        LOOP
            EXECUTE CONCAT('DROP TRIGGER ', trg, ' ON ', tables);
            num := num + 1;
        END LOOP;
    END;
$$ LANGUAGE plpgsql;

-- DO $$
--     DECLARE
--         n INT DEFAULT 0;
--     BEGIN
--         CALL destroy_triggers(n);
--         RAISE NOTICE 'amount of deleted triggers: - %',n;
--     END
-- $$;







-- 4) Create a stored procedure with an input parameter that outputs names and descriptions of object types 
-- (only stored procedures and scalar functions) that have a string specified by the procedure parameter.

CREATE OR REPLACE PROCEDURE names_of_proc_and_func(IN string TEXT) 
AS $$
    DECLARE
        proc_func TEXT := '';
        this_row RECORD;
    BEGIN
        CREATE TEMP TABLE IF NOT EXISTS temp_proc_func AS
            SELECT routine_name,
                routine_type
            FROM information_schema.routines
            WHERE specific_schema = 'public'
            AND routine_name LIKE CONCAT('%', string, '%');
        FOR this_row IN (
            SELECT * FROM temp_proc_func
        ) 
        LOOP
            proc_func := proc_func || this_row.routine_name || '(' || this_row.routine_type || ')' || E'\n';
        END LOOP;
        RAISE NOTICE '%', proc_func;
        DROP TABLE temp_proc_func;
    END;
$$ LANGUAGE plpgsql;

-- CALL names_of_proc_and_func('check');