-- 1) Write a function that returns the TransferredPoints table in a more human-readable form
DROP FUNCTION IF EXISTS fnc_1_nice_transferred_points();
CREATE OR REPLACE FUNCTION fnc_1_nice_transferred_points()
    RETURNS TABLE(Peer1 VARCHAR, Peer2 VARCHAR, PointsAmount BIGINT) 
    AS $$
    BEGIN
        RETURN QUERY
            SELECT tp1.checking_peer AS Peer1, tp1.checked_peer AS Peer2, 
                        (CASE
                            WHEN tp2.sum IS NOT NULL THEN
                                (tp1.sum - tp2.sum)
                            ELSE
                                tp1.sum
                            END
                        ) AS PointsAmount
            FROM (SELECT checking_peer, checked_peer, sum(points_amount)
                            FROM transferred_points
                            GROUP BY checking_peer, checked_peer) AS tp1
                LEFT JOIN (SELECT checking_peer, checked_peer, SUM(points_amount)
                            FROM transferred_points
                            GROUP BY checking_peer, checked_peer) AS tp2
                ON tp1.checking_peer = tp2.checked_peer AND tp1.checked_peer = tp2.checking_peer;
    END;
$$ LANGUAGE plpgsql;
-- SELECT  * FROM fnc_1_nice_transferred_points();


-- 2) Write a function that returns a table of the following form: user name, 
-- name of the checked task, number of XP received
DROP FUNCTION IF EXISTS fnc_2_successes_projects();
CREATE OR REPLACE FUNCTION fnc_2_successes_projects()
    RETURNS TABLE (Peer VARCHAR, Task VARCHAR, XP NUMERIC)
    AS $$
    BEGIN
        RETURN QUERY
            SELECT c.peer, c.task, xp.xp_amount
            FROM xp
                JOIN checks c on xp.check_id = c.check_id;
    END;
$$ LANGUAGE plpgsql;
-- SELECT  * FROM fnc_2_successes_projects();



-- 3) Write a function that finds the peers who have not left campus for the whole day
DROP FUNCTION IF EXISTS fnc_3_find_not_left_campus;
CREATE OR REPLACE FUNCTION fnc_3_find_not_left_campus(day DATE)
    RETURNS TABLE (Peer VARCHAR)
    AS $$
    BEGIN
        RETURN QUERY
            SELECT t.peer FROM time_tracking t
            WHERE t.date_tracking = day AND t.state = 2
            GROUP BY t.peer, t.state
            HAVING COUNT(t.state) = 1;

    END;
$$ LANGUAGE plpgsql;
-- SELECT fnc_3_find_not_left_campus('2023-08-10');



-- -- 4) Calculate the change in the number of peer points of each peer using the TransferredPoints table
DROP PROCEDURE IF EXISTS prc_4_peer_points_change_for_TP(ref refcursor);
CREATE OR REPLACE PROCEDURE prc_4_peer_points_change_for_TP(IN ref refcursor) AS $$
    BEGIN
        OPEN ref FOR
            WITH taken AS (
              SELECT tp.checking_peer Peer, SUM(tp.points_amount) PointsChange 
              FROM transferred_points tp
    		  GROUP BY tp.checking_peer),
        	given AS (
              SELECT tp.checked_peer Peer, SUM(-tp.points_amount) PointsChange 
              FROM transferred_points tp
              GROUP BY tp.checked_peer),
        	all_points AS (
              SELECT * FROM taken 
              UNION 
              SELECT * FROM given),
    		result AS(
              SELECT all_points.Peer, SUM(PointsChange) AS PointsChange 
              FROM all_points 
              GROUP BY all_points.Peer
        	  ORDER BY 1)
        SELECT * FROM result;
    END;
$$ LANGUAGE plpgsql;
-- CALL prc_4_peer_points_change_for_TP('tmp_ref');
-- FETCH ALL IN "tmp_ref";
        




