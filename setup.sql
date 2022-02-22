DROP TYPE IF EXISTS personnel_type CASCADE;
CREATE TYPE personnel_type AS ENUM ('OWNER', 'STAFF', 'VET');

DROP TABLE IF EXISTS booking CASCADE;
DROP TABLE IF EXISTS dog CASCADE;
DROP TABLE IF EXISTS treatments CASCADE;
DROP TABLE IF EXISTS treatment CASCADE;
DROP TABLE IF EXISTS kennel CASCADE;
DROP TABLE IF EXISTS phone CASCADE;
DROP TABLE IF EXISTS treatment_type CASCADE;
DROP TABLE IF EXISTS owner CASCADE;
DROP TABLE IF EXISTS shift CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS staff_roles CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS food_requirement CASCADE;
DROP TABLE IF EXISTS address CASCADE;
DROP TABLE IF EXISTS dog_owners CASCADE;
DROP TABLE IF EXISTS food_requirements CASCADE;
DROP TABLE IF EXISTS phone_numbers CASCADE;
DROP TABLE IF EXISTS vet CASCADE;

CREATE TABLE address
(
    id SERIAL PRIMARY KEY NOT NULL,
    first_line VARCHAR(100) NOT NULL,
    second_line VARCHAR(100) NULL,
    postcode VARCHAR(32) NOT NULL,
    county VARCHAR(255) NULL,
    country VARCHAR(50) NOT NULL
);

CREATE TABLE vet
(
    id SERIAL PRIMARY KEY NOT NULL,
    name VARCHAR(255) NOT NULL
);


CREATE TABLE food_requirement
(
    id SERIAL PRIMARY KEY NOT NULL,
    food_name VARCHAR(50) NOT NULL,
    mins_since_start INT NOT NULL,
    instructions VARCHAR(255) NOT NULL,
    size INT NOT NULL
);


