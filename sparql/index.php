<?php
#$ENDPOINT = "http://localhost:8890/sparql/";
$ENDPOINT = "http://cspc016.cs.man.ac.uk:8080/openrdf-sesame/repositories/OPS";
$IS_VIRTUOSO = false;
$DEBUG = false;
#$QUERY_EXPANDER_URI = "http://openphacts.cs.man.ac.uk:9090/QueryExpander/";
$QUERY_EXPANDER_URI = "http://cspc017.cs.man.ac.uk:8080/QueryExpander/";

require_once "ops_ims.class.php";
require_once "virtuosoformatter.class.php";

if ( $DEBUG ) {
	echo "<h2>Configuration</h2><ul>";
        echo "<li>Endpoint URI: $ENDPOINT</li>";
        echo "<li>Is virtuoso: $IS_VIRTUOSO</li>";
	echo "<li>Query Expander URI: $QUERY_EXPANDER_URI</li>";
        echo "</ul>";
}
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
	global $ENDPOINT, $IS_VIRTUOSO, $DEBUG;
	if ( $DEBUG ) {
		echo "<h2>Processing query</h2><textarea readonly style=\"width:100%;\" rows=\"7\">$query</textarea>";
	}
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
	$ims = new OpsIms();
	$expanded_query = $ims->expandQuery($query, $inputURI);
	if ( $DEBUG ) {
		echo "<h2>Expanded Query</h2><textarea readonly style=\"width:100%;\" rows=\"20\">$expanded_query</textarea>";
	}
	if ( $IS_VIRTUOSO ) {
		$formatter = new VirtuosoFormatter();
		$final_query = $formatter->formatQuery($expanded_query);
	} else {
		$final_query = $expanded_query;
	}
	if ( $DEBUG ) {
		echo "<h2>Final Query</h2><textarea readonly style=\"width:100%;\" rows=\"20\">$final_query</textarea>";
	}
	$con = curl_init($ENDPOINT);
	curl_setopt($con, CURLOPT_POST, 1);
	//Need to explicitly state the accept type for Sesame
	curl_setopt($con, CURLOPT_HTTPHEADER, array("Accept: application/sparql-results+xml"));
	curl_setopt($con, CURLOPT_POSTFIELDS, 'query='.$final_query );
	curl_setopt($con, CURLOPT_RETURNTRANSFER, true);
	if ( $DEBUG ) {
		echo "<h2>Results</h2>";
	}
	echo curl_exec($con);
	curl_close($con);
}

?>