-- 5) Calculate the change in the number of peer points of each peer using the table returned by the first function from Part 3
DROP PROCEDURE IF EXISTS prc_5_peer_points_change();
CREATE OR REPLACE PROCEDURE prc_5_peer_points_change(ref refcursor)
AS $$
    BEGIN
        OPEN ref FOR
            SELECT COALESCE(tmp.peer1, tmp.peer2) AS Peer,
                        (GREATEST(tmp.sumplus, 0)
                        - GREATEST(tmp.summinus, 0)) AS PointsChange
            FROM (
                (SELECT peer1, COALESCE(SUM(pointsamount), 0) AS sumplus
                FROM fnc_1_nice_transferred_points()
                GROUP BY peer1) AS plus
                FULL JOIN
                (SELECT peer2, COALESCE(SUM(pointsamount), 0) AS summinus
                FROM fnc_1_nice_transferred_points()
                GROUP BY peer2) AS minus
                ON plus.peer1 = minus.peer2) AS tmp
            ORDER BY 2 DESC; 
    END;
$$ LANGUAGE plpgsql;
-- CALL prc_5_peer_points_change('tmp_ref');
-- FETCH ALL IN "tmp_ref";



-- 6) Find the most frequently checked task for each day
DROP PROCEDURE IF EXISTS prc_6_popular_task_in_same_day();
CREATE OR REPLACE PROCEDURE prc_6_popular_task_in_same_day(ref refcursor)
AS $$
    BEGIN
        OPEN ref FOR
          WITH tmp AS (SELECT ch.check_date, ch.task, COUNT(*)
          FROM p2p
              JOIN checks ch ON ch.check_id = p2p.check_id
          GROUP BY ch.check_date, ch.task, p2p.p2p_state
          HAVING p2p.p2p_state = 'start'), 
          tmp2 AS (
          SELECT check_date, MAX(COUNT)
          FROM tmp
          GROUP BY check_date)

          SELECT tmp.check_date AS Day, tmp.task AS Task
          FROM tmp
              JOIN tmp2 ON tmp.check_date = tmp2.check_date
          WHERE tmp.count = tmp2.max
          ORDER BY 1 DESC;
    END;
$$ LANGUAGE plpgsql;
-- CALL prc_6_popular_task_in_same_day('tmp_ref');
-- FETCH ALL IN "tmp_ref";



-- 7) Find all peers who have completed the whole given block of tasks and the completion date of the last task
DROP PROCEDURE IF EXISTS prc_7_full_block_tasks();
CREATE OR REPLACE PROCEDURE prc_7_full_block_tasks(ref refcursor, name_block VARCHAR(255)) 
AS $$
    BEGIN
        OPEN ref FOR
        WITH task AS (
            SELECT *
            FROM tasks
            WHERE title SIMILAR TO CONCAT(name_block, '[0-9]%')
        ),
        last_project AS (
            SELECT MAX(title) AS title
            FROM task
        ),
        success AS (
            SELECT c.peer, c.task, c.check_date
            FROM checks c
            JOIN p2p ON c.check_id = p2p.check_id
            LEFT JOIN verter v ON c.check_id = v.check_id
            WHERE p2p.p2p_state = 'success'
            AND v.verter_state IS NULL OR v.verter_state = 'success'
            GROUP BY c.check_id
        )
        SELECT s.peer, s.check_date
        FROM success s
        JOIN last_project l ON s.task = l.title
        ORDER BY 2;
    END;
$$ LANGUAGE plpgsql;

-- CALL prc_7_full_block_tasks('tmp_ref', 'D');
-- FETCH ALL IN "tmp_ref";




-- 8) Determine which peer each student should go to for a check.
-- DROP PROCEDURE IF EXISTS prc_8_recommend_peer();
CREATE OR REPLACE PROCEDURE prc_8_recommend_peer(ref refcursor)
AS $$
    DECLARE
        r peers%rowtype;
    BEGIN
        DROP TABLE IF EXISTS tmp_result;
        CREATE TEMPORARY TABLE tmp_result (peer VARCHAR, RecommendedPeer VARCHAR);
        FOR r IN
            SELECT nickname FROM peers
        LOOP
            INSERT INTO tmp_result
            SELECT r.nickname AS Peer, tmp2.rec_fr AS RecommendedPeer
            FROM (
                SELECT tmp.rec_fr, COUNT(*) AS count
                FROM (
                    SELECT rec.recommended_peer AS rec_fr FROM recommendations rec
                    WHERE rec.peer IN (
                        SELECT fr.peer2 AS fr FROM friends fr
                        WHERE fr.peer1 = r.nickname
                    )
                    UNION ALL
                    SELECT rec.recommended_peer FROM recommendations rec
                    WHERE rec.peer IN (
                        SELECT fr.peer1 AS fr FROM friends fr
                        WHERE fr.peer2 = r.nickname
                    )
                ) AS tmp
                GROUP BY tmp.rec_fr
                HAVING tmp.rec_fr <> r.nickname
                ORDER BY count DESC
                LIMIT 1
            ) AS tmp2;
        END LOOP;
        OPEN ref FOR SELECT * FROM tmp_result;
    END;
