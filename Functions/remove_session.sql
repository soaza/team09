```
23.remove_session: 
This routine is used to remove a course session. 
Inputs : course offering identifier and session number.

If the course session has not yet started and the request is valid, the routine will process the request with the 
necessary updates. The request must not be performed if there is at least one registration for the session.

Note that the resultant seating capacity of the course offering could fall below the course offering’s target number of 
registrations, which is allowed.
```
-- NOTE: course offering identifier consists of launch date and course id as Offerings is a weak entity of Courses
-- TODO: What do they mean by valid?

create procedure remove_session(find_launch_date date, find_course_id integer, session_number integer)
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
    -- The request must not be performed if there is at least one registration for the session.
        IF NOT EXISTS (
                  SELECT *
                  FROM Registers
                  WHERE launch_date = find_launch_date
                  AND course_id = find_course_id
                  AND course_session_id = session_number
                  )
                THEN
                    DELETE FROM Course_Sessions
                    WHERE launch_date = find_launch_date
                    AND course_id = find_course_id
                    AND course_session_id = session_number;
        END IF;
    END IF;

END;
$$;

alter procedure remove_session(date, integer, integer) owner to kimguan;

