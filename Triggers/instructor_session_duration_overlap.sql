```
Trigger 7:
Each instructor can teach at most one course session at any hour. 
Each instructor must not be assigned to teach two consecutive course sessions; 
i.e. there must be at least one hour of break between any two course sessions that the instructor is teaching.
```
create function instructor_session_duration_overlap() returns trigger
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
            RAISE NOTICE 'Instructor can teach at most one course session at any hour ' 
                'and there must be at least one hour of break between any two course sessions that the instructor is teaching.';
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

