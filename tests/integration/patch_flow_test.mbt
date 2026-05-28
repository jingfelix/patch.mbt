///|
test "integration scaffold parses then applies" {
  let parsed = @patch.parse_patch("")
  let applied = @patch.apply_patch([], parsed)
  assert_eq(applied.lines.length(), 0)
  assert_eq(applied.reverse, false)
  assert_eq(applied.fuzz, 2)
}
