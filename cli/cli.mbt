///|
pub fn run() -> Unit {
  let matches = command().parse() catch { _ => return }
  dispatch(matches)
}

///|
pub fn command() -> @argparse.Command {
  @argparse.Command(
    "patch",
    about="Parse and apply unified patches.",
    version="0.1.0",
    arg_required_else_help=true,
    subcommand_required=true,
    subcommands=[
      @argparse.Command(
        "apply",
        about="Apply a patch file to a target tree.",
        flags=[
          @argparse.FlagArg(
            "reverse",
            short='R',
            about="Apply the patch in reverse.",
          ),
        ],
        options=[
          @argparse.OptionArg(
            "fuzz",
            short='F',
            default_values=["2"],
            about="Maximum context lines to ignore while matching hunks.",
          ),
          @argparse.OptionArg(
            "source",
            short='s',
            about="Source file to patch. The patched content is written to stdout.",
          ),
          @argparse.OptionArg(
            "target",
            short='d',
            about="Target directory to update in place.",
          ),
        ],
        positionals=[
          @argparse.PositionArg("patch-file", about="Patch file to apply."),
        ],
      ),
      @argparse.Command("show", about="Parse and summarize a patch file.", positionals=[
        @argparse.PositionArg("patch-file", about="Patch file to inspect."),
      ]),
    ],
  )
}

///|
pub fn color_added(text : String) -> String {
  @style_print.styl(text).color(@style_print.Color::Green).to_ansi()
}

///|
pub fn color_removed(text : String) -> String {
  @style_print.styl(text).color(@style_print.Color::Red).to_ansi()
}

///|
pub fn color_path(text : String) -> String {
  @style_print.styl(text).bold().to_ansi()
}

///|
pub fn show_text(text : String) -> String {
  summarize_patch(@parse.parse_patch(text))
}

///|
pub fn apply_text(
  patch_text : String,
  source_text : String,
  reverse? : Bool = false,
  fuzz? : Int = 2,
) -> String {
  let (ok, text, _failed_hunks) = apply_text_result(
    patch_text,
    source_text,
    reverse~,
    fuzz~,
  )
  if ok {
    text
  } else {
    text
  }
}

///|
pub fn apply_to_target(
  patch_text : String,
  target_dir : String,
  reverse? : Bool = false,
  fuzz? : Int = 2,
) -> String {
  let patch = @parse.parse_patch(patch_text)
  let mut applied_files = 0
  let mut created_files = 0
  let mut deleted_files = 0
  let mut skipped_files = 0
  let mut failed_hunks = 0
  for diff in patch.diffs {
    if diff.hunks.length() == 0 {
      skipped_files = skipped_files + 1
    } else {
      match target_path(target_dir, diff, reverse) {
        Some(path) =>
          try {
            let (ok, text, failed) = apply_diff_to_text(
              diff,
              read_target_source(path, diff, reverse),
              reverse~,
              fuzz~,
            )
            if ok {
              if is_deleted_file(diff, reverse) {
                @fs.remove_file(path)
                deleted_files = deleted_files + 1
              } else {
                @fs.write_string_to_file(path, ensure_trailing_newline(text))
                if is_new_file(diff, reverse) {
                  created_files = created_files + 1
                } else {
                  applied_files = applied_files + 1
                }
              }
            } else {
              failed_hunks = failed_hunks + failed
            }
          } catch {
            _ => failed_hunks = failed_hunks + diff.hunks.length()
          }
        None => failed_hunks = failed_hunks + diff.hunks.length()
      }
    }
  }
  "applied \{applied_files} file(s), created \{created_files} file(s), deleted \{deleted_files} file(s), skipped \{skipped_files} file(s), failed \{failed_hunks} hunk(s)"
}

