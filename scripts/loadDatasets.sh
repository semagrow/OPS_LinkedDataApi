#!/bin/bash

#based on the list of VOID URIs existing in the file 'voidDescriptorsList'
#the following parameters need to be provided (usually they come from loadingScript.sh)
# $META_GRAPH_NAME
# $DATA_DIR
# $SERVER_NAME
# $VIRT_INSTALATION_PATH
# $SCRIPTS_PATH

function handleError {
	echo "$1"

	#revert the loading status in the meta-graph to QUEUED

	updateStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
		<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o1 .	
	}}

	DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
		<$datasetDescriptionURI> <http://www.openphacts.org/api#errorMessage> ?o2 .	
	}}

	INSERT IN GRAPH <$META_GRAPH_NAME> {
		<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_ERROR> .
	        <$datasetDescriptionURI> <http://www.openphacts.org/api#errorMessage> \\\""${1}"\\\"
	}"
	encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=${encodedQuery}"

	success=false
}

#checkpoint Virtuoso here before the whole process starts
echo "Executing checkpoint before it all starts .." 
$SCRIPTS_PATH/executeCheckpoint.sh

workDir=$(pwd)

cat voidDescriptorsList | while read datasetDescriptionURI
do
	echo "Processing $datasetDescriptionURI .."

	#get the download URIs for dataset dumps
	dataDumpsQuery="SELECT ?dataDump WHERE { GRAPH <$META_GRAPH_NAME> {

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
	dumpListPath="$(pwd)/dumpList"

	#update loading status in the meta-graph
	updateStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#errorMessage> ?o2 .	
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_DATASETS> .
}"
	encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

	#get the associated graph name and create a directory where to download the data dumps
	getGraphQuery="SELECT ?graphName WHERE { GRAPH <$META_GRAPH_NAME> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#graphName> ?graphName .
} }"
	encodedQuery=$(php -r "echo urlencode(\"${getGraphQuery}\");")
	graphName=$(curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2)
	dirName=$(echo "$graphName" | sed "s,.*://,," | tr '/' '_') #remove prefix (e.g. http://) and replace '/' with '_' in the rest of the file
	directoryPath="$DATA_DIR/$dirName"
	rm -rf "$directoryPath"
	mkdir -p "$directoryPath"
	cd "$directoryPath"

	#download the data dumps
	echo "Downloading data dumps in $directoryPath .."
	success=true
	while read dumpURI
	do
		wget "$dumpURI"
		if [ $? -ne 0 ]; then
			message="Could not download $dumpURI . Aborting the LOAD for $datasetDescriptionURI . Please fix the VOID header at this location!"
			handleError "$message"
			break;
		fi
	done <"$dumpListPath"

	if [ $success == false ] ; then
		echo "Skipping to next dataset"
		continue
	fi

	#check if we need to un-archive the data dump
	echo "Unarchiving data dumps .."
	find *.tar.gz -exec tar xvzf {} \; -exec rm {} \;
	find *.gz -exec gzip -d -v {} \;
	find *.tar -exec tar xfv {} \; -exec rm {} \;
	find *.zip -exec unzip {} \; -exec rm {} \;
	find *.bz2 -exec bunzip2 {} \;

	#load into Virtuoso using ISQL
	echo "Loading data to Virtuoso .."
	cd "$workDir"
	chown -R www-data:vagrant $directoryPath
	$SCRIPTS_PATH/executeLoadDir.sh "$directoryPath" "*" "$graphName"
	if [ $? -ne 0 ]; then
		message="Could not call the ld_dir script in Virtuoso. Dataset URI may exist already in the load_list table"
		handleError "$message"
		continue
	fi
	$SCRIPTS_PATH/executeLoaderRun.sh
	if [ $? -ne 0 ]; then
		message="Could not call the rdf_loader_run command in Virtuoso. Possible problems with Virtuoso."
		success=false
	fi

	#if successful, update loading status in the meta-graph
	if $success ; then
		echo "Successfully loaded $datasetDescriptionURI"
		$SCRIPTS_PATH/executeCheckpoint.sh

		updateStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
			<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o .
		}}

		INSERT IN GRAPH <$META_GRAPH_NAME> {
			<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/DATASETS_LOADED> .
		}"
		encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
	else #restart Virtuoso and revert to the previous checkpoint
		echo "$datasetDescriptionURI could not be loaded in Virtuoso. Restarting Virtuoso to revert to the previous checkpoint"
		$SCRIPTS_PATH/executeRawExit.sh
		rm $VIRT_INSTALATION_PATH/var/lib/virtuoso/db/virtuoso.trx
		virtuoso-t +wait +configfile $VIRT_INSTALATION_PATH/var/lib/virtuoso/db/virtuoso.ini
		$SCRIPTS_PATH/grantPermissions.sh
		handleError "$message"
	fi

done


