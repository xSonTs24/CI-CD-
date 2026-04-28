CREATE DATABASE IF NOT EXISTS productos;
USE productos;

CREATE TABLE IF NOT EXISTS productos (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255),
    unidades INT,
    precio FLOAT
);

INSERT INTO productos (nombre, unidades, precio) VALUES
("Laptop", 10, 2500),
("Mouse", 50, 25);