$$ LANGUAGE plpgsql;
-- CALL prc_8_recommend_peer('tmp_ref');
-- FETCH ALL IN "tmp_ref";




-- 9) Determine the percentage of peers who: Started only block 1, Started only block 2,
-- Started both, Have not started any of them
DROP PROCEDURE IF EXISTS prc_9_count_different_peers();
CREATE OR REPLACE PROCEDURE prc_9_count_different_peers(IN block1 TEXT, IN block2 TEXT, ref refcursor) 
AS $$
  DECLARE
      count_peers BIGINT;
  BEGIN
        SELECT COUNT(*) INTO count_peers FROM peers;
        DROP TABLE IF EXISTS tmp_result;
        CREATE TEMPORARY TABLE tmp_result (StartedBlock1 BIGINT, StartedBlock2 BIGINT, StartedBothBlock BIGINT, DidntStartAnyBlock BIGINT);
            WITH start_block1 AS (
              SELECT DISTINCT c.peer
              FROM checks c
              WHERE c.task SIMILAR TO concat(block1, '[0-9]%')
            ),
            start_block2 AS (
              SELECT DISTINCT c.peer
              FROM checks c
              WHERE c.task SIMILAR TO concat(block2, '[0-9]%')
            ),
            start_only_block1 AS (
              SELECT peer FROM start_block1
              EXCEPT
              SELECT peer FROM start_block2
            ),
            start_only_block2 AS (
              SELECT peer FROM start_block2
              EXCEPT
              SELECT peer FROM start_block1
            ),
            start_both_block AS (
              SELECT peer FROM start_block1
              INTERSECT
              SELECT peer FROM start_block2
            ),
            didnt_start AS (
              SELECT COUNT(peers.nickname) AS didi
              FROM peers
              LEFT JOIN checks c ON peers.nickname = c.peer
              WHERE c.peer IS NULL
            )
         
            INSERT INTO tmp_result VALUES((((SELECT COUNT(*) FROM start_only_block1) * 100) / count_peers), 
                                          (((SELECT COUNT(*) FROM start_only_block2) * 100) / count_peers), 
                                          (((SELECT COUNT(*) FROM start_both_block) * 100) / count_peers), 
                                          (((SELECT didi FROM didnt_start) * 100) / count_peers));
            OPEN ref For SELECT * FROM tmp_result;
  END;
$$ LANGUAGE plpgsql;

-- CALL prc_9_count_different_peers('C', 'D', 'tmp_ref');
-- FETCH ALL IN "tmp_ref";



-- 10) Determine the percentage of peers who have ever successfully passed a check on their birthday
DROP PROCEDURE IF EXISTS prc_10_calculate_success_failure_per_inHB();
CREATE OR REPLACE PROCEDURE prc_10_calculate_success_failure_per_inHB(OUT SuccessfulPercentage NUMERIC, OUT UnsuccessfulPercentage NUMERIC) AS $$
DECLARE
    total_peers INTEGER;
BEGIN
    SELECT COUNT(*) 
    INTO total_peers
    FROM peers p
    JOIN checks ch ON p.nickname = ch.peer
    WHERE TO_CHAR(p.birthday, 'MM-DD') = TO_CHAR(ch.check_date, 'MM-DD');
    IF total_peers > 0 THEN
        SELECT COUNT(*) * 100.0 / total_peers
        INTO SuccessfulPercentage
        FROM p2p p
        JOIN checks ch ON p.check_id = ch.check_id
        JOIN peers pe ON pe.nickname = ch.peer
        WHERE TO_CHAR(pe.birthday, 'MM-DD') = TO_CHAR(ch.check_date, 'MM-DD')
        AND p.p2p_state = 'success';
        SELECT COUNT(*) * 100.0 / total_peers
        INTO UnsuccessfulPercentage
        FROM p2p p
        JOIN checks ch ON p.check_id = ch.check_id
        JOIN peers pe ON pe.nickname = ch.peer
        WHERE TO_CHAR(pe.birthday, 'MM-DD') = TO_CHAR(ch.check_date, 'MM-DD')
        AND p.p2p_state = 'failure';
    ELSE
        SuccessfulPercentage := 0;
        UnsuccessfulPercentage := 0;
    END IF;
