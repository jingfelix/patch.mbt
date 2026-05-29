///|
/// Parse patch text into a normalized patch object.
///
/// This package will host the whatthepatch-style parser implementation.
pub fn parse_patch(text : String) -> @model.Patch {
  let lines = split_lines(text)
  let diff_start = find_patch_body_start(lines)
  let metadata_lines = slice_lines(lines, 0, diff_start)
  let body = join_lines(slice_lines(lines, diff_start, lines.length()))
  {
    ..@model.empty_patch(text),
    sha: parse_sha(metadata_lines),
    author: parse_author(metadata_lines),
    date: parse_date(metadata_lines),
    subject: parse_subject(metadata_lines),
    message: parse_message(metadata_lines),
    diffs: parse_diffs(body),
  }
}

///|
/// Parse only the file diffs from patch text.
pub fn parse_diffs(text : String) -> Array[@model.Diff] {
  let lines = split_lines(text)
  let diffs : Array[@model.Diff] = []
  let mut i = 0
  while i < lines.length() {
    if lines[i].has_prefix("diff --git ") {
      let start = i
      let index_path = parse_git_index_path(lines[i])
      let block_end = find_next_git_block(lines, i + 1)
      match find_unified_header(lines, i + 1) {
        Some(header_pos) => {
          let (diff, next) = parse_unified_diff_at(
            lines, start, header_pos, index_path,
          )
          diffs.push(diff)
          i = next
        }
        None => {
          diffs.push(parse_git_metadata_diff_at(lines, start, block_end))
          i = block_end
        }
      }
    } else if lines[i].has_prefix("Index: ") {
      let start = i
      let index_path = Some(lines[i][7:].to_owned())
      match find_unified_header(lines, i + 1) {
        Some(header_pos) => {
          let (diff, next) = parse_unified_diff_at(
            lines, start, header_pos, index_path,
          )
          diffs.push(diff)
          i = next
        }
        None => i = i + 1
      }
    } else if is_context_header_at(lines, i) {
      let (diff, next) = parse_context_diff_at(lines, i)
      diffs.push(diff)
      i = next
    } else if is_unified_header_at(lines, i) {
      let (diff, next) = parse_unified_diff_at(lines, i, i, None)
      diffs.push(diff)
      i = next
    } else if is_normal_command_line(lines[i]) {
      let (diff, next) = parse_normal_diff_at(lines, i)
      diffs.push(diff)
      i = next
    } else {
      i = i + 1
    }
  }
  diffs
}

///|
fn parse_unified_diff_at(
  lines : Array[String],
  start : Int,
  header_pos : Int,
  index_path : String?,
) -> (@model.Diff, Int) {
  let header : @model.Header = {
    ..parse_unified_header(lines[header_pos], lines[header_pos + 1]),
    index_path,
  }
  let changes : Array[@model.Change] = []
  let mut i = header_pos + 2
  let mut hunk_index = 0
  let mut old_line = 0
  let mut new_line = 0
  while i < lines.length() {
    let line = lines[i]
    if line.has_prefix("diff --git ") || is_unified_header_at(lines, i) {
      break
    } else if line.has_prefix("@@ ") {
      match parse_hunk_header(line) {
        Some((old_start, _old_count, new_start, _new_count)) => {
          hunk_index = hunk_index + 1
          old_line = old_start
          new_line = new_start
        }
        None => ()
      }
    } else if hunk_index > 0 && line.has_prefix(" ") {
      changes.push(
        @model.Change::context(
          old_line,
          new_line,
          strip_first_char(line),
          hunk_index,
        ),
      )
      old_line = old_line + 1
      new_line = new_line + 1
    } else if hunk_index > 0 && line.has_prefix("-") {
      changes.push(
        @model.Change::delete(old_line, strip_first_char(line), hunk_index),
      )
      old_line = old_line + 1
    } else if hunk_index > 0 && line.has_prefix("+") {
      changes.push(
        @model.Change::insert(new_line, strip_first_char(line), hunk_index),
      )
      new_line = new_line + 1
    } else if line.has_prefix("\\ No newline at end of file") {
      ()
    }
    i = i + 1
  }
  (
    {
      header: Some(header),
      changes,
      text: join_lines(slice_lines(lines, start, i)),
      hunks: @model.changes_to_hunks(changes),
    },
    i,
  )
}

