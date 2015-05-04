cp scripts/civi_api_call.php /data/sites/www.cclr.org/sites/all/modules/civi_api_call.php
php /data/sites/www.cclr.org/sites/all/modules/civi_api_call.php > tmp
grep contact_id tmp | awk '{match($0, /[0-9][0-9]*/); print substr($0, RSTART,RLENGTH);}' > scripts/group_ids.txt
rm tmp
