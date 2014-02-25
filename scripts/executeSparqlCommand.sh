#!/bin/bash
#$1 - graphName for the graph to be updated

isql 1111 dba dba VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout "exec=sparql ${1}; "
