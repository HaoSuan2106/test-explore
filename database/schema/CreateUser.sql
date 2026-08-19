CREATE DATABASE exploremy_dev
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_ai_ci;

CREATE USER 'exploremy_app'@'localhost'
IDENTIFIED BY 'exploreMy123';

GRANT ALL PRIVILEGES
ON exploremy_dev.*
TO 'exploremy_app'@'localhost';

FLUSH PRIVILEGES;

USE exploremy_dev;