-- Active: 1681983930813@@127.0.0.1@5432@info21

DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS xp CASCADE;
DROP TABLE IF EXISTS verter CASCADE;
DROP TABLE IF EXISTS checks CASCADE;
DROP TABLE IF EXISTS p2p CASCADE;
DROP TABLE IF EXISTS transferred_points CASCADE;
DROP TABLE IF EXISTS friends CASCADE;
DROP TABLE IF EXISTS peers CASCADE;
DROP TABLE IF EXISTS recommendations CASCADE;
DROP TABLE IF EXISTS time_tracking CASCADE;
DROP TYPE IF EXISTS check_state CASCADE;

CREATE TABLE
    tasks(
        title VARCHAR(20) PRIMARY KEY UNIQUE NOT NULL,
        parent_task VARCHAR(20) NULL,
        max_xp INT CHECK (max_xp > 0) NOT NULL,
        CONSTRAINT fk_tasks_parent_task FOREIGN KEY (parent_task) REFERENCES tasks(title)
    );

CREATE TABLE
    peers(
        nickname VARCHAR(10) PRIMARY KEY UNIQUE NOT NULL,
        birthday DATE NOT NULL
    );

CREATE TYPE check_state AS ENUM ('start', 'success', 'failure');

CREATE TABLE
    checks(
        check_id SERIAL PRIMARY KEY,
        peer VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        task VARCHAR(20) REFERENCES tasks(title) NOT NULL,
        check_date DATE NOT NULL
    );

CREATE TABLE
    p2p(
        p2p_id SERIAL PRIMARY KEY,
        check_id BIGINT REFERENCES checks(check_id) NOT NULL,
        checking_peer VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        p2p_state check_state NOT NULL,
        p2p_time TIME NOT NULL
    );

CREATE TABLE
    verter(
        verter_id SERIAL PRIMARY KEY,
        check_id BIGINT REFERENCES checks(check_id) NOT NULL,
        verter_state check_state NOT NULL,
        verter_time TIME NOT NULL
    );

CREATE TABLE
    xp(
        xp_id SERIAL PRIMARY KEY,
        check_id BIGINT REFERENCES checks(check_id) NOT NULL,
        xp_amount NUMERIC(7, 3) NOT NULL
    );

CREATE TABLE
    transferred_points(
        transferred_point_id SERIAL PRIMARY KEY,
        checking_peer VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        checked_peer VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        points_amount INT NOT NULL
    );

CREATE TABLE
    friends(
        friend_id SERIAL PRIMARY KEY,
        peer1 VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        peer2 VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        UNIQUE(peer1, peer2)
    );

CREATE TABLE
    recommendations(
        recommendation_id SERIAL PRIMARY KEY,
        peer VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        recommended_peer VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        UNIQUE(peer, recommended_peer)
    );

CREATE TABLE
    time_tracking(
        time_tracking_id SERIAL PRIMARY KEY,
        peer VARCHAR(10) REFERENCES peers(nickname) NOT NULL,
        date_tracking DATE NOT NULL,
        time_tracking TIME NOT NULL,
        state SMALLINT CHECK(
            state = 1
            OR state = 2
        ) NOT NULL
    );

INSERT INTO tasks
VALUES (
        'C2_SimpleBashUtils',
        NULL,
        350
    ), (
        'C3_String+',
        'C2_SimpleBashUtils',
        750
    ), (
        'C4_Math',
        'C2_SimpleBashUtils',
        300
    ), (
        'C5_Decimal',
        'C2_SimpleBashUtils',
        350
    ), (
        'C6_Matrix', 
        'C5_Decimal', 
        300
    ), (
        'C7_SmartCalc v1.0',
        'C6_Matrix',
        500
    ), (
        'D01_Linux', 
        'C3_String+', 
        300
    );

