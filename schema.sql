DROP TABLE IF EXISTS
Employees
,Part_time_Emp
,Full_time_Emp
,Managers
,Administrators
,Pay_slips
,Instructors
,Part_time_instructors
,Full_time_instructors
,Course_area
,Specialises
,Courses
,Offerings
,Rooms
,Course_Sessions
,Customers
,Credit_cards
,Registers
,Course_packages
,Buys
,Redeems
,Cancels CASCADE;

CREATE TABLE Employees (
    eid INTEGER PRIMARY KEY,
    emp_name TEXT,
    emp_address TEXT,
    phone INTEGER,
    email TEXT,
    join_date DATE,
    depart_date DATE
    check (depart_date  - join_date >= 0)
);

-- eid -> the rest

CREATE TABLE Part_time_Emp (
    eid INTEGER PRIMARY KEY,
    hourly_rate DECIMAL,
    CONSTRAINT pt_emp_fkey FOREIGN KEY(eid) REFERENCES Employees(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);

-- eid -> the rest

CREATE TABLE Full_time_Emp (
    eid INTEGER PRIMARY KEY,
    month_salary DECIMAL,
    CONSTRAINT ft_emp_fkey FOREIGN KEY(eid) REFERENCES Employees(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);

-- eid -> the rest


CREATE TABLE Managers (
    eid INTEGER PRIMARY KEY,
    CONSTRAINT managers_ft_fkey FOREIGN KEY(eid) REFERENCES Full_time_Emp(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);

-- skip

CREATE TABLE Administrators (
    eid INTEGER PRIMARY KEY,
    CONSTRAINT administrators_ft_fkey FOREIGN KEY(eid) REFERENCES Full_time_Emp(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);

-- skip 

CREATE TABLE Pay_slips (
    payment_date DATE,
    eid INTEGER,
    amount DECIMAL,
    num_work_hours INTEGER,
    -- last work day - first work day + 1
    num_work_days INTEGER,
    FOREIGN KEY(eid) REFERENCES Employees(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    PRIMARY KEY(payment_date,eid)
);

``` 
FD1: eid + payment_date -> amount + work hours + work days
FD2: eid + work day + work hours -> amount
-- eid determines salary of each employees(monthly/hourly rates)




key : payment_date,eid 

{eid,pd} = {everything}
{payment_date,amount} = {payment_date,amount}
{eid,work days,work hours} = {eid,work days,work hours,amount}

check prime : amount
R1(eid,workdays,work hours,amount)
R1 confirm BCNF
R2(eid,workdays,work hours,payment date)
R2 confirm BCNF 

In R1,
eid + work day + work hours -> amount

In R2,
eid,payment_date ->work hours + work days
By Axiom of augmentation,
eid,payment_date ->eid + works hours + work days
By Axiom of transitivity,
eid,payment_date -> amount

Therefore, functional dependencies are preserved.
R1 and R2 are in BCNF.




```


CREATE TABLE Instructors (
    eid INTEGER PRIMARY KEY,
    CONSTRAINT instructors_emp_fkey FOREIGN KEY(eid) REFERENCES Employees(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);
-- skip

CREATE TABLE Part_time_instructors (
    eid INTEGER PRIMARY KEY,
    CONSTRAINT pti_instructors_fkey FOREIGN KEY(eid) REFERENCES Instructors(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred,
    CONSTRAINT pti_pt_fkey FOREIGN KEY(eid) REFERENCES Part_time_Emp(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);
-- skip

CREATE TABLE Full_time_instructors (
    eid INTEGER PRIMARY KEY,
    CONSTRAINT fti_instructors_fkey FOREIGN KEY(eid) REFERENCES Instructors(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred,
    CONSTRAINT fti_ft_fkey FOREIGN KEY(eid) REFERENCES Full_time_Emp(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);
-- skip

CREATE TABLE Course_area (
    course_area_name TEXT PRIMARY KEY,
    -- eid is for Manager managing Course_area
    eid INTEGER NOT NULL,
    FOREIGN KEY(eid) REFERENCES Managers(eid)
        ON UPDATE CASCADE
    -- decision to not put on delete cascade in order to prevent a deletion of a manager deleting course area (Q2)
    -- for sql external statements
    -- (remove employee enforces for normal deletions)
);
-- skip

CREATE TABLE Specialises (
    -- eid is for instructors specialising in course_area
    eid INTEGER,
    course_area_name TEXT,
    PRIMARY KEY(eid,course_area_name),
    CONSTRAINT specialises_instructors_fkey FOREIGN KEY(eid) REFERENCES Instructors
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred,
    FOREIGN KEY(course_area_name) REFERENCES Course_area
        ON DELETE CASCADE
    -- decision not to put on update cascade because if an instructor specialises in the previous course area, 
    -- it doesn't necessarily mean that he would specialise in the updated course area as well
);
-- skip 

CREATE TABLE Courses (
    course_id INTEGER PRIMARY KEY,
    course_area_name TEXT NOT NULL,
    title TEXT UNIQUE,
    course_description text,
    -- in terms of hours
    duration INTEGER
        check (duration <= 4),
    FOREIGN KEY(course_area_name) REFERENCES Course_area(course_area_name)
        ON DELETE CASCADE
    -- decision to put on delete cascade because it was not specified that a course area cannot be deleted 
    -- when there is a course with that area
    -- decision not to put on update cascade because doesnt mean the course is in cs means it is in english
);
```
course_id -> everything
title -> everything
```

CREATE TABLE Offerings (
    launch_date DATE
        CHECK (launch_date < registration_deadline),
    course_id INTEGER REFERENCES Courses(course_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    -- eid of administrator
    eid INTEGER NOT NULL,
    actual_start_date DATE,
    end_date DATE,
    registration_deadline DATE
        CHECK (actual_start_date - registration_deadline >= 10),
    target_number_registrations INTEGER
        CHECK (target_number_registrations >= 0),
    seating_capacity INTEGER
        CHECK (seating_capacity >= 0),
    fees DECIMAL
        CHECK (fees >= 0),
    PRIMARY KEY(launch_date,course_id),
    FOREIGN KEY(eid) REFERENCES Administrators(eid)
        ON UPDATE CASCADE
    -- decision to not put on delete cascade because cannot an administrator cannot be deleted if he was in charge a course offering
);
```
launch_date + course_id -> everything
```

CREATE TABLE Rooms (
    rid INTEGER PRIMARY KEY,
    -- in terms of floor and room numbers
    room_location TEXT,
    seating_capacity INTEGER
);
```
room_location -> seating_capacity
rid -> everything
```


CREATE TABLE Course_Sessions (
    course_session_id INTEGER,
    rid INTEGER NOT NULL,
    -- eid is instructor id
    eid INTEGER NOT NULL,
    session_date DATE
    -- check session_date falls between monday and friday
        check (extract(isodow from session_date) in (1,2,3,4,5)),
    start_time TIME
    -- start_time after 9am
        check (extract(hour from start_time) - 9 >= 0
        and
        -- no sessions between 12pm and 2pm
        (
         12 - extract(hour from start_time) >= 0
        or
         extract(hour from start_time) - 14 >= 0
        )),
    end_time TIME
    -- end_time after 6pm
        check (18 - extract(hour from end_time) >= 0
            and
               end_time > start_time
            and
            -- no sessions between 12pm and 2pm
               (
                       12 - extract(hour from end_time) >= 0
                       or
                       extract(hour from end_time) - 14 >= 0
                   )
            ),
    launch_date DATE,
    course_id INTEGER,
    FOREIGN KEY(rid) REFERENCES Rooms(rid)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY(eid) REFERENCES Instructors(eid)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT sessions_offerings_fkey FOREIGN KEY(launch_date,course_id) REFERENCES Offerings(launch_date,course_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred,
    PRIMARY KEY(launch_date,course_id,course_session_id)
);

```
FD1:course_id + launch_date + course_session_id -> everything

FD2:course_id + start_time -> end_time
FD3:course_id + end_time -> start_time
Course_id determines duration of a course_session.

FD4:course_id,launch_date,start_time,session_date -> course_session_id


{course_id,start_time}+ -> {course_id,start_time,end_time}
{course_id,end_time,launch_date}+ -> {course_id,end_time,launch_date,start_time}
Prime attributes: course_id,start_time,end_time,launch_date,session_date,course_session_id

By transitivity,the following with FD3 with FD4 and FD1,
{course_id,end_time,launch_date,session_date}+ -> everything
Same applies for 
{course_id,start_time,launch_date,session_date}+ -> everything
Therefore, table is in 3NF
```

CREATE TABLE Customers (
    cust_id INTEGER PRIMARY KEY,
    cust_address TEXT,
    phone INTEGER,
    cust_name TEXT,
    -- we are assuming the input email are valid
    email TEXT
);

-- Each customer can have more than 1 credit card, but only one active credit card which 
-- is determined by the most recent from_date
CREATE TABLE Credit_cards (
    credit_card_num TEXT PRIMARY KEY,
    cvv INTEGER,
    card_expiry_date DATE,
    from_date DATE,
    cust_id INTEGER NOT NULL,
    UNIQUE(cust_id, credit_card_num),
    UNIQUE(cust_id, from_date),
    -- because we determine the status of the credit card based on most recent from_date
    CONSTRAINT creditcards_customers_fkey FOREIGN KEY(cust_id) REFERENCES Customers(cust_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        deferrable initially deferred
);
```
credit_card_num -> everything
cust_id,from_date -> everything
In 3NF
```


CREATE TABLE Registers (
    -- Trigger 1: customers must register before registration_deadline Offerings            
    registration_date DATE,
    -- Primary Key of Course_Sessions
    course_session_id INTEGER NOT NULL,
    launch_date DATE,
    course_id INTEGER,

    cust_id INTEGER,
    -- Primary Key of Credit_cards
    credit_card_num TEXT,
    FOREIGN KEY(cust_id, credit_card_num) REFERENCES Credit_cards(cust_id, credit_card_num)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent a customer from being deleted when he has a transaction history
    FOREIGN KEY(course_session_id,launch_date,course_id) REFERENCES Course_Sessions(course_session_id,launch_date,course_id)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent a session from being deleted when at least 1 person has registered for it
    PRIMARY KEY(cust_id,launch_date,course_id)
    -- No course_session_id due to at most one constraint,
    -- if course_session_id is in primary key, customer can register for more
    -- than 1 session for the same offering which is uniquely identified by launchdate and course_id.
);
```
FD1:cust_id,launch_date,course_id -> everything
FD2:credit_card_num -> cust_id
cust_id is a prime attribute as (cust_id,launch_date,course_id) is the key.

FD3:course_id,launch_date,credit_card_num-> course_session_id
By Axiom of transitivity and augmentation(FD3 followed by FD2 results in FD1),
FD3 fulfils 3NF.

Table is in 3NF.

```

CREATE TABLE Course_packages (
    package_id INTEGER PRIMARY KEY,
    sale_start_date DATE,
    sale_end_date DATE
        check (sale_end_date >= sale_start_date),
    course_package_name TEXT,
    price DECIMAL
        check (price >= 0),
    num_free_registrations INTEGER
        check (num_free_registrations >= 0)
);
```
package_id -> everything
```

CREATE TABLE Buys (
    buy_date DATE,
    package_id INTEGER,
    credit_card_num TEXT,
    num_remaining_redemptions INTEGER
        check (num_remaining_redemptions >= 0),
    FOREIGN KEY(credit_card_num) REFERENCES Credit_cards(credit_card_num)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent a credit_card_num from being deleted when it has a transaction history
    FOREIGN KEY(package_id) REFERENCES Course_packages(package_id)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent packages from being deleted when at least 1 person has bought it
    PRIMARY KEY(buy_date,credit_card_num,package_id)
);
```
buy_date,credit_card_num,package_id -> everything
```

CREATE TABLE Redeems (
    redeem_date DATE,
    -- Primary Key of Buys
    buy_date DATE,
    credit_card_num TEXT,
    package_id INTEGER,
    -- Primary Key of Course_Sessions
    course_session_id INTEGER,
    launch_date DATE,
    course_id INTEGER,
    UNIQUE(credit_card_num, launch_date, course_id),
    FOREIGN KEY(course_session_id,launch_date,course_id) REFERENCES Course_Sessions(course_session_id,launch_date,course_id)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent a session from being deleted when at least 1 person has redeemed it
    FOREIGN KEY(buy_date,credit_card_num,package_id) REFERENCES Buys(buy_date,credit_card_num,package_id)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent packages from being deleted when at least 1 person has redeemed from it
    PRIMARY KEY(redeem_date,course_session_id,launch_date,course_id,buy_date,credit_card_num,package_id)
);
```
credit_card_num + launch_date + course_id -> everything

FD satisfies 3NF
```

CREATE TABLE Cancels (
    -- to check that it is refundable
    cancel_date DATE,
    refund_amt DECIMAL,
    package_credit INTEGER,
    -- to trace back to course_package
    package_id INTEGER REFERENCES Course_packages(package_id)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent a package from being deleted because it has txn history

    -- Primary Key of Course_Sessions
    course_session_id INTEGER,
    launch_date DATE,
    course_id INTEGER,

    cust_id INTEGER,
    FOREIGN KEY(course_session_id,launch_date,course_id) REFERENCES Course_Sessions(course_session_id,launch_date,course_id)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent a session from being deleted when at least 1 person has cancelled it (txn history)
    FOREIGN KEY(cust_id) REFERENCES Customers(cust_id)
        ON UPDATE CASCADE,
    -- decision not to put on delete cascade to prevent a customer from being deleted when he has a transaction history
    PRIMARY KEY(cancel_date,course_session_id,launch_date,course_id,cust_id)
);
```
FD1:cancel_date,course_session_id,launch_date,course_id,cust_id -> everything 
FD2:launch_date,course_id,course_session_id,cancel_date -> refund_amount,package_credit
BCNF must be done because FD2 does not satisfy 3NF.

R1(launch_date,course_id,course_session_id,cancel_date,refund_amount,package_credit)
R2(launch_date,course_id,course_session_id,cancel_date,cust_id,package_id)
R2 is in BCNF due to FD1.

For R1,
R1 is in BCNF due to augmentation of FD2.

For R1,
The functional dependencies that holds on R1 is FD2.
For R2,
The function dependencies that holds on R2 is 
cancel_date,course_session_id,launch_date,course_id,cust_id -> cust_id,package_id

So the FDs that are that needs to be derived to form the original set are:
cancel_date,course_session_id,launch_date,course_id,cust_id -> refund_amount,package_credit

In R2,
cancel_date,course_session_id,launch_date,course_id,cust_id -> launch_date,course_id,course_session_id,cancel_date
(trivial)
By transitivity,
cancel_date,course_session_id,launch_date,course_id,cust_id -> refund_amount,package_credit

So R1 and R2 preserves functional dependencies.
```