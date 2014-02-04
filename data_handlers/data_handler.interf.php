<?php


interface DataHandlerInterface {
	
	function processData();
	
	function getItemURIList();
	
	function getViewer();
	
	function getViewQuery();
	
	function getSelectQuery();
	
	function getPageUri();
}

?>