///|
fn apply_text_result(
  patch_text : String,
  source_text : String,
  reverse~ : Bool,
  fuzz~ : Int,
) -> (Bool, String, Int) {
  let patch = @parse.parse_patch(patch_text)
  let result = @apply.apply_patch(split_lines(source_text), patch, options={
    reverse,
    fuzz,
  })
  if result.failed_hunk_list.length() > 0 {
    (
      false,
      "error: failed to apply \{result.failed_hunk_list.length()} hunk(s)",
      result.failed_hunk_list.length(),
    )
  } else {
    (true, join_lines(result.new_line_list.map(line => line.content)), 0)
  }
}

///|
fn dispatch(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("apply", apply)) => dispatch_apply(apply)
    Some(("show", show)) =>
      match first_value(show, "patch-file") {
        Some(path) =>
          println(show_text(@fs.read_file_to_string(path))) catch {
            _ =>
              println(
                color_removed("error: failed to read patch file: \{path}"),
              )
          }
        None => println(color_removed("error: missing patch file"))
      }
    _ => println(color_removed("unknown command"))
  }
}

///|
fn dispatch_apply(matches : @argparse.Matches) -> Unit {
  match first_value(matches, "patch-file") {
    Some(patch_path) =>
      println(dispatch_apply_text(matches, @fs.read_file_to_string(patch_path))) catch {
        _ =>
          println(color_removed("error: failed to read patch or source file"))
      }
    None => println(color_removed("error: missing patch file"))
  }
}

///|
fn dispatch_apply_text(
  matches : @argparse.Matches,
  patch_text : String,
) -> String {
  let reverse = flag_enabled(matches, "reverse")
  let fuzz = parse_fuzz(matches)
  match (first_value(matches, "source"), first_value(matches, "target")) {
    (Some(source_path), None) =>
      apply_text(
        patch_text,
        @fs.read_file_to_string(source_path),
        reverse~,
        fuzz~,
      ) catch {
        _ => "error: failed to read source file"
      }
    (None, Some(target_dir)) =>
      apply_to_target(patch_text, target_dir, reverse~, fuzz~)
    (Some(_), Some(_)) => "error: choose either --source or --target"
    (None, None) => "error: missing --source or --target"
  }
}

///|
fn summarize_patch(patch : @model.Patch) -> String {
  let lines : Array[String] = ["Patch summary"]
  push_optional(lines, "sha", patch.sha)
  push_optional(lines, "author", patch.author)
  push_optional(lines, "date", patch.date)
  push_optional(lines, "subject", patch.subject)
  lines.push("files: \{patch.diffs.length()}")
  for diff in patch.diffs {
    lines.push(
      "  \{diff_path(diff)}: \{hunk_count_text(diff.hunks.length())}, +\{added_count(diff.changes)} -\{removed_count(diff.changes)}",
    )
  }
  lines.join("\n")
}

///|
fn push_optional(
  lines : Array[String],
  label : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) => lines.push("\{label}: \{text}")
    None => ()
  }
}

///|
fn apply_diff_to_text(
  diff : @model.Diff,
  source_text : String,
  reverse~ : Bool,
  fuzz~ : Int,
) -> (Bool, String, Int) {
  let patch : @model.Patch = { ..@model.empty_patch(""), diffs: [diff] }
  let result = @apply.apply_patch(split_lines(source_text), patch, options={
    reverse,
    fuzz,
  })
  if result.failed_hunk_list.length() > 0 {
    (false, "", result.failed_hunk_list.length())
  } else {
    (true, join_lines(result.new_line_list.map(line => line.content)), 0)
  }
}

///|
fn target_path(
  target_dir : String,
  diff : @model.Diff,
  reverse : Bool,
) -> String? {
  match patch_file_path(diff, reverse) {
    Some(path) =>
      if is_safe_relative_path(path) {
        Some(join_path(target_dir, path))
      } else {
        None
      }
    None => None
  }
}

///|
fn read_target_source(
  path : String,
  diff : @model.Diff,
  reverse : Bool,
) -> String raise {
  if is_new_file(diff, reverse) {
    ""
  } else if is_deleted_file(diff, reverse) && reverse {
    ""
  } else {
    @fs.read_file_to_string(path)
  }
}

