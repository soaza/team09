-- 3. add_customer: 
create procedure add_customer(custname text, homeaddress text, contactnumber integer, custemail text, creditcardnum integer, cardexpirydate date, cardcvv integer)
    language plpgsql
as
$$
DECLARE
    custId INT;
BEGIN
    custId := 11;
    INSERT INTO Customers VALUES (custId, homeAddress, contactNumber, custName, custEmail);
    INSERT INTO Credit_cards VALUES (creditCardNum, cardCVV, cardExpiryDate, NULL, custId);
END;
$$;







-- 4. update_credit_card: 
CREATE OR REPLACE PROCEDURE update_credit_card
    (custId INT, creditCardNum INTEGER, cardExpiryDate DATE, cardCVV INTEGER)
    AS $$
BEGIN
    UPDATE Credit_cards
    SET credit_card_num = creditCardNum,
        cvv = cardCVV,
        card_expiry_date = cardExpiryDate
    WHERE  cust_id = custId;
END;
$$ LANGUAGE plpgsql;

