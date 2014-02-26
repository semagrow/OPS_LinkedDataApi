#!/bin/bash
#$1 - void URI
#$2 - meta graph

source /vagrant/env.sh
META_GRAPH="$2"
SERVER_NAME="$3"
TEMP_META_GRAPH="http://www.openphacts.org/api/tempDatasetDescriptorsTest"


#clear temp graph
$SCRIPTS_PATH/executeSparqlCommand.sh "CLEAR GRAPH <$TEMP_META_GRAPH>"

#insert the VOID header into the temp graph
echo "Inserting VOID header into $TEMP_META_GRAPH"
$SCRIPTS_PATH/executeCommand.sh "DELETE FROM load_list WHERE ll_graph='$TEMP_META_GRAPH'"

WORK_DIR=$(pwd)
TEMP_DIR=/home/www-data/tempDir
rm -rf $TEMP_DIR
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
wget "$1"

$SCRIPTS_PATH/executeLoadDir.sh "$TEMP_DIR" "*" "$TEMP_META_GRAPH"
$SCRIPTS_PATH/executeLoaderRun.sh

#query the header for the list of subjects
echo "Retrieving the list of subjects .."
SUBJECT_LIST_QUERY="SELECT DISTINCT ?s WHERE { GRAPH <$TEMP_META_GRAPH> { ?s ?p ?o } }"
encodedQuery=$(php -r "echo urlencode(\"${SUBJECT_LIST_QUERY}\");")
subjectList=$(curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2)

#remove from the META GRAPH the triples which have subjects in the previous list
echo "Removing the triples from the meta graph $META_GRAPH based on the subject list .."
echo "$subjectList" | while read VOID_SUBJECT
do
	DELETE_DUMP_STATUS_QUERY="DELETE { GRAPH <$META_GRAPH> {?dump <http://www.openphacts.org/api#loadingStatus> ?status .} } WHERE
{ GRAPH <$META_GRAPH> {
?s void:dataDump ?dump .
?dump <http://www.openphacts.org/api#loadingStatus> ?status .
FILTER(?status!=<http://www.openphacts.org/api/LOADED>)
} }"
	encodedQuery=$(php -r "echo urlencode(\"${DELETE_DUMP_STATUS_QUERY}\");")
        curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

	DELETE_QUERY="DELETE WHERE { 
GRAPH<$META_GRAPH> { 
<$VOID_SUBJECT> ?p ?o } }"
	encodedQuery=$(php -r "echo urlencode(\"${DELETE_QUERY}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
done
