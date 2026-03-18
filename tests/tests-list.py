from rdflib import Graph

# Script to generate a file containing function calls run the Turtle 1.1 tests
# in the RDF test suite.  This parses the appropriate manifest file and for
# each contained test generated a corresponding lisp function call (the
# `run-test` function is defined in `tests.lisp`).  The resulting file can be
# then be loaded to execute all listed tests, as done by `run-all-tests` in
# `tests.lisp`.

base = "https://w3c.github.io/rdf-tests/rdf/rdf11/rdf-turtle/"

manifest = Graph()
manifest.parse("rdf-tests/rdf/rdf11/rdf-turtle/manifest.ttl")


def parse_uri(uri):
    return uri.fragment


def parse_type(uri):
    type_name = parse_uri(uri)
    if type_name == "TestTurtleNegativeSyntax":
        return ":failp t"
    if type_name == "TestTurtleEval":
        return ":outputp t"
    return ""


def base_for_test(name):
    return f':initial-base "{base}{name}.ttl"'


tests_query = """
PREFIX mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdft: <http://www.w3.org/ns/rdftest#>

SELECT DISTINCT ?uri ?action ?type
WHERE {
  ?uri a ?type ;
       mf:action ?action .
  VALUES ?type {
    rdft:TestTurtleEval
    rdft:TestTurtlePositiveSyntax
    rdft:TestTurtleNegativeSyntax
  }
}"""

tests_list = manifest.query(tests_query)

with open("test-overview.lisp", "w") as f:
    f.write("(in-package :cl-ttl-parser-tests)\n\n")
    for uri, action, type in tests_list:
        name = parse_uri(uri)
        f.write(f'(run-test "{name}" {base_for_test(name)} {parse_type(type)})\n')