END;
$$ 
LANGUAGE plpgsql;
-- CALL prc_10_calculate_success_failure_per_inHB(NULL, NULL);




-- 11) Determine all peers who did the given tasks 1 and 2, but did not do task 3
DROP PROCEDURE IF EXISTS prc_11_two_from_three();
CREATE OR REPLACE PROCEDURE prc_11_two_from_three(IN Task1Name VARCHAR(255), IN Task2Name VARCHAR(255), IN Task3Name VARCHAR(255), ref refcursor) 
AS $$
  BEGIN
   OPEN ref FOR
      SELECT DISTINCT c.peer
      FROM checks c
      	JOIN verter v ON v.check_id = c.check_id
      WHERE verter_state = 'success' AND c.task IN (Task1Name, Task2Name)
      AND c.peer NOT IN (
          SELECT DISTINCT c2.peer
          FROM checks c2
          WHERE c2.task = Task3Name
      );
  END;
$$ LANGUAGE plpgsql;
--CALL prc_11_two_from_three('C4_Math', 'C3_String+', 'C5_Decimal', 'tmp_ref');
--FETCH ALL IN "tmp_ref";





-- 12) Using recursive common table expression, output the number of preceding tasks for each task
DROP PROCEDURE IF EXISTS prc_12_prev_task_count();
CREATE OR REPLACE PROCEDURE prc_12_prev_task_count(ref refcursor)
AS $$
    BEGIN
        OPEN ref FOR
            WITH RECURSIVE prev_tasks as (
                SELECT title, parent_task, 0 AS count
                FROM tasks t
                WHERE parent_task IS NULL
                UNION ALL
                SELECT t.title, t.parent_task, count + 1
                FROM tasks t
                    JOIN prev_tasks pt ON pt.title = t.parent_task
            )
            SELECT title AS Task, count AS PrevCount
            FROM prev_tasks;
    END;
$$ LANGUAGE plpgsql;
-- CALL prc_12_prev_task_count('tmp_ref');
-- FETCH ALL IN "tmp_ref";




-- 13) Find "lucky" days for checks. A day is considered "lucky" if it has at least N consecutive successful checks
DROP PROCEDURE IF EXISTS prc_13_lucky_days();
CREATE OR REPLACE PROCEDURE prc_13_lucky_days(IN N INT) 
AS $$
  DECLARE
      consecutive_success INT := 0;
      ch_date DATE := (SELECT MIN(DATE_TRUNC('day', check_date)) FROM checks);
  BEGIN
      DROP TABLE IF EXISTS temp_success_days;
      CREATE TEMPORARY TABLE temp_success_days(check_date DATE);
      DROP TABLE IF EXISTS lucky;
      CREATE TEMPORARY TABLE lucky AS (
          SELECT c.check_id, c.check_date, p2p_time, p2p_state, verter_state
          FROM checks c
          	JOIN p2p p ON c.check_id = p.check_id
          	LEFT JOIN verter v ON c.check_id = v.check_id
          	JOIN tasks t ON c.task = t.title
          	JOIN xp ON c.check_id = xp.check_id
          WHERE p.p2p_state IN ('success', 'failure')
          	AND (v.verter_state IN ('success', 'failure') OR v.verter_state IS NULL)
          	AND xp.xp_amount >= t.max_xp * 0.8
      );
      DROP TABLE IF EXISTS lag_result;
      CREATE TEMPORARY TABLE lag_result AS (
          SELECT
              check_date,
              LAG(p2p_state) OVER (ORDER BY p2p_time) = 'success'
              AND LAG(verter_state) OVER (ORDER BY p2p_time) = 'success' AS consecutive_values
          FROM lucky
      );
      FOR ch_date IN (SELECT DISTINCT DATE_TRUNC('day', check_date) FROM checks ORDER BY DATE_TRUNC('day', check_date)) LOOP
          SELECT COUNT(*)
          INTO consecutive_success
          FROM lag_result
          WHERE DATE_TRUNC('day', check_date) = ch_date
          AND consecutive_values = 'True';
          IF consecutive_success >= N - 1 THEN
              INSERT INTO temp_success_days VALUES (ch_date);
          END IF;
          consecutive_success := 0;
      END LOOP;
  END;
