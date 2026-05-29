///|
test "public facade exposes parser and applier" {
  let patch = @patch.parse_patch("")
  assert_eq(patch.diffs.length(), 0)
  let result = @patch.apply_patch([], patch)
  assert_eq(result.new_line_list.length(), 0)
}
