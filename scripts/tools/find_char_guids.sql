-- Find GUIDs for reference characteristics in 1C database (x17, MergedBase)
-- Table: _Reference185 (ПВХ.икВидыХарактеристик)
SELECT 
    _Description AS name,
    _Code AS code,
    encode(_IDRRef, 'hex') AS guid_hex
FROM _Reference185
WHERE _Description IN (
    'Высота помещения',
    'Есть индивидуальный источник отопления (автономное отопление)',
    'Жилая площадь',
    'Количество зарегистрированных граждан',
    'Количество проживающих граждан',
    'Общая площадь',
    'Поливная площадь з/у (норматив Волг. обл.)',
    'Этаж'
)
LIMIT 20;
