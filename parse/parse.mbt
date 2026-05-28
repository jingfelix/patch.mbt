///|
/// Parse patch text into a normalized patch object.
///
/// This package will host the whatthepatch-style parser implementation.
pub fn parse_patch(text : String) -> @model.Patch {
  @model.empty_patch(text)
}

///|
/// Parse only the file diffs from patch text.
pub fn parse_diffs(_text : String) -> Array[@model.Diff] {
  []
}
