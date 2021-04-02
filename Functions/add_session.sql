-- Q24 --
-- add_session: This routine is used to add a new session to a course offering.
-- The inputs to the routine include the following: course offering identifier, new session number, new session day,
-- new session start hour, instructor identifier for new session, and room identifier for new session.
-- If the course offering’s registration deadline has not passed and the the addition request is valid,
-- the routine will process the request with the necessary updates.

-- course offering identifier: do we want to add a field to the schema?
-- or just use launch date and cid, bc for q10 they said course offering identifier but have launch date also
-- Need to consider things like, whether the room is being used on another day
CREATE OR REPLACE PROCEDURE add_session(offering_launch_date DATE, cid INTEGER, new_session_number INTEGER,
new_session_day DATE, new_session_start_hour TIME, instructor_id INTEGER, room_id INTEGER)
AS $$
DECLARE
    end_hour TIME;
    room_seating_capacity INTEGER;
    offering_registration_deadline DATE;
    room_used INTEGER;

    curr_max_session_number INTEGER;
    instructor_specialisation TEXT;
    course_specialisation TEXT;
BEGIN
    SELECT new_session_start_hour + duration * interval '1 hour' FROM Courses WHERE course_id = cid INTO end_hour;
    SELECT seating_capacity FROM Rooms WHERE rid = room_id INTO room_seating_capacity;
    SELECT registration_deadline FROM Offerings WHERE launch_date = offering_launch_date AND course_id = cid INTO offering_registration_deadline;

    SELECT count(*)
        FROM Course_Sessions
        WHERE session_date = new_session_day AND
        (new_session_start_hour, end_hour) OVERLAPS (start_time, end_time) = TRUE
        INTO room_used;

    SElECT MAX(course_session_id) FROM Course_sessions WHERE launch_date = offering_launch_date AND course_id = cid INTO curr_max_session_number;

    SELECT course_area_name FROM Specialises WHERE eid = instructor_id INTO instructor_specialisation;
    SELECT course_area_name FROM Courses WHERE course_id = cid INTO course_specialisation;

    IF offering_registration_deadline < now()::DATE THEN
        ROLLBACK;

    -- check if room is being used by another session
    ELSIF room_used <> 0 THEN
        ROLLBACK;

    ELSIF curr_max_session_number IS NULL AND new_session_number != 0 THEN
        ROLLBACK;

    ELSIF curr_max_session_number + 1 <> new_session_number THEN
        ROLLBACK;

    ELSIF instructor_specialisation <> course_specialisation THEN
        ROLLBACK;

    ELSE
        INSERT INTO Course_sessions VALUES (new_session_number, room_id, instructor_id, new_session_day, new_session_start_hour,
        end_hour, offering_launch_date, cid);

        -- Increase the seating capacity of offerings (Or is this a trigger???)
        UPDATE Offerings SET seating_capacity = (seating_capacity + room_seating_capacity)
        WHERE launch_date = offering_launch_date AND course_id = cid;

        COMMIT;
    END IF;

END;
$$ LANGUAGE plpgsql;