#!/bin/bash

source /vagrant/env.sh

SERVER_NAME="localhost"
META_GRAPH_NAME="http://www.openphacts.org/api/datasetDescriptorsTest"

#update transitivities status in meta-graph
updateTransitvitiesStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> ?status .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> <http://www.openphacts.org/api/COMPUTING> .
}"
encodedQuery=$(php -r "echo urlencode(\"${updateDataDumpStatusTemplate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"


#start computing
echo "<?xml version=\"1.0\"?><loadSteps>" >load.xml
echo "<doTransitive/>" >>load.xml
echo "</loadSteps>" >>load.xml
$SCRIPTS_PATH/imsLoad.sh

#update transitivities status in meta-graph
updateTransitvitiesStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> ?status .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<http://www.openphacts.org/ops_system> <http://www.openphacts.org/api#transitivitiesStatus> <http://www.openphacts.org/api/UP-TO-DATE> .
}"
encodedQuery=$(php -r "echo urlencode(\"${updateDataDumpStatusTemplate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
