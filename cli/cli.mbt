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
fn dispatch(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("apply", _)) => println(color_added("apply command scaffold ready"))
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
