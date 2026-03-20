# cl-ttl-parser

> [!warning]
> This project should be considered in a beta phase, its public API may still change over time.

An [RDF 1.1 Turtle](https://www.w3.org/TR/turtle/) parser written in Common Lisp.  This parser aims to be compliant with that specification.  Any behaviour that deviates should be considered a but, please check [known issues](#known-issues) before reporting.


## Usage
The cl-ttl-parser comes with an ASDF system definition.  Clone this repository to a location ASDF can find it.  Then load the system using `(asdf:load-system :cl-ttl-parser)`.

To parse Turtle it can be passed as a string to the exported `parse-ttl` function.  For example:

```lisp
(parse-ttl "@base <http://foo/bar/> .
    @prefix : <http://example.org/foo#> .
    <foo> <http://example.org/property> :bar .")
```

results in

```lisp
((#<QURI.URI.HTTP:URI-HTTP http://foo/bar/foo>
  #<QURI.URI.HTTP:URI-HTTP http://example.org/property>
  #<QURI.URI.HTTP:URI-HTTP http://example.org/foo#bar>))
```

The `parse-ttl` function optionally allows to pass an IRI string as initial base.  This base will be used to resolve relative as long as no other base is set in the input.  For example, in the following snippet `"http://foo.bar.org/"` is provided as initial base:

```lisp
CL-TTL-PARSER> (parse-ttl "<relative-subject> <http://example.org/property> <http://example.org/object> ." "http://foo.bar.org/")
```

This results in the following output, notice the subject IRI was resolved against the provided initial base.

```lisp
((#<QURI.URI.HTTP:URI-HTTP http://foo.bar.org/relative-subject>
  #<QURI.URI.HTTP:URI-HTTP http://example.org/property>
  #<QURI.URI.HTTP:URI-HTTP http://example.org/object>))
```

Note that relative base and prefix IRIs can also be resolved against the initial base:

```lisp
CL-TTL-PARSER> (parse-ttl "<relative-subject> <http://example.org/property> <http://example.org/object> .

@base </foo/bar/> .
@prefix foo: </baz/oof/> .
<other-relative-subject> <relative-property> foo:object ." "http://foo.bar.org/")
```

Results in the following graph, note the IRIs of the second triple:

```lisp
((#<QURI.URI.HTTP:URI-HTTP http://foo.bar.org/relative-subject>
  #<QURI.URI.HTTP:URI-HTTP http://example.org/property>
  #<QURI.URI.HTTP:URI-HTTP http://example.org/object>)
 (#<QURI.URI.HTTP:URI-HTTP http://foo.bar.org/foo/bar/other-relative-subject>
  #<QURI.URI.HTTP:URI-HTTP http://foo.bar.org/foo/bar/relative-property>
  #<QURI.URI.HTTP:URI-HTTP http://foo.bar.org/baz/oof/object>))
```

Trying to parse a relative IRI without a providing a base will result in an error:

```lisp
CL-TTL-PARSER> (parse-ttl "<relative-subject> <http://example.org/property> <http://example.org/object> .")
; Debugger entered on #<CL-TTL-PARSER-ERROR "Parsing error: cannot not resolve relative IRI \"~A\" without a base IRI" {1203CAC0F3}>
```

## Testing
This parser can be tested against the Turtle 1.1 tests in the [RDF test suite](https://github.com/w3c/rdf-tests). The test suite is included as a submodule in this repository, before continuing make sure the submodule is properly cloned along with this repository.

### Running individual tests
An single test can be run using the `cl-ttl-parser-tests::run-test` function.  As mandatory argument this takes the filename of the test to perform.  For example, to run the [IRI_subject](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-turtle/IRI_subject.ttl) test one would provide that filename, without extension, as argument:

```lisp
CL-TTL-PARSER> (cl-ttl-parser-tests::run-test "IRI_subject")

IRI_subject: [PASS] Successfully parsed
NIL
```

For tests that are expected to fail, one can pass a non-nil value for the `:failp` keyword argument.  For example, the contents of [turtle-syntax-bad-uri-01](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-turtle/turtle-syntax-bad-uri-01.ttl) should fail to parse as spaces are not allowed in IRIs:

```lisp
CL-TTL-PARSER> (cl-ttl-parser-tests::run-test "turtle-syntax-bad-uri-01" :failp t)

turtle-syntax-bad-uri-01: [PASS] Received expected error "Unexpected terminal |error| (value |error|). Expected one of: (NIL
                                                                                                                         [
                                                                                                                         |(|
                                                                                                                         PNAME_NS
                                                                                                                         PNAME_LN
                                                                                                                         IRIREF
                                                                                                                         BLANK-NODE-LABEL
                                                                                                                         ANON
                                                                                                                         |spBase|
                                                                                                                         |@base|
                                                                                                                         |@prefix|
                                                                                                                         |spPrefix|)"
T
```

Providing a non-nil value for `:outputp` keyword variable will write the parsed graph to a file in `./tests/output-files/` with the test's name as filename.  This can be used to compare the result of this parser to the expected, see the section on [comparing graphs](#comparing-graphs).

### Running all tests
Running all tests would require doing the above for each individual test.  This is partially automated using the [tests-list.py](./tests/tests-list.py) script.  This script uses [rdflib](https://rdflib.readthedocs.io/en/stable/) to parse the test suite's [manifest](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-turtle/manifest.ttl) file and generates the appropriate `run-test` calls for each, writing them to the `./tests/test-overview.lisp` file.  After running this script one can use the `cl-ttl-parser-tests::run-all-tests` function to execute all calls in the generated file.  Be aware this will generate a lot of output, at the end a short summary will be printed listing any failed tests:

```lisp
CL-TTL-PARSER> (cl-ttl-parser-tests::run-all-tests)

IRI_subject: [PASS] Successfully parsed
IRI_with_four_digit_numeric_escape: [PASS] Successfully parsed
IRI_with_eight_digit_numeric_escape: [PASS] Successfully parsed
IRI_with_all_punctuation: [PASS] Successfully parsed
bareword_a_predicate: [PASS] Successfully parsed
old_style_prefix: [PASS] Successfully parsed
SPARQL_style_prefix: [PASS] Successfully parsed
<output pruned for readability>

Summary
Number of failed tests: 8

labeled_blank_node_with_non_leading_extras
labeled_blank_node_with_PN_CHARS_BASE_character_boundaries
localName_with_non_leading_extras
localName_with_nfc_PN_CHARS_BASE_character_boundaries
localName_with_assigned_nfc_PN_CHARS_BASE_character_boundaries
localName_with_assigned_nfc_bmp_PN_CHARS_BASE_character_boundaries
prefix_with_non_leading_extras
prefix_with_PN_CHARS_BASE_character_boundaries
NIL
```


### Comparing graphs
For some tests, those of type of type `rdft:TestTurtleEval`, the test suite also provides an n-triples file which contains the graph that is expected when parsing the test file.  The [compare-graphs.py](./tests/compare-graphs.py) script can be used to check whether files produced by this parser are graph equivalent to the result files specified by the test suite.  To this end it uses [rdflib](https://rdflib.readthedocs.io/en/stable/) to parse the test suite's [manifest](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-turtle/manifest.ttl) file.

```shell
$ python ./tests/compare-graphs.py
[PASS] IRI_subject
[PASS] IRI_with_four_digit_numeric_escape
[PASS] IRI_with_eight_digit_numeric_escape
[PASS] IRI_with_all_punctuation
[PASS] bareword_a_predicate
[PASS] old_style_prefix
[PASS] SPARQL_style_prefix
[PASS] prefixed_IRI_predicate
[PASS] prefixed_IRI_object
[PASS] prefix_only_IRI
[FAIL] prefix_with_PN_CHARS_BASE_character_boundaries: no parsed result found
[FAIL] prefix_with_non_leading_extras: no parsed result found
<output pruned for readability>

Summary:
        Missing parsed result file:
          prefix_with_PN_CHARS_BASE_character_boundaries
          prefix_with_non_leading_extras
          localName_with_assigned_nfc_bmp_PN_CHARS_BASE_character_boundaries
          localName_with_assigned_nfc_PN_CHARS_BASE_character_boundaries
          localName_with_nfc_PN_CHARS_BASE_character_boundaries
          localName_with_non_leading_extras
          labeled_blank_node_with_PN_CHARS_BASE_character_boundaries
          labeled_blank_node_with_non_leading_extras
        Number of missing result files: 8

        Failed tests:
          LITERAL_LONG2_with_2_squotes: Invalid line: y" .
          IRI-resolution-01: graphs are NOT equal
          IRI-resolution-07: graphs are NOT equal
        Number of failed tests: 3
```


The [compare-output.py](./tests/compare-output.py) script can be used to compare the graphs in two n-triples files in a bit more detail.  This is primarily used to investigate how a graph produced by this parser differs from the one expected by the test suite.  Before running this this script, assign to the `test_name` variable the name of the test as specified in the manifest.  If the manifest specifies an `mf:result` with a different name than the test itself, assign this value to `expected_name`.  Do not include the `.nt` file extension in the strings, this is automatically appended when parsing the files later on.  For example, the output for comparing the outputs for the [IRI-resolution-01](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-turtle/IRI-resolution-01.ttl#L1) test could look something like as follows:

```shell
$ python ./tests/compare-output.py
In both:
    <urn:ex:s001> <urn:ex:p> <g:h> .
    <urn:ex:s002> <urn:ex:p> <http://a/bb/ccc/g> .
    <urn:ex:s003> <urn:ex:p> <http://a/bb/ccc/g> .
    <urn:ex:s004> <urn:ex:p> <http://a/bb/ccc/g/> .
    <urn:ex:s005> <urn:ex:p> <http://a/g> .
    <urn:ex:s006> <urn:ex:p> <http://g> .
    <output pruned for readability>
In expected:
    <urn:ex:s009> <urn:ex:p> <http://a/bb/ccc/d;p?q#s> .
    <urn:ex:s015> <urn:ex:p> <http://a/bb/ccc/d;p?q> .
In parsed:
    <urn:ex:s009> <urn:ex:p> <http://a/bb/ccc/d;p#s> .
    <urn:ex:s015> <urn:ex:p> <http://a/bb/ccc/d;p> .
```


## Dependencies
- [cl-lex](https://github.com/djr7C4/cl-lex)
- [cl-yacc](https://www.irif.fr/~jch/software/cl-yacc/)
- [quri](https://github.com/fukamachi/quri)

For running the tests:
- [rdflib](https://rdflib.readthedocs.io/en/stable/)


## Known issues
1. The regular expressions for `PN_CHARS_BASE` and `PN_CHARS` do not yet support the full (unicode) character set.
2. In some cases merging an IRI with a base results in an incorrect result.  This is visible by the `IRI-resolution-01` and `IRI-resolution-07` tests resulting in graphs that are not equivalent to the expected result.  The underlying issued is that the result from `quri:merge-uris` differs from the merged IRIs expected by the test suite.  Further investigate whether this is a bug in quri's implementation of the URI resolution algorithm of [RFC3986](https://www.rfc-editor.org/rfc/rfc3986#section-5.2)
