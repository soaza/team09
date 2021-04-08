    --||------------------ EXTRA FUNCTIONS --------------------||--
    CREATE OR REPLACE FUNCTION get_active_pactive_package(IN cid INTEGER, OUT cc_num TEXT, OUT b_date DATE, OUT pkg_id INTEGER)
    RETURNS RECORD AS $$
    DECLARE
        curs CURSOR FOR (SELECT buy_date, credit_card_num, package_id FROM Buys
        WHERE credit_card_num = ANY(SELECT credit_card_num FROM Credit_cards WHERE cust_id = cid)
        AND num_remaining_redemptions = 0);
        r RECORD;
    BEGIN
        SELECT credit_card_num, buy_date, package_id INTO cc_num, b_date, pkg_id FROM Buys
        WHERE credit_card_num = ANY(SELECT credit_card_num FROM Credit_cards WHERE cust_id = cid)
        AND num_remaining_redemptions > 0;

        -- no active package --> check for partially active
        IF b_date IS NULL THEN
            OPEN curs;
            LOOP
                FETCH curs INTO r;
                EXIT WHEN NOT FOUND;
                SELECT credit_card_num, buy_date, package_id INTO cc_num, b_date, pkg_id FROM Redeems natural join Course_Sessions
                WHERE  buy_date = r.buy_date AND package_id = r.package_id AND credit_card_num = r.credit_card_num
                AND session_date - NOW()::timestamp::date >= 7;

                IF b_date IS NOT NULL THEN
                    EXIT;
                END IF;
            END LOOP;
            CLOSE curs;
        END IF;
    END;
    $$ LANGUAGE plpgsql;


    --||------------------ TRIGGERS --------------------||--

    --||------------------ Neil --------------------||--
    -- Trigger 5: Employee overlap and covering constraints 
    -- For insert, a full time employee cannot exist in any of the three tables from before.
    -- e.g. If I want to add a new administrator, I must check if the person is already a manager/instructor.
    -- However, an administrator cannot be added again to the administrator table as employees must be unique entities
    -- I need to check each individual table whether an employee exists because insertion on Full_time_Emp table happens before.

    -- Following 2 functions are overlap constraints i.e. employee must be exclusively one of the categories
    create or replace function full_time_emp_overlap_check() returns Trigger as $$
    BEGIN
        IF (EXISTS(SELECT * FROM Administrators WHERE eid = NEW.eid) or EXISTS(SELECT * FROM Managers WHERE eid = NEW.eid) or EXISTS(SELECT * FROM Instructors WHERE eid = NEW.eid)) THEN
            RAISE NOTICE 'Employee already exists';
            RETURN NULL;
        ELSE
            RETURN NEW;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger administrator_overlap_check
    before insert or update on Administrators
    for each row execute function full_time_emp_overlap_check();

    create trigger manager_overlap_check
    before insert or update on Managers
    for each row execute function full_time_emp_overlap_check();
    
    create trigger instructor_overlap_check
    before insert or update on Instructors
    for each row execute function full_time_emp_overlap_check();

    -- Similar to the logic above, if the employee already exists in either full time or part time,
    -- he cannot be added
    create or replace function pt_ft_emp_overlap_check() returns Trigger as $$
    BEGIN
        IF (EXISTS(SELECT * FROM Full_time_Emp WHERE eid = NEW.eid) or EXISTS(SELECT * FROM Part_time_Emp WHERE eid = NEW.eid)) THEN
            RAISE NOTICE 'Employee already exists.';
            RETURN NULL;
        ELSE
            RETURN NEW;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger pt_ft_overlap_check
    before insert or update on Full_time_Emp
    for each row execute function pt_ft_emp_overlap_check();

    create trigger pt_ft_overlap_check
    before insert or update on Part_time_Emp
    for each row execute function pt_ft_emp_overlap_check();

    -- Following 4 triggers check the covering constraint, ensuring that if an employee exists higher up in the ISA structure
    -- he must exist in the lower part of the ISA structure i.e. Employee tuple exists, then the employee must exists in either
    -- Administrator, Manager, Instructor and similarly must exist in part time full time employee and must exist in part time full time instructor
    -- Employees -> Part Time Emp, Full Time Emp
    -- Full Time Employee -> Full time instructor, administrators, managers
    -- Part time employees -> part time instructor
    -- Instructor -> part time instructor, full time instructor
    -- Job Assignment refers to an employee entity being in the lower part of the hierarchy 


    -- Insertions on full time emp or part time employee must happen before insertion on employee
    create or replace function employees_ft_pt_covering_check() returns Trigger as $$
    BEGIN
        IF NOT EXISTS(SELECT * FROM Full_time_Emp WHERE eid = NEW.eid) OR NOT EXISTS(SELECT * FROM Part_time_Emp WHERE eid = NEW.eid) THEN
            RAISE NOTICE 'Employees table cannot be updated with Employee with no job assignment.';
            RETURN NULL;
        ELSE
            RETURN NEW;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger employees_ft_pt_covering_check
    before insert or update on Employees
    for each row execute function employees_ft_pt_covering_check();

    -- Insertions on full time instructor, managers and administrators must happen before insertion on full_time_employee
    create or replace function ft_fti_administrator_manager_covering_check() returns Trigger as $$
    BEGIN
        IF NOT EXISTS(SELECT * FROM Full_time_instructors WHERE eid = NEW.eid) OR NOT EXISTS(SELECT * FROM Administrators WHERE eid = NEW.eid) OR NOT EXISTS(SELECT * FROM Managers WHERE eid = NEW.eid) THEN
            RAISE NOTICE 'Full Time Employees table cannot be updated with Employee with no job assignment.';
            RETURN NULL;
        ELSE
            RETURN NEW;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger ft_fti_administrator_manager_covering_check
    before insert or update on Full_time_Emp
    for each row execute function ft_fti_administrator_manager_covering_check();

    -- Insertions on part time instructor must happen before insertion on part_time_employee 
    create or replace function pt_pti_covering_check() returns Trigger as $$
    BEGIN
        IF NOT EXISTS(SELECT * FROM Part_time_instructors WHERE eid = NEW.eid) THEN
            RAISE NOTICE 'Full Time Employees table cannot be updated with Employee with no job assignment.';
            RETURN NULL;
        ELSE
            RETURN NEW;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger pt_pti_covering_check
    before insert or update on Part_time_Emp
    for each row execute function pt_pti_covering_check();


    -- Insertions on full time instructor and part time instructor must happen before insertion on instructor 
    create or replace function instructor_pti_fti_covering_check() returns Trigger as $$
    BEGIN
        IF NOT EXISTS(SELECT * FROM Full_time_instructors WHERE eid = NEW.eid) OR NOT EXISTS(SELECT * FROM Part_time_instructors WHERE eid = NEW.eid) THEN
            RAISE NOTICE 'Instructors table cannot be updated with Employee with no job assignment.';
            RETURN NULL;
        ELSE
            RETURN NEW;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger instructor_pti_fti_covering_check
    before insert or update on Instructors
    for each row execute function instructor_pti_fti_covering_check();


    -- Trigger 2: Seating Capacity in Sessions cannot exceed room capacity
    -- Need to make trigger for total_seating_capacity from Rooms>=num_registrations witin the same course_id in Register and Redeems

    create or replace function check_seating_capacity_registers() returns Trigger as $$
    DECLARE
        numRegs INTEGER;
        numRedeems INTEGER;
        totalSeatingCapacity INTEGER;
        room_id INTEGER;
    BEGIN
        SELECT rid FROM Course_sessions
        WHERE course_session_id = NEW.course_session_id AND launch_date =  NEW.launch_date AND course_id = NEW.course_id
        INTO room_id;

        SELECT INTO totalSeatingCapacity seating_capacity FROM Rooms WHERE rid = room_id;
        SELECT INTO numRegs COUNT(*) FROM REGISTERS
        WHERE course_session_id = NEW.course_session_id AND launch_date =  NEW.launch_date AND course_id = NEW.course_id;
        SELECT INTO numRedeems COUNT(*) FROM REDEEMS
        WHERE course_session_id = NEW.course_session_id AND launch_date = NEW.launch_date AND course_id = NEW.course_id;
        IF totalSeatingCapacity >= numRegs + numRedeems + 1 THEN
            RETURN NEW;
        ELSE
            RAISE NOTICE 'There are insufficient seats in the course session, cannot add customer.';
            RETURN NULL;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger check_seating_capacity_registers
    before insert or update on Registers
    for each row execute function check_seating_capacity_registers();

    create or replace function check_seating_capacity_redeems() returns Trigger as $$
    DECLARE
        numRegs INTEGER;
        numRedeems INTEGER;
        totalSeatingCapacity INTEGER;
        room_id INTEGER;
    BEGIN
        SELECT rid FROM Course_sessions
        WHERE course_session_id = NEW.course_session_id AND launch_date =  NEW.launch_date AND course_id = NEW.course_id
        INTO room_id;

        SELECT INTO totalSeatingCapacity seating_capacity FROM Rooms WHERE rid = room_id;
        SELECT INTO numRegs COUNT(*) FROM REGISTERS
        WHERE course_session_id = NEW.course_session_id AND launch_date =  NEW.launch_date AND course_id = NEW.course_id;
        SELECT INTO numRedeems COUNT(*) FROM REDEEMS
        WHERE course_session_id = NEW.course_session_id AND launch_date = NEW.launch_date AND course_id = NEW.course_id;
        IF totalSeatingCapacity >= numRegs + numRedeems + 1 THEN
            RETURN NEW;
        ELSE
            RAISE NOTICE 'There are insufficient seats in the course session, cannot add customer.';
            RETURN NULL;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    create trigger check_seating_capacity_redeems
    before insert or update on Redeems
    for each row execute function check_seating_capacity_redeems();



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
    create function consecutive_sid_course_sessions() returns trigger
        language plpgsql
    as
    $$
    DECLARE
        current_highest_sid INTEGER;

    BEGIN
        SELECT max(course_session_id)
        INTO current_highest_sid
        FROM Course_Sessions;
        IF NEW.course_session_id > current_highest_sid + 1 THEN
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
    create function course_session_date_before_depart_date() returns trigger
        language plpgsql
    as
    $$
    BEGIN
        IF NOT EXISTS(
                SELECT *
                FROM Employees
                WHERE eid = NEW.eid
                AND depart_date > NEW.session_date
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

    -- Trigger:No two sessions for the same course offering can be conducted on the same day
    -- and at the same time

    create or replace function course_session_offering_overlap() returns trigger
    language plpgsql
    as
    $$
    DECLARE
    new_session_duration INTEGER;
    BEGIN
        SELECT T.duration INTO new_session_duration
            FROM (Course_Sessions NATURAL JOIN Courses) T
            WHERE T.course_id = NEW.course_id;

        IF EXISTS(
            SELECT *
            FROM Course_sessions
            WHERE session_date = NEW.session_date
            AND launch_date = NEW.launch_date
            AND course_id = NEW.course_id
            AND
            (
                (
                    -- New session start in middle of session
                    start_time <= NEW.start_time AND NEW.start_time <= end_time
                )
                OR
                (
                    -- New session end in middle of session
                    EXTRACT(hours FROM NEW.start_time) + new_session_duration >= EXTRACT(hours FROM start_time)
                    AND
                    EXTRACT(hours FROM NEW.start_time) + new_session_duration <= EXTRACT(hours FROM end_time)
                )
            )
        ) THEN
        RAISE NOTICE 'No two sessions for the same course offering can be conducted on the same day and at the same time';
        RETURN NULL;
        ELSE
        RETURN NEW;
        END IF;
    END;
    $$;

    create trigger course_session_offering_overlap_trigger
        before insert or update
        on Course_sessions
        for each row
    execute procedure course_session_offering_overlap();



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
    BEFORE INSERT ON Redeems
    FOR EACH ROW EXECUTE FUNCTION max_one_session_func();

    CREATE TRIGGER max_one_session_register_trigger
    BEFORE INSERT ON Registers
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

-- Trigger for Instructors to ensure it specialises in at least one course area
CREATE OR REPLACE FUNCTION instructor_specialisation_func() RETURNS TRIGGER
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Specialises WHERE eid = NEW.eid) THEN
        RETURN NEW;
    ELSE
        RAISE NOTICE 'Note: Instructor not inserted/updated as he does not specialise in any course area.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instructor_specialisation_trigger
