-- Q12
-- available for sale (i.e. current date is between the start date and end date inclusive)
-- package name, number of free course sessions, end date for promotional package, and the price of the package.
CREATE OR REPLACE FUNCTION get_available_course_packages()
RETURNS TABLE(course_package_name TEXT, num_free_registrations INTEGER, sale_end_date DATE,
    price DECIMAL) AS $$
    SELECT course_package_name, num_free_registrations, sale_end_date, price
    FROM Course_packages
    WHERE now()::DATE BETWEEN sale_start_date AND sale_end_date;
$$ LANGUAGE sql;