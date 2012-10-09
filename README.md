PHP SPARQL Endpoint 
=================

A repository to host minimal code that exposes a SPARQL endpoint at:
http://localhost/sparql/

Requirements are php 5.2, with php_xsl, lib_curl, and mod_rewrite and htaccess override enabled.

The endpoint expects a SPARQL query as the content of the 'query' HTTP POST/GET variable. The query is then expanded, translated to Virtuoso syntax and evaluated against the endpoint specified in sparql/index.php . By default this is set to: http://localhost:8890/sparql/ , the default URL for Virtuoso.

Query Expander
--------------
There are 3 ways to interact with the Query Expander:
# Default mode
  All instance URIs (i.e. contained in'<', '>') in the subject and object positions of BGPs are expanded.

# Parameter mode
The URI for expansion is set by the 'inputURI' HTTP POST/GET parameter.
Matching URLs will be used to expand the the variables hardcoded in sparql/ops_ims.class.php : 

     '?cw_uri' , '?cs_uri' , '?db_uri' , '?chembl_uri' , and '?uniprot_uri'

# Implicit mode
If the 'query' HTTP POST/GET parameter is not set, the script will look for the BGP:

     [] ops:input <http://example.org/uri1> . 

If found, the object of the BGP will be used as the 'inputURI' and expansion is carried out as above. The BGP is then removed from the SPARQL query before it is evaluated. Note that the script will not do prefix expansion, but only syntactic checking for the ops:input predicate.

URISpacesPerGraph
-----------------
If named graphs are used in the SPARQL query, only URIs from a predifined namespace are inserted by the expander. Known named graphs and corresponding URI namespaces are listed at:

http://openphacts.cs.man.ac.uk:9090/QueryExpander/URISpacesPerGraph

Examples
--------
In summary, the following requests are equivalent:

     http://localhost/sparql/?query=SELECT * WHERE { <http://www.conceptwiki.org/concept/38932552-111f-4a4e-a46a-4ed1d7bdf9d5> ?p ?o }

     http://localhost/sparql/?query=SELECT * WHERE { ?cw_uri ?p ?o }&inputURI=http://www.conceptwiki.org/concept/38932552-111f-4a4e-a46a-4ed1d7bdf9d5

     http://localhost/sparql/?query=SELECT * WHERE { [] ops:input <http://www.conceptwiki.org/concept/38932552-111f-4a4e-a46a-4ed1d7bdf9d5> . ?cw_uri ?p ?o }

####Graph Example

Note that because of the way this query is written, the number of results is the product of all predicates in each graph, hence the LIMIT 100

     http://localhost/sparql/?query=SELECT * WHERE { GRAPH <http://www.conceptwiki.org> { ?cw_uri ?p1 ?o1 } GRAPH <http://data.kasabi.com/dataset/chembl-rdf> { ?chembl_uri ?p2 ?o2} GRAPH <http://www.chemspider.com> { ?cs_uri ?p3 ?o3 } GRAPH <http://linkedlifedata.com/resource/drugbank> { ?db_uri ?p4 ?o4 } } LIMIT 100&inputURI=http://www.conceptwiki.org/concept/38932552-111f-4a4e-a46a-4ed1d7bdf9d5