-- Polymorphic foreign key association, so we need to use triggers
-- to enforce the relationships.
CREATE TABLE addresses
(
    personnel_id INT NOT NULL,
    address_id INT NOT NULL,
    type personnel_type NOT NULL,
    FOREIGN KEY(address_id)
        REFERENCES address(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);


CREATE TABLE staff_roles
(
    id SERIAL PRIMARY KEY NOT NULL,
    role_name VARCHAR(32) NOT NULL UNIQUE
);


CREATE TABLE staff
(
    id SERIAL PRIMARY KEY NOT NULL,
    first_name VARCHAR(128) NOT NULL,
    last_name VARCHAR(128) NOT NULL,
    dob DATE NOT NULL,
    salary INT NOT NULL,
    role_id INT NOT NULL
);

CREATE TABLE shift
(
    id SERIAL PRIMARY KEY NOT NULL,
    staff_id INT NOT NULL,
    start_time TIMESTAMPTZ NOT NULl,
    end_time TIMESTAMPTZ NOT NULl,
    complete BIT NOT NULL
);

CREATE TABLE owner
(
    id SERIAL PRIMARY KEY NOT NULL,
    first_name VARCHAR(128) NOT NULL,
    last_name VARCHAR(128) NOT NULL,
    dob DATE NOT NULL
);

CREATE TABLE treatment_type(
    id SERIAL PRIMARY KEY NOT NULL,
     name VARCHAR(255) NOT NULL UNIQUE
);


-- Because of the polymorphism we have in the phone_numbers table, we need to
-- define a custom trigger to check that table doesn't already have a
-- an owner with a priority.

CREATE TABLE phone
(
    id SERIAL PRIMARY KEY NOT NULL,
    country_code VARCHAR(5) NOT NULL,
    number VARCHAR(15) NOT NULL,
    instructions VARCHAR(320) NULL,
    priority SMALLINT NOT NULl,
    name VARCHAR(64) NOT NULL,
    CONSTRAINT priority_above_0 CHECK(priority >= 0)
);


CREATE TABLE kennel(
    id SERIAL PRIMARY KEY NOT NULL,
    floor_id INT NOT NULL,
    building_id INT NOT NULL,
    room_id INT NOT NULL UNIQUE,
    capacity INT NOT NULL,
    requirements VARCHAR(255)
);


CREATE TABLE dog(
    id SERIAL PRIMARY KEY NOT NULL,
    name VARCHAR(255) NOT NULL,
    dob DATE NOT NULL,
    kennel_id INT NULL,
    breed VARCHAR(32) NOT NULL,
    vet_id INT NULL,
    microchip_id VARCHAR(15) NOT NULL UNIQUE ,
    FOREIGN KEY (vet_id)
        REFERENCES vet(id)
            ON DELETE SET NULL
            ON UPDATE CASCADE,
    FOREIGN KEY(kennel_id)
        REFERENCES kennel(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);


CREATE TABLE treatment(
    id SERIAL PRIMARY KEY NOT NULL,
    date DATE NOT NULL,
    type INT NOT NULL,
    valid_until DATE NOT NULL,
    FOREIGN KEY (type)
        REFERENCES treatment_type(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);


CREATE TABLE treatments(
    treatment_id INT NOT NULL,
    dog_id INT NOT NULL,
        FOREIGN KEY (dog_id)
        REFERENCES dog(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
    FOREIGN KEY (treatment_id)
        REFERENCES treatment(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);

CREATE TABLE booking(
    id SERIAL PRIMARY KEY NOT NULL,
    dog_id INT NOT NULL,
    expiration TIMESTAMPTZ NOT NULL,
    start TIMESTAMPTZ NOT NULL,
    FOREIGN KEY(dog_id)
        REFERENCES dog(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
    CONSTRAINT expiration_gtr_start CHECK (expiration > start)
);

CREATE TABLE dog_owners
(
    dog_id INT NOT NULL,
    owner_id INT NOT NULL,
    FOREIGN KEY(dog_id)
        REFERENCES dog(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
    FOREIGN KEY(owner_id)
        REFERENCES owner(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);


CREATE TABLE food_requirements
(
    dog_id INT NOT NULL,
    food_requirement_id INT NOT NULL UNIQUE,
    FOREIGN KEY(dog_id)
        REFERENCES dog(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
    FOREIGN KEY (food_requirement_id)
        REFERENCES food_requirement(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);


CREATE TABLE phone_numbers
(
    phone_id INT NOT NULL,
    type personnel_type NOT NULL,
    personnel_id INT NOT NULL,
    FOREIGN KEY (phone_id)
        REFERENCES phone(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);

DROP PROCEDURE IF EXISTS add_vet;
CREATE PROCEDURE add_vet(
    IN p_name VARCHAR(32),
    IN p_country_code VARCHAR(5),
    IN p_number VARCHAR(15),
    IN p_instructions VARCHAR(320),
    IN p_priority INT,
    IN p_phone_name VARCHAR(64),
    IN p_postcode VARCHAR(32),
    IN p_county VARCHAR(255),
    IN p_country VARCHAR(50),
    IN p_first_line VARCHAR(100),
    IN p_second_line VARCHAR(100) DEFAULT NULL
)
LANGUAGE plpgsql
AS
$$
DECLARE
    pv_id INT;
    pv_addr_id INT;
    pv_phone_id INT;
BEGIN

    INSERT INTO vet(name) VALUES (p_name) RETURNING id INTO pv_id;

    INSERT INTO address(first_line, second_line, postcode, county, country) VALUES
        (p_first_line, p_second_line, p_postcode, p_county, p_country) RETURNING id INTO pv_addr_id;

    INSERT INTO phone(country_code, number, instructions, priority, name) VALUES
        (p_country_code, p_number, p_instructions, p_priority, p_phone_name) RETURNING id INTO pv_phone_id;

    INSERT INTO addresses(personnel_id, address_id, type) VALUES(pv_id, pv_addr_id, 'VET'::personnel_type);

    INSERT INTO phone_numbers(personnel_id, phone_id, type) VALUES(pv_id, pv_addr_id, 'VET'::personnel_type);

END
$$;

DROP PROCEDURE IF EXISTS add_staff;
CREATE PROCEDURE add_staff(
    IN p_first_name VARCHAR(32),
    IN p_last_name VARCHAR(32),
    IN p_dob DATE,
    IN p_salary INT,
    IN p_role_id INT,

    IN p_country_code VARCHAR(5),
    IN p_number VARCHAR(15),
    IN p_instructions VARCHAR(320),
    IN p_priority INT,
    IN p_phone_name VARCHAR(64),

    IN p_postcode VARCHAR(32),
    IN p_county VARCHAR(255),
    IN p_country VARCHAR(50),
    IN p_first_line VARCHAR(100),
    IN p_second_line VARCHAR(100) DEFAULT NULL
)
LANGUAGE plpgsql
AS
$$
DECLARE
    pv_id INT;
    pv_addr_id INT;
    pv_phone_id INT;
BEGIN

    INSERT INTO staff(first_name, last_name, dob, salary, role_id)
        VALUES (p_first_name, p_last_name, p_dob, p_salary, p_role_id)
            RETURNING id INTO pv_id;

    INSERT INTO address(first_line, second_line, postcode, county, country) VALUES
        (p_first_line, p_second_line, p_postcode, p_county, p_country) RETURNING id INTO pv_addr_id;

    INSERT INTO phone(country_code, number, instructions, priority, name) VALUES
        (p_country_code, p_number, p_instructions, p_priority, p_phone_name) RETURNING id INTO pv_phone_id;

    INSERT INTO addresses(personnel_id, address_id, type) VALUES(pv_id, pv_addr_id, 'STAFF'::personnel_type);

    INSERT INTO phone_numbers(personnel_id, phone_id, type) VALUES(pv_id, pv_phone_id, 'STAFF'::personnel_type);

END
$$;

DROP PROCEDURE IF EXISTS add_owner_address;
CREATE PROCEDURE add_owner_address(
    IN p_owner_id INT,
    IN p_postcode VARCHAR(32),
    IN p_county VARCHAR(255),
    IN p_country VARCHAR(50),
    IN p_first_line VARCHAR(100),
    IN p_second_line VARCHAR(100) DEFAULT NULL
)
LANGUAGE plpgsql
AS
$$
DECLARE
    pv_id INT;
BEGIN

    INSERT INTO address(first_line, second_line, postcode, county, country) VALUES
        (p_first_line, p_second_line, p_postcode, p_county, p_country) RETURNING id INTO pv_id;

    INSERT INTO addresses(personnel_id, address_id, type) values (p_owner_id, pv_id, 'OWNER'::personnel_type);


END
$$;

DROP PROCEDURE IF EXISTS add_owner_dog;
CREATE PROCEDURE add_owner_dog(
    IN p_owner_id INT,
    IN p_name VARCHAR(255),
    IN p_dob DATE,
    IN p_breed VARCHAR(32),
    IN p_microchip_id VARCHAR(15)
)
LANGUAGE plpgsql
AS
$$
DECLARE
    pv_id INT;
BEGIN

    INSERT INTO dog(name, dob, breed, microchip_id) VALUES
        (p_name, p_dob, p_breed, p_microchip_id) RETURNING id INTO pv_id;

    INSERT INTO dog_owners(dog_id, owner_id) VALUES(pv_id, p_owner_id);

END
$$;

DROP PROCEDURE IF EXISTS add_food_requirement;
CREATE PROCEDURE add_food_requirement(
    IN p_dog_id INT,
    IN p_food_name VARCHAR(50),
    IN p_mins_since_start INT,
    IN p_instructions VARCHAR(255),
    IN p_size INT
)
LANGUAGE plpgsql
AS
$$
    DECLARE
        pv_id INT;
    BEGIN

        INSERT INTO food_requirement(food_name, mins_since_start, instructions, size)
            VALUES (p_food_name, p_mins_since_start, p_instructions, p_size)
            RETURNING id
        INTO pv_id;

        INSERT INTO food_requirements(dog_id, food_requirement_id) VALUES (p_dog_id, pv_id);

    END
$$;

DROP PROCEDURE IF EXISTS add_owner_phone_number;
CREATE PROCEDURE add_owner_phone_number(
    IN p_owner_id INT,
    IN p_country_code VARCHAR(5) ,
    IN p_number VARCHAR(15) ,
    IN p_instructions VARCHAR(320) ,
    IN p_priority INT,
    IN p_name VARCHAR(64)
)
LANGUAGE plpgsql
AS
$$
DECLARE
    pv_id INT;
BEGIN

    INSERT INTO phone(country_code, number, instructions, priority, name) VALUES
        (p_country_code, p_number, p_instructions, p_priority, p_name) RETURNING id INTO pv_id;

    INSERT INTO phone_numbers(phone_id, personnel_id, type) VALUES(pv_id, p_owner_id, 'OWNER'::personnel_type);

END
$$;


-- TODO: Handle cascade deletion on polymorphic relationships.
-- Handle the Polymorphic relations
DROP FUNCTION IF EXISTS enforce_poly_fk_addresses CASCADE ;

CREATE FUNCTION enforce_poly_fk_addresses()
    RETURNS TRIGGER
AS
$$

BEGIN

    /* NOTE: I did consider to construct the sql statements dynamically, depending on the type
       however, this could lead to the possibility of SQL injection down the line.
       Which I wasn't willing to introduce, I'm aware there's a method to prepare dynamic sql queries within
       psql securely without sql injection, however I believe that costs readability.
    */
    CASE NEW.type
        WHEN 'OWNER'::personnel_type THEN

            IF( NOT EXISTS(SELECT id FROM owner WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No owner.id found for personnel id.';
            END IF;

        WHEN 'STAFF'::personnel_type THEN
            IF( NOT EXISTS(SELECT id FROM staff WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No staff.id found';
            END IF;

        WHEN 'VET'::personnel_type THEN
            IF( NOT EXISTS(SELECT id FROM vet WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No vet.id found';
            END IF;

            IF( EXISTS(SELECT address_id FROM addresses WHERE personnel_id = NEW.personnel_id AND type = NEW.type)) THEN
                RAISE EXCEPTION  'Vet address already registered';
            END IF;
    END CASE;

    IF (EXISTS(SELECT address_id FROM addresses WHERE personnel_id = NEW.personnel_id AND type = NEW.type AND address_id = NEW.address_id)) THEN
        RAISE EXCEPTION 'Duplicate address for owner.id found.';
    END IF;

    RETURN NEW;

END

$$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS enforce_poly_fk_phone_numbers CASCADE ;

CREATE FUNCTION enforce_poly_fk_phone_numbers()
    RETURNS TRIGGER
AS
$$

BEGIN

    CASE NEW.type
        WHEN 'OWNER'::personnel_type THEN

            IF( NOT EXISTS(SELECT id FROM owner WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No owner.id found for personnel id.';
            END IF;

        WHEN 'STAFF'::personnel_type THEN

            IF( NOT EXISTS(SELECT id FROM staff WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No staff.id found';
            END IF;

        WHEN 'VET'::personnel_type THEN
            IF( NOT EXISTS(SELECT id FROM vet WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No vet.id found';
            END IF;

            IF( EXISTS(SELECT phone_id FROM phone_numbers WHERE personnel_id = NEW.personnel_id AND type = NEW.type)) THEN
                RAISE EXCEPTION  'Vet phone already registered';
            END IF;
    END CASE;

    IF (EXISTS(SELECT phone_id FROM phone_numbers WHERE personnel_id = NEW.personnel_id AND type = NEW.type AND phone_id = NEW.phone_id)) THEN
        RAISE EXCEPTION 'Duplicate phone id for owner.id found.';
    END IF;

    RETURN NEW;

END

$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS enforce_priority_phone_numbers;

CREATE FUNCTION enforce_priority_phone_numbers()
    RETURNS TRIGGER
AS
$$

DECLARE
    pv_phone_priority INT;
    pv_priority_count INT;
BEGIN

    SELECT priority INTO pv_phone_priority FROM phone WHERE id = NEW.phone_id;

    SELECT count(id)
        INTO pv_priority_count
        FROM phone_numbers
        INNER JOIN phone
            ON phone_numbers.phone_id = phone.id
    WHERE phone.priority = priority AND phone_numbers.personnel_id = NEW.personnel_id AND phone_numbers.type = NEW.type;

    IF(pv_priority_count > 0) THEN
        RAISE EXCEPTION 'Duplicate phone number priorities.';
    END IF;

    RETURN NEW;

END

$$
LANGUAGE plpgsql;

CREATE TRIGGER enforce_priority_phone_numbers_trigger
    BEFORE insert
    ON phone_numbers
    FOR EACH ROW EXECUTE PROCEDURE enforce_priority_phone_numbers();


CREATE TRIGGER enforce_poly_fk_phone_numbers_trigger
    BEFORE insert
    ON phone_numbers
    FOR EACH ROW EXECUTE PROCEDURE enforce_poly_fk_phone_numbers();

CREATE TRIGGER enforce_poly_fk_addresses_trigger
    BEFORE insert
    ON addresses
    FOR EACH ROW EXECUTE PROCEDURE enforce_poly_fk_addresses();


BEGIN;

    SET datestyle = dmy;
    INSERT INTO owner(first_name, last_name, dob) VALUES('John', 'Smith', '15/03/1994');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Sandra', 'Smith', '15/03/1968');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Constince', 'Jerma', '10/03/1967');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Kernle', 'Panic', '15/03/1954');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Linus', 'Torvalds', '15/04/2001');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Micheal', 'Forbes', '15/03/1999');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Linux', 'Tundra', '1/03/1979');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Alan', 'Gates', '25/11/1989');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Debra', 'Lynn', '15/03/1953');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Gordon', 'Ramsay', '07/10/1987');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Falcon', 'Heene', '10/01/2003');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Zeal', 'John', '08/05/1978');
    INSERT INTO owner(first_name, last_name, dob) VALUES('John', 'Boris', '15/12/1920');
    INSERT INTO owner(first_name, last_name, dob) VALUES('Homer', 'Smith', '25/02/1953');

    CALL add_owner_address(1, 'N4 7EB', 'South Lanarkshire', 'Costa Rica', '90 Harry summit');
    CALL add_owner_address(2, 'LL4E 6NT', 'Cleveland', 'Gabon', '893 Thomas drives');
    CALL add_owner_address(3, 'N8 9YT', 'Dorset', 'Panama', 'Flat 30 Herbert locks');
    CALL add_owner_address(4, 'S5D 4QE', 'Greater London', 'Korea', '7 Bowen forks');
    CALL add_owner_address(5, 'NR7H 1FY', 'Orkney Islands', 'Tajikistan', 'Studio 62k White plain');
    CALL add_owner_address(6, 'G3E 4GQ', 'Caernarvonshire', 'Burkina Faso', '346 Ali forest');
    CALL add_owner_address(7, 'KA4X 7YX', 'East Dunbartonshire', 'Papua New Guinea', 'Studio 7 Jordan lock');
    CALL add_owner_address(8, 'E6S 6YR', 'Wiltshire', 'Slovakia (Slovak Republic)', '07 Amber lake');
    CALL add_owner_address(9, 'G9 2DJ', 'Flintshire', 'Barbados', '85 Yates fork');
    CALL add_owner_address(10, 'N7 7QJ', 'Tyrone', 'Lesotho', 'Studio 15 Eric viaduct');
    CALL add_owner_address(11, 'G91 6BS', 'North Yorkshire', 'Bouvet Island (Bouvetoya)', '356 Webster meadows');
    CALL add_owner_address(12, 'PO5 5SU', 'Dundee City', 'Spain', 'Studio 02S Hart shores');
    CALL add_owner_address(13, 'L8 6EG', 'Somerset', 'Malawi', '0 Robson trafficway');
    CALL add_owner_address(14, 'S05 9EF', 'Cardiganshire', 'Armenia', 'Flat 3 Cunningham stream');

    CALL add_owner_dog(1, 'Kelly', '12/01/1973', 'English springer spaniel','983897165550561');
    CALL add_owner_dog(2, 'Ashley', '21/06/2004', 'Chow chow','990314292197188');
    CALL add_owner_dog(3, 'Denise', '16/06/1994', 'Pug','982913308187381');
    CALL add_owner_dog(4, 'Abdul', '07/09/2017', 'American Bully','980889586918508');
    CALL add_owner_dog(5, 'Rhys', '28/11/2009', 'American Bully','987521959369711');
    CALL add_owner_dog(6, 'Mary', '27/02/1977', 'American Bully','994390641508164');
    CALL add_owner_dog(7, 'Daniel', '03/12/1985', 'English springer spaniel','996180318735457');
    CALL add_owner_dog(8, 'Raymond', '15/11/1979', 'English springer spaniel','990638265795038');
    CALL add_owner_dog(9, 'Colin', '27/11/2011', 'Neapolitan Mastiff','993599753657799');
    CALL add_owner_dog(10, 'Jay', '02/04/2006', 'Yorkshire Terrier','981083763016809');
    CALL add_owner_dog(11, 'Tom', '22/11/1988', 'Yorkshire Terrier','982440007793428');
    CALL add_owner_dog(12, 'Janice', '01/10/1975', 'Neapolitan Mastiff','984084608404472');
    CALL add_owner_dog(13, 'Leslie', '12/05/2008', 'Pug','991200731122943');
    CALL add_owner_dog(14, 'Frederick', '17/04/2016', 'Neapolitan Mastiff','978316158625649');

    CALL add_owner_phone_number(1, '+423', '328547982', 'Dolorem enim quod repellendus fugiat eius laborum.', 1, 'Andrea');
    CALL add_owner_phone_number(2, '+961', '322844141', 'Quidem labore at dicta nobis cupiditate vel minus rerum repellendus veritatis voluptate.', 1, 'Alice');
    CALL add_owner_phone_number(3, '+370', '267894541', 'Quia perferendis cupiditate quidem veniam quas cupiditate eum possimus porro.', 1, 'Scott');
    CALL add_owner_phone_number(4, '+993', '559033859', 'Placeat minus amet error cum cum sapiente rerum mollitia.', 1, 'Luke');
    CALL add_owner_phone_number(5, '+248', '675602721', 'Quidem sint corrupti sunt numquam quaerat sit quod temporibus tenetur sapiente.', 1, 'Jill');
    CALL add_owner_phone_number(6, '+56', '167967832', 'Adipisci laborum vitae dignissimos temporibus occaecati pariatur mollitia fugiat ex dolorum explicabo.', 1, 'Aimee');
    CALL add_owner_phone_number(7, '+269', '3701786', 'Autem facere veniam consequuntur itaque ad.', 1, 'Ruth');
    CALL add_owner_phone_number(8, '+45', '810098691', 'Culpa nesciunt autem repellendus cum voluptates.', 1, 'Charlie');
    CALL add_owner_phone_number(9, '+968', '25771105', 'Possimus a exercitationem sint cupiditate vel neque aspernatur itaque itaque saepe illum qui.', 1, 'Philip');
    CALL add_owner_phone_number(10, '+1', '324885055', 'Minima corporis animi perferendis voluptas tempora hic.', 1, 'Julie');
    CALL add_owner_phone_number(11, '+502', '441069271', 'Soluta sequi possimus voluptate illo corporis.', 1, 'Graeme');
    CALL add_owner_phone_number(12, '+63', '106763806', 'Eligendi omnis sequi laudantium porro velit nihil.', 1, 'Albert');
    CALL add_owner_phone_number(13, '+356', '573565356', 'Rem recusandae error maiores aperiam a accusamus sequi numquam.', 1, 'Glenn');
    CALL add_owner_phone_number(14, '+502', '129085269', 'Voluptatem excepturi hic temporibus placeat iusto consequuntur quas officiis voluptatibus.', 1, 'Jacob');

    INSERT INTO treatment_type(name) VALUES('influenza vaccine');
    INSERT INTO treatment_type(name) VALUES('flea treatment');
    INSERT INTO treatment_type(name) VALUES('bubonic plague vaccine');
    INSERT INTO treatment_type(name) VALUES('zombie vaccine');
    INSERT INTO treatment_type(name) VALUES('zombies-reimagined-supreme vaccine');
    INSERT INTO treatment_type(name) VALUES('more-zombies vaccine');

    INSERT INTO treatment(date, type, valid_until) VALUES ('13/07/2007', 2, '19/06/2098');
    INSERT INTO treatment(date, type, valid_until) VALUES ('01/12/1993', 3, '25/10/2045');
    INSERT INTO treatment(date, type, valid_until) VALUES ('03/09/2004', 6, '14/01/2112');
    INSERT INTO treatment(date, type, valid_until) VALUES ('18/09/1995', 4, '11/01/2055');
    INSERT INTO treatment(date, type, valid_until) VALUES ('12/11/2018', 2, '20/08/2110');
    INSERT INTO treatment(date, type, valid_until) VALUES ('30/09/1979', 4, '13/11/2082');
    INSERT INTO treatment(date, type, valid_until) VALUES ('29/04/1990', 3, '02/09/2153');
    INSERT INTO treatment(date, type, valid_until) VALUES ('03/08/2011', 4, '22/06/2053');
    INSERT INTO treatment(date, type, valid_until) VALUES ('18/11/1985', 2, '21/03/2039');
    INSERT INTO treatment(date, type, valid_until) VALUES ('02/03/2015', 3, '01/10/2252');
    INSERT INTO treatment(date, type, valid_until) VALUES ('19/02/1971', 5, '30/11/2120');
    INSERT INTO treatment(date, type, valid_until) VALUES ('27/01/2009', 2, '26/01/2173');
    INSERT INTO treatment(date, type, valid_until) VALUES ('16/12/1980', 1, '14/10/2175');
    INSERT INTO treatment(date, type, valid_until) VALUES ('07/10/1985', 6, '20/03/2027');

    INSERT INTO treatments(treatment_id, dog_id) VALUES (1,1);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (2,2);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (3,3);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (4,4);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (5,5);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (6,6);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (7,7);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (8,8);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (9,9);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (10,10);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (11,11);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (12,12);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (13,13);
    INSERT INTO treatments(treatment_id, dog_id) VALUES (14,14);

    CALL add_food_requirement(1, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(2, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(3, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(4, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(5, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(6, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(7, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(8, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(9, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(10, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(12, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(13, 'Colgate', 50, 'Lorem Ipsum', 60);
    CALL add_food_requirement(14, 'Colgate', 50, 'Lorem Ipsum', 60);

    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 1, 1,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 2,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 3,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 2, 4,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 2, 5,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 3, 6,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 2, 7,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 8,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 1, 9,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 10,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 1, 11,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 2, 12,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 2, 13,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 1, 14,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 15,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 16,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 17,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 2, 18,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 19,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 20,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 3, 21,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 22,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 3, 23,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 2, 24,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 2, 25,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 3, 26,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 3, 27,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 2, 28,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 29,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 30,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 31,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 32,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 3, 33,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 2, 34,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 1, 35,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 36,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 37,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 38,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 1, 39,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 2, 40,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 3, 41,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 2, 42,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 3, 43,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 44,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 45,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 46,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 47,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 48,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 49,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 50,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 51,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 52,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 53,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 54,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 3, 55,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 56,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 1, 57,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 58,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 59,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 2, 60,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 3, 61,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 3, 62,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 3, 63,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 64,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 65,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 2, 66,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 67,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 2, 68,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 69,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 2, 70,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 71,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 72,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 73,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 74,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 2, 75,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 76,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 2, 77,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 3, 78,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 1, 79,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 80,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 1, 81,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 2, 82,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (2, 3, 83,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 3, 84,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 3, 85,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 86,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 2, 87,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 2, 88,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 89,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 1, 90,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 1, 91,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 2, 92,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (5, 1, 93,1, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 1, 94,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (4, 3, 95,3, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 96,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 1, 97,2, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (3, 1, 98,4, 'Lorem ipsum');
    INSERT INTO kennel(floor_id, building_id, room_id, capacity, requirements) VALUES (1, 2, 99,2, 'Lorem ipsum');

    CALL add_vet('Patel Group', '967', '188738920', 'Illum ipsa nihil magni incidunt animi dolorum illo consequuntur.', 1, 'business', 'ZE1 9BA', 'Suffolk', 'Honduras', '90 Connor land');
    CALL add_vet('Watson, Smart and Gray', '228', '384672008', 'Reprehenderit quibusdam nihil explicabo dolores dolore autem in cupiditate pariatur beatae minima.', 1, 'business', 'S21 3XJ', 'West Sussex', 'Netherlands', 'Flat 48 Nicola knolls');
    CALL add_vet('Perry PLC', '221', '725459669', 'Velit eius accusamus repellendus aut fuga quibusdam laudantium incidunt ex repudiandae.', 1, 'business', 'G2 3HJ', 'East Lothian', 'Monaco', 'Studio 81 Nixon common');
    CALL add_vet('Johnson-Evans', '883', '579273295', 'Quis deserunt fuga et nesciunt similique nam numquam.', 1, 'business', 'N40 8UD', 'Buckinghamshire', 'Albania', 'Flat 82 Ford row');
    CALL add_vet('Green Ltd', '354', '64337978', 'Cumque quis minus nostrum culpa rem minus aliquam sed deserunt nemo quis beatae.', 1, 'business', 'B3 5LX', 'Orkney Islands', 'Estonia', 'Flat 96Y Barry passage');
    CALL add_vet('Butcher LLC', '590', '695736978', 'Voluptatum commodi cum eligendi blanditiis ex.', 1, 'business', 'GU27 3NX', 'East Lothian', 'Gambia', 'Studio 93o Ryan station');
    CALL add_vet('Evans LLC', '878', '51082119', 'Quia earum nulla minus libero harum.', 1, 'business', 'M88 7TL', 'Surrey', 'United States Minor Outlying Islands', 'Studio 6 Johnston lake');
    CALL add_vet('Davis, Barker and Henderson', '81', '252812661', 'Officia animi occaecati quidem omnis dolorum maiores consequatur mollitia.', 1, 'business', 'G8 7EP', 'Essex', 'Indonesia', '25 Smith route');
    CALL add_vet('Owens-Hill', '1', '370561825', 'Quo corporis possimus cum cum magnam consequuntur.', 1, 'business', 'S6D 1JU', 'Durham', 'Bangladesh', 'Flat 0 Smith field');
    CALL add_vet('Macdonald Group', '356', '29025255', 'Sint impedit adipisci aperiam magni iure eligendi.', 1, 'business', 'DE98 5XJ', 'North Lanarkshire', 'Saudi Arabia', 'Flat 11F Moore inlet');
    CALL add_vet('Smith Group', '373', '906017189', 'Tempore delectus voluptatum reiciendis eveniet deleniti praesentium cumque adipisci nihil incidunt.', 1, 'business', 'M52 1DJ', 'Aberdeenshire', 'Algeria', 'Studio 5 Carey club');
    CALL add_vet('Richardson LLC', '63', '369169511', 'Ullam vero odit quasi blanditiis placeat quam facilis.', 1, 'business', 'MK29 9HB', 'Wiltshire', 'Martinique', '461 Charles field');
    CALL add_vet('Davies-Turner', '599', '625732923', 'Aliquam minima atque officiis cum nostrum occaecati in provident.', 1, 'business', 'G87 3AR', 'Pembrokeshire', 'Iraq', 'Studio 58y Perry junctions');
    CALL add_vet('Cameron-Slater', '961', '362471424', 'Quisquam accusantium atque quasi quos eos quam accusamus.', 1, 'business', 'HX9E 9YD', 'City of Edinburgh', 'Venezuela', 'Studio 82f Dominic crescent');

    INSERT INTO staff_roles(role_name) VALUES ('General Staff');
    INSERT INTO staff_roles(role_name) VALUES ('Manager');

    CALL add_staff('Roger','Knight', '10/03/1988', 22105, 2, '881 7', '94101991', 'Nisi excepturi inventore eos excepturi accusamus quo quam tenetur voluptates labore in excepturi.', 1, 'business', 'HX4P 5BB', 'Derry and Londonderry', 'Chad', '44 Alexandra lane');
    CALL add_staff('Elizabeth','Wall', '17/04/1983', 34463, 2, '1 340', '596970579', 'Aliquam suscipit non minima molestiae dolorem quasi fugiat culpa possimus omnis.', 1, 'business', 'B9J 4JH', 'Armagh', 'Moldova', 'Studio 45r Leonard forge');
    CALL add_staff('Diane','Parker', '19/12/1986', 22661, 1, '290', '802292512', 'Itaque a exercitationem eaque vel assumenda iure tempore.', 1, 'business', 'CV2H 3TL', 'Nottinghamshire', 'Qatar', 'Studio 71 Michelle circle');
    CALL add_staff('Valerie','Lowe', '06/04/1988', 32050, 2, '881 9', '272304699', 'Maxime provident consequatur ut iusto suscipit id nemo dicta optio commodi odio odit.', 1, 'business', 'B22 1JA', 'Surrey', 'Korea', 'Studio 7 Lloyd ranch');
    CALL add_staff('Lynne','Harrison', '14/09/1997', 13388, 1, '1 246', '945365568', 'Facere ducimus sapiente totam ullam quisquam corrupti temporibus ipsa soluta dolore officia a.', 1, 'business', 'HS94 6DT', 'Perth and Kinross', 'Japan', '996 Jeffrey estates');
    CALL add_staff('Nigel','Wood', '09/09/2005', 24586, 1, '43', '821966407', 'Ipsum dicta excepturi sed id officia.', 1, 'business', 'E84 1TG', 'Anglesey', 'Turkmenistan', '416 Patrick common');
    CALL add_staff('Alex','Bell', '08/05/2009', 26677, 1, '53', '519552816', 'Odio animi perspiciatis ipsum doloribus fugit magnam ea totam assumenda dolores nemo error.', 1, 'business', 'L7 8QZ', 'Clackmannanshire', 'Svalbard & Jan Mayen Islands', '933 Mandy squares');
    CALL add_staff('Carole','Smith', '13/06/1974', 24596, 1, '976', '930550989', 'Vero praesentium sequi commodi nesciunt quam perspiciatis culpa aspernatur repudiandae.', 1, 'business', 'S9 2BY', 'Anglesey', 'South Africa', '00 Gerald mission');
    CALL add_staff('Pamela','Kelly', '10/04/2012', 19396, 1, '231', '325930295', 'Assumenda eligendi non optio quidem aliquam praesentium possimus quae ab quis ipsa itaque doloribus.', 1, 'business', 'NP6A 9DH', 'Cumbria', 'Mozambique', 'Studio 16O Leon path');
    CALL add_staff('Lewis','Hamilton', '10/02/2004', 26317, 1, '590', '613993867', 'Est perspiciatis architecto reprehenderit nam modi earum.', 1, 'business', 'RH9 5TG', 'West Yorkshire', 'Gibraltar', '6 Rowley branch');
    CALL add_staff('Laura','Pickering', '12/09/2008', 25112, 1, '55', '702530331', 'Voluptas ullam laboriosam expedita pariatur illum tenetur atque dicta harum aperiam.', 1, 'business', 'BL0P 9JL', 'Orkney Islands', 'Libyan Arab Jamahiriya', '52 Marian ramp');
    CALL add_staff('Kate','Mills', '15/10/1997', 19025, 2, '688', '838781154', 'Maiores porro necessitatibus molestiae quos provident quos praesentium ipsa sint ab.', 1, 'business', 'HS8R 0NJ', 'Midlothian', 'Tonga', 'Flat 0 Bruce mill');
    CALL add_staff('Hazel','Marshall', '08/06/1985', 22025, 2, '870', '773930421', 'Quo eos ullam laboriosam ipsum ducimus ex.', 1, 'business', 'G2 2GA', 'Antrim', 'Israel', 'Studio 61 Carr street');
    CALL add_staff('Glenn','Robinson', '14/02/2018', 32510, 1, '855', '930996820', 'Blanditiis amet ipsam nemo est iure accusantium nemo atque molestias sapiente mollitia molestias architecto.', 1, 'business', 'G3 5XF', 'Greater Manchester', 'Italy', 'Studio 59 Ann dam');

    INSERT INTO shift(staff_id, start_time, end_time, complete) VALUES (1, 'January 8 09:00:00 1999 BST', 'January 8 17:00:00 2022 BST',0::bit );
    INSERT INTO shift(staff_id, start_time, end_time, complete) VALUES (2, 'January 10 09:00:00 1999 BST', 'January 12 10:00:00 2022 BST',0::bit );
    INSERT INTO shift(staff_id, start_time, end_time, complete) VALUES (3, 'January 11 09:00:00 1999 BST', 'January 12 11:00:00 2022 BST',0::bit );
    INSERT INTO shift(staff_id, start_time, end_time, complete) VALUES (4, 'January 12 09:00:00 1999 BST', 'January 12 17:00:00 2022 BST',0::bit );
    INSERT INTO shift(staff_id, start_time, end_time, complete) VALUES (5, 'January 12 09:00:00 1999 BST', 'January 12 17:00:00 2022 BST',0::bit );

    INSERT INTO booking(dog_id, start, expiration) VALUES (1, 'January 12 09:00:00 1999 BST', 'January 28 09:00:00 2022 BST');
    INSERT INTO booking(dog_id, start, expiration) VALUES (2, 'January 12 09:00:00 1999 BST', 'January 31 09:00:00 2022 BST');
    INSERT INTO booking(dog_id, start, expiration) VALUES (3, 'January 12 09:00:00 1999 BST', 'January 28 17:00:00 2022 BST');
    INSERT INTO booking(dog_id, start, expiration) VALUES (4, 'February 12 09:00:00 1999 BST', 'February 28 17:00:00 2022 BST');

COMMIT;
