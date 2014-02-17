<?php

require_once 'data_handlers/data_handler_adapter.class.php';

class TriggerLoadDataHandler extends DataHandlerAdapter{
    
    protected $Request = false;
    protected $DataGraph = false;
    private $pageUri = false;
    private $Response;
    
    function __construct($dataHandlerParams){
        $this->Request = $dataHandlerParams->Request;
        $this->DataGraph = $dataHandlerParams->DataGraph;
        $this->Response = $dataHandlerParams->Response;
    } 
    
    function processData(){    
        //shell_exec('nohup /var/www/html/scripts/loadingScript.sh &>/dev/null');
	$cmd = "/var/www/html/scripts/loadingScript.sh &> /dev/null &";
	exec('/bin/bash -c "' . addslashes($cmd) . '"');

        
        $this->pageUri = $this->Request->getUriWithoutPageParam();
        $this->DataGraph->add_literal_triple($this->pageUri, OPS_RESULT_PREDICATE, "Loading triggered successfully. Use /loadingStatus for progress info.");
        
        $this->Response->cacheable = NOT_CACHEABLE;
    }
    
    function getPageUri(){
        return $this->pageUri;
    }
    
}

?>
