-- 8. find_rooms: This routine is used to find all the rooms that could be used for a course session. 
-- The inputs to the routine include the following: 
-- session date, session start hour, and session duration. 
-- The routine returns a table of room identifiers.
create function find_rooms(find_session_date date, find_start_time time without time zone, find_duration integer)
    returns TABLE(rid integer)
    language sql
as
$$
SELECT R.rid
    FROM Rooms R
    -- exclude rooms occupied during start time
    -- and rooms occupied where duration overlaps
    EXCEPT
    SELECT C.rid
    FROM Course_Sessions C
    WHERE C.session_date = find_session_date
    AND (
        -- start time is between existing sessions
            (C.start_time <= find_start_time and find_start_time < C.end_time)
            OR
            -- end time is between existing sessions
            (
                        extract(hour from find_start_time) + find_duration > extract(hour from C.start_time)
                    AND
                        extract(hour from C.end_time) >= extract(hour from find_start_time) + find_duration
                )
        );
$$;







