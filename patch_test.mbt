///|
test "public facade exposes parser and applier" {
  let patch = @patch.parse_patch("")
  assert_eq(patch.diffs.length(), 0)
  let result = @patch.apply_patch([], patch)
  assert_eq(result.new_line_list.length(), 0)
}

///|
test "public facade parses unified diff" {
  let patch = @patch.parse_patch(
    (
      #|--- a
      #|+++ b
      #|@@ -1 +1 @@
      #|-old
      #|+new
      #|
    ),
  )
  assert_eq(patch.diffs.length(), 1)
  assert_eq(patch.diffs[0].changes.length(), 2)
  assert_true(patch.diffs[0].changes[0].old is Some(1))
  assert_true(patch.diffs[0].changes[1].new is Some(1))
}