INSERT INTO peers
VALUES ('lavondas', '2000-12-26'), ('papawfen', '1999-06-13'), ('karleenk', '2001-09-15'), ('sharronr', '2001-09-08'), ('cmerlyn', '1997-09-10'), ('hhullen', '1996-08-13'), ('ebonicra', '1999-07-02');

INSERT INTO checks
VALUES (
        1,
        'cmerlyn',
        'C4_Math',
        '2021-11-05'
    ), (
        2,
        'cmerlyn',
        'C4_Math',
        '2021-12-11'
    ), (
        3,
        'lavondas',
        'C2_SimpleBashUtils',
        '2022-05-21'
    ), (
        4,
        'papawfen',
        'C3_String+',
        '2022-06-13'
    ), (
        5,
        'karleenk',
        'C5_Decimal',
        '2022-08-15'
    ), (
        6,
        'cmerlyn',
        'C3_String+',
        '2022-09-15'
    ), (
        7,
        'lavondas',
        'C3_String+',
        '2022-09-15'
    ), (
        8,
        'karleenk',
        'C5_Decimal',
        '2022-09-15'
    ), (
        9,
        'sharronr',
        'D01_Linux',
        '2022-09-20'
    );

INSERT INTO p2p
VALUES (
        1,
        1,
        'papawfen',
        'start',
        '13:03'
    ), (
        2,
        1,
        'papawfen',
        'success',
        '13:16'
    ), (
        3,
        2,
        'hhullen',
        'start',
        '17:06'
    ), (
        4,
        2,
        'hhullen',
        'success',
        '17:23'
    ), (
        5,
        3,
        'sharronr',
        'start',
        '12:11'
    ), (
        6,
        3,
        'sharronr',
        'success',
        '12:25'
    ), (
        7,
        4,
        'karleenk',
        'start',
        '23:12'
    ), (
        8,
        4,
        'karleenk',
        'failure',
        '23:29'
    ), (
        9,
        5,
        'papawfen',
        'start',
        '19:07'
    ), (
        10,
        5,
        'papawfen',
        'success',
        '19:33'
    ), (
        11,
        6,
        'ebonicra',
        'start',
        '01:01'
    ), (
        12,
        6,
        'ebonicra',
        'success',
        '01:58'
    ), (
        13,
        7,
        'ebonicra',
        'start',
        '12:46'
    ), (
        14,
        7,
        'ebonicra',
        'success',
        '13:12'
    ), (
        15,
        8,
        'papawfen',
        'start',
        '16:15'
    ), (
        16,
        8,
        'papawfen',
        'success',
        '17:30'
    ), (
        17,
        9,
        'lavondas',
        'start',
        '22:22'
    ), (
        18,
        9,
        'lavondas',
        'success',
        '22:33'
    );


INSERT INTO verter
VALUES 
(1, 1, 'start', '13:16'), 
(2, 1, 'failure', '14:16'), 
(3, 2, 'start', '17:23'), 
(4, 2, 'success', '17:24'), 
(5, 3, 'start', '12:25'), 
(6, 3, 'success', '12:26'), 
(7, 5, 'start', '19:33'), 
(8, 5, 'success', '19:35'), 
(9, 6, 'start', '01:59'), 
(10, 6, 'success', '02:02'), 
(11, 7, 'start', '13:12'), 
(12, 7, 'success', '13:20'), 
(13, 8, 'start', '17:30'), 
(14, 8, 'success', '17:45'),
(15, 9, 'start', '22:33'), 
(16, 9, 'success', '22:44');

INSERT INTO xp
VALUES (1, 2, 297), (2, 3, 335), (3, 5, 326), (4, 6, 750), (5, 7, 350), (6, 8, 340), (7, 9, 100);

INSERT INTO transferred_points
VALUES (1, 'cmerlyn', 'papawfen', 1), (2, 'cmerlyn', 'hhullen', 1), (3, 'lavondas', 'sharronr', 2), (4, 'papawfen', 'karleenk', 2), (5, 'karleenk', 'papawfen', 1), (6, 'ebonicra', 'cmerlyn', 1), (7, 'ebonicra', 'lavondas', 1);

