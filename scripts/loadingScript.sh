#!/bin/bash

function handleError {
	echo "$1"

	#revert the loading status in the meta-graph to QUEUED

	updateStatusTemplate="DELETE WHERE { GRAPH <$metaGraphName> {
		<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o1 .
		<$datasetDescriptionURI> <http://www.openphacts.org/api#errorMessage> ?o2 .
	}}

	INSERT IN GRAPH <$metaGraphName> {
		<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_ERROR> .
		<$datasetDescriptionURI> <http://www.openphacts.org/api#errorMessage> \"$1\"
	}"
	encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
			
	success=false
}



SERVER_NAME="ops2.few.vu.nl"
metaGraphName="http://www.openphacts.org/api/datasetDescriptorsTest"

#get the list of datasets to be loaded
URIsToUpdate="SELECT ?description WHERE { GRAPH <$metaGraphName> {
?description <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/QUEUED> .
} } ";
encodedQuery=$(php -r "echo urlencode(\"${URIsToUpdate}\");")
curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2 >datasetList

#checkpoint Virtuoso here before the whole process starts
./executeCheckpoint.sh

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

	#get the associated graph name and create a directory where to download the data dumps
	getGraphQuery="SELECT ?graphName WHERE { GRAPH <$metaGraphName> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#graphName> ?graphName .
} }"
	encodedQuery=$(php -r "echo urlencode(\"${getGraphQuery}\");")
	graphName=$(curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2)
	directoryName=$(echo "$graphName" | sed "s,.*://,," | tr '/' '_') #remove prefix (e.g. http://) and replace '/' with '_' in the rest of the file
	echo "$directoryName"
	mkdir "$directoryName"
	cd "$directoryName"

	#download the data dumps
	success=true
	while read dumpURI
	do
		wget "$dumpURI"
		if [ $? -ne 0 ]; then
			$message="Could not download $dumpURI . Aborting the LOAD for $datasetDescriptionURI . Please fix the VOID header at this location!"
			handleError "$message"
			break;	
		fi

		
	done <../dumpList 

	if !$success ; then
		continue
	fi

	#check if we need to un-archive the data dump		
	find *.tar.gz -exec tar xzf {} \; -exec rm {} \;
	find *.gz -exec gzip -d {} \;
	find *.tar -exec tar xf {} \; -exec rm {} \;
	find *.zip -exec unzip {} \; -exec rm {} \;
	find *.bz2 -exec bunzip2 {} \;
		
	#load into Virtuoso using ISQL
	cd ..
	$fullPath=$(echo "$(pwd)"."$directoryName")
	./executeLoadDir.sh "$fullPath" "*" "$graphName"
	if [ $? -ne 0 ]; then
		$message="Could not call the ld_dir script in Virtuoso. Dataset URI may exist already in the load_list table"
		handleError "$message"	
		continue
	fi
	./executeLoaderRun.sh
	if [ $? -ne 0 ]; then
		$message="Could not call the rdf_loader_run command in Virtuoso. Possible problems with Virtuoso."
		handleError "$message"
		continue
	fi

	#if successful, update loading status in the meta-graph
	if $success ; then
		echo "Successfully loaded $datasetDescriptionURI"
		#TODO checkpoint Virtuoso
		
		updateStatusTemplate="DELETE WHERE { GRAPH <$metaGraphName> {
			<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o .
		}}

		INSERT IN GRAPH <$metaGraphName> {
			<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADED> .
		}"
		encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
	#TODO else revert to previous checkpoint
	fi	

done

./executeCheckpoint.sh



