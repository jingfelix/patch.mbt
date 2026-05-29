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
  patch : @model.Patch,
  options? : ApplyOptions = ApplyOptions::default(),
) -> @model.ApplyResult {
  let mut target = lines.copy()
  let mut offset = 0
  let applied_hunks : Array[@model.AppliedHunk] = []
  let failed_hunks : Array[@model.Hunk] = []
  for diff in patch.diffs {
    for hunk in diff.hunks {
      let changes = if options.reverse {
        reverse_changes(hunk.all_)
      } else {
        hunk.all_
      }
      match apply_hunk(target, changes, offset) {
        Some(new_target) => {
          let applied_offset = offset
          offset = offset +
            new_lines(changes).length() -
            old_lines(changes).length()
          target = new_target
          applied_hunks.push({
            index: hunk.index,
            offset: applied_offset,
            fuzz: 0,
          })
        }
        None => failed_hunks.push(hunk)
      }
    }
  }
  {
    new_line_list: @model.lines_from_strings(target),
    applied_hunks,
    conflict_hunk_num_list: failed_hunks.map(hunk => hunk.index),
    failed_hunk_list: failed_hunks,
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

///|
fn apply_hunk(
  target : Array[String],
  changes : Array[@model.Change],
  offset : Int,
) -> Array[String]? {
  match hunk_position(changes) {
    Some(base_pos) => {
      let pos = base_pos + offset
      if matches_old_lines(target, pos, changes) {
        let replacement = new_lines(changes)
        Some(replace_range(target, pos, old_line_count(changes), replacement))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn hunk_position(changes : Array[@model.Change]) -> Int? {
  for change in changes {
    if change.old is Some(old) {
      return Some(old - 1)
    }
  }
  for change in changes {
    if change.new is Some(new_) {
      return Some(new_ - 1)
    }
  }
  None
}

///|
fn matches_old_lines(
  target : Array[String],
  pos : Int,
  changes : Array[@model.Change],
) -> Bool {
  let old_lines = old_lines(changes)
  if pos < 0 || pos + old_lines.length() > target.length() {
    return false
  }
  for i in 0..<old_lines.length() {
    if target[pos + i] != old_lines[i] {
      return false
    }
  }
  true
}

///|
fn old_line_count(changes : Array[@model.Change]) -> Int {
  old_lines(changes).length()
}

///|
fn old_lines(changes : Array[@model.Change]) -> Array[String] {
  let lines : Array[String] = []
  for change in changes {
    if change.old is Some(_) && change.line is Some(line) {
      lines.push(line)
    }
  }
  lines
}

///|
fn new_lines(changes : Array[@model.Change]) -> Array[String] {
  let lines : Array[String] = []
  for change in changes {
    if change.new is Some(_) && change.line is Some(line) {
      lines.push(line)
    }
  }
  lines
}

///|
fn replace_range(
  target : Array[String],
  pos : Int,
  old_count : Int,
  replacement : Array[String],
) -> Array[String] {
  let result : Array[String] = []
  for i in 0..<pos {
    result.push(target[i])
  }
  for line in replacement {
    result.push(line)
  }
  let suffix_start = pos + old_count
  for i in suffix_start..<target.length() {
    result.push(target[i])
  }
  result
}

///|
fn reverse_changes(changes : Array[@model.Change]) -> Array[@model.Change] {
  changes.map(change => { ..change, old: change.new, new: change.old })
}
