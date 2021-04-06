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