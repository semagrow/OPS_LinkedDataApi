<?php

require_once 'data_handlers/data_handler_adapter.class.php';

define (DATA_DUMPS_QUERY_TEMPLATE, 'SELECT ?dataDump WHERE { GRAPH <'.DATASET_DESCRIPTORS_GRAPH.'> {

<%%voidDescriptorPlaceHolder%%> foaf:primaryTopic ?dataset .

{ ?dataset a void:Dataset .
?dataset void:dataDump ?dataDump . }
UNION
{ ?dataset void:subset+ ?subset .

{ ?subset a void:Dataset . }
UNION
{ ?subset a <http://www.openphacts.org/api/LDCLinkset> . }
UNION
{ ?subset a void:Linkset . }

?subset void:dataDump ?dataDump . }

OPTIONAL{ ?dataDump <'.LOADING_STATUS_PREDICATE.'> ?status }
FILTER(!bound(?status) OR (?status=<'.LOADING_ERROR.'>) OR (?status=<'.LOADING_QUEUED.'>))
} }');

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
        
        //add metainformation at the VOID descriptor level
        $datasetLoadingStatusMetaTriple = '<'.$voidUrl.'> <'.DATASET_LOADING_STATUS_PREDICATE.'> <'.LOADING_QUEUED.'> .';
        $linksetLoadingStatusMetaTriple = '<'.$voidUrl.'> <'.LINKSET_LOADING_STATUS_PREDICATE.'> <'.LOADING_QUEUED.'> .';
        $loadingGraphMetaTriple = '<'.$voidUrl.'> <'.LOADING_GRAPH_PREDICATE.'> <'.$graphName.'> ';
        $voidData .= $datasetLoadingStatusMetaTriple."\n".$linksetLoadingStatusMetaTriple."\n".$loadingGraphMetaTriple;
        
        $dataStartPos=stripos($voidData, "\n<");
        $prefixes = substr($voidData, 0, $dataStartPos);
        $prefixes = preg_replace('/@/', '', $prefixes);
        $prefixes = preg_replace('@> +\.@', '> ', $prefixes);
        $remainingData = substr($voidData, $dataStartPos+1);
        
        //call sparqlWriter function to generate the INSERT query in Virtuoso
        $insertQuery = $this->SparqlWriter->getInsertQueryForGraph($remainingData, DATASET_DESCRIPTORS_GRAPH, $prefixes);
              
        $response = $this->SparqlEndpoint->insert($insertQuery);
        if(!$response->is_success()){
            logError("Endpoint returned {$response->status_code} {$response->body} Insert Query <<<{$insertQuery}>>> failed against {$this->SparqlEndpoint->uri}");
            throw new ErrorException("Insertion of VOID header in data-store: ".$insertQuery." failed");
        }
        else{
            logDebug("Insert query: ".$insertQuery);
            logDebug("Inserted in graph: ".DATASET_DESCRIPTORS_GRAPH." for the request ".$this->Request->getUri());
        }

        //insert meta information at the data dumps level
        //TODO add force parameter to force re-load
        $dataDumpsQuery =  preg_replace('/%%voidDescriptorPlaceHolder%%/', $voidUrl, DATA_DUMPS_QUERY_TEMPLATE);
        $response = $this->SparqlEndpoint->graph($dataDumpsQuery, 'text/tab-separated-values;q=1');
        if(!$response->is_success()){
            logError("Attempting to retrieve data-dumps; Endpoint returned {$response->status_code} {$response->body} for query {$dataDumpsQuery}");
            throw new ErrorException("Attempting to retrieve data-dumps from data-store: ".$dataDumpsQuery." failed");
        }
        else{
            logDebug("Retrieved data dumps: ".$response->body);
        }
        
        //insert in LinkedDataGraph meta triple with status and information
        $this->pageUri = $this->Request->getUriWithoutPageParam();
        
        $metaTriples = '';
        $dumpList = preg_replace('/"/', '', $response->body);
        $dumpArray = explode("\n", $dumpList);
        for ($i=1; $i<count($dumpArray)-1; $i++){
            $this->DataGraph->add_resource_triple($this->pageUri, OPS_RESULT_PREDICATE, $dumpArray[$i]);
            $this->DataGraph->add_resource_triple($dumpArray[$i], LOADING_STATUS_PREDICATE, LOADING_QUEUED);
            
            $metaTriples .= '<'.$dumpArray[$i].'> <'.LOADING_STATUS_PREDICATE.'> <'.LOADING_QUEUED."> .\n";
        }
        
        $insertQuery = $this->SparqlWriter->getInsertQueryForGraph($metaTriples, DATASET_DESCRIPTORS_GRAPH, '');
        $response = $this->SparqlEndpoint->insert($insertQuery);
        if(!$response->is_success()){
            logError("Endpoint returned {$response->status_code} {$response->body} Insert Query <<<{$insertQuery}>>> failed against {$this->SparqlEndpoint->uri}");
            throw new ErrorException("Insertion of loading status meta triples in data-store: ".$insertQuery." failed");
        }
        else{
            logDebug("Meta triples insert query: ".$insertQuery);
            logDebug("Inserted in graph: ".DATASET_DESCRIPTORS_GRAPH." for the request ".$this->Request->getUri());
        }

        $this->Response->cacheable = NOT_CACHEABLE;
    }
    
    function getPageUri(){
        return $this->pageUri;
    }
}

?>
