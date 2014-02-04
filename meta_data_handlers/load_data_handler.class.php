<?php

require_once 'data_handlers/data_handler_adapter.class.php';

class LoadDataHandler extends DataHandlerAdapter{   
    
    protected $Request = false;
    protected $ConfigGraph = false;
    protected $SparqlWriter = false;
    protected $SparqlEndpoint = false;
    protected $endpointUrl = '';
    protected $DataGraph = false;
    private $pageUri = false;
    private $Response;
    
    function __construct($dataHandlerParams){
        $this->Request = $dataHandlerParams->Request;
        $this->ConfigGraph = $dataHandlerParams->ConfigGraph;
        $this->SparqlWriter = $dataHandlerParams->SparqlWriter;
        $this->SparqlEndpoint = $dataHandlerParams->SparqlEndpoint;
        $this->endpointUrl = $dataHandlerParams->endpointUrl;
        $this->DataGraph = $dataHandlerParams->DataGraph;
        $this->Response = $dataHandlerParams->Response;
    }
    
    function processData(){

        //extract VOID url from request
        $paramBindings = $this->ConfigGraph->getParamVariableBindings();
        $voidUrl = $paramBindings['uri']['value'];
        $graphName = $paramBindings['graph']['value'];//this should be retrieved via config graph
        
        //download VOID using curl
        $ch = curl_init($voidUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        $voidData = curl_exec($ch);
        curl_close($ch);
        logDebug("VOID content: ".$voidData);
        
        //add metainformation
        $loadingStatusMetaTriple = '<'.$voidUrl.'> <'.LOADING_STATUS_PREDICATE.'> <'.LOADING_QUEUED.'> .';
        $loadingGraphMetaTriple = '<'.$voidUrl.'> <'.LOADING_GRAPH_PREDICATE.'> <'.$graphName.'> ';
        $voidData .= $loadingStatusMetaTriple."\n".$loadingGraphMetaTriple;
        
        $dataStartPos=stripos($voidData, "\n<");
        $prefixes = substr($voidData, 0, $dataStartPos);
        $prefixes = preg_replace('/@/', '', $prefixes);
        $prefixes = preg_replace('@> +\.@', '> ', $prefixes);
        $remainingData = substr($voidData, $dataStartPos+1);
        
        //call sparqlWriter function to generate the INSERT query in Virtuoso
        $insertQuery = $this->SparqlWriter->getInsertQueryForGraph($remainingData, DATASET_DESCRIPTORS_GRAPH, $prefixes);
              
        $response = $this->SparqlEndpoint->query($insertQuery);
        if(!$response->is_success()){
            logError("Endpoint returned {$response->status_code} {$response->body} Insert Query <<<{$insertQuery}>>> failed against {$this->SparqlEndpoint->uri}");
            throw new ErrorException("Insertion of VOID header in data-store: ".$insertQuery." failed");
        }
        else{
            logDebug("Inserted in graph: ".DATASET_DESCRIPTORS_GRAPH." for the request ".$this->Request->getUri());
        }
        
        //insert in LinkedDataGraph meta triple with status and information 
        $this->pageUri = $this->Request->getUriWithoutPageParam();
        $this->DataGraph->add_resource_triple($this->pageUri, LOADING_STATUS_PREDICATE, LOADING_QUEUED);
        
        $this->Response->cacheable = NOT_CACHEABLE;
    }
    
    function getPageUri(){
        return $this->pageUri;
    }
}

?>