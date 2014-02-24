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
		<$voidDescriptor> <http://www.openphacts.org/api#linksetLoadingStatus> ?o1 .	
	}}

	DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
		<$voidDescriptor> <http://www.openphacts.org/api#errorMessage> ?o2 .	
	}}

	INSERT IN GRAPH <$META_GRAPH_NAME> {
		<$voidDescriptor> <http://www.openphacts.org/api#linksetLoadingStatus> <http://www.openphacts.org/api/LOADING_ERROR> .
	        <$voidDescriptor> <http://www.openphacts.org/api#errorMessage> \\\""${1}"\\\"
	}"
	encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=${encodedQuery}"

	updateLinksetDumpStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING_ERROR> .
}"
	encodedQuery=$(php -r "echo urlencode(\"${updateLinksetDumpStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

	success=false
}

workDir=$(pwd)

#clearAllLoadXML="<?xml version=\"1.0\"?>
#<loadSteps>
#    <clearAll/>
#</loadSteps>"
#echo "$clearAllLoadXML">load.xml
#$SCRIPTS_PATH/imsLoad.sh "$(pwd)/load.xml"

cat linksetVoidDescriptorsList | while read voidDescriptor
do
	echo "Processing $voidDescriptor .."

	#get the download URIs for linksets dumps
	linksetDumpsQuery="SELECT ?linksetDump WHERE { GRAPH <$META_GRAPH_NAME> {

<$voidDescriptor> foaf:primaryTopic ?dataset .

{ ?dataset a void:Linkset .
?dataset void:dataDump ?linksetDump . }
UNION
{ ?dataset void:subset+ ?subset .
?subset a void:Linkset . 
?subset void:dataDump ?linksetDump . 
?linksetDump <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/QUEUED> .
}
} }"
	encodedQuery=$(php -r "echo urlencode(\"${linksetDumpsQuery}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2 >linksetDumpList
	linksetDumpListPath="$(pwd)/linksetDumpList"

	#update loading status in the meta-graph at the VOID descriptor level
	updateStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$voidDescriptor> <http://www.openphacts.org/api#linksetLoadingStatus> ?o .
}}

DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$voidDescriptor> <http://www.openphacts.org/api#errorMessage> ?o2 .	
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$voidDescriptor> <http://www.openphacts.org/api#linksetLoadingStatus> <http://www.openphacts.org/api/LOADING> .
}"
	encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
	curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

	#get the associated graph name and create a directory where to download the data dumps
	getGraphQuery="SELECT ?graphName WHERE { GRAPH <$META_GRAPH_NAME> {
<$voidDescriptor> <http://www.openphacts.org/api#graphName> ?graphName .
} }"
	encodedQuery=$(php -r "echo urlencode(\"${getGraphQuery}\");")
	graphName=$(curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery&format=csv" | tr -d '\"' | tail -n +2)
	dirName=$(echo "$graphName" | sed "s,.*://,," | tr '/' '_') #remove prefix (e.g. http://) and replace '/' with '_' in the rest of the file
	dirName=$(echo "$dirName\_linksets")
	directoryPath="$DATA_DIR/$dirName"
	#rm -rf "$directoryPath"
	mkdir -p "$directoryPath"
	cd "$directoryPath"

	#load the linkset dumps
	
	success=true
	i=0
	while read dumpURI #for each linkset dump
	do
		#update loading status in the meta-graph for this dump URI
		updateDataDumpStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADING> .
}"
		encodedQuery=$(php -r "echo urlencode(\"${updateDataDumpStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
		#download linkset dump in a separate directory

		mkdir "dumpDir_$i"
		cd "dumpDir_$i"
		echo "Downloading linkset dumps in $directoryPath/dumpDir_$i .."
		wget "$dumpURI"
		if [ $? -ne 0 ]; then
			message="Could not download $dumpURI . Aborting the Linkset Load for $voidDescriptor . Please fix the VOID header for this linkset!"
			handleError "$message"
			break;
		fi
	
		if [ $success == false ] ; then
			echo "Skipping to next linkset"
			continue
		fi

		#check if we need to un-archive the linkset dump
		echo "Unarchiving linkset dumps .."
		find *.tar.gz -exec tar xvzf --overwrite {} \; -exec rm {} \;
		find *.gz -exec gzip -d -f -v {} \;
		find *.tar -exec tar xfv --overwrite {} \; -exec rm {} \;
		find *.zip -exec unzip -u {} \; -exec rm {} \;
		find *.bz2 -exec bunzip2 -f {} \;

		#load dump into the IMS
		echo "Loading linksets in $directoryPath/dumpDir_$i in the IMS .."
	
		echo "<?xml version=\"1.0\"?><loadSteps>" >load.xml
		find $(pwd) -maxdepth 1 -type f -exec echo "<linkset>file://{}</linkset>">>load.xml \;
		echo "</loadSteps>" >>load.xml
	
		$SCRIPTS_PATH/imsLoad.sh "$(pwd)/load.xml"
		if [ $? -ne 0 ]; then
			message="Could not load linksets for $voidDescriptor in the IMS. Please check for errors in the mappings."
			handleError "$message"
			echo "<?xml version=\"1.0\"?><loadSteps><recover/></loadSteps>" >load.xml
			$SCRIPTS_PATH/imsLoad.sh "$(pwd)/load.xml"
			break;
		fi

		#imsLoading OK, update status for the linkset Dump
		updateDataDumpStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> ?o .
}}

INSERT IN GRAPH <$META_GRAPH_NAME> {
<$dumpURI> <http://www.openphacts.org/api#loadingStatus> <http://www.openphacts.org/api/LOADED> .
}"
		encodedQuery=$(php -r "echo urlencode(\"${updateDataDumpStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"

		cd ..
		i=$((i+1))
	done < "$linksetDumpListPath"
		
	

	#if successful, update loading status in the meta-graph
	if $success ; then
		echo "Successfully loaded $voidDescriptor"
		$SCRIPTS_PATH/executeCheckpoint.sh

		updateStatusTemplate="DELETE WHERE { GRAPH <$META_GRAPH_NAME> {
			<$voidDescriptor> <http://www.openphacts.org/api#linksetLoadingStatus> ?o .
		}}

		INSERT IN GRAPH <$META_GRAPH_NAME> {
			<$voidDescriptor> <http://www.openphacts.org/api#linksetLoadingStatus> <http://www.openphacts.org/api/LOADED> .
		}"
		encodedQuery=$(php -r "echo urlencode(\"${updateStatusTemplate}\");")
		curl "http://$SERVER_NAME:8890/sparql?query=$encodedQuery"
	fi
	#else cotinue to load next linksets

done

#echo "<?xml version=\"1.0\"?><loadSteps>" >load.xml
#echo "<doTransitive/>" >>load.xml
#echo "</loadSteps>" >>load.xml
#$SCRIPTS_PATH/imsLoad.sh

