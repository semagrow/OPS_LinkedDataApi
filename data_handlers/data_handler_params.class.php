<?php


class DataHandlerParams {
    
    public $Request = false;
    public $Response = false;
    public $ConfigGraph = false;
    public $DataGraph = false;
    public $SparqlWriter = false;
    public $SparqlEndpoint = false;
    public $viewerUri = false;
    public $endpointUrl = false;
    
    function __construct($Request, $ConfigGraph, $DataGraph, $viewerUri, $SparqlWriter, $SparqlEndpoint, $endpointUrl, $Response){
        $this->Request = $Request;
        $this->Response = $Response;
        $this->ConfigGraph = $ConfigGraph;
        $this->DataGraph = $DataGraph;
        $this->viewerUri = $viewerUri;
        $this->SparqlWriter = $SparqlWriter;
        $this->SparqlEndpoint = $SparqlEndpoint;
        $this->endpointUrl = $endpointUrl;
    }
    
}