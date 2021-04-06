-- Trigger for Course_sessions: course_session_id inserted into Course_sessions must be in consecutive order

create or replace function consecutive_sid_course_sessions() returns trigger
    language plpgsql
as 
$$
DECLARE
current_highest_sid INTEGER;

BEGIN 
    SELECT max(course_session_id) INTO current_highest_sid
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