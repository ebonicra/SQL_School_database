-- 1) Write a procedure for adding P2P check
-- Parameters: nickname of the person being checked, checker's nickname, task name, [P2P check status]( #check-status), time. \
-- If the status is "start", add a record in the Checks table (use today's date). \
-- Add a record in the P2P table. \
-- If the status is "start", specify the record just added as a check, otherwise specify the check with the unfinished P2P step.

DROP FUNCTION IF EXISTS fnc_find_unfinished_p2p;
DROP PROCEDURE IF EXISTS add_p2p_check;

CREATE OR REPLACE FUNCTION fnc_find_unfinished_p2p(
checked_peer VARCHAR(10), checking_peer_ VARCHAR(10),
task_name VARCHAR(20)) RETURNS INT AS $$ 
	DECLARE unfinished_check INT;
	BEGIN
	SELECT
	    check_id INTO unfinished_check
	FROM (
				SELECT
					COUNT(c.check_id),
					c.check_id
				FROM p2p p
				JOIN checks c ON c.check_id = p.check_id
				WHERE c.peer = checked_peer
					AND p.checking_peer = checking_peer_
					AND c.task = task_name
				GROUP BY
					c.check_id
				HAVING
					COUNT(c.check_id) <> 2
	    ) t;
	RETURN unfinished_check;
	END;
	$$ LANGUAGE 
PLPGSQL;

CREATE OR REPLACE PROCEDURE add_p2p_check(checked_peer 
VARCHAR(10), peer VARCHAR(10), task_name 
VARCHAR(20), state CHECK_STATE, check_time TIME) AS 
$$ 
	DECLARE unfinished_check INT;
	BEGIN
	  IF state = 'start' THEN
			INSERT INTO checks
			VALUES (
							(SELECT MAX(check_id) FROM checks) + 1,
							checked_peer,
							task_name,
							CURRENT_DATE
					);
			SELECT MAX(check_id) FROM checks
	    INTO unfinished_check;
		ELSE
			SELECT fnc_find_unfinished_p2p(
	        checked_peer,
	        peer,
	        task_name
	    ) INTO unfinished_check;	
		END IF;
		IF unfinished_check IS NOT NULL THEN
			INSERT INTO
	    p2p
			VALUES (
					(SELECT MAX(p2p_id) FROM p2p) + 1,
	        unfinished_check,
	        peer,
	        state,
	        check_time
	   	);
			ELSE RAISE EXCEPTION 'p2p not found';
		END IF;
	END;
	$$ LANGUAGE 
PLPGSQL; 

-- call add_p2p_check('lavondas', 'karleenk', 'C5_Decimal', 'start', '14:03');
-- call add_p2p_check('lavondas', 'karleenk', 'C5_Decimal', 'success', '14:24');
-- call add_p2p_check('ebonicra', 'papawfen', 'C2_SimpleBashUtils', 'start', '15:28');
-- call add_p2p_check('ebonicra', 'papawfen', 'C2_SimpleBashUtils', 'success', '15:49');


-- 2) Write a procedure for adding checking by Verter
-- Parameters: nickname of the person being checked, task name, Verter check status, time. 
-- Add a record to the Verter table (as a check specify the check of the corresponding task with the latest (by time) successful P2P step)

DROP PROCEDURE IF EXISTS add_verter_check;
DROP FUNCTION IF EXISTS fnc_find_last_success_p2p;
CREATE OR REPLACE PROCEDURE add_verter_check(checked_peer 
VARCHAR(10), task_name VARCHAR(20), state CHECK_STATE, check_time TIME) 
AS $$ 
	DECLARE last_success_check INT;
	BEGIN
		SELECT fnc_find_last_success_p2p(
	        checked_peer,
	        task_name
	    ) INTO last_success_check;
		IF last_success_check IS NOT NULL THEN
			INSERT INTO
	    verter
			VALUES (
					(SELECT MAX(verter_id) FROM verter) + 1,
	        last_success_check,
	        state,
	        check_time
	   	);
		ELSE RAISE EXCEPTION 'p2p not found';
		END IF;
	END;
