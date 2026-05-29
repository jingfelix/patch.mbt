///|
/// Options controlling patch application.
pub(all) struct ApplyOptions {
  reverse : Bool
  fuzz : Int
} derive(Eq, @debug.Debug)

///|
pub fn ApplyOptions::default() -> ApplyOptions {
  { reverse: false, fuzz: 2 }
}

///|
pub fn ApplyOptions::reverse(fuzz? : Int = 2) -> ApplyOptions {
  { reverse: true, fuzz }
}

///|
/// Apply all diffs in a patch. The implementation will support reverse and fuzz.
pub fn apply_patch(
  lines : Array[String],
  _patch : @model.Patch,
  options? : ApplyOptions = ApplyOptions::default(),
) -> @model.ApplyResult {
  let result = @model.empty_apply_result(lines)
  if options.reverse || options.fuzz != 2 {
    result
  } else {
    result
  }
}

///|
/// Apply a patch in reverse with a GNU patch-style default fuzz of 2.
pub fn reverse_patch(
  lines : Array[String],
  patch : @model.Patch,
  fuzz? : Int = 2,
) -> @model.ApplyResult {
  apply_patch(lines, patch, options=ApplyOptions::reverse(fuzz~))
}
