select table_name
from information_schema.tables
where table_schema = 'public'
  and (
    lower(table_name) like '%document%'
    or lower(table_name) like '%reference%'
    or lower(table_name) like '%accumrg%'
    or lower(table_name) like '%inforg%'
  )
order by table_name
limit 200;
