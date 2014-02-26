<?php

require_once 'data_handlers/data_handler_adapter.class.php';

class TriggerCommandHandler extends DataHandlerAdapter{
    
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
        
        $loadingCommand = $this->ConfigGraph->get_first_literal($this->ConfigGraph->getEndpointUri(), API.'command');
        $cmd = $loadingCommand." &> /dev/null &";
        exec('/bin/bash -c "' . addslashes($cmd) . '"');

        $userMessage = $this->ConfigGraph->get_first_literal($this->ConfigGraph->getEndpointUri(), API.'userMessage');
        $this->DataGraph->add_literal_triple($this->pageUri, OPS_RESULT_PREDICATE, $userMessage);

        $this->Response->cacheable = NOT_CACHEABLE;
    }
    
    function getPageUri(){
        return $this->pageUri;
    }
    
}

?>
