<?php

require_once 'data_handlers/data_handler.interf.php';

class LoadDataHandler implements DataHandlerInterface{
    
    protected $Request = false;
    protected $ConfigGraph = false;
    protected $SparqlWriter = false;
    protected $SparqlEndpoint = false;
    protected $endpointUrl = '';
    
    function __construct($dataHandlerParams){
        $this->Request = $dataHandlerParams->Request;
        $this->ConfigGraph = $dataHandlerParams->ConfigGraph;
        $this->SparqlWriter = $dataHandlerParams->SparqlWriter;
        $this->SparqlEndpoint = $dataHandlerParams->SparqlEndpoint;
        $this->endpointUrl = $dataHandlerParams->endpointUrl;
    }
    
    function processData(){
            
    }
}

?>