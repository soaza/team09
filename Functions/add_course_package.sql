-- Q11
-- package_id is auto generated in this function
CREATE OR REPLACE PROCEDURE add_course_package(course_package_name TEXT, num_free_registrations INTEGER, sale_start_date DATE,
    sale_end_date DATE, price DECIMAL)
AS $$
DECLARE
    pkg_id INTEGER;
    num_pkgs INTEGER;
BEGIN
    -- increment one from current max package id
    SELECT count(*) FROM Course_packages INTO num_pkgs;
    IF num_pkgs = 0 THEN
        select 1 INTO pkg_id;
    ELSE
        SELECT max(package_id) + 1 FROM Course_packages INTO pkg_id;

    INSERT INTO Course_packages
    values (pkg_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations);
    END IF;

END;
$$ LANGUAGE plpgsql;