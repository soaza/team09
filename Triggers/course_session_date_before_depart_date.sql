-- Trigger: Course_session_date must be before depart_date of employee
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