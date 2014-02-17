#!/bin/bash

SERVER_NAME="localhost"
metaGraphName="http://www.openphacts.org/api/datasetDescriptorsTest"

DatasetsLoadingQuery="SELECT COUNT(?description) WHERE { GRAPH <$metaGraphName>
{ ?description <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING> . }
}"
encodedQuery=$(php -r "echo urlencode(\"${DatasetsLoadingQuery}\");")
DatasetsLoadingCount=$(curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tail -1)
echo "$DatasetsLoadingCount"

