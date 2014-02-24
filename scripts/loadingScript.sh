#!/bin/bash
#$1 - datasets/linksets


#set -x
#trap read debug

source /vagrant/env.sh

export SCRIPTS_PATH="/var/www/html/scripts"
export SERVER_NAME="localhost"
export META_GRAPH_NAME="http://www.openphacts.org/api/datasetDescriptorsTest"


#get the list of datasets to be loaded
if [ "$1" -eq "datasets" ]; then
	LOADING_PREDICATE="http://www.openphacts.org/api#datasetLoadingStatus"
	VOID_LIST_FILE="datasetVoidDescriptorsList"
else
	LOADING_PREDICATE="http://www.openphacts.org/api#linksetLoadingStatus"
	VOID_LIST_FILE="linksetVoidDescriptorsList"
fi

URIsToUpdate="SELECT ?description WHERE { GRAPH <$META_GRAPH_NAME> {
?description foaf:primaryTopic ?dataset .
{?description <$LOADING_PREDICATE> <http://www.openphacts.org/api/QUEUED> .}
UNION
{?description <$LOADING_PREDICATE> <http://www.openphacts.org/api/LOADING_ERROR> .}
} } ";
encodedQuery=$(php -r "echo urlencode(\"${URIsToUpdate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2 >"$VOID_LIST_FILE"

if [ "$1" -eq "datasets" ]; then
	$SCRIPTS_PATH/loadDatasets.sh
else
	$SCRIPTS_PATH/loadLinksets.sh
fi



