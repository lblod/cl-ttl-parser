from rdflib import Graph, compare

# Script to compare the graphs in two n-triples files in more detail.  This can
# be used to check why a test in `compare-graphs` reports that graphs are not
# equal.

# Name of the test
test_name = "IRI-resolution-01"
# Optional, name of the test suite result file. Only needed if this name differs
# from the test's name. Without `.nt` file extension.
expected_name = None

expected = Graph().parse(
    f"../rdf-tests/rdf/rdf11/rdf-turtle/{expected_name if expected_name and len(expected_name) > 0 else test_name}.nt"
)
parsed = Graph().parse(f"./output-files/{test_name}.nt")

iso_expected = compare.to_isomorphic(expected)
iso_parsed = compare.to_isomorphic(parsed)

in_both, in_expected, in_parsed = compare.graph_diff(iso_expected, iso_parsed)


def dump_nt_sorted(graph):
    for line in sorted(graph.serialize(format="nt").splitlines()):
        if line:
            print("\t" + line)


print("In both:")
dump_nt_sorted(in_both)

print("In expected:")
dump_nt_sorted(in_expected)

print("In parsed:")
dump_nt_sorted(in_parsed)
