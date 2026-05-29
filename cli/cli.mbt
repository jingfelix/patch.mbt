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
            required=true,
            about="Source file to patch. The patched content is written to stdout.",
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
  let patch = @parse.parse_patch(patch_text)
  let result = @apply.apply_patch(split_lines(source_text), patch, options={
    reverse,
    fuzz,
  })
  if result.failed_hunk_list.length() > 0 {
    "error: failed to apply \{result.failed_hunk_list.length()} hunk(s)"
  } else {
    join_lines(result.new_line_list.map(line => line.content))
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
  match (first_value(matches, "patch-file"), first_value(matches, "source")) {
    (Some(patch_path), Some(source_path)) =>
      println(
        apply_text(
          @fs.read_file_to_string(patch_path),
          @fs.read_file_to_string(source_path),
          reverse=flag_enabled(matches, "reverse"),
          fuzz=parse_fuzz(matches),
        ),
      ) catch {
        _ =>
          println(color_removed("error: failed to read patch or source file"))
      }
    (_, _) => println(color_removed("error: missing patch or source file"))
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
