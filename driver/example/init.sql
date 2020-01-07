DROP DATABASE IF EXISTS postgres_dart_test;
DROP USER IF EXISTS postgres_dart_test;
CREATE DATABASE postgres_dart_test WITH ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';
CREATE USER postgres_dart_test WITH PASSWORD 'postgres_dart_test';
GRANT ALL ON DATABASE postgres_dart_test TO postgres_dart_test;
ALTER DATABASE postgres_dart_test OWNER TO postgres_dart_test;
