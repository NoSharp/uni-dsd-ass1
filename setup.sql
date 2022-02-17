DROP DATABASE IF EXISTS assignment2076563;
CREATE DATABASE assignment2076563;
\c assignment2076563;

CREATE TYPE personnel_type AS ENUM ('OWNER', 'STAFF');

CREATE TABLE treatment_type(
    id SERIAL PRIMARY KEY NOT NULL,
     name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE treatment(
    id SERIAL PRIMARY KEY NOT NULL,
    date DATE NOT NULL,
    type INT NOT NULL,
    valid_until DATE NOT NULL,
    dog_id INT NOT NULL,
    FOREIGN KEY (dog_id)
        REFERENCES dog(id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
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
    flea_treatment DATE NOT NULL,
    FOREIGN KEY(kennel_id)
        REFERENCES kennel(id)
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
            ON UPDATE CASCADE
);

CREATE TABLE address
(
    id SERIAL PRIMARY KEY NOT NULL,
    first_line VARCHAR(100) NOT NULL,
    second_line VARCHAR(100) NULL,
    postcode VARCHAR(32) NOT NULL,
    county VARCHAR(255) NULL,
    country VARCHAR(50) NOT NULL
);

-- Polymorphic foreign key association, so we need to use triggers
-- to enforce the relationships.
CREATE TABLE addresses
(
    personnel_id INT NOT NULL,
    address_id INT NOT NULL,
    personnel_type personnel_type NOT NULL
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
    salary INT NOT NULL
);

CREATE TABLE shift
(
    id SERIAL PRIMARY KEY NOT NULL,
    staff_id INT NOT NULL,
    start TIMESTAMPTZ NOT NULl,
    end TIMESTAMPTZ NOT NULl,
    complete BIT NOT NULL
);

CREATE TABLE owner
(
    id SERIAL PRIMARY KEY NOT NULL,
    first_name VARCHAR(128) NOT NULL,
    last_name VARCHAR(128) NOT NULL,
    dob DATE NOT NULL
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

CREATE TABLE food_requirement
(
    id SERIAL PRIMARY KEY NOT NULL,
    food_name VARCHAR(50) NOT NULL,
    mins_since_start INT NOT NULL,
    instructions VARCHAR(255) NOT NULL,
    size INT NOT NULL
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
    CONSTRAINT priority_above_0 CHECK(priority > 0)
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


-- TODO: Handle cascade deletion on polymorphic relationships.
-- Handle the Polymorphic relations
DROP FUNCTION IF EXISTS enforce_poly_fk_addresses;

CREATE FUNCTION enforce_poly_fk_addresses()
    RETURNS TRIGGER
AS
$enforce_poly$

BEGIN

    /* NOTE: I did consider to construct the sql statements dynamically, depending on the type
       however, this lead to the possibility of SQL injection down the line.
       Which I wasn't willing to introduce, I'm aware there's a method to prepare dynamic sql queries within
       psql, however I believe that costs readability.
    */
    CASE NEW.personnel_type
        WHEN 'OWNER'::personnel_type THEN
            IF( EXISTS(SELECT id FROM owner WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No owner.id found for personnel id.';
            END IF;

            IF (EXISTS(SELECT address_id FROM addresses WHERE personnel_id = NEW.personnel_id AND personnel_type = NEW.personnel_type)) THEN
                RAISE EXCEPTION 'Duplicate address for owner.id found.';
            END IF;
        WHEN 'STAFF'::personnel_type THEN
            IF( EXISTS(SELECT id FROM staff WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No staff.id found';
            END IF;

            IF (EXISTS(SELECT address_id FROM addresses WHERE personnel_id = NEW.personnel_id AND personnel_type = NEW.personnel_type)) THEN
                RAISE EXCEPTION 'Duplicate address for owner.id found.';
            END IF;
    END CASE;

    RETURN NEW;

END

$enforce_poly$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS enforce_poly_fk_phone_numbers;

CREATE FUNCTION enforce_poly_fk_phone_numbers()
    RETURNS TRIGGER
AS
$enforce_poly$

BEGIN

    CASE NEW.personnel_type
        WHEN 'OWNER'::personnel_type THEN
            IF( EXISTS(SELECT id FROM owner WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No owner.id found for personnel id.';
            END IF;

            IF (EXISTS(SELECT address_id FROM addresses WHERE personnel_id = NEW.personnel_id AND personnel_type = NEW.personnel_type)) THEN
                RAISE EXCEPTION 'Duplicate address for owner.id found.';
            END IF;
        WHEN 'STAFF'::personnel_type THEN
            IF( EXISTS(SELECT id FROM staff WHERE id = NEW.personnel_id) ) THEN
                RAISE EXCEPTION 'No staff.id found';
            END IF;

            IF (EXISTS(SELECT address_id FROM addresses WHERE personnel_id = NEW.personnel_id AND personnel_type = NEW.personnel_type)) THEN
                RAISE EXCEPTION 'Duplicate address for owner.id found.';
            END IF;
    END CASE;

    RETURN NEW;

END

$enforce_poly$
LANGUAGE plpgsql;
/*
CREATE TRIGGER enforce_poly_fk_phone_numbers_trigger
    BEFORE insert
    ON phone_numbers
    FOR EACH ROW EXECUTE PROCEDURE enforce_poly_fk_phone_numbers();*/

CREATE TRIGGER enforce_poly_fk_addresses_trigger
    BEFORE insert
    ON addresses
    FOR EACH ROW EXECUTE PROCEDURE enforce_poly_fk_addresses();

BEGIN;
SET datestyle = dmy;

/*INSERT INTO owner(first_name, last_name, dob) VALUES('Test', 'Test2', DATE '15-03-2003');
INSERT INTO addresses(personnel_id, address_id, personnel_type) VALUES(1,1,'OWNER');
INSERT INTO addresses(personnel_id, address_id, personnel_type) VALUES(2,1,'OWNER');*/

COMMIT;