BEFORE INSERT OR UPDATE ON Instructors
FOR EACH ROW EXECUTE FUNCTION instructor_specialisation_func();

-- Trigger to check that it is not the only specialisation before deletion
-- Ensures the at least one specialisation for instructors constraint
CREATE OR REPLACE FUNCTION delete_specialisation_func() RETURNS TRIGGER
AS $$
BEGIN
    IF (SELECT count(*) FROM Specialises WHERE eid = OLD.eid) > 1 THEN
        RETURN OLD;
    ELSE
        RAISE NOTICE 'Note: Specialises not deleted as it is the only specialisation for this instructor.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_specialisation_trigger
BEFORE DELETE ON Specialises
FOR EACH ROW EXECUTE FUNCTION delete_specialisation_func();

-- trigger for Customers: at least one credit card
CREATE OR REPLACE FUNCTION customer_creditcard_func() RETURNS TRIGGER
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Credit_cards WHERE cust_id = NEW.cust_id) THEN
        RETURN NEW;
    ELSE
        RAISE NOTICE 'Note: Customer not inserted/updated as he does not own a credit card.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER customer_creditcard_trigger
BEFORE INSERT OR UPDATE ON Customers
FOR EACH ROW EXECUTE FUNCTION customer_creditcard_func();

-- check that it is not the only credit card before deletion
-- ensure cust has at least one credit card
CREATE OR REPLACE FUNCTION delete_creditcard_func() RETURNS TRIGGER
AS $$
BEGIN
    IF (SELECT count(*) FROM Credit_cards WHERE cust_id = OLD.cust_id) > 1 THEN
        RETURN OLD;
    ELSE
        RAISE NOTICE 'Note: Credit card not deleted as it is the only credit card for this customer.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_creditcard_trigger
