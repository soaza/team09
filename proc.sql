--||------------------ TRIGGERS --------------------||--

--||------------------ Neil --------------------||--


--||------------------ Kim Guan --------------------||--

-- Trigger 3: overlapping of start_time-end_time in Course_sessions as each room used to conduct
-- at most 1 course session at any time
-- TABLE: Course_sessions

create or replace function course_session_duration_overlap() returns trigger
    language plpgsql
as
$$
DECLARE
-- new duration in hours
    new_session_duration INTEGER;

BEGIN
    SELECT T.duration
    INTO new_session_duration
    FROM (Course_Sessions NATURAL JOIN Courses) T
    WHERE T.course_id = NEW.course_id;

    IF EXISTS(
            SELECT *
            FROM (Course_Sessions NATURAL JOIN Courses) T
            WHERE session_date = NEW.session_date
              AND rid = NEW.rid
              AND (T.launch_date <> NEW.launch_date OR T.course_id <> NEW.course_id)
              -- new session ends in between a session
              AND (
                    (EXTRACT(hours FROM start_time) <= EXTRACT(hours FROM NEW.start_time) + new_session_duration
                        AND EXTRACT(hours FROM NEW.start_time) + new_session_duration <= EXTRACT(hours FROM end_time))
                    -- new session starts in between a session
                    OR
                    (start_time <= NEW.start_time AND NEW.start_time <= end_time)
                ))
    THEN
        RAISE NOTICE 'New course_session timing overlaps with existing timings,each room used to conduct at most 1 course session at any time ';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$;

create trigger course_session_duration_overlap_trigger
    before insert or update
    on course_sessions
    for each row
execute procedure course_session_duration_overlap();

-- Trigger 6: Instructor who is assigned to teach a course session must be specialized in that course area
-- TABLE: Course_sessions
create or replace function instructor_specialise_session() returns trigger
    language plpgsql
as
$$
BEGIN
    IF (NEW.eid <> OLD.eid) THEN
        IF NOT EXISTS(
                SELECT T.eid
                FROM (Specialises NATURAL JOIN Courses) T
                WHERE T.eid = NEW.eid
                  and T.course_id = NEW.course_id
            ) THEN
            RETURN NULL;
        ELSE
            RETURN NEW;
        END IF;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


CREATE TRIGGER instructor_specialise_session_trigger
    BEFORE INSERT OR UPDATE
    ON Course_Sessions
    FOR EACH ROW
EXECUTE FUNCTION instructor_specialise_session();

-- Trigger 7:
-- Each instructor can teach at most one course session at any hour.
-- Each instructor must not be assigned to teach two consecutive course sessions;
-- i.e. there must be at least one hour of break between any two course sessions that the instructor is teaching.
-- TABLE: Course_sessions

create or replace function instructor_session_duration_overlap() returns trigger
    language plpgsql
as
$$
BEGIN
    -- Each instructor can teach at most one course session at any hour.
    IF EXISTS(
            SELECT *
            FROM Course_Sessions
            WHERE eid = NEW.eid
              AND session_date = NEW.session_date
              AND (end_time = NEW.start_time OR start_time = NEW.end_time)
              -- we do not compare with old tuple if its an update
              AND (OLD.launch_date <> NEW.launch_date OR course_session_id <> NEW.course_session_id)
        )
    THEN
        RAISE NOTICE 'Instructor can teach at most one course session at any hour and there must be at least one hour of break between any two course sessions that the instructor is teaching.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

create trigger instructor_session_duration_overlap_trigger
    before insert or update
    on course_sessions
    for each row
execute procedure instructor_session_duration_overlap();


-- Trigger 10: course_session_id inserted into Course_sessions must be in consecutive order
-- TABLE: Course_sessions
create or replace function consecutive_sid_course_sessions() returns trigger
    language plpgsql
as
$$
DECLARE
    current_highest_sid INTEGER;

BEGIN
    SELECT max(course_session_id)
    INTO current_highest_sid
    FROM Course_Sessions;
    IF NEW.course_session_id <> current_highest_sid + 1 THEN
        RAISE NOTICE 'Course_session_id must be consecutively numbered.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


create trigger consecutive_sid_course_sessions_trigger
    before insert or update
    on Course_sessions
    for each row
execute procedure consecutive_sid_course_sessions();

-- Trigger 11: Course_session_date must be before depart_date of employee
-- TABLE: Course_sessions
create or replace function course_session_date_before_depart_date() returns trigger
    language plpgsql
as
$$
BEGIN
    IF NOT EXISTS(
            SELECT *
            FROM (Course_Sessions natural join Employees) T
            WHERE T.eid = NEW.eid
              AND T.depart_date > NEW.session_date
        ) THEN
        RAISE NOTICE 'Course_session date must be before depart_date of employee.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

create trigger course_session_date_before_depart_date_trigger
    before insert or update
    on Course_sessions
    for each row
execute procedure course_session_date_before_depart_date();



--||------------------ Constance --------------------||--

-- Trigger 4: Each course offering has a start date and an end date that
-- is determined by the dates of its earliest and latest sessions, respectively
CREATE OR REPLACE FUNCTION offering_start_end_func() RETURNS TRIGGER
AS $$
DECLARE
    curr_start_date DATE;
    curr_end_date DATE;

