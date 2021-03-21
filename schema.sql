-- TODO : Add status field to package redemeption (possible trigger)
-- TODO : Check primary key for Registration whether to include cust_id and course_session_id
-- Trigger 1: customers must register before registration_deadline Offerings
-- Trigger 2: total seating_capacity from Rooms >= num_registrations with the same course_id in Register and Redeems
-- Trigger 3: overlapping of start_time-end_time in CourseSessions
    -- each room used to conduct at most 1 course session at any time
-- Trigger 4: Each course offering has a start date and an end date that 
    -- is determined by the dates of its earliest and latest sessions, respectively
-- Trigger 5: Overlap constraint for Employees is either Manager,Administrator or Instructor
-- Trigger 6: Instructor who is assigned to teach a course session must be specialized in that course area
-- Trigger 7:Each instructor can teach at most one course session at any hour. 
    -- Each instructor must not be assigned to teach two consecutive course sessions; 
    -- i.e. there must be at least one hour of break between any two course sessions that the instructor is teaching.
-- Trigger 8:Each part-time instructor must not teach more than 30 hours for each month.
-- Trigger 9:Each course offering is managed by the manager of that course area.
CREATE TABLE Employees(
    eid INTEGER PRIMARY KEY,
    emp_name TEXT,
    emp_address TEXT,
    phone INTEGER,
    email TEXT,
    join_date DATE,
    depart_date DATE
        check depart_date - join_date >= 0
);

