
CREATE DATABASE assignment0;

CREATE TABLE assignment0.vaccination_type(
    id SERIAL PRIMARY KEY NOT NULL,
     name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE assignment0.vaccination(
    id SERIAL PRIMARY KEY NOT NULL,
    date DATE NOT NULL,
    type INT NOT NULL,
    valid_until DATE NOT NULL,
    FOREIGN KEY (type)
        REFERENCES assignment0.vaccination_type(id));

CREATE TABLE assignment0.kennel(
    id SERIAL PRIMARY KEY NOT NULL,
    floor_id INT NOT NULL,
    building_id INT NOT NULL,
    room_id INT NOT NULL UNIQUE,
    capacity INT NOT NULL,
    requirements VARCHAR(255)
);

CREATE TABLE assignment0.dog(
    id SERIAL PRIMARY KEY NOT NULL,
    name VARCHAR(255) NOT NULL,
    dob DATE NOT NULL,
    kennel_id INT NULL,
    flea_treatment DATE NOT NULL,
    FOREIGN KEY(kennel_id)
        REFERENCES assignment0.kennel(id)
);

