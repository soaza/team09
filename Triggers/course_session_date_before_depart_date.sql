-- Trigger: Course_session_date must be before depart_date of employee
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
)   THEN
RETURN NULL;
ELSE
RETURN NEW;
END IF;
END;
$$

create trigger course_session_date_before_depart_date_trigger
    before insert or update
    on Course_sessions
    for each row 
execute procedure course_session_date_before_depart_date();