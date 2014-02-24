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

	#update the loading status in the meta-graph to LOADING_ERROR, both at the VOID descriptor and datasets dumps level

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

	while read dumpURI
	do
		updateDataDumpStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_ERROR> .
}"
		encodedQuery=$(php -r "echo urlencode(\"${updateDataDumpStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
	done <"$dumpListPath"

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

	#update loading status in the meta-graph at the VOID descriptor level
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
	#rm -rf "$directoryPath"
	mkdir "$directoryPath"
	if [ $? -ne 0 ]; then #check if directory existed
		#directory existed, means we are dealing with a reload
		echo "Reload true for $graphName"
		reload=true
	else
		echo "Reload false for $graphName"
		reload=false
	fi
	cd "$directoryPath"

	#download the data dumps
	echo "Downloading data dumps in $directoryPath .."
	success=true
	while read dumpURI
	do
		#update loading status in the meta-graph for this dump URI
		updateDataDumpStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_DATASETS> .
}"
		encodedQuery=$(php -r "echo urlencode(\"${updateDataDumpStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

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
	find *.tar.gz -exec tar xvzf --overwrite {} \; -exec rm {} \;
	find *.gz -exec gzip -d -f -v {} \;
	find *.tar -exec tar xfv --overwrite {} \; -exec rm {} \;
	find *.zip -exec unzip -u {} \; -exec rm {} \;
	find *.bz2 -exec bunzip2 -f {} \;

	#load into Virtuoso using ISQL
	echo "Loading data to Virtuoso .."
	cd "$workDir"
	#chown -R www-data:vagrant $directoryPath
	$SCRIPTS_PATH/executeDropGraph.sh "$graphName"
	if $reload ; then
                $SCRIPTS_PATH/executeReload.sh "$graphName"
        else
                $SCRIPTS_PATH/executeLoadDir.sh "$directoryPath" "*" "$graphName"
                if [ $? -ne 0 ]; then
                        message="Could not call the ld_dir script in Virtuoso. Dataset URI may exist already in the load_list table"
                        handleError "$message"
                        continue
                fi
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

		while read dumpURI
		do
			updateDataDumpStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADED> .
}"
			encodedQuery=$(php -r "echo urlencode(\"${updateDataDumpStatusTemplate}\");")
			curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
		done <"$dumpListPath"
	else #restart Virtuoso and revert to the previous checkpoint
		echo "$datasetDescriptionURI could not be loaded in Virtuoso. Restarting Virtuoso to revert to the previous checkpoint"
		$SCRIPTS_PATH/executeRawExit.sh
		rm $VIRT_INSTALATION_PATH/var/lib/virtuoso/db/virtuoso.trx
		virtuoso-t +wait +configfile $VIRT_INSTALATION_PATH/var/lib/virtuoso/db/virtuoso.ini
		$SCRIPTS_PATH/grantPermissions.sh
		handleError "$message"
	fi

done



