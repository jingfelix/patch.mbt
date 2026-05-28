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
fn dispatch(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("apply", _)) => println(color_added("apply command scaffold ready"))
    Some(("show", _)) => println(color_path("show command scaffold ready"))
    _ => println(color_removed("unknown command"))
  }
}