///|
fn is_new_file(diff : @model.Diff, reverse : Bool) -> Bool {
  match diff.header {
    Some(header) =>
      if reverse {
        header.new_path is Some("/dev/null")
      } else {
        header.old_path is Some("/dev/null")
      }
    None => false
  }
}

///|
fn is_deleted_file(diff : @model.Diff, reverse : Bool) -> Bool {
  match diff.header {
    Some(header) =>
      if reverse {
        header.old_path is Some("/dev/null")
      } else {
        header.new_path is Some("/dev/null")
      }
    None => false
  }
}

///|
fn patch_file_path(diff : @model.Diff, reverse : Bool) -> String? {
  match diff.header {
    Some(header) =>
      match header.index_path {
        Some(path) =>
          if is_new_file(diff, reverse) {
            normalize_optional_patch_path(header.new_path)
          } else if is_deleted_file(diff, reverse) {
            normalize_optional_patch_path(header.old_path)
          } else {
            normalize_patch_path(path)
          }
        None =>
          if reverse {
            if header.new_path is Some("/dev/null") {
              normalize_optional_patch_path(header.old_path)
            } else {
              normalize_optional_patch_path(header.new_path)
            }
          } else if is_new_file(diff, reverse) {
            normalize_optional_patch_path(header.new_path)
          } else if is_deleted_file(diff, reverse) {
            normalize_optional_patch_path(header.old_path)
          } else {
            normalize_optional_patch_path(header.old_path)
          }
      }
    None => None
  }
}

///|
fn normalize_optional_patch_path(path : String?) -> String? {
  match path {
    Some(path) => normalize_patch_path(path)
    None => None
  }
}

///|
fn normalize_patch_path(path : String) -> String? {
  if path == "/dev/null" {
    None
  } else {
    match path.strip_prefix("a/") {
      Some(rest) => Some(rest.to_owned())
      None =>
        match path.strip_prefix("b/") {
          Some(rest) => Some(rest.to_owned())
          None => Some(path)
        }
    }
  }
}

///|
fn is_safe_relative_path(path : String) -> Bool {
  path != "" &&
  !path.has_prefix("/") &&
  path != ".." &&
  !path.has_prefix("../") &&
  !path.contains("/../")
}

///|
fn join_path(dir : String, path : String) -> String {
  if dir == "" || dir == "." {
    path
  } else if dir.has_suffix("/") {
    dir + path
  } else {
    dir + "/" + path
  }
}

///|
fn ensure_trailing_newline(text : String) -> String {
  if text == "" || text.has_suffix("\n") {
    text
  } else {
    text + "\n"
  }
}

///|
fn first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => if values.length() > 0 { Some(values[0]) } else { None }
    None => None
  }
}

///|
fn flag_enabled(matches : @argparse.Matches, name : String) -> Bool {
  match matches.flags.get(name) {
    Some(enabled) => enabled
    None => false
  }
}

///|
fn parse_fuzz(matches : @argparse.Matches) -> Int {
  match first_value(matches, "fuzz") {
    Some(text) => @string.parse_int(text) catch { _ => 2 }
    None => 2
  }
}

///|
fn diff_path(diff : @model.Diff) -> String {
  match diff.header {
    Some(header) =>
      match header.index_path {
        Some(path) => path
        None =>
          match header.new_path {
            Some(path) => path
            None =>
              match header.old_path {
                Some(path) => path
                None => "(unknown)"
              }
          }
      }
    None => "(unknown)"
  }
}

///|
fn hunk_count_text(count : Int) -> String {
  if count == 1 {
    "1 hunk"
  } else {
    "\{count} hunks"
  }
}

///|
fn added_count(changes : Array[@model.Change]) -> Int {
  let mut count = 0
  for change in changes {
    if change.old is None && change.new is Some(_) {
      count = count + 1
    }
  }
  count
}

///|
fn removed_count(changes : Array[@model.Change]) -> Int {
  let mut count = 0
  for change in changes {
    if change.old is Some(_) && change.new is None {
      count = count + 1
    }
  }
  count
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
fn join_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    ""
  } else {
    lines.join("\n")
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
