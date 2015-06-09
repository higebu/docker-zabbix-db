#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
  set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
  # read DATADIR from the MySQL config
  DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

  if [ ! -d "$DATADIR/mysql" ]; then
    if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
      echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
      echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
      exit 1
    fi

    echo 'Running mysql_install_db ...'
    mysql_install_db --datadir="$DATADIR"
    echo 'Finished mysql_install_db'

    tempSqlFile='/tmp/mysql-first-time.sql'
    cat > "$tempSqlFile" <<-EOSQL
      DELETE FROM mysql.user ;
      CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
      GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
      DROP DATABASE IF EXISTS test ;
    EOSQL

    echo "CREATE DATABASE IF NOT EXISTS \`zabbix\` character set utf8 collate utf8_bin;" >> "$tempSqlFile"

    if [ -z "$MYSQL_PASSWORD" ]; then
      echo "CREATE USER 'zabbix'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
      echo "GRANT ALL ON \`zabbix\`.* TO 'zabbix'@'%' ;" >> "$tempSqlFile"
    fi

    echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"

    zabbix_db_dir=/usr/share/zabbix/database/mysql
    cat $zabbix_db_dir/schema.sql >> "$tempSqlFile"
    cat $zabbix_db_dir/images.sql >> "$tempSqlFile"
    cat $zabbix_db_dir/data.sql >> "$tempSqlFile"

    set -- "$@" --init-file="$tempSqlFile"
  fi

  chown -R mysql:mysql "$DATADIR"
fi

exec "$@"
