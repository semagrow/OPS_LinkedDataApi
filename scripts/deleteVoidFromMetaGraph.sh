#!/bin/bash
#$1 - void URI
#$2 - meta graph

META_GRAPH="$2"
TEMP_META_GRAPH="http://www.openphacts.org/api/tempDatasetDescriptorsTest"
SERVER_NAME="$3"

voidContent=$(curl "$1")
#TODO handle error

#clear temp graph
CLEAR_COMMAND="CLEAR GRAPH <$TEMP_META_GRAPH>"
encodedQuery=$(php -r "echo urlencode(\"${CLEAR_COMMAND}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

#insert the VOID header into the temp graph
prefixes=$(echo "$voidContent" | grep "@prefix" | tr -d "@" | sed 's/> *\./>/')
voidBody=$(echo "$voidContent" | grep -v "@prefix")
INSERT_QUERY="$prefixes
INSERT INTO $TEMP_META_GRAPH {
$voidBody
}"
encodedQuery=$(php -r "echo urlencode(\"${INSERT_QUERY}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
 
#query the header for the list of subjects
SUBJECT_LIST_QUERY="SELECT DISTINCT ?s WHERE { GRAPH <$TEMP_META_GRAPH> { ?s ?p ?o } }"
encodedQuery=$(php -r "echo urlencode(\"${SUBJECT_LIST_QUERY}\");")
subjectList=$(curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2)
 
#remove from the META GRAPH the triples which have subjects in the previous list
echo "$subjectList" | while read VOID_SUBJECT
do
	DELETE_QUERY="DELETE WHERE { 
GRAPH<$TEMP_META_GRAPH> { 
<$VOID_SUBJECT> ?p ?o } }"
	encodedQuery=$(php -r "echo urlencode(\"${DELETE_QUERY}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
done
