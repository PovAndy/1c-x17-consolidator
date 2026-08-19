select current_user,
       current_database(),
       inet_server_addr()::text as server_addr,
       inet_server_port() as server_port,
       version();
