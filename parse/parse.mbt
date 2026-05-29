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
    } else if is_unified_header_at(lines, i) {
      let (diff, next) = parse_unified_diff_at(lines, i, i, None)
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
  let header = {
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
      lines[i] == "---" ||
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
  }
  None
}

///|
fn is_unified_header_at(lines : Array[String], i : Int) -> Bool {
  i + 1 < lines.length() &&
  lines[i].has_prefix("--- ") &&
  lines[i + 1].has_prefix("+++ ")
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
