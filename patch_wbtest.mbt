///|
test "default reverse facade uses fuzz two" {
  let patch = parse_patch("")
  let result = reverse_patch([], patch)
  assert_eq(result.new_line_list.length(), 0)
  assert_eq(result.failed_hunk_list.length(), 0)
}