INSERT INTO friends
VALUES (1, 'lavondas', 'papawfen'), (2, 'cmerlyn', 'sharronr'), (3, 'karleenk', 'hhullen'), (4, 'lavondas', 'karleenk'), (5, 'papawfen', 'sharronr'), (6, 'ebonicra', 'lavondas');

INSERT INTO recommendations
VALUES (1, 'cmerlyn', 'papawfen'), (2, 'cmerlyn', 'sharronr'), (3, 'lavondas', 'sharronr'), (4, 'lavondas', 'cmerlyn'), (5, 'karleenk', 'papawfen'), (6, 'sharronr', 'cmerlyn');

INSERT INTO time_tracking
VALUES (
        1,
        'cmerlyn',
        '2021-11-05',
        '12:23',
        1
    ), (
        2,
        'cmerlyn',
        '2021-11-05',
        '20:02',
        2
    ), (
        3,
        'papawfen',
        '2022-07-13',
        '17:01',
        1
    ), (
        4,
        'papawfen',
        '2022-07-13',
        '19:57',
        2
    ), (
        5,
        'papawfen',
        '2022-07-13',
        '20:13',
        1
    ), (
        6,
        'papawfen',
        '2022-07-13',
        '23:23',
        2
    ), (
        7,
        'karleenk',
        '2022-08-15',
        '11:13',
        1
    ), (
        8,
        'karleenk',
        '2022-08-15',
        '22:34',
        2
    ), (
        9,
        'ebonicra',
        '2023-08-10',
        '11:15',
        1
    ), (
        10,
        'karleenk',
        '2023-08-10',
        '13:22',
        1
    ), (
        11,
        'karleenk',
        '2023-08-10',
        '15:57',
        2
    ), (
        12,
        'karleenk',
        '2023-08-10',
        '16:05',
        1
    ), (
        13,
        'ebonicra',
        '2023-08-10',
        '17:11',
        2
    ), (
        14,
        'karleenk',
        '2023-08-10',
        '22:31',
        2
    ), (
        15,
        'karleenk',
        '2023-08-10',
        '22:50',
        1
    ), (
        16,
        'karleenk',
        '2023-08-10',
        '23:40',
        2
    ), (
        17,
        'sharronr',
        '2023-08-11',
        '18:14',
        1
    ), (
        18,
        'sharronr',
        '2023-08-11',
        '21:50',
        2
    ), (
        19,
        'lavondas',
        '2023-08-11',
        '12:02',
        1
    ), (
        20,
        'lavondas',
        '2023-08-11',
        '22:02',
        2
    ), (
        21,
        'ebonicra',
        '2024-07-02',
        '11:02',
        1
    ), (
        22,
        'ebonicra',
        '2024-07-02',
        '15:09',
        2
    );


CREATE OR REPLACE PROCEDURE EXPORT_DATA(table_name VARCHAR(20), file_path TEXT, separator CHARACTER(1)) AS $$
    DECLARE
	BEGIN
        EXECUTE format('COPY %s TO %L WITH DELIMITER %L CSV HEADER', table_name, file_path, separator);
	END;
$$ LANGUAGE PLPGSQL;


CREATE OR REPLACE PROCEDURE IMPORT_DATA(table_name VARCHAR(20), file_path TEXT, separator CHARACTER(1)) AS $$
    DECLARE
	BEGIN
        EXECUTE format('COPY %s FROM %L WITH DELIMITER %L CSV HEADER', table_name, file_path, separator);
	END;
$$ LANGUAGE PLPGSQL;


-- call export_data('p2p', '/Users/lavondas/sql/SQL2_Info21_v1.0-1/src/p2p.scv', ';');
-- call import_data('p2p', '/Users/lavondas/sql/SQL2_Info21_v1.0-1/src/p2p.scv', ';');
