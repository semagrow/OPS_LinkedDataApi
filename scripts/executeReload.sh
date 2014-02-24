#!/bin/bash
#$1 - graphName for the graph to be updated

isql 1111 dba dba VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout "exec=update load_list set ll_state=0 where ll_graph='${1}'; "
