``` 
Trigger 6: Instructor who is assigned to teach a course session must be specialized in that course area
```
CREATE OR REPLACE FUNCTION instructor_specialise_session() RETURNS TRIGGER AS $$
BEGIN 
    IF(NEW.eid <> OLD.eid) THEN 
        IF NOT EXISTS (
                  SELECT T.eid
                  FROM Specialises NATURAL JOIN Courses T
                  WHERE  T.eid = NEW.eid
                         and T.course_id = NEW.course_id
                  ) THEN
                    RETURN NULL;
        ELSE 
            RETURN NEW;
        END IF
    END IF
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instructor_specialise_session_trigger
BEFORE INSERT OR UPDATE ON Course_Sessions
FOR EACH ROW EXECUTE FUNCTION instructor_specialise_session();