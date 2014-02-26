<?php

require_once 'data_handlers/data_handler_adapter.class.php';

define(CHECK_IF_CMD_RUNNING_SCRIPT, '/var/www/html/scripts/checkIfCommandIsRunning.sh');

class TriggerLoadDataHandler extends DataHandlerAdapter{
    
    protected $Request = false;
    protected $ConfigGraph = false;
    protected $DataGraph = false;
    private $pageUri = false;
    private $Response;
    
    function __construct($dataHandlerParams){
        $this->Request = $dataHandlerParams->Request;
        $this->ConfigGraph = $dataHandlerParams->ConfigGraph;
        $this->DataGraph = $dataHandlerParams->DataGraph;
        $this->Response = $dataHandlerParams->Response;
    } 
    
    function processData(){
        $this->pageUri = $this->Request->getUriWithoutPageParam();
        
        $loadingCommand = $this->ConfigGraph->get_first_literal($this->ConfigGraph->getEndpointUri(), API.'loadingCommand');
        
        $check = shell_exec(CHECK_IF_CMD_RUNNING_SCRIPT.' '.$loadingCommand.' 2>/dev/null');
        if ($check == 'true'){
            $this->DataGraph->add_literal_triple($this->pageUri, OPS_RESULT_PREDICATE, "Loading not triggered. Other datasets are already loading. Try again later.");
        }
        else{
            logDebug($loadingCommand." triggered");
            $cmd = $loadingCommand." &> /dev/null &";
            exec('/bin/bash -c "' . addslashes($cmd) . '"');

            $this->DataGraph->add_literal_triple($this->pageUri, OPS_RESULT_PREDICATE, "Loading triggered successfully. Use /getLoadingStatus for progress info.");
        }

        $this->Response->cacheable = NOT_CACHEABLE;
    }
    
    function getPageUri(){
        return $this->pageUri;
    }
    
}

?>
