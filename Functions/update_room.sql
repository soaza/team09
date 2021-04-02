```
22. update_room: This routine is used to change the room for a course session. 

Inputs: course offering identifier, session number, and identifier of the new room.

If the course session has not yet started and the update request is valid, the routine 
will process the request with the necessary updates. 

Note that update request should not be performed if the number of registrations for the session
exceeds the seating capacity of the new room.
```
-- NOTE: course offering identifier consists of launch date and course id as Offerings is a weak entity of Courses

create procedure update_room(find_launch_date date, find_course_id integer, session_number integer, updated_rid integer)
    language plpgsql
as
$$
DECLARE
    find_session_date DATE;
    room_capacity INTEGER;
    number_registered INTEGER;  
BEGIN 

    SELECT R.seating_capacity INTO room_capacity
            FROM Rooms R
            WHERE R.rid = updated_rid;

    SELECT COUNT(*) INTO number_registered
            FROM (Registers NATURAL JOIN Course_Sessions) T
            WHERE T.launch_date = find_launch_date 
            AND T.course_id=find_course_id
            AND T.course_session_id = session_number;
    
    SELECT S.session_date INTO find_session_date 
            FROM Course_Sessions S
            WHERE S.course_session_id = session_number
            AND S.launch_date = find_launch_date
            AND S.course_id = find_course_id;

    -- Only update if session_date later than today and number of registrations for the session does not exceed seating capacity
    IF (find_session_date > CURRENT_DATE and number_registered <= room_capacity) THEN
        UPDATE Course_Sessions S
        SET rid = updated_rid
        WHERE S.course_session_id = session_number
        and S.launch_date = find_launch_date
        and S.course_id = find_course_id;
    END IF;
END;
$$;

alter procedure update_room(date, integer, integer, integer) owner to kimguan;

