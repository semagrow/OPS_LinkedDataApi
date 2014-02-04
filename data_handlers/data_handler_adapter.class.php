<?php

require_once 'data_handlers/data_handler.interf.php';

abstract class DataHandlerAdapter implements DataHandlerInterface {
    
    function getItemURIList(){
        return array();
    }
    
    function getViewer(){
        return null;
    }
    
    function getViewQuery(){
        return '';
    }
    
    function getSelectQuery(){
        return '';
    }
    
    function getPageUri(){
        return '';
    }
     
}

?>