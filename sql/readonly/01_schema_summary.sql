select table_schema,
       count(*) as table_count
from information_schema.tables
where table_schema not in ('information_schema')
  and table_schema not like 'pg_%'
group by table_schema
order by table_schema;
