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

-- Testcases
SELECT find_rooms('2020-10-10','08:00',2);
SELECT find_rooms('2020-11-13','08:00',2);