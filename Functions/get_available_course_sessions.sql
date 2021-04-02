create function get_available_course_sessions(l_date date, cid integer)
    returns TABLE(s_date date, s_start_time time without time zone, s_instructor integer, num_remaining_seats integer)
    language plpgsql
as
$$
DECLARE
    curs CURSOR FOR (SELECT * FROM Course_Sessions
    WHERE launch_date = l_date AND course_id = cid ORDER BY session_date, start_time);
    r RECORD;
    s_capacity INTEGER;
    num_registrations INTEGER;
    num_redemptions INTEGER;
BEGIN
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        s_date := r.session_date;
        s_start_time := r.start_time;
        s_instructor := r.eid;
        SELECT seating_capacity INTO s_capacity FROM Rooms WHERE rid = r.rid;
        SELECT COUNT(*) INTO num_registrations FROM REGISTERS
        WHERE course_session_id = r.course_session_id AND launch_date = r.launch_date AND course_id = r.course_id;
        SELECT COUNT(*) INTO num_redemptions FROM REDEEMS
        WHERE course_session_id = r.course_session_id AND launch_date = r.launch_date AND course_id = r.course_id;
        num_remaining_seats := s_capacity - num_registrations - num_redemptions;
        RETURN NEXT;
    END LOOP;
    CLOSE curs;
END;
$$;
