SELECT 'history_log';
ALTER TABLE history_log DROP KEY history_log_2;
ALTER TABLE history_log ADD KEY history_log_2(itemid, id);
ALTER TABLE history_log DROP PRIMARY KEY ;
ALTER TABLE history_log ADD KEY history_logid (id);
SELECT 'history_text';
ALTER TABLE history_text DROP KEY history_text_2;
ALTER TABLE history_text ADD KEY history_text_2 (itemid, clock);
ALTER TABLE history_text DROP PRIMARY KEY ;
ALTER TABLE history_text ADD KEY history_textid (id);

/**************************************************************
  MySQL Auto Partitioning Procedure for Zabbix 1.8
  http://zabbixzone.com/zabbix/partitioning-tables/

  Author:  Ricardo Santos (rsantos at gmail.com)
  Version: 20110518
**************************************************************/
DELIMITER //
DROP PROCEDURE IF EXISTS zabbix.create_zabbix_partitions; //
CREATE PROCEDURE zabbix.create_zabbix_partitions ()
BEGIN
	CALL zabbix.create_next_partitions("zabbix","history");
	CALL zabbix.drop_old_partitions("zabbix","history");
	CALL zabbix.create_next_partitions("zabbix","history_log");
	CALL zabbix.drop_old_partitions("zabbix","history_log");
	CALL zabbix.create_next_partitions("zabbix","history_str");
	CALL zabbix.drop_old_partitions("zabbix","history_str");
	CALL zabbix.create_next_partitions("zabbix","history_text");
	CALL zabbix.drop_old_partitions("zabbix","history_text");
	CALL zabbix.create_next_partitions("zabbix","history_uint");
	CALL zabbix.drop_old_partitions("zabbix","history_uint");

	CALL zabbix.create_next_monthly_partitions("zabbix","trends");
	CALL zabbix.drop_old_monthly_partitions("zabbix","trends");
	CALL zabbix.create_next_monthly_partitions("zabbix","trends_uint");
	CALL zabbix.drop_old_monthly_partitions("zabbix","trends_uint");
END //

DROP PROCEDURE IF EXISTS zabbix.create_next_partitions; //
CREATE PROCEDURE zabbix.create_next_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE NEXTCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @totaldays = 7;
	SET @i = 1;
	createloop: LOOP
		SET NEXTCLOCK = DATE_ADD(NOW(),INTERVAL @i DAY);
		SET PARTITIONNAME = DATE_FORMAT( NEXTCLOCK, 'p%Y%m%d' );
		SET CLOCK = UNIX_TIMESTAMP(DATE_FORMAT(DATE_ADD( NEXTCLOCK ,INTERVAL 1 DAY),'%Y-%m-%d 00:00:00'));
		CALL zabbix.create_partition( SCHEMANAME, TABLENAME, PARTITIONNAME, CLOCK );
		SET @i=@i+1;
		IF @i > @totaldays THEN
			LEAVE createloop;
		END IF;
	END LOOP;
END //


DROP PROCEDURE IF EXISTS zabbix.drop_old_partitions; //
CREATE PROCEDURE zabbix.drop_old_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE OLDCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @mindays = 90;
	SET @maxdays = @mindays+4;
	SET @i = @maxdays;
	droploop: LOOP
		SET OLDCLOCK = DATE_SUB(NOW(),INTERVAL @i DAY);
		SET PARTITIONNAME = DATE_FORMAT( OLDCLOCK, 'p%Y%m%d' );
		CALL zabbix.drop_partition( SCHEMANAME, TABLENAME, PARTITIONNAME );
		SET @i=@i-1;
		IF @i <= @mindays THEN
			LEAVE droploop;
		END IF;
	END LOOP;
END //

DROP PROCEDURE IF EXISTS zabbix.create_next_monthly_partitions; //
CREATE PROCEDURE zabbix.create_next_monthly_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE NEXTCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @totalmonths = 3;
	SET @i = 1;
	createloop: LOOP
		SET NEXTCLOCK = DATE_ADD(NOW(),INTERVAL @i MONTH);
		SET PARTITIONNAME = DATE_FORMAT( NEXTCLOCK, 'p%Y%m' );
		SET CLOCK = UNIX_TIMESTAMP(DATE_FORMAT(DATE_ADD( NEXTCLOCK ,INTERVAL 1 MONTH),'%Y-%m-01 00:00:00'));
		CALL zabbix.create_partition( SCHEMANAME, TABLENAME, PARTITIONNAME, CLOCK );
		SET @i=@i+1;
		IF @i > @totalmonths THEN
			LEAVE createloop;
		END IF;
	END LOOP;
END //

DROP PROCEDURE IF EXISTS zabbix.drop_old_monthly_partitions; //
CREATE PROCEDURE zabbix.drop_old_monthly_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE OLDCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @minmonths = 12;
	SET @maxmonths = @minmonths+24;
	SET @i = @maxmonths;
	droploop: LOOP
		SET OLDCLOCK = DATE_SUB(NOW(),INTERVAL @i MONTH);
		SET PARTITIONNAME = DATE_FORMAT( OLDCLOCK, 'p%Y%m' );
		CALL zabbix.drop_partition( SCHEMANAME, TABLENAME, PARTITIONNAME );
		SET @i=@i-1;
		IF @i <= @minmonths THEN
			LEAVE droploop;
		END IF;
	END LOOP;
END //

DROP PROCEDURE IF EXISTS zabbix.create_partition; //
CREATE PROCEDURE zabbix.create_partition (SCHEMANAME varchar(64), TABLENAME varchar(64), PARTITIONNAME varchar(64), CLOCK int)
BEGIN
	DECLARE RETROWS int;
	SELECT COUNT(1) INTO RETROWS
		FROM information_schema.partitions
		WHERE table_schema = SCHEMANAME AND table_name = TABLENAME AND partition_name = PARTITIONNAME;

	IF RETROWS = 0 THEN
		SELECT CONCAT( "create_partition(", SCHEMANAME, ",", TABLENAME, ",", PARTITIONNAME, ",", CLOCK, ")" ) AS msg;
     		SET @sql = CONCAT( 'ALTER TABLE ', SCHEMANAME, '.', TABLENAME, 
				' ADD PARTITION (PARTITION ', PARTITIONNAME, ' VALUES LESS THAN (', CLOCK, '));' );
		PREPARE STMT FROM @sql;
		EXECUTE STMT;
		DEALLOCATE PREPARE STMT;
	END IF;
END //

DROP PROCEDURE IF EXISTS zabbix.drop_partition; //
CREATE PROCEDURE zabbix.drop_partition (SCHEMANAME varchar(64), TABLENAME varchar(64), PARTITIONNAME varchar(64))
BEGIN
	DECLARE RETROWS int;
	SELECT COUNT(1) INTO RETROWS
		FROM information_schema.partitions
		WHERE table_schema = SCHEMANAME AND table_name = TABLENAME AND partition_name = PARTITIONNAME;

	IF RETROWS = 1 THEN
		SELECT CONCAT( "drop_partition(", SCHEMANAME, ",", TABLENAME, ",", PARTITIONNAME, ")" ) AS msg;
     		SET @sql = CONCAT( 'ALTER TABLE ', SCHEMANAME, '.', TABLENAME,
				' DROP PARTITION ', PARTITIONNAME, ';' );
		PREPARE STMT FROM @sql;
		EXECUTE STMT;
		DEALLOCATE PREPARE STMT;
	END IF;
END //
DELIMITER ;
