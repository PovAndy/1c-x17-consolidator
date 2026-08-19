-- Find all characteristic GUIDs in x17 database
-- Search in _Reference185 table (ПВХ.икВидыХарактеристик)
SELECT 
    _IDRRef,
    _Code,
    _Description
FROM _Reference185
WHERE _Description LIKE '%площадь%'
   OR _Description LIKE '%этаж%'
   OR _Description LIKE '%высота%'
   OR _Description LIKE '%количество%'
   OR _Description LIKE '%отопление%'
LIMIT 50;
