<?php 
  require_once 'civicrm/api/class.api.php';
  $api = new civicrm_api3(array( 'conf_path' => '/data/sites/www.cclr.org/sites/default' ));

$params = array(
  'version' => 3,
  'sequential' => 1,
	'group' => array(47 => 1),
	'options' => array('limit' => 5000),
);
$result = civicrm_api('Contact', 'get', $params);

  print_r($result);
?>