///|
/// Diff line classification after parsing patch syntax.
pub(all) enum LineKind {
  Context
  Insert
  Delete
} derive(Eq, @debug.Debug)

///|
/// File-level header parsed from a unified, Git, SVN, CVS, or context diff.
pub(all) struct Header {
  index_path : String?
  old_path : String?
  old_version : String?
  new_path : String?
  new_version : String?
} derive(Eq, @debug.Debug)

///|
/// A normalized line-level change, following whatthepatch's old/new numbering.
pub(all) struct Change {
  old : Int?
  new : Int?
  line : String?
  hunk : Int
  kind : LineKind
} derive(Eq, @debug.Debug)

///|
/// A parsed hunk with original header ranges and normalized changes.
pub(all) struct Hunk {
  index : Int
  old_start : Int
  old_count : Int
  new_start : Int
  new_count : Int
  changes : Array[Change]
} derive(Eq, @debug.Debug)

///|
/// One file diff inside a patch.
pub(all) struct Diff {
  header : Header?
  hunks : Array[Hunk]
  changes : Array[Change]
  text : String
} derive(Eq, @debug.Debug)

///|
/// Optional metadata parsed from git log or format-patch text.
pub(all) struct PatchMetadata {
  sha : String?
  author : String?
  date : String?
  subject : String?
  message : String?
} derive(Eq, @debug.Debug)

///|
/// Top-level patch object exposed by the package API.
pub(all) struct Patch {
  metadata : PatchMetadata
  diffs : Array[Diff]
  text : String
} derive(Eq, @debug.Debug)

///|
/// Structured error categories planned for parser and applier failures.
pub(all) enum PatchError {
  ParseError(String)
  ApplyError(String)
} derive(Eq, @debug.Debug)

///|
pub fn empty_metadata() -> PatchMetadata {
  { sha: None, author: None, date: None, subject: None, message: None }
}

///|
pub fn empty_patch(text : String) -> Patch {
  { metadata: empty_metadata(), diffs: [], text }
}
