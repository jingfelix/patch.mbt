///|
test "integration scaffold parses then applies" {
  let parsed = @patch.parse_patch("")
  let applied = @patch.apply_patch([], parsed)
  assert_eq(applied.new_line_list.length(), 0)
  assert_eq(applied.failed_hunk_list.length(), 0)
}
