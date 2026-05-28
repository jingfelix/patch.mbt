///|
/// Parse patch text into the public patch model.
pub fn parse_patch(text : String) -> @model.Patch {
  @parse.parse_patch(text)
}

///|
/// Apply a parsed patch to a line array.
pub fn apply_patch(
  lines : Array[String],
  patch : @model.Patch,
  options? : @apply.ApplyOptions = @apply.ApplyOptions::default(),
) -> @apply.ApplyResult {
  @apply.apply_patch(lines, patch, options~)
}

///|
/// Apply a parsed patch in reverse to a line array.
pub fn reverse_patch(
  lines : Array[String],
  patch : @model.Patch,
  fuzz? : Int = 2,
) -> @apply.ApplyResult {
  @apply.reverse_patch(lines, patch, fuzz~)
}