BEFORE DELETE ON Credit_cards
FOR EACH ROW EXECUTE FUNCTION delete_creditcard_func();

-- trigger for Offerings to check that at least one session exist before adding into offerings
CREATE OR REPLACE FUNCTION offering_sessions_func() RETURNS TRIGGER
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Course_sessions WHERE launch_date = NEW.launch_date AND course_id = NEW.course_id) THEN
        RETURN NEW;
    ELSE
        RAISE NOTICE 'Note: Offering not inserted/updated as it does not have at least one session.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER offering_sessions_trigger
BEFORE INSERT OR UPDATE ON Offerings
FOR EACH ROW EXECUTE FUNCTION offering_sessions_func();

-- check before deletion of session, that it is not the only session left.
CREATE OR REPLACE FUNCTION delete_session_func() RETURNS TRIGGER
AS $$
BEGIN
    IF (SELECT count(*) FROM Course_sessions WHERE launch_date = OLD.launch_date AND course_id = OLD.course_id) > 1 THEN
        RETURN OLD;
    ELSE
        RAISE NOTICE 'Note: Course session not deleted as it is the only session for this offering.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_session_trigger
BEFORE DELETE ON Course_Sessions
FOR EACH ROW EXECUTE FUNCTION delete_session_func();

    --||------------------ Esmanda --------------------||--
    ---------------------- DELETE TRIGGERS FOR EMPLOYEES HIERARCHY ----------------------
    -- Employees
    CREATE OR REPLACE FUNCTION block_employees_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_employees_delete_trigger
    BEFORE DELETE ON Employees
    FOR EACH ROW EXECUTE FUNCTION block_employees_delete_func();

    -- Part_time_Emp
    CREATE OR REPLACE FUNCTION block_pt_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_pt_delete_trigger
    BEFORE DELETE ON Part_time_Emp
    FOR EACH ROW EXECUTE FUNCTION block_pt_delete_func();

    -- Full_time_Emp
    CREATE OR REPLACE FUNCTION block_ft_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_ft_delete_trigger
    BEFORE DELETE ON Full_time_Emp
    FOR EACH ROW EXECUTE FUNCTION block_ft_delete_func();


    -- Managers
    CREATE OR REPLACE FUNCTION block_managers_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_managers_delete_trigger
    BEFORE DELETE ON Managers
    FOR EACH ROW EXECUTE FUNCTION block_managers_delete_func();

    -- Administrators
    CREATE OR REPLACE FUNCTION block_administrators_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_administrators_delete_trigger
    BEFORE DELETE ON Administrators
    FOR EACH ROW EXECUTE FUNCTION block_administrators_delete_func();

    -- Instructors
    CREATE OR REPLACE FUNCTION block_instructors_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_instructors_delete_trigger
    BEFORE DELETE ON Instructors
    FOR EACH ROW EXECUTE FUNCTION block_instructors_delete_func();

    -- Part_time_instructors
    CREATE OR REPLACE FUNCTION block_pt_instructors_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_pt_instructors_delete_trigger
    BEFORE DELETE ON Part_time_instructors
    FOR EACH ROW EXECUTE FUNCTION block_pt_instructors_delete_func();

    -- Full_time_instructors
    CREATE OR REPLACE FUNCTION block_ft_instructors_delete_func() RETURNS TRIGGER AS $$
    BEGIN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER block_ft_instructors_delete_trigger
    BEFORE DELETE ON Full_time_instructors
    FOR EACH ROW EXECUTE FUNCTION block_ft_instructors_delete_func();

    -- TRIGGER 8
    CREATE OR REPLACE FUNCTION part_time_instructor_hours_func() RETURNS TRIGGER AS $$
    DECLARE
        new_duration INTEGER;
        total_hours INTEGER;
    BEGIN
        IF EXISTS(SELECT 1 FROM Part_time_instructors WHERE eid = NEW.eid) THEN
            SELECT SUM(duration) INTO total_hours FROM Course_Sessions natural join Courses
            WHERE eid = NEW.eid
            AND EXTRACT(MONTH FROM session_date) = EXTRACT(MONTH FROM NEW.session_date)
            AND EXTRACT(YEAR FROM session_date) = EXTRACT(YEAR FROM NEW.session_date);

            SELECT duration INTO new_duration FROM Courses WHERE course_id = NEW.course_id;

            IF total_hours + new_duration > 30 THEN
                RAISE NOTICE 'NOTE: Not updated/inserted as each part-time instructor must not
                    teach more than 30 hours for each month';
                RETURN NULL;
            ELSE
                RETURN NEW;
            END IF;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER part_time_instructor_hours_trigger
    BEFORE INSERT OR UPDATE ON Course_Sessions
    FOR EACH ROW EXECUTE FUNCTION part_time_instructor_hours_func();

    -- EXTRA TRIGGERS FOR BUYS REDEEMS CANCELS
    CREATE OR REPLACE FUNCTION buys_func() RETURNS TRIGGER AS $$
    DECLARE
        cid INTEGER;
        b_date DATE;
        cc_num TEXT;
        pkg_id INTEGER;
        is_empty BOOLEAN;
    BEGIN
        SELECT cust_id INTO cid FROM Credit_cards WHERE credit_card_num = NEW.credit_card_num;
        SELECT * INTO cc_num, b_date, pkg_id FROM get_active_pactive_package(cid);
        is_empty := (b_date IS NULL);

        IF (is_empty) THEN
            RETURN NEW;
        ELSE
            RAISE NOTICE 'NOTE: Not inserted as each customer can have at most one active or partially active package.';
            RETURN NULL;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER buys_trigger
    BEFORE INSERT ON Buys
    FOR EACH ROW EXECUTE FUNCTION buys_func();

    CREATE OR REPLACE FUNCTION redeem_func() RETURNS TRIGGER AS $$
    DECLARE
        cid INTEGER;
        b_date DATE;
        cc_num TEXT;
        pkg_id INTEGER;
        is_empty BOOLEAN;
    BEGIN
        SELECT cust_id INTO cid FROM Credit_cards WHERE credit_card_num = OLD.credit_card_num;
        SELECT * INTO cc_num, b_date, pkg_id FROM get_active_pactive_package(cid);
        is_empty := (b_date IS NULL);

        IF (TG_OP = 'INSERT') THEN
            UPDATE Buys
            SET num_remaining_redemptions = num_remaining_redemptions - 1
            WHERE buy_date = NEW.buy_date AND package_id = NEW.package_id AND credit_card_num = NEW.credit_card_num;
            RETURN NEW;
        ELSIF (TG_OP = 'DELETE') THEN
            IF (is_empty OR (OLD.buy_date = b_date AND OLD.credit_card_num = cc_num AND OLD.package_id = pkg_id)) THEN
                UPDATE Buys
                SET num_remaining_redemptions = num_remaining_redemptions + 1
                WHERE buy_date = OLD.buy_date AND package_id = OLD.package_id AND credit_card_num = OLD.credit_card_num;
                RETURN OLD;
            ELSE
                RAISE NOTICE 'NOTE: Not deleted as each customer can have at most one active or partially active package.';
                RETURN NULL;
            END IF;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER redeem_trigger
    BEFORE INSERT OR UPDATE OR DELETE ON Redeems
    FOR EACH ROW EXECUTE FUNCTION redeem_func();

    CREATE OR REPLACE FUNCTION cancel_func() RETURNS TRIGGER AS
    $$
    DECLARE
        cc_num TEXT;
        b_date DATE;
        pkg_id INTEGER;
    BEGIN
        IF (TG_OP = 'INSERT') THEN
            IF NEW.package_credit IS NULL THEN
                -- if cancelling from registers
                DELETE
                FROM Registers
                WHERE cust_id = NEW.cust_id
                  AND launch_date = NEW.launch_date
                  AND course_id = NEW.course_id;
                RETURN NEW;
            ELSE
                -- if cancelling from redeems
                -- will only have at most one record in redeems such that (credit_card_num, launch_date, course_id) match
                -- bc each customer cannot redeem >1 session from each course offering
                SELECT buy_date, package_id, credit_card_num
                INTO b_date, pkg_id, cc_num
                FROM Redeems
                         natural join Credit_cards
                WHERE cust_id = NEW.cust_id
                  AND course_session_id = NEW.course_session_id
                  AND launch_date = NEW.launch_date
                  AND course_id = NEW.course_id;

                DELETE
                FROM Redeems
                WHERE credit_card_num = cc_num
                  AND course_session_id = NEW.course_session_id
                  AND launch_date = NEW.launch_date
                  AND course_id = NEW.course_id;

                IF NEW.package_credit = 0 THEN
                    UPDATE Buys
                    SET num_remaining_redemptions = num_remaining_redemptions - 1
                    WHERE credit_card_num = cc_num
                      AND buy_date = b_date
                      AND package_id = pkg_id;
                END IF;

                RETURN NEW;
            END IF;
        ELSE
            RETURN NULL;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER cancel_trigger
    BEFORE INSERT OR UPDATE OR DELETE ON Cancels
    FOR EACH ROW EXECUTE FUNCTION cancel_func();

    --||------------------ FUNCTIONS --------------------||--

    --||------------------ Neil --------------------||--
    --
    -- /*Arrays are 1 based LOL */
    -- 1. add_employee:
    create procedure add_employee(empname text, homeaddress text, contactnumber integer, email text, salary numeric, datejoined date, category text, courseareas text[], parttime boolean)
        language plpgsql
    as
    $$
    DECLARE
        employeeId INTEGER;
        numCount INTEGER;
        arrayItems INTEGER;
    BEGIN
        SELECT INTO employeeId max(eid) + 1 from Employees;
        arrayItems := cardinality(courseAreas);
        numCount := 1;
        set constraints managers_ft_fkey deferred;
        set constraints ft_emp_fkey deferred;
        set constraints pti_instructors_fkey deferred;
        set constraints pti_pt_fkey deferred;
        set constraints pt_emp_fkey deferred;
        set constraints fti_instructors_fkey deferred;
        set constraints fti_ft_fkey deferred;
        set constraints administrators_ft_fkey deferred;
        set constraints specialises_instructors_fkey deferred;
        CASE
            WHEN category = 'MANAGER' THEN
                INSERT INTO Managers VALUES (employeeId);
                INSERT INTO Full_time_Emp VALUES (employeeId, salary);
                INSERT INTO Employees VALUES (employeeId, empName, homeAddress, contactNumber, email, dateJoined, NULL);
                LOOP
                    EXIT WHEN numCount > arrayItems;
                    INSERT INTO Course_area VALUES (courseAreas[numCount], employeeId);
                    numCount := numCount + 1;
                END LOOP;
            WHEN category = 'INSTRUCTOR' THEN
                LOOP
                EXIT WHEN numCount > arrayItems;
                INSERT INTO Specialises VALUES (employeeId, courseAreas[numCount]);
                numCount := numCount + 1;
                END LOOP;

                IF partTime THEN
                    INSERT INTO Part_time_instructors VALUES (employeeId);
                    INSERT INTO Instructors VALUES (employeeId);
                    INSERT INTO Part_time_Emp VALUES (employeeId, salary);
                ELSE
                    INSERT INTO Full_time_instructors VALUES (employeeId);
                    INSERT INTO Instructors VALUES (employeeId);
                    INSERT INTO Full_time_Emp VALUES (employeeId, salary);
                END IF;
                INSERT INTO Employees VALUES (employeeId, empName, homeAddress, contactNumber, email, dateJoined, NULL);

            WHEN category = 'ADMINISTRATOR' THEN
                INSERT INTO Administrators VALUES (employeeId);
                INSERT INTO Full_time_Emp VALUES (employeeId, salary);
                INSERT INTO Employees VALUES (employeeId, empName, homeAddress, contactNumber, email, dateJoined, NULL);
        END CASE;
    END;
    $$;





    -- 2. remove_employee:
    -- This function does not trigger any triggers!
    create procedure remove_employee(employeeid integer, departdate date)
        language plpgsql
    as
    $$
    BEGIN
        IF EXISTS(SELECT * FROM Administrators WHERE eid = employeeId) THEN
            IF NOT EXISTS(SELECT departDate < any (SELECT registration_deadline FROM Offerings WHERE eid = employeeId)) THEN
                UPDATE Employees
                SET depart_date = departDate
                WHERE eid = employeeId;
            END IF;
        END IF;
        IF EXISTS(SELECT * FROM Instructors WHERE eid = employeeId) THEN
            IF NOT EXISTS(SELECT departDate < any (SELECT session_date FROM Course_Sessions WHERE eid = employeeId)) THEN
                UPDATE Employees
                SET depart_date = departDate
                WHERE eid = employeeId;
            END IF;
        END IF;
        IF EXISTS(SELECT * FROM Managers WHERE eid = employeeId) THEN
            IF NOT EXISTS(SELECT * FROM Course_area WHERE eid = employeeId) THEN
                UPDATE Employees
                SET depart_date = departDate
                WHERE eid = employeeId;
            END IF;
        END IF;
    END;
    $$;



    -- 3. add_customer:
    -- This function does not trigger any triggers!
 create or replace procedure add_customer(custname text, homeaddress text, contactnumber integer, custemail text, creditcardnum integer, cardexpirydate date, cardcvv integer)
    as
    $$
    DECLARE
        custId INT;
    BEGIN
        set constraints creditcards_customers_fkey deferred;
        select into custId max(cust_id) + 1 from Customers;
        INSERT INTO Credit_cards VALUES (creditCardNum, cardCVV, cardExpiryDate, CURRENT_DATE, custId);
        INSERT INTO Customers VALUES (custId, homeAddress, contactNumber, custName, custEmail);
    END;
    $$ language plpgsql;


    -- 4. update_credit_card:
    -- This function does not trigger any triggers!
    CREATE OR REPLACE PROCEDURE update_credit_card
        (custId INT, creditCardNum INTEGER, cardExpiryDate DATE, cardCVV INTEGER)
        AS $$
    BEGIN
        INSERT INTO Credit_cards VALUES (creditCardNum, cardCVV, cardExpiryDate, CURRENT_DATE, custId);
    END;
    $$ LANGUAGE plpgsql;



    -- 17. register_session:
    create procedure register_session(custid integer, launchdate date, courseid integer, coursesessionid integer, paymentmethod text)
        language plpgsql
    as
    $$
    DECLARE
        activeCreditCardNum TEXT;
        buyDate DATE;
        packageId INTEGER;
        registr_deadline DATE;
    BEGIN
        -- If registration deadline has not lapsed
        select registration_deadline INTO registr_deadline from Offerings where launch_date = launchDate;
        IF CURRENT_DATE < registr_deadline THEN

            SELECT INTO activeCreditCardNum credit_card_num FROM Credit_cards
            WHERE cust_id = custId
            AND from_date >= ALL(SELECT from_date FROM Credit_cards WHERE cust_id = custId);

            -- If customer does not already have a course session in that specific course offering under Registers
            IF  not exists(select cust_id, launch_date, course_id from Registers where cust_id = custId and launch_date = launchDate and course_id = courseId)
                AND
            -- If customer does not already have a course session in that specific course offering under Redeems
                not exists(select credit_card_num, launch_date, course_id from Redeems where launch_date = launchDate and course_id = courseId and credit_card_num = any(select credit_card_num from Credit_cards where cust_id = custId))
                THEN
            -- If seating capacity allows, this means that the count of (launch_date, course_id) tuples under Registers and Redeems added together must be < seating Capacity of the room its under
            -- This is checked under trigger for seating capacity
                IF paymentMethod = 'CREDIT CARD' THEN
                /* Execute relevant registers SQL statements*/
                    INSERT INTO Registers VALUES (CURRENT_DATE, courseSessionId, launchDate, courseId, custId, activeCreditCardNum);
                END IF;
                IF paymentMethod = 'REDEMPTION' THEN
                /* Execute relevant redemtion SQL statements*/
                    select into activeCreditCardNum, buyDate, packageId from get_active_pactive_package(custId);
                    IF packageId IS NOT NULL THEN
                        INSERT INTO Redeems VALUES (CURRENT_DATE, buyDate, activeCreditCardNum, packageId, courseSessionId, launchDate, courseId);
                    ELSE
                        RAISE NOTICE 'There are no active packages.';
                    END IF;
                END IF;
            ELSE
                RAISE NOTICE 'Customer is already taking course!';
            END IF;
        ELSE
            RAISE NOTICE 'The registration deadline has already lapsed!';
        END IF;
    END;
    $$;


    /*
        Returns table relating to all course sessions that the customer has registered for that have a session_date > current_date
        First get all the course sessions from Registers and Redeems table for the customer, then for each of them generate the following information
        Will need,
        Registers and Redeems for
            - all the active registered course sessions under customer
        Course_Sessions for
            - eid(for instructorName),
            - session_date for sessionDate,
            - startTime for sessionStartHour,
            - endTime-startTime for sessionDuration
        Courses for
            - title for courseName
        Course_Offerings for
            - fees for courseFees
        Employees for
            - emp_name for InstructorName using eid from Course_Sessions
        */
    -- 18. get_my_registrations:
    -- CHANGED
    create function get_my_registrations(custid integer)
        returns TABLE(coursename text, coursefees numeric, sessiondate date, sessionstarthour integer, sessionduration interval, instructorname text)
        language plpgsql
    as
    $$
    DECLARE
        cursActiveSession CURSOR FOR (
            with TABLE1 as (
                select launch_date, course_id, course_session_id
                from Registers
                where cust_id = custId
                and CURRENT_DATE < (select session_date
                                    from Course_Sessions
                                    where Course_Sessions.launch_date = Registers.launch_date
                                        and Course_Sessions.course_id = Registers.course_id
                                        and Course_Sessions.course_session_id = Registers.course_session_id)
                union
                (
                    select launch_date, course_id, course_session_id
                    from Redeems
                    where credit_card_num = any (select credit_card_num from Credit_cards where cust_id = custId)
                    and CURRENT_DATE < (select session_date
                                        from Course_Sessions
                                        where Course_Sessions.launch_date = Redeems.launch_date
                                            and Course_Sessions.course_id = Redeems.course_id
                                            and Course_Sessions.course_session_id = Redeems.course_session_id)
                )
            )
            select *
            from TABLE1
            natural join Course_Sessions
            order by session_date, start_time asc);
        r RECORD;
    BEGIN
        OPEN cursActiveSession;
        LOOP
            FETCH cursActiveSession into r;
            EXIT WHEN NOT FOUND;
            select into courseName title from Courses where Courses.course_id = r.course_id;
            select into courseFees fees from Offerings where Offerings.launch_date = r.launch_date and Offerings.course_id = r.course_id;
            select into sessionDate session_date from Course_Sessions where Course_Sessions.launch_date = r.launch_date and Course_Sessions.course_id = r.course_id and Course_Sessions.course_session_id = r.course_session_id;
            select into sessionStartHour extract(hour from start_time) from Course_Sessions where Course_Sessions.launch_date = r.launch_date and Course_Sessions.course_id = r.course_id and Course_Sessions.course_session_id = r.course_session_id;
            sessionDuration := (select end_time from Course_Sessions where Course_Sessions.launch_date = r.launch_date and Course_Sessions.course_id = r.course_id and Course_Sessions.course_session_id = r.course_session_id) -
            (select start_time from Course_Sessions where Course_Sessions.launch_date = r.launch_date and Course_Sessions.course_id = r.course_id and Course_Sessions.course_session_id = r.course_session_id);
            select into instructorName emp_name from Employees where Employees.eid = (select eid from Course_Sessions where Course_Sessions.launch_date = r.launch_date and Course_Sessions.course_id = r.course_id and Course_Sessions.course_session_id = r.course_session_id);
            RETURN NEXT;
        END LOOP;
        CLOSE cursActiveSession;
    END;
    $$;




    /*
    This is talking about changing the session within a course offering.
    The only difference is between 2 different sessions.
    What I need to check for:
    - CURRENT_DATE < session_date
    - Seating capacity, checked by trigger on insert to registrations and redeems
    */
    -- 19. update_course_sesssion:
    create or replace procedure update_course_session(custId INTEGER, launchDate DATE, courseId INTEGER, courseSessionId INTEGER)
    as $$
    DECLARE
        currentSessionDate date;
        activeCreditCardNum INTEGER;
    BEGIN
        /*Checking if the registration time has lapsed and if the customer has takent the course before, then update accordingly, the seating trigger will check for available seat.*/
        select session_date INTO currentSessionDate from Course_Sessions where launch_date = launchDate and course_id = courseId and course_session_id = courseSessionId;
        IF CURRENT_DATE < currentSessionDate THEN

            SELECT INTO activeCreditCardNum credit_card_num FROM Credit_cards
            WHERE cust_id = custId
            AND from_date >= ALL(SELECT from_date FROM Credit_cards WHERE cust_id = custId);

            /* Check where the customer exists with this current session, Redeems or Registration Table and update accordingly */
            -- If the customer did a registration then
            IF exists(select * from Registers where cust_id = custId and launch_date = launchDate and course_id = courseId )  then
                UPDATE Registers
                SET course_session_id = courseSessionId
                WHERE cust_id = custId AND launch_date = launchDate AND course_id = courseID;
            -- The where condition here is enough to uniquely identify a redeems record since these 3 attributes are unique.
            ELSIF exists(select * from Redeems where credit_card_num = any(select credit_card_num from Credit_cards where cust_id = custId) and launch_date = launchDate and course_id = courseId) then
                UPDATE Redeems
                SET course_session_id = courseSessionId
                WHERE credit_card_num = any(select credit_card_num from Credit_cards where cust_id = custId) and launch_date = launchDate and course_id = courseId;
            END IF;
        END IF;
    END;
    $$ language plpgsql;

    -- 20. cancel_registration:
    create or replace procedure cancel_registration(custId INTEGER, launchDate DATE, courseId INTEGER)
    as $$
    DECLARE
        refundAmount DECIMAL;
        packageCredit INTEGER;
        packageId INTEGER;
        courseSessionId INTEGER;
        selectedSessionDate DATE;
    BEGIN
        select session_date INTO selectedSessionDate from Course_Sessions where launch_date = launchDate and course_id = courseId and course_session_id = courseSessionId;
        IF exists(select * from Registers where cust_id = custId and launch_date = launchDate and course_id = courseId)  then
            select into courseSessionId course_session_id from Registers where cust_id = custId and launch_date = launchDate and course_id = courseId;
            IF (extract(day from selectedSessionDate)) - (extract(day from CURRENT_DATE)) >= 7 then
                select into refundAmount fees*0.9 from Offerings where launch_date = launchDate and course_id = courseId;
            ELSE
                refundAmount := 0;
            END IF;
            packageCredit := NULL;
            packageId := NULL;
            INSERT INTO Cancels VALUES (CURRENT_DATE, refundAmount, packageCredit, packageId, courseSessionId, launchDate, courseId, custId);
        ELSIF exists(select * from Redeems where credit_card_num = any(select credit_card_num from Credit_cards where cust_id = custId) and launch_date = launchDate and course_id = courseId) then
            select into courseSessionId, packageId course_session_id, package_id from Redeems where credit_card_num = any(select credit_card_num from Credit_cards where cust_id = custId) and launch_date = launchDate and course_id = courseId;
            IF (extract(day from selectedSessionDate)) - (extract(day from CURRENT_DATE)) >= 7 then
                packageCredit := 1;
            ELSE
                packageCredit := 0;
            END IF;
            refundAmount := NULL;
            INSERT INTO Cancels VALUES (CURRENT_DATE, refundAmount, packageCredit, packageId, courseSessionId, launchDate, courseId, custId);
        END IF;
    END;
    $$ language plpgsql;


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

    -- 7. get_available_instructors
    -- This routine is used to retrieve the availability information of instructors who could be assigned to teach a specified course.
    --  inputs: course identifier, start date, and end date.
    -- output:SETS OF (eid, name,total number of teaching hours
    --  that the instructor has been assigned for this month, day
    -- (which is within the input date range [start date, end date]),
    -- and an array of the available hours for the instructor on the specified day.
    -- output: sorted in ascending order of employee identifier and day, and the array entries are sorted in ascending order of hour.
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

            course_duration INTEGER;

        BEGIN
            set constraints sessions_offerings_fkey deferred;

            session_number := 0;
            total_seating_capacity := 0;

            SELECT duration from Courses WHERE course_id = cid INTO course_duration;

            FOREACH info SLICE 1 IN ARRAY sessions_info
            LOOP
                session_number := session_number + 1;
                session_date := info[1]::DATE;
                start_time := TO_TIMESTAMP(info[2], 'HH24:MI')::TIME;
                room_id := info[3]::INTEGER;

                IF course_duration = 4 AND start_time <> '14:00' THEN
                    ROLLBACK;
                END IF;

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

            INSERT INTO Offerings (launch_date, course_id, eid, registration_deadline, target_number_registrations, fees)
            VALUES (offering_launch_date, cid, admin_eid, offering_registration_deadline, offering_target_number_registrations, offering_fees);

            -- if no sessions info provided, seating capacity will be 0
            SELECT COALESCE(seating_capacity, 0) FROM Offerings WHERE launch_date = offering_launch_date AND course_id = cid INTO total_seating_capacity;

            -- 'Note that the seating capacity of the course offering must be at least equal to the course offering’s target number of registrations.'
            IF offering_target_number_registrations > total_seating_capacity THEN
                RAISE NOTICE 'Note: Target number of registrations greater than seat capacity, addition of course offering is rollbacked.';
                ROLLBACK;
            END IF;

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
                WHERE registration_date BETWEEN (date_trunc('month', now()::DATE - INTERVAL '5 months')) AND now()::DATE
                AND C.cust_id = R.cust_id
            ) AND not exists (
                SELECT 1
                FROM Redeems RD INNER JOIN Credit_cards CC ON RD.credit_card_num = CC.credit_card_num
                WHERE redeem_date BETWEEN (date_trunc('month', now()::DATE - INTERVAL '5 months')) AND now()::DATE
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
                FOR course_offering_info IN
                    (SELECT * FROM Offerings O INNER JOIN Courses C ON O.course_id = C.course_id
                    WHERE launch_date <= NOW()::DATE
                    AND registration_deadline >= now()::DATE
                    AND seating_capacity > (
                        (SELECT count(*) FROM Registers WHERE Registers.launch_date = O.launch_date AND Registers.course_id = O.course_id) +
                        (SELECT count(*) FROM Redeems WHERE Redeems.launch_date = O.launch_date AND Redeems.course_id = O.course_id)
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

            ELSE
                FOR course_offering_info IN
                    (WITH RegistersRedeem AS
                        (SELECT course_id, registration_date FROM Registers WHERE cust_id = r.cust_id
                        UNION ALL
                        SELECT course_id, redeem_date FROM Redeems INNER JOIN Credit_cards ON Redeems.credit_card_num = Credit_cards.credit_card_num WHERE cust_id = r.cust_id)

                    SELECT * FROM Offerings INNER JOIN Courses ON Offerings.course_id = Courses.course_id
                    WHERE launch_date <= NOW()::DATE
                    AND registration_deadline >= now()::DATE
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

                    -- check that total num registrations still less than seating capacity
                    AND seating_capacity > (
                        (SELECT count(*) FROM Registers WHERE Registers.launch_date = Offerings.launch_date AND Registers.course_id = Offerings.course_id) +
                        (SELECT count(*) FROM Redeems WHERE Redeems.launch_date = Offerings.launch_date AND Redeems.course_id = Offerings.course_id)
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
    -- FN 13
    create or replace procedure buy_course_package(cid integer, pkg_id integer)
    language plpgsql
    as
    $$
    DECLARE
        cc_num TEXT;
        num_free_reg INTEGER;
        end_date DATE;
        current_date DATE;
    BEGIN
        SELECT credit_card_num INTO cc_num FROM Credit_cards
        WHERE cust_id = cid
        AND from_date >= ALL(SELECT from_date FROM Credit_cards WHERE cust_id = cid);
        SELECT num_free_registrations, sale_end_date INTO num_free_reg, end_date
        FROM Course_packages WHERE package_id = pkg_id;

        current_date := NOW()::timestamp::date;
        IF current_date <= end_date THEN
            INSERT INTO Buys
            VALUES (current_date, pkg_id, cc_num, num_free_reg);
        ELSE
            RAISE EXCEPTION 'Note: The promotional package is no longer available for sale';
        END IF;
    END;
    $$;

    -- FN 14
    create or replace function get_my_course_package(cid integer, OUT result json) returns json
        language plpgsql
    as
    $$
    DECLARE
        cc_num TEXT;
        pkg_id INTEGER;
        b_date DATE;
        is_empty BOOLEAN;
        to_append JSON;
    BEGIN
        SELECT * INTO cc_num, b_date, pkg_id FROM get_active_pactive_package(cid);
        is_empty := (b_date IS NULL);

        IF (NOT is_empty) THEN
            -- course package info
            SELECT json_agg(t) INTO result FROM (
                SELECT course_package_name, buy_date, price, num_free_registrations, num_remaining_redemptions
                FROM Buys natural join Course_packages
                WHERE package_id = pkg_id AND credit_card_num = cc_num AND buy_date = b_date) t;

            -- info for all redeemed sessions
            SELECT json_agg(r) INTO to_append FROM (
                SELECT course_session_id, launch_date, course_id FROM Redeems natural join Course_Sessions
                WHERE credit_card_num = cc_num AND package_id = pkg_id AND buy_date = b_date
                ORDER BY session_date, start_time) r;

            IF to_append IS NOT NULL THEN
                result := result::jsonb || to_append::jsonb;
            END IF;
        END IF;
    END;
    $$;

    -- FN 15
    create or replace function get_available_course_offerings()
        returns TABLE(c_title text, c_area_name text, c_start_date date, c_end_date date, reg_deadline date, c_fees decimal, num_remaining_seats integer)
        language plpgsql
    as
    $$
    DECLARE
        curs CURSOR FOR (SELECT * FROM Courses natural join Offerings ORDER BY registration_deadline, title);
        r RECORD;
        seating_cap INTEGER;
        num_registrations INTEGER;
        num_redemptions INTEGER;
    BEGIN
        -- num remaining seats = seating capacity - total number of reg
        OPEN curs;
        LOOP
            FETCH curs INTO r;
            EXIT WHEN NOT FOUND;
            reg_deadline := r.registration_deadline;
            IF reg_deadline > NOW()::timestamp::date THEN
                seating_cap := r.seating_capacity;
                SELECT COUNT(*) INTO num_registrations FROM REGISTERS
                WHERE launch_date = r.launch_date and course_id = r.course_id;
                SELECT COUNT(*) INTO num_redemptions FROM REDEEMS
                WHERE launch_date = r.launch_date and course_id = r.course_id;
                num_remaining_seats := seating_cap - num_registrations - num_redemptions;

                IF num_remaining_seats > 0 THEN
                    c_title := r.title;
                    c_area_name := r.course_area_name;
                    c_start_date := r.actual_start_date;
                    c_end_date := r.end_date;
                    c_fees := r.fees;
                    RETURN NEXT;
                END IF;
            END IF;
        END LOOP;
        CLOSE curs;
    END;
    $$;

    -- FN 16
    create or replace function get_available_course_sessions(l_date date, cid integer)
        returns TABLE(s_date date, s_start_time time, s_instructor integer, num_remaining_seats integer)
        language plpgsql
    as
    $$
    DECLARE
        curs CURSOR FOR (SELECT * FROM Course_Sessions
        WHERE launch_date = l_date AND course_id = cid ORDER BY session_date, start_time);
        r RECORD;
        s_capacity INTEGER;
        num_registrations INTEGER;
        num_redemptions INTEGER;
    BEGIN
        OPEN curs;
        LOOP
            FETCH curs INTO r;
            EXIT WHEN NOT FOUND;
            s_date := r.session_date;
            s_start_time := r.start_time;
            s_instructor := r.eid;
            SELECT seating_capacity INTO s_capacity FROM Rooms WHERE rid = r.rid;
            SELECT COUNT(*) INTO num_registrations FROM REGISTERS
            WHERE course_session_id = r.course_session_id AND launch_date = r.launch_date AND course_id = r.course_id;
            SELECT COUNT(*) INTO num_redemptions FROM REDEEMS
            WHERE course_session_id = r.course_session_id AND launch_date = r.launch_date AND course_id = r.course_id;
            num_remaining_seats := s_capacity - num_registrations - num_redemptions;
            RETURN NEXT;
        END LOOP;
        CLOSE curs;
    END;
    $$;

    -- FN 29
    CREATE OR REPLACE FUNCTION view_summary_report(num_months INTEGER)
    RETURNS TABLE (month TEXT, year INTEGER, total_salary DECIMAL, total_pkg_sales DECIMAL,
        total_reg_fees DECIMAL, total_refunded DECIMAL, total_reg_from_pkg INTEGER) AS $$
    DECLARE
        month_int INTEGER;
        to_convert_month INTEGER;
        curr_date DATE;
    BEGIN
        curr_date := NOW()::timestamp::date;
        month_int := EXTRACT(MONTH FROM curr_date);
        year:= EXTRACT(YEAR FROM curr_date);

        LOOP
            IF (EXTRACT(MONTH FROM curr_date) - num_months >= month_int) THEN
                EXIT;
            END IF;

            IF month_int <= 0 THEN
                to_convert_month := ((month_int % 12) + 12) % 12;
                IF to_convert_month = 0 THEN
                    to_convert_month := to_convert_month + 12;
                    year := year - 1;
                END IF;
            ELSE
                to_convert_month := month_int;
            END IF;

            SELECT TO_CHAR(TO_DATE(to_convert_month::text, 'MM'), 'Month') AS "Month Name" INTO month;

            SELECT SUM(amount) INTO total_salary FROM Pay_slips
            WHERE EXTRACT(MONTH FROM payment_date) = month_int
            AND EXTRACT(YEAR FROM payment_date) = year;
            IF total_salary IS NULL THEN total_salary := 0;
            END IF;

            SELECT SUM(price) INTO total_pkg_sales FROM Course_packages natural join Buys
            WHERE EXTRACT(MONTH FROM buy_date) = month_int
            AND EXTRACT(YEAR FROM buy_date) = year;
            IF total_pkg_sales IS NULL THEN total_pkg_sales := 0;
            END IF;

            SELECT SUM(fees) INTO total_reg_fees FROM Offerings natural join Registers
            WHERE EXTRACT(MONTH FROM registration_date) = month_int
            AND EXTRACT(YEAR FROM registration_date) = year;
            IF total_reg_fees IS NULL THEN total_reg_fees := 0;
            END IF;

            SELECT SUM(refund_amt) INTO total_refunded FROM Cancels
            WHERE refund_amt IS NOT NULL
            AND EXTRACT(MONTH FROM cancel_date) = month_int
            AND EXTRACT(YEAR FROM cancel_date) = year;
            IF total_refunded IS NULL THEN total_refunded := 0;
            END IF;

            SELECT COUNT(*) INTO total_reg_from_pkg FROM Redeems
            WHERE EXTRACT(MONTH FROM redeem_date) = month_int
            AND EXTRACT(YEAR FROM redeem_date) = year;
            IF total_reg_from_pkg IS NULL THEN total_reg_from_pkg := 0;
            END IF;

            RETURN NEXT;
            month_int := month_int - 1;
        END LOOP;
    END;
    $$ LANGUAGE plpgsql;

    -- FN 30
    CREATE OR REPLACE FUNCTION view_manager_report()
    RETURNS TABLE (mngr_name TEXT, num_course_areas INTEGER, num_offerings_ended INTEGER,
        net_reg_fees DECIMAL, highest_course_title TEXT[]) AS $$
    DECLARE
        curs1 CURSOR FOR (SELECT eid, emp_name FROM Employees natural join Managers ORDER BY emp_name);
        curs2 CURSOR FOR (
            SELECT O.course_id, O.launch_date, O.end_date, O.fees, C.title, A.eid
            FROM (Offerings O natural join Courses C) join Course_area A ON (C.course_area_name = A.course_area_name)
            WHERE EXTRACT(YEAR FROM end_date) = EXTRACT(YEAR FROM CURRENT_DATE));
        r1 RECORD;
        r2 RECORD;
        num_reg INTEGER;
        num_cancelled_reg INTEGER;
        tmp_sum DECIMAL;
        reg_fees DECIMAL;
        highest_reg_fees DECIMAL;
        highest_course TEXT[];
    BEGIN
        OPEN CURS1;
        LOOP
            FETCH curs1 INTO r1;
            EXIT WHEN NOT FOUND;
            mngr_name := r1.emp_name;

            SELECT COUNT(*) INTO num_course_areas FROM Course_area
            WHERE eid = r1.eid;

            SELECT COUNT(*) INTO num_offerings_ended
            FROM (Offerings O natural join Courses C) join Course_area A ON (C.course_area_name = A.course_area_name)
            WHERE A.eid = r1.eid AND EXTRACT(YEAR FROM O.end_date) = EXTRACT(YEAR FROM CURRENT_DATE);

            net_reg_fees := 0;
            reg_fees := 0;
            highest_reg_fees := -1;
            highest_course := ARRAY[]::TEXT[];
            OPEN CURS2;
            LOOP
                FETCH curs2 INTO r2;
                EXIT WHEN NOT FOUND;
                IF (r2.eid = r1.eid) THEN
                    RAISE NOTICE '%', mngr_name;
                    -- calculating registration fees
                    SELECT COUNT(*) INTO num_reg FROM Registers WHERE launch_date = r2.launch_date AND course_id = r2.course_id;
                    reg_fees := r2.fees * num_reg;
                    RAISE NOTICE '1. %', reg_fees;
                    SELECT COUNT(*), SUM(refund_amt) INTO num_cancelled_reg, tmp_sum FROM Cancels
                    WHERE refund_amt IS NOT NULL AND launch_date = r2.launch_date AND course_id = r2.course_id;
                    IF tmp_sum IS NULL THEN
                        tmp_sum := 0;
                    end if;
                    reg_fees := reg_fees + (num_cancelled_reg * r2.fees - tmp_sum);
                    RAISE NOTICE '2. %', reg_fees;

                    -- calculating total redemption registration fees
                    SELECT SUM(price / num_free_registrations) INTO tmp_sum FROM Redeems natural join Course_packages
                    WHERE launch_date = r2.launch_date AND course_id = r2.course_id;
                    IF tmp_sum IS NULL THEN
                        tmp_sum := 0;
                    end if;
                    reg_fees := reg_fees + tmp_sum;
                    RAISE NOTICE '3. %', reg_fees;
                    SELECT SUM(price / num_free_registrations) INTO tmp_sum FROM Cancels natural join Course_packages
                    WHERE launch_date = r2.launch_date AND course_id = r2.course_id
                    AND package_credit = 0;
                    IF tmp_sum IS NULL THEN
                        tmp_sum := 0;
                    end if;
                    reg_fees := reg_fees + tmp_sum;
                    RAISE NOTICE '4. %', reg_fees;

                    net_reg_fees := net_reg_fees + reg_fees;

                    IF (reg_fees > highest_reg_fees) THEN
                        highest_reg_fees := reg_fees;
                        highest_course := ARRAY[r2.title];
                    ELSIF (reg_fees = highest_reg_fees) THEN
                        highest_course := array_append(highest_course, r2.title);
                    END IF;
                END IF;
            END LOOP;
            CLOSE CURS2;
            RAISE NOTICE '%',highest_course_title;
            highest_course_title := highest_course;
            RETURN NEXT;
        END LOOP;
        CLOSE CURS1;
    END;
    $$ LANGUAGE plpgsql;
