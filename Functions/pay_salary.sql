```
25. pay_salary: This routine is used at the end of the month to pay salaries to employees.
The routine inserts the new salary payment records 
and returns a table of records (sorted in ascending order of employee identifier) 
with the following information for each employee who is paid for the month: 
employee identifier, name, status (either part-time or full-time), number of work days for the month, 
number of work hours for the month, hourly rate, monthly salary, and salary amount paid.
 For a part-time employees, the values for number of work days for the month and monthly salary should be null. 
For a full-time employees, the values for number of work hours for the month and hourly rate should be null.
```
create function pay_salary()
    returns TABLE(emp_id integer, curr_emp_name text, emp_status text, num_work_days integer, num_work_hours integer, curr_hourly_rate numeric, curr_monthly_salary numeric, salary_amount numeric)
    language plpgsql
as
$$
DECLARE
    curs CURSOR FOR (
        SELECT * FROM Employees
            NATURAL FULL OUTER JOIN
            Part_Time_Emp NATURAL FULL OUTER JOIN
            Full_Time_Emp
            ORDER BY eid ASC);
    r RECORD;
    curr_join_date DATE;
    curr_depart_date DATE;
    part_time_duration INTEGER;

BEGIN
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;

        emp_id := r.eid;
        curr_emp_name := r.emp_name;
        curr_monthly_salary := r.month_salary;
        curr_hourly_rate := r.hourly_rate;

        curr_join_date := r.join_date;
        curr_depart_date := r.depart_date;

        -- Full-Time
        IF r.hourly_rate IS NULL THEN
            emp_status := 'Full-Time';
            num_work_hours := NULL;

            -- if normal month
            num_work_days := EXTRACT(DAY FROM CURRENT_DATE) - 1 + 1;
            salary_amount := curr_monthly_salary;

            -- if current month same as month of joining
            IF EXTRACT(MONTH FROM curr_join_date) = EXTRACT(MONTH FROM CURRENT_DATE)
            and EXTRACT(YEAR FROM curr_join_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
            --  'routine is used at the end of the month' implies that the current date is the last day
            num_work_days := EXTRACT(DAY FROM CURRENT_DATE) - EXTRACT(DAY FROM curr_join_date) + 1;
            salary_amount := num_work_days/EXTRACT(DAY FROM CURRENT_DATE) * 100;
            END IF;

            -- if current month same as month of departing
            IF EXTRACT(MONTH FROM curr_depart_date) = EXTRACT(MONTH FROM CURRENT_DATE)
            and EXTRACT(YEAR FROM curr_depart_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
            num_work_days := EXTRACT(DAY FROM curr_depart_date) - 1 + 1;
            salary_amount := num_work_days/EXTRACT(DAY FROM CURRENT_DATE) * 100;
            END IF;

        -- Part-Time
        ELSE
            emp_status := 'Part-Time';
            num_work_days := NULL;

            SELECT T.duration INTO part_time_duration
                    FROM (Course_Sessions NATURAL JOIN Courses) T
                    WHERE T.eid = emp_id;
            SELECT part_time_duration * COUNT(*) INTO num_work_hours
                    FROM (Course_Sessions NATURAL JOIN Courses) T
                    -- We only consider sessions this month
                    WHERE T.eid = emp_id
                      and EXTRACT(MONTH FROM T.session_date) = EXTRACT(MONTH FROM CURRENT_DATE)
                      and EXTRACT(YEAR FROM T.session_date) = EXTRACT(YEAR FROM CURRENT_DATE);

            salary_amount := curr_hourly_rate * num_work_hours;
        END IF;

        --  If employee has departed we do not pay them
        IF curr_depart_date < CURRENT_DATE and curr_depart_date IS NOT NULL THEN
            salary_amount := 0;
        ELSIF salary_amount <> 0 THEN
            INSERT INTO pay_slips VALUES (current_date,emp_id,salary_amount,num_work_hours,num_work_days);
        END IF;

        RETURN NEXT;
    END LOOP;
END;
$$;

alter function pay_salary() owner to kimguan;








