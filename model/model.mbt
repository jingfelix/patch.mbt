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
} derive(Eq, @debug.Debug)

///|
/// A parsed hunk split into leading context, changed body, and trailing context.
pub(all) struct Hunk {
  index : Int
  context : Array[Change]
  middle : Array[Change]
  post : Array[Change]
  all_ : Array[Change]
} derive(Eq, @debug.Debug)

///|
/// One file diff inside a patch.
pub(all) struct Diff {
  header : Header?
  changes : Array[Change]
  text : String
  hunks : Array[Hunk]
} derive(Eq, @debug.Debug)

///|
/// Top-level patch object exposed by the package API.
pub(all) struct Patch {
  sha : String?
  author : String?
  date : String?
  subject : String?
  message : String?
  diffs : Array[Diff]
  text : String
} derive(Eq, @debug.Debug)

///|
/// One target line tracked during patch application.
pub(all) struct Line {
  index : Int
  content : String
  changed : Bool
  status : Bool
  flag : Bool
  hunk : Int?
} derive(Eq, @debug.Debug)

///|
/// One successfully positioned hunk.
pub(all) struct AppliedHunk {
  index : Int
  offset : Int
  fuzz : Int
} derive(Eq, @debug.Debug)

///|
/// Result of applying a patch to a target line array.
pub(all) struct ApplyResult {
  new_line_list : Array[Line]
  applied_hunks : Array[AppliedHunk]
  conflict_hunk_num_list : Array[Int]
  failed_hunk_list : Array[Hunk]
} derive(Eq, @debug.Debug)

///|
/// Structured error categories planned for parser and applier failures.
pub(all) enum PatchError {
  ParseError(String)
  ApplyError(String)
} derive(Eq, @debug.Debug)

///|
pub fn Change::context(
  old : Int,
  new : Int,
  line : String,
  hunk : Int,
) -> Change {
  { old: Some(old), new: Some(new), line: Some(line), hunk }
}

///|
pub fn Change::insert(new : Int, line : String, hunk : Int) -> Change {
  { old: None, new: Some(new), line: Some(line), hunk }
}

///|
pub fn Change::delete(old : Int, line : String, hunk : Int) -> Change {
  { old: Some(old), new: None, line: Some(line), hunk }
}

///|
pub fn Change::is_context(self : Change) -> Bool {
  self.old is Some(_) && self.new is Some(_)
}

///|
pub fn Line::new(index : Int, content : String) -> Line {
  { index, content, changed: false, status: true, flag: false, hunk: None }
}

///|
pub fn lines_from_strings(lines : Array[String]) -> Array[Line] {
  let result : Array[Line] = []
  for i in 0..<lines.length() {
    result.push(Line::new(i, lines[i]))
  }
  result
}

///|
pub fn empty_apply_result(lines : Array[String]) -> ApplyResult {
  {
    new_line_list: lines_from_strings(lines),
    applied_hunks: [],
    conflict_hunk_num_list: [],
    failed_hunk_list: [],
  }
}

///|
pub fn empty_patch(text : String) -> Patch {
  {
    sha: None,
    author: None,
    date: None,
    subject: None,
    message: None,
    diffs: [],
    text,
  }
}

///|
pub fn changes_to_hunks(changes : Array[Change]) -> Array[Hunk] {
  let hunks : Array[Hunk] = []
  let mut current : Array[Change] = []
  let mut current_index = 0
  for change in changes {
    if current.length() == 0 {
      current_index = change.hunk
      current.push(change)
    } else if change.hunk == current_index {
      current.push(change)
    } else {
      hunks.push(build_hunk(current_index, current))
      current = [change]
      current_index = change.hunk
    }
  }
  if current.length() > 0 {
    hunks.push(build_hunk(current_index, current))
  }
  hunks
}

///|
fn build_hunk(index : Int, all : Array[Change]) -> Hunk {
  let mut middle_start = 0
  while middle_start < all.length() && all[middle_start].is_context() {
    middle_start = middle_start + 1
  }
  let mut middle_end = all.length()
  while middle_end > middle_start && all[middle_end - 1].is_context() {
    middle_end = middle_end - 1
  }
  {
    index,
    context: copy_range(all, 0, middle_start),
    middle: copy_range(all, middle_start, middle_end),
    post: copy_range(all, middle_end, all.length()),
    all_: all,
  }
}

///|
fn copy_range(changes : Array[Change], start : Int, end : Int) -> Array[Change] {
  let result : Array[Change] = []
  for i in start..<end {
    result.push(changes[i])
  }
  result
}
