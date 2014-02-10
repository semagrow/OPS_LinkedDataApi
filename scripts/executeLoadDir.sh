#!/bin/bash
#$1 - directory where to get files from
#$2 - filename, can also be '*' to get everything
#$3 - graphName

isql 1111 dba dba VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout "exec=ld_dir('${1}', '${2}', '${3}');"
