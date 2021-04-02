```21. update_instructor: 
This routine is used to change the instructor for a course session. 
input : course offering identifier, session number, and eid 
. If the course session has not yet started and the update request is valid, 
the routine will process the request with the necessary updates. ```
-- NOTE: course offering identifier consists of launch date and course id as Offerings is a weak entity of Courses
-- TODO: What do they mean by valid?

create or replace procedure update_instructor(find_launch_date DATE ,find_course_id INTEGER,session_number INTEGER,updated_eid INTEGER)
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
        UPDATE Course_Sessions S
        SET eid = updated_eid
        WHERE S.course_session_id = session_number
        and S.launch_date = find_launch_date
        and S.course_id = find_course_id;
    END IF;
END;
$$