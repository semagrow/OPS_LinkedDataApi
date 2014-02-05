#!/bin/bash

SERVER_NAME="ops2.few.vu.nl"
metaGraphName="http://www.openphacts.org/api/datasetDescriptorsTest"

#get the list of datasets to be loaded
URIsToUpdate="SELECT ?description WHERE { GRAPH <$metaGraphName> {
?description <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/QUEUED> .
} } ";
encodedQuery=$(php -r "echo urlencode(\"${URIsToUpdate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2 >datasetList

cat datasetList | while read datasetDescriptionURI
do
	echo "Processing $datasetDescriptionURI .."

	#get the links to dataset dumps
	dataDumpsQuery="SELECT ?dataDump WHERE { GRAPH <$metaGraphName> {

<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/QUEUED> .
<$datasetDescriptionURI> foaf:primaryTopic ?dataset .

{ ?dataset a void:Dataset .
?dataset void:dataDump ?dataDump . }
UNION
{ ?dataset void:subset+ ?subset .

{ ?subset a void:Dataset . }
UNION
{ ?subset a <http://www.openphacts.org/api/LDCLinkset> . }

?subset void:dataDump ?dataDump . }

} }"

	encodedQuery=$(php -r "echo urlencode(\"${dataDumpsQuery}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2 >dumpList

	#update loading status in the meta-graph

	updateStatusTemplate="DELETE WHERE { GRAPH <$metaGraphName> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

INSERT IN GRAPH <$metaGraphName> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING> .
}"
	encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

	#download the dumps
	success=true
	while read dumpURI
	do
		wget "$dumpURI"
		if [ $? -ne 0 ]; then
			echo "Could not download $dumpURI . Aborting the LOAD for $datasetDescriptionURI . Please fix the VOID header at this location!"

			#revert the loading status in the meta-graph to QUEUED

			updateStatusTemplate="DELETE WHERE { GRAPH <$metaGraphName> {
				<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o .
			}}

			INSERT IN GRAPH <$metaGraphName> {
				<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/QUEUED> .
			}"
			encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
			curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
			
			success=false
			break;	
		fi
	done <dumpList 

	if $success ; then
		echo "Successfully loaded $datasetDescriptionURI"
		
		#update loading status in the meta-graph
		updateStatusTemplate="DELETE WHERE { GRAPH <$metaGraphName> {
			<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o .
		}}

		INSERT IN GRAPH <$metaGraphName> {
			<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADED> .
		}"
		encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
	fi	

done
