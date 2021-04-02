-- Q10 --
-- eid refers to Administrator's eid
-- assign instructors if valid, else abort
-- seating capacity of the course offering must be at least equal to the course offering’s target number of registrations.
---- session_info includes: session_date DATE, start_time TIME, rid INTEGER
CREATE OR REPLACE PROCEDURE add_course_offering(course_offering_identifier INTEGER, offering_launch_date DATE, cid INTEGER,
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
        -- Do we need check whether course_id exists, fees > 0, reg_deadline before the launch date, eid is of admin? Or rely on schema to check?
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
                ROLLBACK;
            ELSE
                SELECT eid FROM find_instructors(cid, session_date, start_time) ORDER BY eid ASC LIMIT 1 INTO instructor_id;

                CALL add_session(offering_launch_date, cid, session_number, session_date, start_time, instructor_id, room_id);

            END IF;

        END LOOP;

        -- 'Note that the seating capacity of the course offering must be at least equal to the course offering’s target number of registrations.'
        IF offering_target_number_registrations > total_seating_capacity THEN
            ROLLBACK;
        END IF;

        UPDATE Offerings
        SET seating_capacity = total_seating_capacity
        WHERE launch_date = offering_launch_date AND course_id = cid;

        COMMIT;

    END;
$$ LANGUAGE plpgsql;