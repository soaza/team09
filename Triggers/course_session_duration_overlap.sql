```
Trigger 3: overlapping of start_time-end_time in CourseSessions as each room used to conduct 
at most 1 course session at any time
```
create or replace function course_session_duration_overlap() returns trigger
    language plpgsql
as
$$
DECLARE
-- new duration in hours
new_session_duration INTEGER;

BEGIN
    SELECT T.duration INTO new_session_duration
        FROM (Course_Sessions NATURAL JOIN Courses) T
        WHERE T.course_id = NEW.course_id;

    IF EXISTS(
        SELECT *
        FROM (Course_Sessions NATURAL JOIN Courses) T
        WHERE session_date = NEW.session_date
        AND  rid = NEW.rid
        AND  (T.launch_date <> NEW.launch_date OR T.course_id <> NEW.course_id)
        -- new session ends in between a session
        AND (
        (EXTRACT(hours FROM start_time) <= EXTRACT(hours FROM NEW.start_time) + new_session_duration 
             AND EXTRACT(hours FROM NEW.start_time) + new_session_duration <= EXTRACT(hours FROM end_time))
        -- new session starts in between a session
        OR
        (start_time <= NEW.start_time AND NEW.start_time <= end_time)
            ))
        THEN
    RAISE NOTICE 'New course_session timing overlaps with existing timings,
                each room used to conduct at most 1 course session at any time ';
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
