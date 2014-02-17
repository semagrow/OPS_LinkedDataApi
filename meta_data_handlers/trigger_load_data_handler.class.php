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
        $this->pageUri = $this->Request->getUriWithoutPageParam();
        
        $loadingDatasetsCount = shell_exec('/var/www/html/scripts/getLoadingDatasetCount.sh 2>/dev/null');
        if ($loadingDatasetsCount > 0){
            $this->DataGraph->add_literal_triple($this->pageUri, OPS_RESULT_PREDICATE, "Loading not triggered. Other datasets are already loading. Try again later.");
        }
        else{
            $cmd = "/var/www/html/scripts/loadingScript.sh &> /dev/null &";
            exec('/bin/bash -c "' . addslashes($cmd) . '"');

            $this->DataGraph->add_literal_triple($this->pageUri, OPS_RESULT_PREDICATE, "Loading triggered successfully. Use /loadingStatus for progress info.");
        }

        $this->Response->cacheable = NOT_CACHEABLE;
    }
    
    function getPageUri(){
        return $this->pageUri;
    }
    
}

?>
