#!/bin/bash

isql 1111 dba dba VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout "exec=rdf_loader_run();"
