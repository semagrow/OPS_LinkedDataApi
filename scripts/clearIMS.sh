#!/bin/bash

source /vagrant/env.sh

echo "<?xml version=\"1.0\"?><loadSteps>" >load.xml
echo "<clearAll/>" >>load.xml
echo "</loadSteps>" >>load.xml
$SCRIPTS_PATH/imsLoad.sh "$(pwd)/load.xml"
