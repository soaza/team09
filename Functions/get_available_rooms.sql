-- q9
-- retrieve availability info of rooms for specific duration
-- NOTE: they used "day" but i assume they are talking about date? otherwise abit dont make sense.
-- output sorted in ascending order of room identifier n day
-- array entries are sorted in ascending order of hour. [do i assume 0 - 23?]
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

    session_info Course_sessions%ROWTYPE;

-- sessions: session_date, start_time, end_time, rooms: rid, seating capacity
-- IDEA: For each room, loop through each date and find the sessions for that rm and date.
-- Generate a array of 24 hours, remove (start, end hour) found in sessions
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

                with Hours_Unavailable as
                        (SELECT '00:00:00'::time + x * '1 hour'::interval
                        FROM generate_series(start_hour, end_hour - 1) as t(x)) -- NOTE: exclusive of end_hour!!
                SELECT ARRAY(SELECT * FROM Hours_Unavailable) INTO hours_not_available;

                -- result of this will not be sorted, so need to sort it
                select array(select unnest(hours_available) except select unnest(hours_not_available)) into hours_available;
            END LOOP;

            -- For sorting in ascending order
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