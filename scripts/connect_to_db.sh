echo 'starting connect to db'
mysql -u cclr_logo74 --password=cclr_pass < scripts/queries.sql > scripts/tables.txt # cclr_pass
