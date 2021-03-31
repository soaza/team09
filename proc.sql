-- 3. add_customer: 
create procedure add_customer(custname text, homeaddress text, contactnumber integer, custemail text, creditcardnum integer, cardexpirydate date, cardcvv integer)
    language plpgsql
as
$$
DECLARE
    custId INT;
BEGIN
    custId := 11;
    INSERT INTO Customers VALUES (custId, homeAddress, contactNumber, custName, custEmail);
    INSERT INTO Credit_cards VALUES (creditCardNum, cardCVV, cardExpiryDate, NULL, custId);
END;
$$;







-- 4. update_credit_card: 
CREATE OR REPLACE PROCEDURE update_credit_card
    (custId INT, creditCardNum INTEGER, cardExpiryDate DATE, cardCVV INTEGER)
    AS $$
BEGIN
    UPDATE Credit_cards
    SET credit_card_num = creditCardNum,
        cvv = cardCVV,
        card_expiry_date = cardExpiryDate
    WHERE  cust_id = custId;
END;
$$ LANGUAGE plpgsql;


-- 5. add_course: 
--  This routine is used to add a new course. 
--  inputs: course title, course description, course area, and duration(in terms of hours).
--  The course identifier is generated by the system.
create procedure add_course(title text, course_description text, course_area_name text, duration integer)
    language plpgsql
as
$$
DECLARE
    id INT;
BEGIN
    SELECT MAX(course_id) + 1 INTO id FROM Courses;
    INSERT INTO Courses (course_id,course_area_name,title,course_description,duration)
    VALUES (id,course_area_name,title,course_description,duration);
END;
$$;





-- 6. find_instructors
--  This routine is used to find all the instructors who could be assigned to teach a course session.
--  inputs: course identifier, session date, and session start hour. 
--  The routine returns a table of records consisting of employee identifier and name.
create function find_instructors(find_course_id integer, find_session_date date, find_start_time time without time zone)
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
        (extract(hours from C.start_time) <= extract(hours from find_start_time) + 1
         and extract(hours from find_start_time) + 1 <= C.end_time)
        or
        (   
            -- end time between the range
            extract(hours from C.start_time) <= extract(hours from find_start_time) + T.duration + 1
            and
            extract(hours from find_start_time) + T.duration + 1 <=  extract(hours from C.end_time)
        )
        )
    )
$$;


-- 7. get_available_instructors
-- This routine is used to retrieve the availability information of instructors who could be assigned to teach a specified course. 
--  inputs: course identifier, start date, and end date. 
-- output:SETS OF (eid, name,total number of teaching hours
--  that the instructor has been assigned for this month, day 
-- (which is within the input date range [start date, end date]), 
-- and an array of the available hours for the instructor on the specified day. 
-- output: sorted in ascending order of employee identifier and day, and the array entries are sorted in ascending order of hour.



-- 8. find_rooms: This routine is used to find all the rooms that could be used for a course session. 
-- The inputs to the routine include the following: 
-- session date, session start hour, and session duration. 
-- The routine returns a table of room identifiers.
CREATE OR REPLACE FUNCTION find_rooms
-- ASSUMPTION: DURATION IN HOURS
(IN find_session_date DATE,IN find_start_time TIME,IN find_duration INTEGER)
RETURNS TABLE(rid INTEGER) AS $$
    SELECT R.rid
    FROM Rooms R
    -- exclude rooms occupied during start time
    -- and rooms occupied where duration overlaps
    EXCEPT
    SELECT C.rid
    FROM Course_Sessions C
    WHERE C.session_date = find_session_date
    AND (
    (C.start_time < find_start_time and find_start_time < C.end_time)
    OR
    -- and rooms occupied where duration overlaps
    (extract(hour from start_time) + find_duration > C.start_time)
    );
END
$$ LANGUAGE SQL





