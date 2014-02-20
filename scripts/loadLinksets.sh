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

workDir=$(pwd)

clearAllLoadXML="<?xml version=\"1.0\"?>
<loadSteps>
    <clearAll/>
</loadSteps>"
echo "$clearAllLoadXML">load.xml
$SCRIPTS_PATH/imsLoad.sh

cat voidDescriptorsList | while read datasetDescriptionURI
do
	echo "Processing $datasetDescriptionURI .."

	#get the download URIs for linksets dumps
	linksetDumpsQuery="SELECT ?linksetDump WHERE { GRAPH <http://www.openphacts.org/api/datasetDescriptorsTest> {

<https://raw.github.com/openphacts/ops-platform-setup/severVOIDs/void/chembl/chembl16-void.ttl> foaf:primaryTopic ?dataset .

{ ?dataset a void:Linkset .
?dataset void:dataDump ?linksetDump . }
UNION
{ ?dataset void:subset+ ?subset .
?subset a void:Linkset . 
?subset void:dataDump ?linksetDump . 
}
} }"
	encodedQuery=$(php -r "echo urlencode(\"${linksetDumpsQuery}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2 >linksetDumpList
	linksetDumpListPath="$(pwd)/linksetDumpList"

	#update loading status in the meta-graph
	updateStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#errorMessage> ?o2 .	
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_LINKSETS> .
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
	dirName=$(echo "$dirName\_linksets")
	directoryPath="$DATA_DIR/$dirName"
	rm -rf "$directoryPath"
	mkdir -p "$directoryPath"
	cd "$directoryPath"

	#download the linkset dumps
	echo "Downloading linkset dumps in $directoryPath .."
	success=true
	while read dumpURI
	do
		wget "$dumpURI"
		if [ $? -ne 0 ]; then
			message="Could not download $dumpURI . Aborting the Linkset Load for $datasetDescriptionURI . Please fix the VOID header for this linkset!"
			handleError "$message"
			break;
		fi
	done <"$linksetDumpListPath"

	if [ $success == false ] ; then
		echo "Skipping to next linkset"
		continue
	fi

	#check if we need to un-archive the data dump
	echo "Unarchiving data dumps .."
	find *.tar.gz -exec tar xvzf {} \; -exec rm {} \;
	find *.gz -exec gzip -d -v {} \;
	find *.tar -exec tar xfv {} \; -exec rm {} \;
	find *.zip -exec unzip {} \; -exec rm {} \;
	find *.bz2 -exec bunzip2 {} \;

	echo "<?xml version=\"1.0\"?><loadSteps>" >load.xml
	find $(pwd) -maxdepth 1 -type f -exec echo "<linkset>file://{}</linkset>">>load.xml \;
	echo "</loadSteps>" >>load.xml


	#load into the IMS
	echo "Loading linksets in $directoryPath in the IMS .."
	cd "$workDir"
	chown -R www-data:vagrant $directoryPath
	
	$SCRIPTS_PATH/imsLoad.sh
	if [ $? -ne 0 ]; then
		message="Could not linksets for $datasetDescriptionURI in the IMS. Please check for errors in the mappings."
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
			<$datasetDescriptionURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADED> .
		}"
		encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
	else 
		#cotinue to load next linksets with <recover> enabled
		handleError "$message"
	fi

done

echo "<?xml version=\"1.0\"?><loadSteps>" >load.xml
echo "<doTransitive/>" >>load.xml
echo "</loadSteps>" >>load.xml
$SCRIPTS_PATH/imsLoad.sh

