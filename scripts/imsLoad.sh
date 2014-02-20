#!/bin/bash
#$1 - should be an absolute path to the load.xml file
java -jar $IMS_JAR_PATH/loader-2.0.0-SNAPSHOT.one-jar.jar file://$1
