<?php

require_once "ops_ims.class.php";
require_once "virtuosoformatter.class.php";

if ( isset($_POST['query']) && !isset($_GET['query'])) {
	runQuery($_POST['query']);
}
elseif ( !isset($_POST['query']) && isset($_GET['query'])) {
	runQuery($_GET['query']);
}
elseif ( isset($_POST['query']) && isset($_GET['query'])) {
	echo "<h1>Required variable 'query' must provided by HTTP POST or GET, not both.</h1>";
}
else {
	echo "<h1>Required variable 'query' not provided</h1>";
}

function runQuery ( $query ) {
	$VirtuosoEndpoint = "http://ops2.few.vu.nl:8890/sparql/";
	$ims = new OpsIms();
	$formatter = new VirtuosoFormatter();
	$inputURI='';
	if (isset($_POST['inputURI'])) {
		$inputURI = $_POST['inputURI'];
	}
	else if (isset($_GET['inputURI'])) {
		$inputURI = $_GET['inputURI'];
        }
	else if (strstr($query, 'ops:input')!==false) {
		preg_match('/^.*ops:input[ ]*<(.*)>/', $query, $matches);
		$inputURI = $matches[1];
		$query = preg_replace('/\[\][ ]*ops:input.*>[ ]*\./', '', $query);
	}
	$expanded_query = $ims->expandQuery($query, $inputURI);
	$virtuoso_query = $formatter->formatQuery($expanded_query);
	$con = curl_init($VirtuosoEndpoint);
	curl_setopt($con, CURLOPT_POST, 1);
	curl_setopt($con, CURLOPT_POSTFIELDS, array('query' => $virtuoso_query) );
	curl_setopt($con, CURLOPT_RETURNTRANSFER, true);
	echo curl_exec($con);
	curl_close($con);
}

?>
