///|
/// Parse patch text into a normalized patch object.
///
/// This package will host the whatthepatch-style parser implementation.
pub fn parse_patch(text : String) -> @model.Patch {
  { ..@model.empty_patch(text), diffs: parse_diffs(text) }
}

///|
/// Parse only the file diffs from patch text.
pub fn parse_diffs(text : String) -> Array[@model.Diff] {
  let lines = split_lines(text)
  let diffs : Array[@model.Diff] = []
  let mut i = 0
  while i < lines.length() {
    if lines[i].has_prefix("--- ") &&
      i + 1 < lines.length() &&
      lines[i + 1].has_prefix("+++ ") {
      let start = i
      let header = parse_unified_header(lines[i], lines[i + 1])
      i = i + 2
      let changes : Array[@model.Change] = []
      let mut hunk_index = 0
      let mut old_line = 0
      let mut new_line = 0
      while i < lines.length() {
        let line = lines[i]
        if line.has_prefix("--- ") &&
          i + 1 < lines.length() &&
          lines[i + 1].has_prefix("+++ ") {
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
      let diff_text = join_lines(slice_lines(lines, start, i))
      diffs.push({
        header: Some(header),
        changes,
        text: diff_text,
        hunks: @model.changes_to_hunks(changes),
      })
    } else {
      i = i + 1
    }
  }
  diffs
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
