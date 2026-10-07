#!/bin/bash
set -euo pipefail

create_database() {
  local db_name="$1" db_user="$2" db_password="$3"

  psql -v ON_ERROR_STOP=1 \
       -v db_name="$db_name" -v db_user="$db_user" -v db_password="$db_password" \
       --username "$POSTGRES_USER" --dbname postgres <<-'EOSQL'
    CREATE ROLE :"db_user" LOGIN PASSWORD :'db_password';
    CREATE DATABASE :"db_name" OWNER :"db_user";
    REVOKE ALL ON DATABASE :"db_name" FROM PUBLIC;
EOSQL
}

create_database "$CATALOGO_DB_NAME" "$CATALOGO_DB_USER" "$CATALOGO_DB_PASSWORD"
create_database "$TURNOS_DB_NAME"   "$TURNOS_DB_USER"   "$TURNOS_DB_PASSWORD"
