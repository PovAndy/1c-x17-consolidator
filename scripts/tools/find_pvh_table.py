#!/usr/bin/env python3
"""
Find the correct table for ПВХ.икВидыХарактеристик in x17 MergedBase.
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

    # Find all tables
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name
    """)
    all_tables = [row[0] for row in cur.fetchall()]
    print(f"Total tables: {len(all_tables)}")

    # Search for "поливная" in all tables that might contain characteristics
    target = "%поливн%"
    for table in all_tables:
        try:
            # Check if table has _Description column
            cur.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = %s 
                AND column_name = '_Description'
            """, (table,))
            if cur.fetchone():
                cur.execute(f"""
                    SELECT _Description FROM {table} 
                    WHERE _Description LIKE %s 
                    LIMIT 3
                """, (target,))
                rows = cur.fetchall()
                if rows:
                    print(f"\nTable: {table}")
                    for row in rows:
                        print(f"  {row[0]}")
        except Exception:
            pass

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
