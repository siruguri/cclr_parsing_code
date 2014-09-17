cp civi_api_call.php /var/www/vhosts/cclr.org/httpdocs/sites/all/modules/civi_api_call.php
php /var/www/vhosts/cclr.org/httpdocs/sites/all/modules/civi_api_call.php > tmp
grep contact_id tmp | awk '{match($0, /[0-9][0-9]*/); print substr($0, RSTART,RLENGTH);}' > group_ids.txt
rm tmp