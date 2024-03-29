-- 6. find_instructors
--  This routine is used to find all the instructors who could be assigned to teach a course session.
--  inputs: course identifier, session date, and session start hour. 
--  The routine returns a table of records consisting of employee identifier and name.
create or replace function find_instructors(find_course_id integer, find_session_date date, find_start_time time without time zone)
    returns TABLE(eid integer, emp_name text)
    language sql
as
$$
SELECT eid,emp_name
    FROM (Specialises NATURAL JOIN Courses NATURAL JOIN Instructors NATURAL JOIN Employees) T
    WHERE T.course_id = find_course_id
    -- filter out instructors that have lessons during the start time
    AND T.eid NOT IN (
        SELECT C.eid
        FROM Course_Sessions C
        where C.session_date = find_session_date
        and C.eid = T.eid
        and
        (
        -- start_time between the range
        (
            extract(hours from C.start_time) < extract(hours from find_start_time)
            and 
            extract(hours from find_start_time) < extract(hours from C.end_time)  + 1
         )
        or
        (
            -- end time between the range
            extract(hours from C.start_time) < extract(hours from find_start_time) + T.duration
            and
            extract(hours from find_start_time) + T.duration <  extract(hours from C.end_time) + 1
        )
        )
    )
$$;