echo 'starting connect to db'
mysql -u cclr_dba --password=musu30in cclr < scripts/queries.sql > scripts/tables.txt # cclr_pass
