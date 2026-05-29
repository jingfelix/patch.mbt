///|
let lao : Array[String] = [
  "The Way that can be told of is not the eternal Way;", "The name that can be named is not the eternal name.",
  "The Nameless is the origin of Heaven and Earth;", "The Named is the mother of all things.",
  "Therefore let there always be non-being,", "  so we may see their subtlety,",
  "And let there always be being,", "  so we may see their outcome.", "The two are the same,",
  "But after they are produced,", "  they have different names.",
]

///|
let tzu : Array[String] = [
  "The Nameless is the origin of Heaven and Earth;", "The named is the mother of all things.",
  "", "Therefore let there always be non-being,", "  so we may see their subtlety,",
  "And let there always be being,", "  so we may see their outcome.", "The two are the same,",
  "But after they are produced,", "  they have different names.", "They both may be called deep and profound.",
  "Deeper and more profound,", "The door of all subtleties!",
]

///|
let unified_diff =
  #|--- lao	2013-01-05 16:56:19.000000000 -0600
  #|+++ tzu	2013-01-05 16:56:35.000000000 -0600
  #|@@ -1,7 +1,6 @@
  #|-The Way that can be told of is not the eternal Way;
  #|-The name that can be named is not the eternal name.
  #| The Nameless is the origin of Heaven and Earth;
  #|-The Named is the mother of all things.
  #|+The named is the mother of all things.
  #|+
  #| Therefore let there always be non-being,
  #|   so we may see their subtlety,
  #| And let there always be being,
  #|@@ -9,3 +8,6 @@
  #| The two are the same,
  #| But after they are produced,
  #|   they have different names.
  #|+They both may be called deep and profound.
  #|+Deeper and more profound,
  #|+The door of all subtleties!
  #|

///|
fn line_contents(lines : Array[@model.Line]) -> Array[String] {
  lines.map(line => line.content)
}

///|
fn assert_lines_eq(
  actual : Array[String],
  expected : Array[String],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<actual.length() {
    assert_eq(actual[i], expected[i])
  }
}

///|
test "strict apply transforms lao to tzu" {
  let patch = @parse.parse_patch(unified_diff)
  let result = @apply.apply_patch(lao, patch)
  assert_lines_eq(line_contents(result.new_line_list), tzu)
  assert_eq(result.applied_hunks.length(), 2)
  assert_eq(result.failed_hunk_list.length(), 0)
}

///|
test "strict reverse transforms tzu to lao" {
  let patch = @parse.parse_patch(unified_diff)
  let result = @apply.reverse_patch(tzu, patch)
  assert_lines_eq(line_contents(result.new_line_list), lao)
  assert_eq(result.applied_hunks.length(), 2)
  assert_eq(result.failed_hunk_list.length(), 0)
}

///|
test "strict apply reports failed hunk on mismatch" {
  let patch = @parse.parse_patch(unified_diff)
  let result = @apply.apply_patch(["not matching"], patch)
  assert_eq(result.new_line_list.length(), 1)
  assert_eq(result.failed_hunk_list.length(), 2)
  assert_eq(result.conflict_hunk_num_list.length(), 2)
  assert_eq(result.conflict_hunk_num_list[0], 1)
  assert_eq(result.conflict_hunk_num_list[1], 2)
}