///|
fn parse_context_diff_at(
  lines : Array[String],
  start : Int,
) -> (@model.Diff, Int) {
  let (old_path, old_version) = parse_file_marker(lines[start], "*** ")
  let (new_path, new_version) = parse_file_marker(lines[start + 1], "--- ")
  let header : @model.Header = {
    index_path: None,
    old_path: Some(old_path),
    old_version,
    new_path: Some(new_path),
    new_version,
  }
  let changes : Array[@model.Change] = []
  let mut i = start + 2
  let mut hunk_index = 0
  while i < lines.length() {
    if starts_new_diff(lines, i) || is_context_header_at(lines, i) {
      break
    } else if lines[i] == "***************" {
      i = i + 1
    } else if is_context_old_hunk_header(lines[i]) {
      match parse_context_old_hunk_header(lines[i]) {
        Some(old_start) => {
          let old_entries_start = i + 1
          let mut new_header_pos = old_entries_start
          while new_header_pos < lines.length() &&
                !is_context_new_hunk_header(lines[new_header_pos]) {
            new_header_pos = new_header_pos + 1
          }
          if new_header_pos >= lines.length() {
            break
          }
          match parse_context_new_hunk_header(lines[new_header_pos]) {
            Some(new_start) => {
              let new_entries_start = new_header_pos + 1
              let mut next = new_entries_start
              while next < lines.length() &&
                    !is_context_hunk_boundary(lines, next) {
                next = next + 1
              }
              hunk_index = hunk_index + 1
              append_context_changes(
                changes,
                parse_context_entries(lines, old_entries_start, new_header_pos),
                old_start,
                parse_context_entries(lines, new_entries_start, next),
                new_start,
                hunk_index,
              )
              i = next
            }
            None => i = new_header_pos + 1
          }
        }
        None => i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  (
    {
      header: Some(header),
      changes,
      text: join_lines(slice_lines(lines, start, i)),
      hunks: @model.changes_to_hunks(changes),
    },
    i,
  )
}

///|
fn parse_normal_diff_at(
  lines : Array[String],
  start : Int,
) -> (@model.Diff, Int) {
  let changes : Array[@model.Change] = []
  let mut i = start
  let mut hunk_index = 0
  while i < lines.length() {
    match parse_normal_command(lines[i]) {
      Some((old_start, _old_end, op, new_start, _new_end)) => {
        hunk_index = hunk_index + 1
        i = i + 1
        if op == "c" {
          let mut old_line = old_start
          while i < lines.length() && lines[i].has_prefix("< ") {
            changes.push(
              @model.Change::delete(
                old_line,
                lines[i][2:].to_owned(),
                hunk_index,
              ),
            )
            old_line = old_line + 1
            i = i + 1
          }
          if i < lines.length() && lines[i] == "---" {
            i = i + 1
          }
          let mut new_line = new_start
          while i < lines.length() && lines[i].has_prefix("> ") {
            changes.push(
              @model.Change::insert(
                new_line,
                lines[i][2:].to_owned(),
                hunk_index,
              ),
            )
            new_line = new_line + 1
            i = i + 1
          }
        } else if op == "a" {
          let mut new_line = new_start
          while i < lines.length() && lines[i].has_prefix("> ") {
            changes.push(
              @model.Change::insert(
                new_line,
                lines[i][2:].to_owned(),
                hunk_index,
              ),
            )
            new_line = new_line + 1
            i = i + 1
          }
        } else {
          let mut old_line = old_start
          while i < lines.length() && lines[i].has_prefix("< ") {
            changes.push(
              @model.Change::delete(
                old_line,
                lines[i][2:].to_owned(),
                hunk_index,
              ),
            )
            old_line = old_line + 1
            i = i + 1
          }
        }
      }
      None => break
    }
  }
  (
    {
      header: None,
      changes,
      text: join_lines(slice_lines(lines, start, i)),
      hunks: @model.changes_to_hunks(changes),
    },
    i,
  )
}

///|
fn parse_git_metadata_diff_at(
  lines : Array[String],
  start : Int,
  end : Int,
) -> @model.Diff {
  let (old_path, new_path) = parse_git_paths(lines[start])
  let header : @model.Header = {
    index_path: parse_git_index_path(lines[start]),
    old_path,
    old_version: None,
    new_path,
    new_version: None,
  }
  {
    header: Some(header),
    changes: [],
    text: join_lines(slice_lines(lines, start, end)),
    hunks: [],
  }
}

///|
fn parse_unified_header(old_line : String, new_line : String) -> @model.Header {
  let (old_path, old_version) = parse_file_marker(old_line, "--- ")
  let (new_path, new_version) = parse_file_marker(new_line, "+++ ")
  {
    index_path: None,
    old_path: Some(old_path),
    old_version,
    new_path: Some(new_path),
    new_version,
  }
}

///|
fn find_patch_body_start(lines : Array[String]) -> Int {
  for i in 0..<lines.length() {
    if lines[i].has_prefix("diff --git ") ||
      lines[i].has_prefix("Index: ") ||
      is_normal_command_line(lines[i]) ||
      lines[i] == "---" ||
      is_context_header_at(lines, i) ||
      is_unified_header_at(lines, i) {
      return i
    }
  }
  lines.length()
}

///|
fn find_unified_header(lines : Array[String], start : Int) -> Int? {
  for i in start..<lines.length() {
    if is_unified_header_at(lines, i) {
      return Some(i)
    }
    if lines[i].has_prefix("diff --git ") {
      return None
    }
    if lines[i].has_prefix("Index: ") || is_context_header_at(lines, i) {
      return None
    }
  }
  None
}

///|
fn find_next_git_block(lines : Array[String], start : Int) -> Int {
  for i in start..<lines.length() {
    if lines[i].has_prefix("diff --git ") {
      return i
    }
  }
  lines.length()
}

///|
fn is_unified_header_at(lines : Array[String], i : Int) -> Bool {
  i + 1 < lines.length() &&
  lines[i].has_prefix("--- ") &&
  lines[i + 1].has_prefix("+++ ")
}

///|
fn starts_new_diff(lines : Array[String], i : Int) -> Bool {
  lines[i].has_prefix("diff --git ") ||
  lines[i].has_prefix("Index: ") ||
  is_unified_header_at(lines, i)
}

///|
fn is_context_header_at(lines : Array[String], i : Int) -> Bool {
  i + 1 < lines.length() &&
  lines[i].has_prefix("*** ") &&
  lines[i + 1].has_prefix("--- ") &&
  !is_context_old_hunk_header(lines[i])
}

///|
fn is_context_old_hunk_header(line : String) -> Bool {
  line.has_prefix("*** ") && line.has_suffix(" ****")
}

///|
fn is_context_new_hunk_header(line : String) -> Bool {
  line.has_prefix("--- ") && line.has_suffix(" ----")
}

///|
fn is_context_hunk_boundary(lines : Array[String], i : Int) -> Bool {
  lines[i] == "***************" ||
  starts_new_diff(lines, i) ||
  is_context_header_at(lines, i)
}

///|
fn parse_git_index_path(line : String) -> String? {
  match line.strip_prefix("diff --git ") {
    Some(rest) =>
      match rest.split_once(" ") {
        Some((old_path, _new_path)) =>
          Some(strip_git_prefix(old_path.to_owned()))
        None => None
      }
    None => None
  }
}

///|
fn parse_git_paths(line : String) -> (String?, String?) {
  match line.strip_prefix("diff --git ") {
    Some(rest) =>
      match rest.split_once(" ") {
        Some((old_path, new_path)) =>
          (Some(old_path.to_owned()), Some(new_path.to_owned()))
        None => (None, None)
      }
    None => (None, None)
  }
}

///|
fn strip_git_prefix(path : String) -> String {
  match path.strip_prefix("a/") {
    Some(rest) => rest.to_owned()
    None => path
  }
}

///|
fn parse_sha(lines : Array[String]) -> String? {
  if lines.length() == 0 {
    return None
  }
  let first = lines[0]
  if first.has_prefix("commit ") {
    second_token(first)
  } else if first.has_prefix("From ") {
    second_token(first)
  } else {
    None
  }
}

///|
fn parse_author(lines : Array[String]) -> String? {
  match find_prefixed_value(lines, "Author: ") {
    Some(author) => Some(author)
    None => find_prefixed_value(lines, "From: ")
  }
}

///|
fn parse_date(lines : Array[String]) -> String? {
  find_prefixed_value(lines, "Date: ")
}

///|
fn parse_subject(lines : Array[String]) -> String? {
  match find_prefixed_value(lines, "Subject: ") {
    Some(subject) => Some(subject)
    None => first_nonempty_after_date(lines)
  }
}

///|
fn parse_message(lines : Array[String]) -> String? {
  if lines.length() == 0 {
    None
  } else {
    Some(join_lines(lines))
  }
}

///|
fn find_prefixed_value(lines : Array[String], prefix : String) -> String? {
  for line in lines {
    match line.strip_prefix(prefix) {
      Some(rest) => return Some(rest.trim().to_owned())
      None => ()
    }
  }
  None
}

///|
fn first_nonempty_after_date(lines : Array[String]) -> String? {
  let mut seen_date = false
  for line in lines {
    if seen_date {
      let trimmed = line.trim()
      if trimmed != "" {
        return Some(trimmed.to_owned())
      }
    } else if line.has_prefix("Date: ") {
      seen_date = true
    }
  }
  None
}

///|
fn second_token(line : String) -> String? {
  match line.split_once(" ") {
    Some((_first, rest)) =>
      match rest.split_once(" ") {
        Some((token, _tail)) => Some(token.to_owned())
        None => Some(rest.to_owned())
      }
    None => None
  }
}

///|
fn parse_file_marker(line : String, prefix : String) -> (String, String?) {
  let payload = match line.strip_prefix(prefix) {
    Some(rest) => rest.to_owned()
    None => line
  }
  if payload.split_once("\t") is Some((path, version)) {
    (path.to_owned(), Some(version.to_owned()))
  } else {
    (payload, None)
  }
}

///|
fn parse_context_old_hunk_header(line : String) -> Int? {
  match line.strip_prefix("*** ") {
    Some(rest) =>
      match rest.strip_suffix(" ****") {
        Some(range) =>
          match parse_range(range) {
            Some((start, _count)) => Some(start)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn parse_context_new_hunk_header(line : String) -> Int? {
  match line.strip_prefix("--- ") {
    Some(rest) =>
      match rest.strip_suffix(" ----") {
        Some(range) =>
          match parse_range(range) {
            Some((start, _count)) => Some(start)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn parse_context_entries(
  lines : Array[String],
  start : Int,
  end : Int,
) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  for i in start..<end {
    let line = lines[i]
    if line.has_prefix("  ") {
      entries.push((" ", line[2:].to_owned()))
    } else if line.has_prefix("! ") {
      entries.push(("!", line[2:].to_owned()))
    } else if line.has_prefix("- ") {
      entries.push(("-", line[2:].to_owned()))
    } else if line.has_prefix("+ ") {
      entries.push(("+", line[2:].to_owned()))
    }
  }
  entries
}

///|
fn append_context_changes(
  changes : Array[@model.Change],
  old_entries : Array[(String, String)],
  old_start : Int,
  new_entries : Array[(String, String)],
  new_start : Int,
  hunk_index : Int,
) -> Unit {
  let mut old_i = 0
  let mut new_i = 0
  let mut old_line = old_start
  let mut new_line = new_start
  while old_i < old_entries.length() || new_i < new_entries.length() {
    if old_i < old_entries.length() &&
      new_i < new_entries.length() &&
      old_entries[old_i].0 == " " &&
      new_entries[new_i].0 == " " {
      changes.push(
        @model.Change::context(
          old_line,
          new_line,
          old_entries[old_i].1,
          hunk_index,
        ),
      )
      old_i = old_i + 1
      new_i = new_i + 1
      old_line = old_line + 1
      new_line = new_line + 1
    } else {
      let mut consumed = false
      while old_i < old_entries.length() && old_entries[old_i].0 != " " {
        changes.push(
          @model.Change::delete(old_line, old_entries[old_i].1, hunk_index),
        )
        old_i = old_i + 1
        old_line = old_line + 1
        consumed = true
      }
      while new_i < new_entries.length() && new_entries[new_i].0 != " " {
        changes.push(
          @model.Change::insert(new_line, new_entries[new_i].1, hunk_index),
        )
        new_i = new_i + 1
        new_line = new_line + 1
        consumed = true
      }
      if !consumed {
        if old_i < old_entries.length() {
          changes.push(
            @model.Change::delete(old_line, old_entries[old_i].1, hunk_index),
          )
          old_i = old_i + 1
          old_line = old_line + 1
        }
        if new_i < new_entries.length() {
          changes.push(
            @model.Change::insert(new_line, new_entries[new_i].1, hunk_index),
          )
          new_i = new_i + 1
          new_line = new_line + 1
        }
      }
    }
  }
}

///|
fn is_normal_command_line(line : String) -> Bool {
  parse_normal_command(line) is Some(_)
}

///|
fn parse_normal_command(line : String) -> (Int, Int, String, Int, Int)? {
  match parse_normal_command_with_op(line, "a") {
    Some(command) => Some(command)
    None =>
      match parse_normal_command_with_op(line, "c") {
        Some(command) => Some(command)
        None => parse_normal_command_with_op(line, "d")
      }
  }
}

///|
fn parse_normal_command_with_op(
  line : String,
  op : String,
) -> (Int, Int, String, Int, Int)? {
  match line.split_once(op) {
    Some((old_range, new_range)) =>
      match (parse_range(old_range), parse_range(new_range)) {
        (Some((old_start, old_count)), Some((new_start, new_count))) =>
          Some(
            (
              old_start,
              old_start + old_count - 1,
              op,
              new_start,
              new_start + new_count - 1,
            ),
          )
        _ => None
      }
    None => None
  }
}

///|
fn parse_hunk_header(line : String) -> (Int, Int, Int, Int)? {
  match line.strip_prefix("@@ -") {
    Some(rest) =>
      match rest.split_once(" @@") {
        Some((ranges, _section)) =>
          match ranges.split_once(" +") {
            Some((old_range, new_range)) =>
              match (parse_range(old_range), parse_range(new_range)) {
                (Some((old_start, old_count)), Some((new_start, new_count))) =>
                  Some((old_start, old_count, new_start, new_count))
                _ => None
              }
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn parse_range(range : StringView) -> (Int, Int)? {
  if range.split_once(",") is Some((start, count)) {
    match (parse_int(start), parse_int(count)) {
      (Some(start), Some(count)) => Some((start, count))
      _ => None
    }
  } else {
    match parse_int(range) {
      Some(start) => Some((start, 1))
      None => None
    }
  }
}

///|
fn parse_int(text : StringView) -> Int? {
  try @string.parse_int(text) |> Some catch {
    _ => None
  }
}

///|
fn split_lines(text : String) -> Array[String] {
  let parts = text.split("\n").map(line => line.to_owned()).collect()
  if parts.length() > 0 && parts[parts.length() - 1] == "" {
    slice_lines(parts, 0, parts.length() - 1)
  } else {
    parts
  }
}

///|
fn slice_lines(lines : Array[String], start : Int, end : Int) -> Array[String] {
  let result : Array[String] = []
  for i in start..<end {
    result.push(lines[i])
  }
  result
}

///|
fn join_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    ""
  } else {
    lines.join("\n") + "\n"
  }
}

///|
fn strip_first_char(line : String) -> String {
  line[1:].to_owned()
}
