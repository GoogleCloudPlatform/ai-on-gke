-- First, disable foreign key checks to avoid issues with constraints during data deletion
SET FOREIGN_KEY_CHECKS = 0;

-- Truncate the tables in the right order to remove all data
TRUNCATE TABLE recall_history;
TRUNCATE TABLE userwords;
TRUNCATE TABLE words;
TRUNCATE TABLE wordsets;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- Load data into wordsets
LOAD DATA LOCAL INFILE '/mnt/csv/wordsets.csv'
INTO TABLE wordsets
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Load data into words
LOAD DATA LOCAL INFILE '/mnt/csv/words.csv'
INTO TABLE words
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
