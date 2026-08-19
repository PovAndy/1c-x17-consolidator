-- Check structure of _Reference185
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = '_Reference185'
ORDER BY ordinal_position
LIMIT 20;
