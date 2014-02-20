#!/bin/bash

#set -x
#trap read debug

source /vagrant/env.sh

export SCRIPTS_PATH="/var/www/html/scripts"
export SERVER_NAME="localhost"
export META_GRAPH_NAME="http://www.openphacts.org/api/datasetDescriptorsTest"


#get the list of datasets to be loaded
URIsToUpdate="SELECT ?description WHERE { GRAPH <$META_GRAPH_NAME> {
{?description <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/QUEUED> .}
UNION
{?description <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_ERROR> .}
} } ";
encodedQuery=$(php -r "echo urlencode(\"${URIsToUpdate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2 >voidDescriptorsList

$SCRIPTS_PATH/loadDatasets.sh
#$SCRIPTS_PATH/loadLinksets.sh



