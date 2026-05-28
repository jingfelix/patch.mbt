///|
test "cli renders top-level help" {
  inspect(
    @cli.command().render_help(),
    content=(
      #|Usage: patch <command>
      #|
      #|Parse and apply unified patches.
      #|
      #|Commands:
      #|  apply  Apply a patch file to a target tree.
      #|  show   Parse and summarize a patch file.
      #|  help   Print help for the subcommand(s).
      #|
      #|Options:
      #|  -h, --help     Show help information.
      #|  -V, --version  Show version information.
      #|
    ),
  )
}

///|
test "cli parses apply options" {
  let matches = @cli.command().parse(
    argv=[
      "apply", "--reverse", "--fuzz", "1", "tests/fixtures/diff-unified.diff",
    ],
    env={},
  ) catch {
    _ => panic()
  }
  assert_true(
    matches.subcommand is Some(("apply", apply)) &&
    apply.flags is { "reverse": true, .. } &&
    apply.values
    is { "fuzz": ["1"], "patch-file": ["tests/fixtures/diff-unified.diff"], .. },
  )
}

///|
test "diff colors emit ansi sequences" {
  assert_eq(color_added("+ added"), "\u001B[32m+ added\u001B[0m")
  assert_eq(color_removed("- removed"), "\u001B[31m- removed\u001B[0m")
}