BEGIN
    IF (TG_OP = 'DELETE') THEN
        SELECT session_date FROM Course_Sessions
        WHERE launch_date = OLD.launch_date AND course_id = OLD.course_id
        ORDER BY session_date ASC LIMIT 1 INTO curr_start_date;

        SELECT session_date FROM Course_Sessions
        WHERE launch_date = OLD.launch_date AND course_id = OLD.course_id
        ORDER BY session_date DESC LIMIT 1 INTO curr_end_date;

        UPDATE Offerings SET actual_start_date = curr_start_date, end_date = curr_end_date
        WHERE launch_date = OLD.launch_date and course_id = OLD.course_id;

        RETURN OLD;

    ELSIF  (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        SELECT actual_start_date FROM Offerings
        WHERE launch_date = NEW.launch_date and course_id = NEW.course_id INTO curr_start_date;

        SELECT end_date FROM Offerings
        WHERE launch_date = NEW.launch_date and course_id = NEW.course_id INTO curr_end_date;

        IF curr_start_date IS NULL AND curr_end_date IS NULL THEN
            UPDATE Offerings SET actual_start_date = NEW.session_date, end_date = NEW.session_date
            WHERE launch_date = NEW.launch_date and course_id = NEW.course_id;

        ELSIF (NEW.session_date < curr_start_date) THEN
            UPDATE Offerings SET actual_start_date = NEW.session_date
            WHERE launch_date = NEW.launch_date and course_id = NEW.course_id;

        ELSIF (NEW.session_date > curr_end_date) THEN
            UPDATE Offerings SET end_date = NEW.session_date
            WHERE launch_date = NEW.launch_date and course_id = NEW.course_id;
        END IF;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER offering_start_end_trigger
AFTER INSERT OR UPDATE OR DELETE ON Course_Sessions
FOR EACH ROW EXECUTE FUNCTION offering_start_end_func();

-- Trigger 9: duration of course = duration of course session and also checks that deadline is not over yet.
-- Before inserting/updating into sessions, duration of end time should be start time + end time
CREATE OR REPLACE FUNCTION duration_session_func() RETURNS TRIGGER
AS $$
DECLARE
    session_duration INTEGER;
    offering_registration_deadline DATE;
BEGIN
    SELECT duration FROM Courses WHERE course_id = NEW.course_id INTO session_duration;

    SELECT registration_deadline FROM Offerings WHERE launch_date = NEW.launch_date AND course_id = NEW.course_id INTO offering_registration_deadline;

    IF NEW.start_time + session_duration * '1hour'::interval <> NEW.end_time THEN
        RAISE NOTICE 'Note: Not updated/inserted as the session duration does not match the course duration.';
        RETURN NULL;

    ELSIF offering_registration_deadline < NOW()::DATE THEN
        RAISE NOTICE 'Note: Not updated/inserted as the offering registration deadline is over.';
        RETURN NULL;

    ELSE
        RETURN NEW;

    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER duration_session_trigger
BEFORE INSERT OR UPDATE ON Course_Sessions
FOR EACH ROW EXECUTE FUNCTION duration_session_func();

CREATE OR REPLACE FUNCTION max_one_session_func() RETURNS TRIGGER
AS $$
DECLARE
    num_registered INTEGER;
    num_redeemed INTEGER;
    customer_id INTEGER;

BEGIN

    SELECT cust_id FROM Credit_cards WHERE credit_card_num = NEW.credit_card_num INTO customer_id;

    SELECT count(*) FROM Registers RG INNER JOIN Credit_cards ON RG.credit_card_num = Credit_cards.credit_card_num
    WHERE RG.launch_date = NEW.launch_date AND RG.course_id = NEW.course_id AND Credit_cards.cust_id = customer_id
    INTO num_registered;

    SELECT count(*) FROM Redeems RD INNER JOIN Credit_cards CC ON RD.credit_card_num = CC.credit_card_num
    WHERE RD.launch_date = NEW.launch_date AND RD.course_id = NEW.course_id AND CC.cust_id = customer_id
    INTO num_redeemed;

    IF num_registered + num_redeemed <> 0 THEN
        RAISE NOTICE 'Note: Not updated/inserted as customer can only register for at most one session for each offering.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER max_one_session_redeem_trigger
BEFORE INSERT OR UPDATE ON Redeems
FOR EACH ROW EXECUTE FUNCTION max_one_session_func();

CREATE TRIGGER max_one_session_register_trigger
BEFORE INSERT OR UPDATE ON Registers
FOR EACH ROW EXECUTE FUNCTION max_one_session_func();

-- Trigger 1: customers must register before registration_deadline Offerings
CREATE OR REPLACE FUNCTION reg_bef_deadline_func() RETURNS TRIGGER
AS $$
DECLARE
    reg_deadline DATE;
BEGIN
    SELECT registration_deadline
    FROM Offerings O
    WHERE O.launch_date = NEW.launch_date AND O.course_id = NEW.course_id
    INTO reg_deadline;

    IF NEW.registration_date > reg_deadline THEN
        RAISE NOTICE 'Note: Not updated/inserted as registration deadline is over.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reg_bef_deadline_trigger
BEFORE INSERT OR UPDATE ON Registers
FOR EACH ROW EXECUTE FUNCTION reg_bef_deadline_func();

CREATE OR REPLACE FUNCTION redeem_bef_deadline_func() RETURNS TRIGGER
AS $$
DECLARE
    reg_deadline DATE;
BEGIN
    SELECT registration_deadline
    FROM Offerings O
    WHERE O.launch_date = NEW.launch_date AND O.course_id = NEW.course_id
    INTO reg_deadline;

    IF NEW.redeem_date > reg_deadline THEN
        RAISE NOTICE 'Note: Not updated/inserted as registration deadline is over.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER redeem_bef_deadline_trigger
BEFORE INSERT OR UPDATE ON Redeems
FOR EACH ROW EXECUTE FUNCTION redeem_bef_deadline_func();

CREATE OR REPLACE FUNCTION offering_capacity_func() RETURNS TRIGGER
AS $$
DECLARE
    offering_seating_capacity INTEGER;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        SELECT sum(seating_capacity)
        FROM Course_Sessions CS INNER JOIN Rooms R ON CS.rid = R.rid
        WHERE CS.launch_date = NEW.launch_date AND CS.course_id = NEW.course_id
        INTO offering_seating_capacity;

        IF offering_seating_capacity IS NULL THEN
            offering_seating_capacity := 0;
        END IF;

        UPDATE Offerings SET seating_capacity = offering_seating_capacity
        WHERE launch_date = NEW.launch_date AND course_id = NEW.course_id;
        RETURN NEW;
    ELSE
        SELECT sum(seating_capacity)
        FROM Course_Sessions CS INNER JOIN Rooms R ON CS.rid = R.rid
        WHERE CS.launch_date = OLD.launch_date AND CS.course_id = OLD.course_id
        INTO offering_seating_capacity;

        IF offering_seating_capacity IS NULL THEN
            offering_seating_capacity := 0;
        END IF;

        UPDATE Offerings SET seating_capacity = offering_seating_capacity
        WHERE launch_date = OLD.launch_date AND course_id = OLD.course_id;
        RETURN OLD;
    END IF;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER offering_capacity_trigger
AFTER INSERT OR UPDATE OR DELETE ON Course_sessions
FOR EACH ROW EXECUTE FUNCTION offering_capacity_func();

--||------------------ Esmanda --------------------||--


--||------------------ FUNCTIONS --------------------||--

--||------------------ Neil --------------------||--

-- 3. add_customer:
create or replace procedure add_customer(custname text, homeaddress text, contactnumber integer, custemail text,
                              creditcardnum integer, cardexpirydate date, cardcvv integer)
    language plpgsql
as
$$
DECLARE
    custId INT;
BEGIN
    custId := 11;
    INSERT INTO Customers VALUES (custId, homeAddress, contactNumber, custName, custEmail);
    INSERT INTO Credit_cards VALUES (creditCardNum, cardCVV, cardExpiryDate, NULL, custId);
END;
$$;



-- 4. update_credit_card:
CREATE OR REPLACE PROCEDURE update_credit_card(custId INT, creditCardNum INTEGER, cardExpiryDate DATE, cardCVV INTEGER)
AS
$$
BEGIN
    UPDATE Credit_cards
    SET credit_card_num  = creditCardNum,
        cvv              = cardCVV,
        card_expiry_date = cardExpiryDate
    WHERE cust_id = custId;
END;
$$ LANGUAGE plpgsql;


--||------------------ Kim Guan --------------------||--

-- 5. add_course:
--  This routine is used to add a new course.
--  inputs: course title, course description, course area, and duration(in terms of hours).
--  The course identifier is generated by the system.
create or replace procedure add_course(title text, course_description text, course_area_name text, duration integer)
    language plpgsql
as
$$
DECLARE
    id INT;
BEGIN
    SELECT MAX(course_id) + 1 INTO id FROM Courses;
    INSERT INTO Courses (course_id, course_area_name, title, course_description, duration)
    VALUES (id, course_area_name, title, course_description, duration);
END;
$$;



-- 6. find_instructors
--  This routine is used to find all the instructors who could be assigned to teach a course session.
--  inputs: course identifier, session date, and session start hour.
--  The routine returns a table of records consisting of employee identifier and name.
create or replace function find_instructors(find_course_id integer, find_session_date date,
                                            find_start_time time without time zone)
    returns TABLE
            (
                eid      integer,
                emp_name text
            )
    language sql
as
$$
SELECT eid, emp_name
FROM (Specialises NATURAL JOIN Courses NATURAL JOIN Instructors NATURAL JOIN Employees) T
WHERE T.course_id = find_course_id
  -- filter out instructors that have lessons during the start time
  AND T.eid NOT IN (
    SELECT C.eid
    FROM Course_Sessions C
    where C.session_date = find_session_date
      and C.eid = T.eid
      and (
        -- start_time between the range
            (
                    extract(hours from C.start_time) < extract(hours from find_start_time)
                    and
                    extract(hours from find_start_time) < extract(hours from C.end_time) + 1
                )
            or
            (
                -- end time between the range
                        extract(hours from C.start_time) < extract(hours from find_start_time) + T.duration
                    and
                        extract(hours from find_start_time) + T.duration < extract(hours from C.end_time) + 1
                )
        )
)
$$;

create or replace function get_available_instructors(find_course_id integer, find_start_date date, find_end_date date)
    returns TABLE(emp_id integer, emp_name text, teaching_hours integer, day_available date, hours_arr time without time zone[])
    language plpgsql
as
$$
DECLARE
    curs CURSOR FOR (
                    SELECT *  FROM Instructors natural join Employees natural join Specialises natural join  courses T
                    WHERE T.course_id = find_course_id);
    possible_date DATE;
    days_arr DATE[];
    r RECORD;
    possible_hour TIME;
    possible_hours TIME[];
    total_sessions int;
    session_duration int;
BEGIN
    OPEN curs;
    LOOP
        FETCH curs into r;
        EXIT WHEN NOT FOUND;
        emp_id := r.eid;
        emp_name := r.emp_name;
        days_arr := ARRAY(
                SELECT day::date
                FROM generate_series( find_start_date, find_end_date, '1 day') day
            );
        -- Loop through all possible days
        FOREACH possible_date SLICE 0 IN ARRAY days_arr
        LOOP
            day_available := possible_date;
            --Loop through all possible hours
            hours_arr := '{}';
            possible_hours := '{09:00,10:00,11:00,13:00,14:00,15:00,16:00,17:00}';
            FOREACH possible_hour in ARRAY possible_hours
            LOOP
                 IF EXISTS (
                  SELECT T.eid
                  FROM find_instructors(find_course_id,possible_date,possible_hour) T
                  WHERE  T.eid = emp_id
                  ) THEN
                    hours_arr := array_append(hours_arr, possible_hour);
                END IF;
            END LOOP;

            -- we get total number of teaching hours that the instructor has been assigned for this month
            SELECT COUNT(*) INTO total_sessions
            FROM (Course_Sessions NATURAL JOIN Courses) C
            group by C.eid;

            SELECT duration INTO session_duration
            FROM Courses NATURAL JOIN Course_Sessions T
            WHERE T.eid = emp_id;

            teaching_hours := total_sessions * session_duration;


            RETURN  NEXT;

        END LOOP;

    END LOOP;
    END;
$$;

-- 8. find_rooms: This routine is used to find all the rooms that could be used for a course session.
-- The inputs to the routine include the following:
-- session date, session start hour, and session duration.
-- The routine returns a table of room identifiers.
create or replace function find_rooms(find_session_date date, find_start_time time without time zone, find_duration integer)
    returns TABLE
            (
                rid integer
            )
    language sql
as
$$
SELECT R.rid
FROM Rooms R
     -- exclude rooms occupied during start time
     -- and rooms occupied where duration overlaps
    EXCEPT
SELECT C.rid
FROM Course_Sessions C
WHERE C.session_date = find_session_date
  AND (
    -- start time is between existing sessions
        (C.start_time <= find_start_time and find_start_time < C.end_time)
        OR
        -- end time is between existing sessions
        (
                    extract(hour from find_start_time) + find_duration > extract(hour from C.start_time)
                AND
                    extract(hour from C.end_time) >= extract(hour from find_start_time) + find_duration
            )
    );
$$;


-- 21. update_instructor:
-- This routine is used to change the instructor for a course session.

-- input : course offering identifier, session number, and eid

-- If the course session has not yet started and the update request is valid,
-- the routine will process the request with the necessary updates.
-- NOTE: course offering identifier consists of launch date and course id as Offerings is a weak entity of Courses

create or replace procedure update_instructor(find_launch_date DATE ,find_course_id INTEGER,session_number INTEGER,updated_eid INTEGER)
language plpgsql
as
$$
DECLARE
    find_session_date DATE;
BEGIN

    SELECT S.session_date INTO find_session_date
            FROM Course_Sessions S
            WHERE S.course_session_id = session_number
            and S.launch_date = find_launch_date
            and S.course_id = find_course_id;

    IF find_session_date > CURRENT_DATE THEN
        UPDATE Course_Sessions S
        SET eid = updated_eid
        WHERE S.course_session_id = session_number
        and S.launch_date = find_launch_date
        and S.course_id = find_course_id;
    END IF;
END;
$$;


-- 22. update_room: This routine is used to change the room for a course session.

-- Inputs: course offering identifier, session number, and identifier of the new room.

-- If the course session has not yet started and the update request is valid, the routine
-- will process the request with the necessary updates.

-- Note that update request should not be performed if the number of registrations for the session
-- exceeds the seating capacity of the new room.
-- NOTE: course offering identifier consists of launch date and course id as Offerings is a weak entity of Courses

create or replace procedure update_room(find_launch_date date, find_course_id integer, session_number integer, updated_rid integer)
    language plpgsql
as
$$
DECLARE
    find_session_date DATE;
    room_capacity     INTEGER;
    number_registered INTEGER;
BEGIN

    SELECT R.seating_capacity
    INTO room_capacity
    FROM Rooms R
    WHERE R.rid = updated_rid;

    SELECT COUNT(*)
    INTO number_registered
    FROM (Registers NATURAL JOIN Course_Sessions) T
    WHERE T.launch_date = find_launch_date
      AND T.course_id = find_course_id
      AND T.course_session_id = session_number;

    SELECT S.session_date
    INTO find_session_date
    FROM Course_Sessions S
    WHERE S.course_session_id = session_number
      AND S.launch_date = find_launch_date
      AND S.course_id = find_course_id;

    -- Only update if session_date later than today and number of registrations for the session does not exceed seating capacity
    IF (find_session_date > CURRENT_DATE and number_registered <= room_capacity) THEN
        UPDATE Course_Sessions S
        SET rid = updated_rid
        WHERE S.course_session_id = session_number
          and S.launch_date = find_launch_date
          and S.course_id = find_course_id;
    END IF;
END;
$$;

-- 23.remove_session:
-- This routine is used to remove a course session.
-- Inputs : course offering identifier and session number.

-- If the course session has not yet started and the request is valid, the routine will process the request with the
-- necessary updates. The request must not be performed if there is at least one registration for the session.

-- Note that the resultant seating capacity of the course offering could fall below the course offering’s target number of
-- registrations, which is allowed.
-- NOTE: course offering identifier consists of launch date and course id as Offerings is a weak entity of Courses

create or replace procedure remove_session(find_launch_date date, find_course_id integer, session_number integer)
    language plpgsql
as
$$
DECLARE
    find_session_date DATE;
BEGIN

    SELECT S.session_date
    INTO find_session_date
    FROM Course_Sessions S
    WHERE S.course_session_id = session_number
      and S.launch_date = find_launch_date
      and S.course_id = find_course_id;

    IF find_session_date > CURRENT_DATE THEN
        -- The request must not be performed if there is at least one registration for the session.
        IF NOT EXISTS(
                SELECT *
                FROM Registers
                WHERE launch_date = find_launch_date
                  AND course_id = find_course_id
                  AND course_session_id = session_number
            )
        THEN
            DELETE
            FROM Course_Sessions
            WHERE launch_date = find_launch_date
              AND course_id = find_course_id
              AND course_session_id = session_number;
        END IF;
    END IF;

END;
$$;

-- 25. pay_salary: This routine is used at the end of the month to pay salaries to employees.
-- The routine inserts the new salary payment records
-- and returns a table of records (sorted in ascending order of employee identifier)
-- with the following information for each employee who is paid for the month:
-- employee identifier, name, status (either part-time or full-time), number of work days for the month,
-- number of work hours for the month, hourly rate, monthly salary, and salary amount paid.
--  For a part-time employees, the values for number of work days for the month and monthly salary should be null.
-- For a full-time employees, the values for number of work hours for the month and hourly rate should be null.

create or replace function pay_salary()
    returns TABLE
            (
                emp_id              integer,
                curr_emp_name       text,
                emp_status          text,
                num_work_days       integer,
                num_work_hours      integer,
                curr_hourly_rate    numeric,
                curr_monthly_salary numeric,
                salary_amount       numeric
            )
    language plpgsql
as
$$
DECLARE
    curs CURSOR FOR (
        SELECT *
        FROM Employees
                 NATURAL FULL OUTER JOIN
             Part_Time_Emp
                 NATURAL FULL OUTER JOIN
             Full_Time_Emp
        ORDER BY eid ASC);
    r                  RECORD;
    curr_join_date     DATE;
    curr_depart_date   DATE;
    part_time_duration INTEGER;

BEGIN
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;

        emp_id := r.eid;
        curr_emp_name := r.emp_name;
        curr_monthly_salary := r.month_salary;
        curr_hourly_rate := r.hourly_rate;

        curr_join_date := r.join_date;
        curr_depart_date := r.depart_date;

        -- Full-Time
        IF r.hourly_rate IS NULL THEN
            emp_status := 'Full-Time';
            num_work_hours := NULL;

            -- if normal month
            num_work_days := EXTRACT(DAY FROM CURRENT_DATE) - 1 + 1;
            salary_amount := curr_monthly_salary;

            -- if current month same as month of joining
            IF EXTRACT(MONTH FROM curr_join_date) = EXTRACT(MONTH FROM CURRENT_DATE)
                and EXTRACT(YEAR FROM curr_join_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
                --  ''routine is used at the end of the month'' implies that the current date is the last day
                num_work_days := EXTRACT(DAY FROM CURRENT_DATE) - EXTRACT(DAY FROM curr_join_date) + 1;
                salary_amount := num_work_days / EXTRACT(DAY FROM CURRENT_DATE) * 100;
            END IF;

            -- if current month same as month of departing
            IF EXTRACT(MONTH FROM curr_depart_date) = EXTRACT(MONTH FROM CURRENT_DATE)
                and EXTRACT(YEAR FROM curr_depart_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
                num_work_days := EXTRACT(DAY FROM curr_depart_date) - 1 + 1;
                salary_amount := num_work_days / EXTRACT(DAY FROM CURRENT_DATE) * 100;
            END IF;

            -- Part-Time
        ELSE
            emp_status := ' Part-Time';
            num_work_days := NULL;

            SELECT SUM(duration)
            INTO num_work_hours
            FROM (Course_Sessions natural join Courses) T
            WHERE T.eid = emp_id
              AND EXTRACT(MONTH FROM T.session_date) = EXTRACT(MONTH FROM CURRENT_DATE)
              AND EXTRACT(YEAR FROM T.session_date) = EXTRACT(YEAR FROM CURRENT_DATE);

            salary_amount := curr_hourly_rate * num_work_hours;
        END IF;

        --  If employee has departed we do not pay them
        IF curr_depart_date < CURRENT_DATE and curr_depart_date IS NOT NULL THEN
            salary_amount := 0;
        ELSIF salary_amount <> 0 THEN
            INSERT INTO pay_slips VALUES (current_date, emp_id, salary_amount, num_work_hours, num_work_days);
        END IF;

        RETURN NEXT;
    END LOOP;
END
$$;


--||------------------ Constance --------------------||--

-- q9
-- Retrieves availability info of rooms for specific range of dates.
-- NOTE: they used "day" but i assume they are talking about date.
-- The output is sorted in ascending order of room identifier and day, and array entries are sorted in ascending order of hour.
-- IDEA: For each room, loop through each date and find the sessions for that rm and date.
-- Generate a array of 24 hours, remove (start, end hour) found in sessions
CREATE OR REPLACE FUNCTION get_available_rooms(start_date DATE, end_date DATE)
RETURNS TABLE (room_id INTEGER, seating_capacity INTEGER, date_available DATE,
hours_available TIME[]) AS $$
DECLARE
    curs_room CURSOR FOR (SELECT * FROM Rooms ORDER BY rid ASC); -- ensures sorted by room id first
    r RECORD;

    curs_date CURSOR FOR (
        SELECT * FROM generate_series(start_date::timestamp, end_date::timestamp, '1 day')
    ); -- date generated in increasing order, so ensures sorted when looping through it
    d DATE;

    hours_not_available TIME[];
    start_hour INTEGER;
    end_hour INTEGER;
    end_minute INTEGER;

    session_info Course_sessions%ROWTYPE;

BEGIN
    OPEN curs_room;
    LOOP
        FETCH curs_room into r;
        EXIT WHEN NOT FOUND;
        room_id := r.rid;
        seating_capacity := r.seating_capacity;

        OPEN curs_date;
        LOOP
            FETCH curs_date into d;
            EXIT WHEN NOT FOUND;
            date_available := d::date;
            SELECT ARRAY(
                select * from generate_series (
                    timestamp '2021-03-03 00:00', timestamp '2021-03-03 23:59', interval '1h'))::time[] INTO hours_available;

            -- loop through sessions that are using the room at this date to extract out timings that the room is in use
            FOR session_info IN (SELECT * FROM Course_Sessions WHERE rid = r.rid AND session_date = d)
            LOOP
                SELECT extract(hour from session_info.start_time) INTO start_hour;
                SELECT extract(hour from session_info.end_time) INTO end_hour;
                SELECT extract(minute from session_info.end_time) INTO end_minute;

                IF end_minute = 0 THEN
                    with Hours_Unavailable as
                            (SELECT '00:00:00'::time + x * '1 hour'::interval
                            FROM generate_series(start_hour, end_hour - 1) as t(x)) -- NOTE: exclusive of end_hour!!
                    SELECT ARRAY(SELECT * FROM Hours_Unavailable) INTO hours_not_available;
                ELSE
                    with Hours_Unavailable as
                            (SELECT '00:00:00'::time + x * '1 hour'::interval
                            FROM generate_series(start_hour, end_hour) as t(x)) -- NOTE: inclusive of end_hour!!
                    SELECT ARRAY(SELECT * FROM Hours_Unavailable) INTO hours_not_available;
                END IF;

                -- Result of this will not be sorted
                select array(select unnest(hours_available) except select unnest(hours_not_available)) into hours_available;
            END LOOP;

            -- Sorts array in ascending order
            SELECT array(
                SELECT DISTINCT UNNEST(
                    hours_available
                ) ORDER BY 1) INTO hours_available;

            -- looked through all sessions for this room, for this date, add to table
            RETURN NEXT;
        END LOOP;
        CLOSE curs_date;

    END LOOP;
    CLOSE curs_room;

END;
$$ LANGUAGE plpgsql;

-- Q24 --
-- add_session: This routine is used to add a new session to a course offering.
-- The inputs to the routine include the following: course offering identifier, new session number, new session day,
-- new session start hour, instructor identifier for new session, and room identifier for new session.
-- If the course offering’s registration deadline has not passed and the the addition request is valid,
-- the routine will process the request with the necessary updates.
CREATE OR REPLACE PROCEDURE add_session(offering_launch_date DATE, cid INTEGER, new_session_number INTEGER,
new_session_day DATE, new_session_start_hour TIME, instructor_id INTEGER, room_id INTEGER)
AS $$
DECLARE
    end_hour TIME;

BEGIN
    SELECT new_session_start_hour + duration * interval '1 hour' FROM Courses WHERE course_id = cid INTO end_hour;

    INSERT INTO Course_sessions VALUES (new_session_number, room_id, instructor_id, new_session_day, new_session_start_hour, end_hour, offering_launch_date, cid);

END;
$$ LANGUAGE plpgsql;

-- Q10 --
-- Adds course offering and sessions if any.
-- Assign instructors if valid, else abort whole function.
-- Seating capacity of the course offering must be at least equal to the course offering’s target number of registrations.
-- Input sessions_info includes: session_date DATE, start_time TIME, rid INTEGER
CREATE OR REPLACE PROCEDURE add_course_offering(offering_launch_date DATE, cid INTEGER,
    offering_fees DECIMAL, offering_registration_deadline DATE, admin_eid INTEGER, offering_target_number_registrations INTEGER,
    sessions_info TEXT[][])
AS $$
    DECLARE
        total_seating_capacity INTEGER;
        info TEXT[];

        session_number INTEGER;
        session_date DATE;
        start_time TIME;
        room_id INTEGER;

        num_available_instructors INTEGER;
        instructor_id INTEGER;

    BEGIN
        INSERT INTO Offerings (launch_date, course_id, eid, registration_deadline, target_number_registrations, fees)
        VALUES (offering_launch_date, cid, admin_eid, offering_registration_deadline, offering_target_number_registrations, offering_fees);

        session_number := 0;
        total_seating_capacity := 0;

        FOREACH info SLICE 1 IN ARRAY sessions_info
        LOOP
            session_number := session_number + 1;
            session_date := info[1]::DATE;
            start_time := TO_TIMESTAMP(info[2], 'HH24:MI')::TIME;
            room_id := info[3]::INTEGER;

            SELECT (seating_capacity + total_seating_capacity) FROM Rooms where rid = room_id INTO total_seating_capacity;

            SELECT count(*) from find_instructors(cid, session_date, start_time) INTO num_available_instructors;
            IF num_available_instructors = 0 THEN
                RAISE NOTICE 'Note: Unable to assign instructors, addition of course offering is rollbacked.';
                ROLLBACK;
            ELSE
                SELECT eid FROM find_instructors(cid, session_date, start_time) ORDER BY eid ASC LIMIT 1 INTO instructor_id;

                CALL add_session(offering_launch_date, cid, session_number, session_date, start_time, instructor_id, room_id);

            END IF;

        END LOOP;

        -- 'Note that the seating capacity of the course offering must be at least equal to the course offering’s target number of registrations.'
        IF offering_target_number_registrations > total_seating_capacity THEN
            RAISE NOTICE 'Note: Target number of registrations greater than seat capacity, addition of course offering is rollbacked.';
            ROLLBACK;
        END IF;

        UPDATE Offerings
        SET seating_capacity = total_seating_capacity
        WHERE launch_date = offering_launch_date AND course_id = cid;

        COMMIT;

    END;
$$ LANGUAGE plpgsql;

-- Q11
-- package_id is auto generated in this function
CREATE OR REPLACE PROCEDURE add_course_package(course_package_name TEXT, num_free_registrations INTEGER, sale_start_date DATE,
    sale_end_date DATE, price DECIMAL)
AS $$
DECLARE
    pkg_id INTEGER;
    num_pkgs INTEGER;
BEGIN
    -- increment one from current max package id
    SELECT count(*) FROM Course_packages INTO num_pkgs;
    IF num_pkgs = 0 THEN
        select 1 INTO pkg_id;
    ELSE
        SELECT max(package_id) + 1 FROM Course_packages INTO pkg_id;

    INSERT INTO Course_packages
    values (pkg_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations);
    END IF;

END;
$$ LANGUAGE plpgsql;

-- Q12
-- available for sale (i.e. current date is between the start date and end date inclusive)
-- package name, number of free course sessions, end date for promotional package, and the price of the package.
CREATE OR REPLACE FUNCTION get_available_course_packages()
RETURNS TABLE(course_package_name TEXT, num_free_registrations INTEGER, sale_end_date DATE,
    price DECIMAL) AS $$
    SELECT course_package_name, num_free_registrations, sale_end_date, price
    FROM Course_packages
    WHERE now()::DATE BETWEEN sale_start_date AND sale_end_date;
$$ LANGUAGE sql;

-- Q26. promote_courses: This routine is used to identify potential course offerings that could be of interest to inactive customers.
-- Active customer: customer has registered for some course offering in the last six months (inclusive of the current month), else inactive customer.
-- A course area A is of interest to a customer C if there is some course offering in area A among the three most recent course offerings registered by C.
-- If a customer has not yet registered for any course offering, we assume that every course area is of interest to that customer.
-- The routine returns a table of records consisting of the following information for each inactive customer: customer identifier,
-- customer name, course area A that is of interest to the customer, course identifier of a course C in area A, course title of C,
-- launch date of course offering of course C that still accepts registrations, course offering’s registration deadline, and fees for the course offering.
-- The output is sorted in ascending order of customer identifier and course offering’s registration deadline.

CREATE OR REPLACE FUNCTION promote_courses()
RETURNS TABLE(customer_id INTEGER, customer_name TEXT, course_area TEXT, cid INTEGER, course_title TEXT,
offering_launch_date DATE, offering_registration_deadline DATE, offering_fees DECIMAL)
AS $$
DECLARE
    curs_inactive_cust CURSOR FOR
        (SELECT cust_id, cust_name FROM Customers C
        WHERE not exists (
            SELECT 1
            FROM Registers R
            WHERE registration_date BETWEEN (now()::DATE - INTERVAL '6 months') AND now()::DATE
            AND C.cust_id = R.cust_id
        ) AND not exists (
            SELECT 1
            FROM Redeems RD INNER JOIN Credit_cards CC ON RD.credit_card_num = CC.credit_card_num
            WHERE redeem_date BETWEEN (now()::DATE - INTERVAL '6 months') AND now()::DATE
            AND C.cust_id = CC.cust_id
        )
        ORDER BY cust_id ASC);

    r RECORD;
    course_offering_info RECORD;
BEGIN
    OPEN curs_inactive_cust;
    LOOP
        FETCH curs_inactive_cust into r;
        EXIT WHEN NOT FOUND;

        customer_id := r.cust_id;
        customer_name := r.cust_name;

        -- has not registered/redeemed any offerings, interested in all areas
        IF (SELECT count(*) FROM Registers WHERE cust_id = r.cust_id) = 0 AND
        (SELECT count(*) FROM Redeems INNER JOIN Credit_cards ON Redeems.credit_card_num = Credit_cards.credit_card_num WHERE cust_id = r.cust_id) = 0 THEN
            FOR course_offering_info IN (SELECT * FROM Offerings O INNER JOIN Courses C ON O.course_id = C.course_id
                WHERE registration_deadline >= now()::DATE ORDER BY registration_deadline ASC)
            LOOP
                course_area := course_offering_info.course_area_name;
                cid := course_offering_info.course_id;
                course_title := course_offering_info.title;
                offering_launch_date := course_offering_info.launch_date;
                offering_registration_deadline := course_offering_info.registration_deadline;
                offering_fees := course_offering_info.fees;
                RETURN NEXT;
            END LOOP;

        ELSE
            FOR course_offering_info IN
                (WITH RegistersRedeem AS
                    (SELECT course_id, registration_date FROM Registers WHERE cust_id = r.cust_id
                    UNION ALL
                    SELECT course_id, redeem_date FROM Redeems INNER JOIN Credit_cards ON Redeems.credit_card_num = Credit_cards.credit_card_num WHERE cust_id = r.cust_id)

                SELECT * FROM Offerings INNER JOIN Courses ON Offerings.course_id = Courses.course_id
                WHERE registration_deadline >= now()::DATE
                AND Courses.course_area_name IN (
                    SELECT course_area_name -- impt that course_area_name not distinct so that we get from 3 most recent course offering registered
                    FROM RegistersRedeem INNER JOIN Courses ON RegistersRedeem.course_id = Courses.course_id
                    ORDER BY registration_date DESC LIMIT 3)

                -- removes offerings that are already registered/redeemed
                AND (Offerings.course_id, Offerings.launch_date) NOT IN (
                    SELECT course_id, launch_date
                    FROM Registers
                    WHERE Registers.cust_id = customer_id
                )
                AND (Offerings.course_id, Offerings.launch_date) NOT IN (
                    SELECT course_id, launch_date
                    FROM Redeems INNER JOIN Credit_cards on Redeems.credit_card_num = Credit_cards.credit_card_num
                    WHERE Credit_cards.cust_id = customer_id
                )
                ORDER BY registration_deadline ASC)

            LOOP
                course_area := course_offering_info.course_area_name;
                cid := course_offering_info.course_id;
                course_title := course_offering_info.title;
                offering_launch_date := course_offering_info.launch_date;
                offering_registration_deadline := course_offering_info.registration_deadline;
                offering_fees := course_offering_info.fees;
                RETURN NEXT;
            END LOOP;
        END IF;
    END LOOP;
    CLOSE curs_inactive_cust;
END;
$$ LANGUAGE plpgsql;

-- Q27. top_packages: This routine is used to find the top N course packages in terms of the total number of packages sold for this year
-- (i.e., the package’s start date is within this year). The input to the routine is a positive integer number N.
-- The routine returns a table of records consisting of the following information for each of the top N course packages:
-- package identifier, number of included free course sessions, price of package, start date, end date, and number of packages sold.
-- The output is sorted in descending order of number of packages sold followed by descending order of price of package.
-- In the event that there are multiple packages that tie for the top Nth position, all these packages should be included in the output records;
-- thus, the output table could have more than N records. It is also possible for the output table to have fewer than N records if N is larger than the number of packages launched this year.

-- number of packages sold DESC, price package DESC
-- output can have >N records if there is a tie, or <N records
CREATE OR REPLACE FUNCTION top_packages(N INTEGER)
RETURNS TABLE(package_identifier INTEGER, num_free_course_sessions INTEGER, price_pkg DECIMAL, pkg_start_date DATE, pkg_end_date DATE,
num_sold INTEGER)
AS $$
DECLARE
    num_pkgs_sold INTEGER;

    curs CURSOR FOR
        (SELECT Buys.package_id, num_free_registrations, price, sale_start_date, sale_end_date, count(*) AS num_pkgs_sold
        FROM (Buys INNER JOIN Course_packages ON Buys.package_id = Course_packages.package_id)
        WHERE date_part('year', sale_start_date) = date_part('year', now())
        GROUP BY Buys.package_id, num_free_registrations, price, sale_start_date, sale_end_date
        ORDER BY num_pkgs_sold DESC, price DESC);

    r RECORD;
    num_pkgs INTEGER;
    prev_num_sold INTEGER;
    prev_price DECIMAL;
BEGIN
    OPEN curs;
    num_pkgs := 0;
    prev_num_sold := 0;
    prev_price := 0;

    LOOP
        FETCH curs into r;
        EXIT WHEN NOT FOUND;
        num_pkgs := num_pkgs + 1;

        IF (prev_num_sold = r.num_pkgs_sold AND prev_price = r.price) OR num_pkgs <= N THEN
            prev_num_sold := r.num_pkgs_sold;
            prev_price := r.price;

            package_identifier := r.package_id;
            num_free_course_sessions := r.num_free_registrations;
            price_pkg := r.price;
            pkg_start_date := r.sale_start_date;
            pkg_end_date := r.sale_end_date;
            num_sold := r.num_pkgs_sold;
            RETURN NEXT;

        ELSE
            EXIT;
        END IF;

    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;

-- Q28 popular_courses: This routine is used to find the popular courses offered this year
-- (i.e., start date is within this year). A course is popular if the course has at least two offerings this year,
-- and for every pair of offerings of the course this year, the offering with the later start date has a higher number of registrations
-- than that of the offering with the earlier start date.
-- The routine returns a table of records consisting of the following information for each popular course:
-- course identifier, course title, course area, number of offerings this year, and number of registrations for the latest offering this year.
-- The output is sorted in descending order of the number of registrations for the latest offering this year followed by in ascending order of course identifier.

-- number of registrations: so have to look at both registers and redeems to find the number of registrations
-- DESC num reg, ASC course identifier
CREATE OR REPLACE FUNCTION popular_courses()
RETURNS TABLE(course_identifier INTEGER, course_title TEXT, course_area TEXT, num_offerings INTEGER, num_registrations INTEGER)
AS $$
    WITH RegistersRedeem AS
        (SELECT Registers.course_id, launch_date, registration_date FROM Registers
        UNION ALL
        SELECT Redeems.course_id, launch_date, redeem_date FROM Redeems),

    -- for OfferingsRegistrations, we are trying to get the offerings and corr number of registration
        OfferingsRegistrations AS
        (SELECT RR.course_id, RR.launch_date, actual_start_date, count(*) as num_regs
        FROM RegistersRedeem RR INNER JOIN Offerings O
            ON RR.course_id = O.course_id AND RR.launch_date = O.launch_date
        WHERE (RR.course_id) IN
            (SELECT course_id
            FROM Offerings
            WHERE date_part('year', actual_start_date) = date_part('year', now()) -- this year
            GROUP BY course_id
            HAVING count(*) >= 2 -- at least 2 offerings this year
            )
        GROUP BY (RR.course_id, RR.launch_date, actual_start_date)
        )

    -- check for every pair, offering w later start date higher number of registration
    SELECT OR0.course_id, title, course_area_name, count(*), MAX(num_regs) as max_num_regs
    FROM OfferingsRegistrations OR0 INNER JOIN Courses ON OR0.course_id = Courses.course_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM OfferingsRegistrations OR1, OfferingsRegistrations OR2
        WHERE OR1.course_id = OR0.course_id AND OR2.course_id = OR0.course_id
        AND ((OR1.actual_start_date < OR2.actual_start_date AND OR1.num_regs >= OR2.num_regs)
        OR (OR1.actual_start_date > OR2.actual_start_date AND OR1.num_regs <= OR2.num_regs))
    )
    GROUP BY OR0.course_id, title, course_area_name
    ORDER BY max_num_regs DESC, course_id ASC;

$$ LANGUAGE sql;


--||------------------ Esmanda --------------------||--
