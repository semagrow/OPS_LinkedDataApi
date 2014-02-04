<?php

require_once 'lda.inc.php';

class Response304
{
	var $response;
	
	public function __construct($response)
	{
		$this->response = $response; 
		$this->cacheable = NOT_CACHEABLE;
	}
	
	public function serve()
	{
		header('HTTP/1.1 304 Not Modified');
		header('Last-Modified:'.$this->response->lastModified, true);
		header('ETag:'.$this->response->eTag, true);
	}
}
