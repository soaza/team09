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


--||------------------ Esmanda --------------------||--
