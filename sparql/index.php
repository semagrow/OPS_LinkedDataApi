<?php

require_once "ops_ims.class.php";
//require_once "virtuosoformatter.class.php";

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
//	echo "<h2>Processing query:</h2><textarea readonly style=\"width:100%;\" rows=\"7\">$query</textarea>";
	//$VirtuosoEndpoint = "http://localhost:8890/sparql/";
	$SesameEndpoint = "http://cspc016.cs.man.ac.uk:8080/openrdf-sesame/repositories/OPS";
	$ims = new OpsIms();
	//$formatter = new VirtuosoFormatter();
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
//	echo "<h2>Expanded query:</h2><textarea readonly style=\"width:100%;\" rows=\"7\">$expanded_query</textarea>";
	//$virtuoso_query = $formatter->formatQuery($expanded_query);
	//$con = curl_init($VirtuosoEndpoint);
	$con = curl_init($SesameEndpoint);
	curl_setopt($con, CURLOPT_POST, 1);
	//Need to explicitly state the accept type for Sesame
	curl_setopt($con, CURLOPT_HTTPHEADER, array("Accept: application/sparql-results+xml"));
	//curl_setopt($con, CURLOPT_POSTFIELDS, array('query' => $virtuoso_query) );
	curl_setopt($con, CURLOPT_POSTFIELDS, 'query='.$expanded_query );
	curl_setopt($con, CURLOPT_RETURNTRANSFER, true);
//	echo "<h2>Results</h2>";
	echo curl_exec($con);
	curl_close($con);
}

?>
