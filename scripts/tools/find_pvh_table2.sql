-- Find the table containing "Поливная площадь" in x17 database
SELECT table_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND column_name = '_Description'
LIMIT 5;
