///|
test "default reverse facade uses fuzz two" {
  let patch = parse_patch("")
  let result = reverse_patch([], patch)
  assert_eq(result.fuzz, 2)
}
