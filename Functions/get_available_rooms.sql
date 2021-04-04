-- q9
-- Retrieves availability info of rooms for specific range of dates.
-- NOTE: they used "day" but i assume they are talking about date.
-- The output is sorted in ascending order of room identifier and day, and array entries are sorted in ascending order of hour.
-- IDEA: For each room, loop through each date and find the sessions for that rm and date.
-- Generate a array of 24 hours, remove (start, end hour) found in sessions
CREATE OR REPLACE FUNCTION get_available_rooms(start_date DATE, end_date DATE)
RETURNS TABLE (room_id INTEGER, seating_capacity INTEGER, date_available DATE,
hours_available TIME[]) AS $$
DECLARE
    curs_room CURSOR FOR (SELECT * FROM Rooms ORDER BY rid ASC); -- ensures sorted by room id first
    r RECORD;

    curs_date CURSOR FOR (
        SELECT * FROM generate_series(start_date::timestamp, end_date::timestamp, '1 day')
    ); -- date generated in increasing order, so ensures sorted when looping through it
    d DATE;

    hours_not_available TIME[];
    start_hour INTEGER;
    end_hour INTEGER;
    end_minute INTEGER;

    session_info Course_sessions%ROWTYPE;

BEGIN
    OPEN curs_room;
    LOOP
        FETCH curs_room into r;
        EXIT WHEN NOT FOUND;
        room_id := r.rid;
        seating_capacity := r.seating_capacity;

        OPEN curs_date;
        LOOP
            FETCH curs_date into d;
            EXIT WHEN NOT FOUND;
            date_available := d::date;
            SELECT ARRAY(
                select * from generate_series (
                    timestamp '2021-03-03 00:00', timestamp '2021-03-03 23:59', interval '1h'))::time[] INTO hours_available;

            -- loop through sessions that are using the room at this date to extract out timings that the room is in use
            FOR session_info IN (SELECT * FROM Course_Sessions WHERE rid = r.rid AND session_date = d)
            LOOP
                SELECT extract(hour from session_info.start_time) INTO start_hour;
                SELECT extract(hour from session_info.end_time) INTO end_hour;
                SELECT extract(minute from session_info.end_time) INTO end_minute;

                IF end_minute = 0 THEN
                    with Hours_Unavailable as
                            (SELECT '00:00:00'::time + x * '1 hour'::interval
                            FROM generate_series(start_hour, end_hour - 1) as t(x)) -- NOTE: exclusive of end_hour!!
                    SELECT ARRAY(SELECT * FROM Hours_Unavailable) INTO hours_not_available;
                ELSE
                    with Hours_Unavailable as
                            (SELECT '00:00:00'::time + x * '1 hour'::interval
                            FROM generate_series(start_hour, end_hour) as t(x)) -- NOTE: inclusive of end_hour!!
                    SELECT ARRAY(SELECT * FROM Hours_Unavailable) INTO hours_not_available;
                END IF;

                -- Result of this will not be sorted
                select array(select unnest(hours_available) except select unnest(hours_not_available)) into hours_available;
            END LOOP;

            -- Sorts array in ascending order
            SELECT array(
                SELECT DISTINCT UNNEST(
                    hours_available
                ) ORDER BY 1) INTO hours_available;

            -- looked through all sessions for this room, for this date, add to table
            RETURN NEXT;
        END LOOP;
        CLOSE curs_date;

    END LOOP;
    CLOSE curs_room;

END;
$$ LANGUAGE plpgsql;