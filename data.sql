-- No foreign keys
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (1,'Lana','250-9772 Litora St.','94637110','ipsum.dolor.sit@posuerecubiliaCurae.co.uk','2020-08-09 20:45:21','2021-11-24 11:36:06');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (2,'Stone','P.O. Box 695, 3874 Nam Avenue','97716276','Sed.congue@Etiam.ca','2020-09-14 17:26:07','2022-03-10 19:44:24');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (3,'Rana','P.O. Box 305, 9870 Vehicula St.','99558718','vitae.posuere@eunulla.org','2020-07-17 15:32:11','2021-08-13 23:22:25');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (4,'Shay','P.O. Box 236, 4179 Elit. Street','93092594','penatibus.et.magnis@sedorcilobortis.edu','2020-06-26 17:05:55','2021-05-30 07:40:00');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (5,'Rylee','P.O. Box 791, 680 Sapien. Ave','96989079','tempor@luctus.com','2021-02-12 06:29:33','2021-08-15 14:05:17');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (6,'Beck','P.O. Box 266, 708 Mauris Av.','93075463','et.magnis@mattis.com','2020-09-11 12:28:36','2022-01-10 05:01:49');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (7,'Micah','P.O. Box 591, 3820 Netus Ave','95606636','consectetuer.adipiscing.elit@sagittis.edu','2020-04-10 22:28:01','2021-05-07 16:00:22');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (8,'Justine','Ap #445-2105 Aenean Street','90013317','consectetuer.rhoncus.Nullam@massa.net','2020-04-12 08:56:13','2022-01-18 16:01:55');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (9,'Fuller','Ap #583-8652 Quisque Rd.','93665122','nec@Utnecurna.co.uk','2020-10-13 05:58:06','2022-03-11 16:54:47');
INSERT INTO Employees (eid,emp_name,emp_address,phone,email,join_date,depart_date) VALUES (10,'Ifeoma','P.O. Box 526, 1158 Eget, Street','98373247','dictum.sapien@placeratorci.co.uk','2020-07-09 23:17:17','2022-02-14 02:35:02');

INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (1, '01-904', '66');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (2, '07-467', '25');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (3, '08-334', '68');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (4, '08-532', '29');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (5, '05-366', '62');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (6, '04-086', '14');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (7, '00-127', '65');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (8, '03-682', '25');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (9, '04-484', '77');
INSERT INTO Rooms (rid, room_location, seating_capacity) VALUES (10, '05-180', '48');

INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (1, '417 Roxbury Avenue', '95520089', 'Cathrin', 'cvandermark0@spotify.com');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (2, '06 Havey Terrace', '93650609', 'Aveline', 'ahenighan1@uiuc.edu');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (3, '7 Independence Terrace', '96886328', 'Chaunce', 'cdionisio2@theatlantic.com');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (4, '573 Hollow Ridge Point', '96151674', 'Lauren', 'lfairlaw3@feedburner.com');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (5, '08470 Surrey Way', '90928887', 'Genovera', 'gdanilyuk4@whitehouse.gov');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (6, '66 Vidon Alley', '93460379', 'Denny', 'dsenogles5@godaddy.com');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (7, '6 Northview Way', '96622560', 'Payton', 'pdevoy6@rediff.com');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (8, '4 Red Cloud Trail', '99017037', 'Orran', 'ogullane7@dot.gov');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (9, '73 Maryland Court', '90731293', 'Laurie', 'lboulden8@gov.uk');
INSERT INTO Customers (cust_id, cust_address, phone, cust_name, email) values (10, '2 Shelley Hill', '94081690', 'Robers', 'rwarrener9@abc.net.au');

INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (1, '2021-02-16', '2021-02-25', 'Flexidy', 233, 10);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (2, '2021-01-13', '2021-03-03', 'Bitwolf', 569, 3);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (3, '2021-01-02', '2021-12-01', 'Home Ing', 397, 9);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (4, '2021-03-26', '2021-08-18', 'Alphazap', 488, 6);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (5, '2021-01-03', '2021-10-13', 'Span', 599, 9);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (6, '2021-03-21', '2021-05-04', 'Duobam', 863, 9);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (7, '2021-01-10', '2021-12-08', 'Aerified', 132, 2);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (8, '2021-06-16', '2021-12-15', 'Asoka', 731, 1);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (9, '2021-06-10', '2021-08-22', 'Tempsoft', 365, 2);
INSERT INTO Course_packages (package_id, sale_start_date, sale_end_date, course_package_name, price, num_free_registrations) values (10, '2021-05-22', '2021-08-17', 'Veribet', 228, 5);

-- With foreign keys
INSERT INTO Instructors VALUES (1)
INSERT INTO Instructors VALUES (3)
INSERT INTO Instructors VALUES (5)

INSERT INTO Full_Time_Emp VALUES (2)
INSERT INTO Full_Time_Emp VALUES (4)
INSERT INTO Full_Time_Emp VALUES (6)

INSERT INTO Administrators values (2)
INSERT INTO Administrators values (6)

INSERT INTO Managers VALUES (3)
INSERT INTO Course_area VALUES ('Math',3)
INSERT INTO Courses VALUES (1,'Math','Math 101','Math is fun',2)
INSERT INTO Offerings VALUES ('2020-11-11',1,2,'2020-11-12','2020-12-12','2020-12-01',3,100,100.0)
INSERT INTO Course_Sessions VALUES (1,1,1,'2020-11-13','09:00:00','10:00:00','2020-11-11',1)

INSERT INTO Specialises VALUES (5,'Math')