///|
/// Options controlling patch application.
pub(all) struct ApplyOptions {
  reverse : Bool
  fuzz : Int
} derive(Eq, @debug.Debug)

///|
/// One successfully positioned hunk.
pub(all) struct AppliedHunk {
  index : Int
  offset : Int
  fuzz : Int
} derive(Eq, @debug.Debug)

///|
/// Result of applying a patch to a line array.
pub(all) struct ApplyResult {
  lines : Array[String]
  applied_hunks : Array[AppliedHunk]
  rejected_hunks : Array[@model.Hunk]
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
) -> ApplyResult {
  {
    lines,
    applied_hunks: [],
    rejected_hunks: [],
    reverse: options.reverse,
    fuzz: options.fuzz,
  }
}

///|
/// Apply a patch in reverse with a GNU patch-style default fuzz of 2.
pub fn reverse_patch(
  lines : Array[String],
  patch : @model.Patch,
  fuzz? : Int = 2,
) -> ApplyResult {
  apply_patch(lines, patch, options=ApplyOptions::reverse(fuzz~))
}
