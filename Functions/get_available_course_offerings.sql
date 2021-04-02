create function get_available_course_offerings()
    returns TABLE(c_title text, c_area_name text, c_start_date date, c_end_date date, reg_deadline date, c_fees money, num_remaining_seats integer)
    language plpgsql
as
$$
DECLARE
    curs CURSOR FOR (SELECT * FROM Courses natural join Offerings ORDER BY registration_deadline, title);
    r RECORD;
    seating_cap INTEGER;
    num_registrations INTEGER;
    num_redemptions INTEGER;
BEGIN
    -- num remaining seats = seating capacity - total number of reg
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        reg_deadline := r.registration_deadline;
        IF reg_deadline > NOW()::timestamp::date THEN
            seating_cap := r.seating_capacity;
            SELECT COUNT(*) INTO num_registrations FROM REGISTERS
            WHERE launch_date = r.launch_date and course_id = r.course_id;
            SELECT COUNT(*) INTO num_redemptions FROM REDEEMS
            WHERE launch_date = r.launch_date and course_id = r.course_id;
            num_remaining_seats := seating_cap - num_registrations - num_redemptions;

            IF num_remaining_seats > 0 THEN
                c_title := r.title;
                c_area_name := r.course_area_name;
                c_start_date := r.actual_start_date;
                c_end_date := r.end_date;
                c_fees := r.fees;
                RETURN NEXT;
            END IF;
        END IF;
    END LOOP;
    CLOSE curs;
END;
$$;
