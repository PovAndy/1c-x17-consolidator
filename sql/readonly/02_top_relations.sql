select n.nspname as schema_name,
       c.relname as relation_name,
       c.relkind,
       pg_total_relation_size(c.oid) as total_bytes
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r','v','m')
order by pg_total_relation_size(c.oid) desc nulls last
limit 50;
