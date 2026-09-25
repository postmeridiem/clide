#!/usr/bin/env bash
# Names each failed test on the run page, as a GitHub annotation. Reading a
# run's log takes a GitHub sign-in and reading its annotations does not, so a
# red job says which tests failed to anyone who opens it.
#
# Reads the JSON reports ci/test.sh writes into TEST_REPORT_DIR and prints one
# `::error` workflow command per failed test: the file and line that declare
# it, its full name, and the first lines of its failure. The test workflow
# runs it after a failed step. A report that does not exist is skipped, so a
# job that failed before its tests ran prints nothing.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)/"

for report in "$@"; do
  [[ -f "$report" ]] || continue
  jq -rs --arg root "$root" '
    # Workflow-command escaping; properties also reserve ":" and ",".
    def message: gsub("%"; "%25") | gsub("\r"; "%0D") | gsub("\n"; "%0A");
    def property: message | gsub(":"; "%3A") | gsub(","; "%2C");
    (map(select(.type == "suite") | {key: (.suite.id | tostring), value: .suite.path}) | from_entries) as $suites
    | (map(select(.type == "testStart") | {key: (.test.id | tostring), value: .test}) | from_entries) as $tests
    | (map(select(.type == "error")) | group_by(.testID) | map({key: (.[0].testID | tostring), value: .[0].error}) | from_entries) as $errors
    | .[]
    | select(.type == "testDone" and .result != "success" and (.hidden | not))
    | $tests[.testID | tostring] as $test
    | ((if $test.url then $test.url | ltrimstr("file://") else $suites[$test.suiteID | tostring] // "" end) | ltrimstr($root)) as $file
    | (($errors[.testID | tostring] // .result) | split("\n") | .[:6] | join("\n") | sub("\\s+$"; "")) as $failure
    | "::error file=\($file | property),line=\($test.line // 1),title=\($test.name | property)::\($failure | message)"
  ' "$report"
done