$$ LANGUAGE plpgsql;
-- CALL prc_13_lucky_days(2);
-- SELECT * FROM temp_success_days;
-- DROP TABLE IF EXISTS temp_success_days;
-- DROP TABLE IF EXISTS lucky;
-- DROP TABLE IF EXISTS lag_result;





-- 14) Find the peer with the highest amount of XP
DROP PROCEDURE IF EXISTS prc_14_get_xp();
CREATE OR REPLACE PROCEDURE prc_14_get_xp(ref refcursor)
AS $$
    BEGIN
        OPEN ref FOR
          SELECT peer AS Peer, sum(xp) AS XP
          FROM (SELECT ch.peer AS peer, ch.task, MAX(xp_amount) AS xp
              FROM xp
                  JOIN checks ch ON ch.check_id = xp.check_id
              GROUP BY ch.peer, ch.task) AS tmp
          GROUP BY peer
          ORDER BY 2 DESC
          LIMIT 1;
    END;
$$ LANGUAGE plpgsql;
-- CALL prc_14_get_xp('tmp_ref');
-- FETCH ALL IN "tmp_ref";





-- 15) Determine the peers that came before the given time at least N times during the whole time
DROP PROCEDURE IF EXISTS prc_15_lucky_days();
CREATE OR REPLACE PROCEDURE prc_15_lucky_days(ref refcursor, target_time TIME, target_count INT) 
AS $$
  BEGIN
      OPEN REF FOR
        SELECT peer
        FROM time_tracking
        WHERE time_tracking < target_time AND state = 1
        GROUP BY peer
        HAVING COUNT(*) >= target_count
        ORDER BY 1 DESC;
  END;
$$ LANGUAGE plpgsql;
-- CALL prc_15_lucky_days('tmp_ref', '12:00:00', 1);
-- FETCH ALL IN "tmp_ref";




-- 16) Determine the peers who left the campus more than M times during the last N days
DROP PROCEDURE IF EXISTS prc_16_count_peers_exits();
CREATE OR REPLACE PROCEDURE prc_16_count_peers_exits(IN N INT, IN M INT, ref refcursor)
AS $$
    BEGIN
        OPEN ref FOR
            SELECT peer
            FROM (SELECT peer, COUNT(*) AS count
                FROM time_tracking
                WHERE date_tracking > (CURRENT_DATE - N) AND date_tracking <> CURRENT_DATE
                GROUP BY peer, state
                HAVING state=2) AS tmp
            WHERE COUNT > M;
    END;
$$ LANGUAGE plpgsql;
-- CALL prc_16_count_peers_exits(100, 0, 'tmp_ref');
-- FETCH ALL IN "tmp_ref";




-- 17) Determine for each month the percentage of early entries
DROP PROCEDURE IF EXISTS prc_17_early_entries();
CREATE OR REPLACE PROCEDURE prc_17_early_entries(ref refcursor)
AS $$
  BEGIN
      OPEN ref FOR
        WITH all_visits AS (
            SELECT
                TO_CHAR(p.birthday, 'Month') AS month,
                COUNT(*) AS visits
            FROM peers p
            JOIN time_tracking tt ON p.nickname = tt.peer
            WHERE TO_CHAR(tt.date_tracking, 'Month') = TO_CHAR(p.birthday, 'Month') 
                AND tt.state = 1
            GROUP BY TO_CHAR(p.birthday, 'Month')
        ),
        early_visits AS (
            SELECT
                TO_CHAR(p.birthday, 'Month') AS month,
                COUNT(*) AS visits
            FROM peers p
            JOIN time_tracking tt ON p.nickname = tt.peer
            WHERE TO_CHAR(tt.date_tracking, 'Month') = TO_CHAR(p.birthday, 'Month') 
                AND tt.state = 1
                AND EXTRACT(HOUR FROM time_tracking) < 12
            GROUP BY TO_CHAR(p.birthday, 'Month')
        )
        SELECT
            b.month AS "Month",
            CASE WHEN b.visits = 0 THEN 0.00
                ELSE ROUND((e.visits::decimal / b.visits) * 100, 2)
            END AS "EarlyEntries"
        FROM
            all_visits b
        FULL OUTER JOIN
            early_visits e ON b.month = e.month
        ORDER BY
            b.month;
  END;
$$ LANGUAGE plpgsql;
-- CALL prc_17_early_entries('tmp_ref');
-- FETCH ALL IN "tmp_ref";
