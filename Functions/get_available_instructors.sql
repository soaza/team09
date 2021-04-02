```7. get_available_instructors
This routine is used to retrieve the availability information of instructors who could be assigned to teach a specified course. 
 inputs: course identifier, start date, and end date. 
output:SETS OF (eid, name,total number of teaching hours
 that the instructor has been assigned for this month, day 
(which is within the input date range [start date, end date]), 
and an array of the available hours for the instructor on the specified day. 
output: sorted in ascending order of employee identifier and day, and the array entries are sorted in ascending order of hour.```
create function get_available_instructors(find_course_id integer, find_start_date date, find_end_date date) 
    returns TABLE(emp_id integer, emp_name text, teaching_hours integer, day_available date, hours_arr time without time zone[])
    language plpgsql
as
$$
-- sessions 1h apart from each other
DECLARE 
    curs CURSOR FOR (
                    SELECT *  FROM Instructors natural join Employees natural join Specialises natural join  courses T 
                    WHERE T.course_id = find_course_id);
    possible_date DATE;
    days_arr DATE[];
    r RECORD;
    possible_hour TIME;
    possible_hours TIME[];
    total_sessions int;
    session_duration int;
BEGIN
    OPEN curs;
    LOOP
        FETCH curs into r;
        EXIT WHEN NOT FOUND;
        emp_id := r.eid;
        emp_name := r.emp_name;
        days_arr := ARRAY(
                SELECT day::date
                FROM generate_series( find_start_date, find_end_date, '1 day') day
            );
        -- Loop through all possible days
        FOREACH possible_date SLICE 0 IN ARRAY days_arr
        LOOP
            day_available := possible_date;
            --Loop through all possible hours
            hours_arr := '{}';
            possible_hours := '{09:00,10:00,11:00,13:00,14:00,15:00,16:00,17:00}';
            FOREACH possible_hour in ARRAY possible_hours
            LOOP
                 IF EXISTS (
                  SELECT T.eid
                  FROM find_instructors(find_course_id,possible_date,possible_hour) T
                  WHERE  T.eid = emp_id
                  ) THEN
                    hours_arr := array_append(hours_arr, possible_hour);
                END IF;
            END LOOP;

            -- we get total number of teaching hours that the instructor has been assigned for this month
            SELECT COUNT(*) INTO total_sessions
            FROM (Course_Sessions NATURAL JOIN Courses) C
            group by C.eid;

            SELECT duration INTO session_duration
            FROM Courses NATURAL JOIN Course_Sessions T
            WHERE T.eid = emp_id;

            teaching_hours := total_sessions * session_duration;


            RETURN  NEXT;

        END LOOP;

    END LOOP;
    END;
$$;

alter function get_available_instructors(integer, date, date) owner to kimguan;

