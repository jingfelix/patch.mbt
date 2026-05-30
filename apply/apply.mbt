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
/// Apply all diffs in a patch.
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
      match apply_hunk(target, changes, offset, options.fuzz) {
        Some((new_target, applied_offset, applied_fuzz)) => {
          offset = applied_offset +
            new_lines(changes).length() -
            old_lines(changes).length()
          target = new_target
          applied_hunks.push({
            index: hunk.index,
            offset: applied_offset,
            fuzz: applied_fuzz,
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
  max_fuzz : Int,
) -> (Array[String], Int, Int)? {
  match hunk_position(changes) {
    Some(base_pos) => {
      let leading_context = leading_context_count(changes)
      let trailing_context = trailing_context_count(changes)
      let max_fuzz = max_int(0, max_fuzz)
      for fuzz in 0..<(max_fuzz + 1) {
        let trim_start = min_int(fuzz, leading_context)
        let trim_end = min_int(fuzz, trailing_context)
        let candidate = trim_changes(changes, trim_start, trim_end)
        match
          find_match_pos(target, candidate, base_pos + offset + trim_start) {
          Some(pos) => {
            let replacement = new_lines(candidate)
            let new_target = replace_range(
              target,
              pos,
              old_line_count(candidate),
              replacement,
            )
            let applied_offset = pos - trim_start - base_pos
            return Some((new_target, applied_offset, fuzz))
          }
          None => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn hunk_position(changes : Array[@model.Change]) -> Int? {
  for change in changes {
    if change.old is Some(old) {
      return Some(max_int(0, old - 1))
    }
  }
  for change in changes {
    if change.new is Some(new_) {
      return Some(max_int(0, new_ - 1))
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
fn find_match_pos(
  target : Array[String],
  changes : Array[@model.Change],
  expected_pos : Int,
) -> Int? {
  if changes.length() == 0 {
    return None
  }
  if matches_old_lines(target, expected_pos, changes) {
    return Some(expected_pos)
  }
  let old_count = old_line_count(changes)
  if old_count == 0 {
    if expected_pos >= 0 && expected_pos <= target.length() {
      Some(expected_pos)
    } else {
      None
    }
  } else if old_count > target.length() {
    None
  } else {
    let mut best : Int? = None
    let end = target.length() - old_count + 1
    for pos in 0..<end {
      if matches_old_lines(target, pos, changes) {
        match best {
          Some(best_pos) =>
            if distance(pos, expected_pos) < distance(best_pos, expected_pos) {
              best = Some(pos)
            }
          None => best = Some(pos)
        }
      }
    }
    best
  }
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

///|
fn trim_changes(
  changes : Array[@model.Change],
  trim_start : Int,
  trim_end : Int,
) -> Array[@model.Change] {
  let result : Array[@model.Change] = []
  let end = changes.length() - trim_end
  if trim_start >= end {
    return result
  }
  for i in trim_start..<end {
    result.push(changes[i])
  }
  result
}

///|
fn leading_context_count(changes : Array[@model.Change]) -> Int {
  let mut count = 0
  while count < changes.length() && changes[count].is_context() {
    count = count + 1
  }
  count
}

///|
fn trailing_context_count(changes : Array[@model.Change]) -> Int {
  let mut count = 0
  while count < changes.length() &&
        changes[changes.length() - count - 1].is_context() {
    count = count + 1
  }
  count
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn distance(a : Int, b : Int) -> Int {
  if a > b {
    a - b
  } else {
    b - a
  }
}
