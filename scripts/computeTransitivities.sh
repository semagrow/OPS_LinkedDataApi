#!/bin/bash

source /vagrant/env.sh

SERVER_NAME="localhost"
META_GRAPH_NAME="http://www.openphacts.org/api/datasetDescriptorsTest"

#update transitivities status in meta-graph
updateTransitivitiesStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> ?status .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> <http://www.openphacts.org/api/COMPUTING> .
}"
encodedQuery=$(php -r "echo urlencode(\"${updateTransitivitiesStatusTemplate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"


#start computing
echo "Starting to compute transitivities .."
cd /home/www-data
echo "<?xml version=\"1.0\"?><loadSteps>" >load.xml
echo "<doTransitive/>" >>load.xml
echo "</loadSteps>" >>load.xml
$SCRIPTS_PATH/imsLoad.sh "$(pwd)/load.xml"
if [ $? -ne 0 ]; then
	updateTransitivitiesStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> ?status .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> <http://www.openphacts.org/api/OUTDATED> .
}"
	encodedQuery=$(php -r "echo urlencode(\"${updateTransitivitiesStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
	exit 1
fi

#Computation ok, update transitivities status in meta-graph
updateTransitivitiesStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> ?status .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> <http://www.openphacts.org/api/UP-TO-DATE> .
}"
encodedQuery=$(php -r "echo urlencode(\"${updateTransitivitiesStatusTemplate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
