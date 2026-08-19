#!/usr/bin/env python3
"""
Find GUIDs for reference characteristics from 1C database x17 (MergedBase).

Usage:
    python3 find_char_guids.py

Output: GUID, Code, and Description for each characteristic.
"""

import psycopg2

def main():
    conn = psycopg2.connect(
        host="192.168.195.46",
        port=5432,
        user="codex_sql_ro",
        password="963741",
        dbname="MergedBase"
    )

    cur = conn.cursor()

    # First, find the correct table for ПВХ.икВидыХарактеристик
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name LIKE '_Reference%'
        ORDER BY table_name
    """)
    ref_tables = cur.fetchall()
    print("=== Reference tables ===")
    for t in ref_tables:
        print(f"  {t[0]}")

    # Search for our characteristics in all reference tables
    characteristics = [
        "Высота помещения",
        "Есть индивидуальный источник отопления (автономное отопление)",
        "Жилая площадь",
        "Количество зарегистрированных граждан",
        "Количество проживающих граждан",
        "Общая площадь",
        "Поливная площадь з/у (норматив Волг. обл.)",
        "Этаж"
    ]

    print("\n=== Searching for characteristics ===")
    for name in characteristics:
        # Try to find in any reference table
        for table in ref_tables:
            table_name = table[0]
            try:
                cur.execute(f"""
                    SELECT _IDRRef, _Code, _Description 
                    FROM {table_name} 
                    WHERE _Description = %s 
                    LIMIT 1
                """, (name,))
                row = cur.fetchone()
                if row:
                    guid_bytes = row[0]
                    if isinstance(guid_bytes, bytes):
                        guid_hex = guid_bytes.hex()
                        guid_str = f"{guid_hex[:8]}-{guid_hex[8:12]}-{guid_hex[12:16]}-{guid_hex[16:20]}-{guid_hex[20:32]}"
                    else:
                        guid_str = str(guid_bytes)
                    print(f"  {name}")
                    print(f"    Table: {table_name}")
                    print(f"    GUID: {guid_str}")
                    print(f"    Code: {row[1]}")
                    break
            except Exception:
                pass
        else:
            print(f"  {name}: NOT FOUND in any reference table")

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
