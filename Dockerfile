FROM alpine:latest

RUN apk --update add mariadb mariadb-client zabbix-setup \
    && rm -rf /var/cache/apk/*

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]