CREATE TABLE Part_time_Emp (
    eid INTEGER PRIMARY KEY,
    hourly_rate MONEY,
    FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

CREATE TABLE Full_time_Emp (
    eid INTEGER PRIMARY KEY,
    month_salary MONEY,
    FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

CREATE TABLE Managers (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY(eid) REFERENCES Full_time_Emp(eid) ON DELETE CASCADE
);

CREATE TABLE Administrators (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY(eid) REFERENCES Full_time_Emp(eid) ON DELETE CASCADE
);

CREATE TABLE Pay_slips (
    payment_date DATE,
    eid INTEGER,
    amount MONEY,
    num_work_hours INTEGER,
    -- last work day - first work day + 1
    num_work_days INTEGER,
    FOREIGN KEY(eid) REFERENCES Employees(eid),
    PRIMARY KEY(payment_date,eid)
);

CREATE TABLE Instructors(
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

CREATE TABLE Part_time_instructors (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY(eid) REFERENCES Instructors(eid) REFERENCES Part_time_Emp(eid)
     ON DELETE CASCADE
);

CREATE TABLE Full_time_instructors (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY(eid) REFERENCES Instructors(eid) REFERENCES Full_time_Emp(eid)
     ON DELETE CASCADE
);

CREATE TABLE Course_area (
    course_area_name TEXT PRIMARY KEY,
    -- eid is for Manager managing Course_area
    eid INTEGER NOT NULL,
    FOREIGN KEY(eid) REFERENCES Managers(eid)
);

CREATE TABLE Specialises (
    -- eid is for instructors specialising in course_area
    eid INTEGER,
    course_area_name TEXT,
    PRIMARY KEY(eid,course_area_name),
    FOREIGN KEY(eid) REFERENCES Instructors,
    FOREIGN KEY(course_area_name) REFERENCES course_area
);

CREATE TABLE Courses (
    course_id INTEGER PRIMARY KEY,
    course_area_name TEXT NOT NULL,
    title TEXT UNIQUE,
    course_description text,
    -- in terms of hours
    duration INTEGER,
    FOREIGN KEY(course_area_name) REFERENCES Course_area(course_area_name)
);


CREATE TABLE Offerings (
    launch_date DATE,
    course_id INTEGER REFERENCES Courses(course_id),
    -- eid of administrator
    eid INTEGER NOT NULL
    actual_start_date DATE,
    end_date DATE,
    registration_deadline DATE
        CHECK registration_deadline - actual_start_date >= 10,
    target_number_registrations INTEGER
        CHECK target_number_registrations >= 0,
    seating_capacity INTEGER
        CHECK seating_capacity >= 0,
    fees MONEY
        CHECK fees >= 0,
    PRIMARY KEY(launch_date,course_id),
    FOREIGN KEY(eid) REFERENCES Administrators(eid)
);
-- Trigger: seating_capacity >= num_registrations with the same course_id in Register 

CREATE TABLE Rooms (
    rid INTEGER PRIMARY KEY,
    -- in terms of floor and room numbers
    room_location TEXT,
    seating_capacity INTEGER
);


CREATE TABLE Course_Sessions (
    course_session_id INTEGER,
    room_id INTEGER NOT NULL,
    eid INTEGER NOT NULL,
    session_date DATE
    -- check session_date falls between monday and friday
        check extract(isodow from session_date) in (1,2,3,4,5),
    start_time TIME
    -- start_time after 9am
        check extract(hour from start_time) - 9 >= 0
        and 
        -- no sessions between 12pm and 2pm
        (
         12 - extract(hour from start_time) >= 0
        or
         extract(hour from start_time) - 14 >= 0
        )
    end_time TIME
    -- end_time after 6pm
        check 18 - extract(hour from end_time) >= 0
        and
        end_time > start_time
        and 
        -- no sessions between 12pm and 2pm
        (
         12 - extract(hour from end_time) >= 0
        or
         extract(hour from end_time) - 14 >= 0
        )
    
    launch_date DATE,
    course_id INTEGER,
    FOREIGN KEY(room_id) REFERENCES Rooms(room_id),
    FOREIGN KEY(eid) REFERENCES Instructors(eid),
    FOREIGN KEY(launch_date,course_id) REFERENCES Offerings(launch_date,course_id),
    PRIMARY KEY(launch_date,course_id,course_session_id)
);

CREATE TABLE Customers (
    cust_id  PRIMARY KEY,
    cust_address TEXT,
    phone INTEGER,
    cust_name TEXT,
    -- we are assuming the input email are valid
    email TEXT
);

CREATE TABLE Credit_cards (
    credit_card_num INTEGER PRIMARY KEY,
    cvv INTEGER,
    card_expiry_date DATE,
    from_date DATE,
    cust_id INTEGER NOT NULL,
    UNIQUE(credit_card_num,cust_id),
    FOREIGN KEY cust_id REFERENCES Customers(cust_id)
);


CREATE TABLE Registers (
    -- Trigger 1: customers must register before registration_deadline Offerings
    registration_date DATE,
    -- Primary Key of Course_Sessions
    course_session_id INTEGER NOT NULL,
    launch_date DATE, 
    course_id INTEGER,

    cust_id INTEGER,
    -- Primary Key of Credit_cards
    credit_card_num INTEGER,
    FOREIGN KEY(credit_card_num,cust_id) REFERENCES Credit_cards(credit_card_num,cust_id),
    FOREIGN KEY(course_session_id,launch_date,course_id) REFERENCES Course_Sessions(course_session_id,launch_date,course_id),
    PRIMARY KEY(cust_id,launch_date,course_id)
    -- No course_session_id due to at most one constraint, 
    -- if course_session_id is in primary key, customer can register for more 
    -- than 1 session for the same offering which is uniquely identified by launchdate and course_id.
);

CREATE TABLE Course_packages (
    package_id INTEGER PRIMARY KEY,
    sale_start_date DATE,
    sale_end_date DATE
        check sale_end_date >= sale_start_date,
    course_package_name TEXT,
    price MONEY 
        check price >= 0,
    num_free_registrations INTEGER
        check num_free_registrations >= 0
);

CREATE TABLE Buys (
    buy_date DATE,
    package_id INTEGER,
    credit_card_num INTEGER,
    num_remaining_redemptions INTEGER,
    FOREIGN KEY(credit_card_num) REFERENCES Credit_cards(credit_card_num),
    FOREIGN KEY(package_id) REFERENCES Course_packages(package_id),
    PRIMARY KEY(buy_date,credit_card_num,package_id)
);

CREATE TABLE Redeems (
    redeem_date DATE,
    -- Primary Key of Buys
    buy_date DATE,
    credit_card_num INTEGER,
    package_id INTEGER,
    -- Primary Key of Course_Sessions
    course_session_id INTEGER,
    launch_date DATE, 
    course_id INTEGER,

    FOREIGN KEY(course_session_id,launch_date,course_id) REFERENCES Course_Sessions(course_session_id,launch_date,course_id),
    FOREIGN KEY(buy_date,credit_card_num,package_id) REFERENCES Buys(buy_date,credit_card_num,package_id),
    PRIMARY KEY(redeem_date,course_session_id,launch_date,course_id,buy_date,credit_card_num,package_id)
);

CREATE TABLE Cancels (
    -- to check that it is refundable 
    cancel_date DATE,
    refund_amt MONEY,
    package_credit INTEGER,
    -- Primary Key of Course_Sessions
    course_session_id INTEGER,
    launch_date DATE, 
    course_id INTEGER,

    cust_id INTEGER,
    FOREIGN KEY(course_session_id,launch_date,course_id) REFERENCES Course_Sessions(course_session_id,launch_date,course_id),
    FOREIGN KEY(cust_id) REFERENCES Customers(cust_id),
    PRIMARY KEY(cancel_date,course_session_id,launch_date,course_id,cust_id)
);

 
