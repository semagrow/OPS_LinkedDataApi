#!/bin/sh

config_dir="$1"
tmp_dir="$2"
output_dir="$3"
if [[ x$4 == x ]] ; then action=exec; else action="$4"; fi

# the command to get the checksum is md5sum in Linux, md5 in MacOS
checksum=$(which md5sum)
if [[ "x$checksum" == "x" ]]; then checksum=$(which md5); fi
if [[ "x$checksum" == "x" ]]; then checksum="noop"; fi

if [[ `diff -N --exclude=*.sh --exclude=*.bak --exclude=*.json --exclude=".*" --exclude="colorCoding" --exclude="docs" "$config_dir" "$tmp_dir"` ]] ; then
    today=`date "+%Y%m%d"`
    mkdir -p $output_dir/$today
    echo "Changes detected, dumping SPARQL queries to: $output_dir/$today"
    rm -f $tmp_dir/*.ttl
    cp $config_dir/*.ttl $tmp_dir/
    for file in $tmp_dir/*.ttl
    do
	echo "Processing: $file"
	urls=`grep "api:exampleRequestPath" $file  | sed -e 's,^.*api:exampleRequestPath *",http://ops2.few.vu.nl,' -e 's,".*$,\&_format=ttl\&_metadata=execution,'`
	for url in $urls
	do
		if [[ ! "$url" == *\?* ]] ; then
			url=`echo "$url" | sed 's,&,?,'`
		fi
		echo $url
		response=`curl -s -S $url`
		while [[ $response == "" ]]
		do
		    response=`curl -s -S $url`
		done
		if [[ "$response" == *\<html* ]] ; then
			echo "Turtle output not received from: $url"
		fi
		method_name=`echo $url | sed -e 's,http://ops2.few.vu.nl/,,' -e 's,/,_,g' -e 's,\?.*,,'`
		if [[ "$response" == *selectionQuery* ]] ; then
			filename="$method_name"_select
			oldname=$filename
			count=2
			while [[ -f $output_dir/$today/$filename.txt ]]
			do
				filename="$oldname"_"$count"
				((count++))
			done
			
			selectQuery=`echo "$response" | sed -n '/^_:selectionQuery/,/""" ./p' | sed -e 's,_:selectionQuery rdf:value ,,' -e 's,"""[ \.]*,,'`
			echo "$selectQuery" > $output_dir/$today/$filename.txt
			outputFileName="$filename"_out
			if [[ $action == exec ]] ; then ./executeSparqlSelector.sh "$selectQuery" > $output_dir/$today/$outputFileName; fi
			blankNodeCount=$(grep "_:" $output_dir/$today/$outputFileName | wc -l)
			grep -v "_:" $output_dir/$today/$outputFileName | sort >$output_dir/$today/temp
			echo $blankNodeCount >>$output_dir/$today/temp

			#sleep 30
			cat $output_dir/$today/temp | $checksum | cut -d " " -f 1 >$output_dir/$today/$outputFileName.md5
			rm $output_dir/$today/$outputFileName
		fi
		filename="$method_name"_view
		oldname=$filename
		count=2
		while [[ -f $output_dir/$today/$filename.txt ]]
		do
			filename="$oldname"_"$count"
			((count++))
		done
		viewQuery=`echo "$response" | sed -n '/^_:viewingQuery/,/""" ./p' | sed -e 's,_:viewingQuery rdf:value ,,' -e 's,"""[ \.]*,,'`
		echo "$viewQuery" > $output_dir/$today/$filename.txt
		outputFileName="$filename"_out
		if [[ $action == exec ]]; then ./executeSparqlViewer.sh "$viewQuery" > $output_dir/$today/$outputFileName; fi

		blankNodeCount=$(grep "_:" $output_dir/$today/$outputFileName | wc -l)
                grep -v "_:" $output_dir/$today/$outputFileName | sort >$output_dir/$today/temp
                echo $blankNodeCount >>$output_dir/$today/temp
                #sleep 30

		cat $output_dir/$today/temp | $checksum | cut -d " " -f 1 >$output_dir/$today/$outputFileName.md5
		rm $output_dir/$today/$outputFileName
	done
    done
else
   echo "No changes detected"
fi