$$ LANGUAGE PLPGSQL; 

CREATE OR REPLACE FUNCTION fnc_find_last_success_p2p(
checked_peer VARCHAR(10), task_name VARCHAR(20)) RETURNS INT AS $$ 
	DECLARE last_check INT;
	BEGIN
	SELECT
	    check_id INTO last_check
	FROM (
				SELECT c.check_id
				FROM p2p p
				JOIN checks c ON c.check_id = p.check_id
				WHERE c.peer = checked_peer
					AND c.task = task_name
					AND p.p2p_state = 'success'
				ORDER BY c.check_date DESC, p.p2p_time DESC
				LIMIT 1
	    ) t;
	RETURN last_check;
	END;
	$$ LANGUAGE 
PLPGSQL; 


-- call add_verter_check('sharronr', 'D01_Linux', 'start', '22:33');
-- call add_verter_check('sharronr', 'D01_Linux', 'success', '22:44');
-- call add_verter_check('ebonicra', 'C2_SimpleBashUtils', 'start', '18:12');
-- call add_verter_check('ebonicra', 'C2_SimpleBashUtils', 'success', '18:16');


--3) Write a trigger: after adding a record with the "start" status to the P2P table, 
--change the corresponding record in the TransferredPoints table

DROP TRIGGER IF EXISTS trg_3_start_p2p ON p2p;
DROP FUNCTION IF EXISTS fnc_trg_3_start_p2p();
CREATE OR REPLACE FUNCTION fnc_trg_3_start_p2p() 
	RETURNS TRIGGER 
	AS $$
	DECLARE
		new_checked VARCHAR := (SELECT peer from checks where new.check_id = checks.check_id);
		new_checking VARCHAR := new.checking_peer;
	BEGIN
		IF (TG_OP = 'INSERT' AND NEW.p2p_state = 'start') THEN
        	UPDATE transferred_points
            	SET points_amount = points_amount + 1
                WHERE checking_peer = new_checking AND checked_peer = new_checked;
            IF NOT FOUND THEN
            	INSERT INTO transferred_points
                SELECT (SELECT COALESCE(MAX(transferred_point_id) + 1, 1)  FROM transferred_points),
                new_checking, 
                new_checked,
                1;
            END IF;
		END IF;
		RETURN NULL;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_3_start_p2p
    AFTER INSERT ON p2p
    FOR EACH ROW
    EXECUTE FUNCTION fnc_trg_3_start_p2p();

-- INSERT Into p2p VALUES(17, 8, 'ebonicra', 'start', '18:00');
-- SELECT * FROM transferred_points;


-- 4) Write a trigger: before adding a record to the XP table, check if it is correct

DROP TRIGGER IF EXISTS trg_4_insert_xp ON xp;
DROP FUNCTION IF EXISTS fnc_trg_4_insert_xp();
CREATE OR REPLACE FUNCTION fnc_trg_4_insert_xp() 
  RETURNS TRIGGER 
  AS $$
  BEGIN
      IF (NEW.xp_amount <= 0 OR
          NEW.xp_amount > (select t.max_xp
                           from checks
                              join tasks t ON checks.task = t.title
                           where NEW.check_id = check_id) OR
          'success' NOT IN (select verter_state from verter where check_id = NEW.check_id)) THEN
          RAISE EXCEPTION 'There is some mistake here, you can not add this line.';
      END IF;
      RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_4_insert_xp
    AFTER INSERT ON xp
    FOR EACH ROW
    EXECUTE FUNCTION fnc_trg_4_insert_xp();

-- INSERT INTO XP VALUES (7, 8, 1000);
-- INSERT INTO XP VALUES (7, 1, 200);
-- INSERT INTO XP VALUES (7, 8, 200);
-- SELECT * FROM XP;
