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
      "apply", "--reverse", "--fuzz", "1", "--source", "tests/fixtures/tzu.txt",
      "tests/fixtures/diff-unified.diff",
    ],
    env={},
  ) catch {
    _ => panic()
  }
  assert_true(
    matches.subcommand is Some(("apply", apply)) &&
    apply.flags is { "reverse": true, .. } &&
    apply.values
    is {
      "fuzz": ["1"],
      "source": ["tests/fixtures/tzu.txt"],
      "patch-file": ["tests/fixtures/diff-unified.diff"],
      ..
    },
  )
}

///|
test "cli parses show positional" {
  let matches = @cli.command().parse(
    argv=["show", "tests/fixtures/diff-unified.diff"],
    env={},
  ) catch {
    _ => panic()
  }
  assert_true(
    matches.subcommand is Some(("show", show)) &&
    show.values is { "patch-file": ["tests/fixtures/diff-unified.diff"], .. },
  )
}

///|
test "show_text summarizes parsed patch" {
  inspect(
    @cli.show_text(
      (
        #|diff --git a/src/hello.txt b/src/hello.txt
        #|index 1111111..2222222 100644
        #|--- a/src/hello.txt
        #|+++ b/src/hello.txt
        #|@@ -1 +1,2 @@
        #|-old
        #|+new
        #|+again
        #|
      ),
    ),
    content=(
      #|Patch summary
      #|files: 1
      #|  src/hello.txt: 1 hunk, +2 -1
    ),
  )
}

///|
test "apply_text applies patch to source text" {
  let patch_text =
    #|--- old.txt
    #|+++ new.txt
    #|@@ -1,3 +1,3 @@
    #| one
    #|-two
    #|+TWO
    #| three
    #|
  inspect(
    @cli.apply_text(patch_text, "one\ntwo\nthree\n"),
    content=(
      #|one
      #|TWO
      #|three
    ),
  )
}

///|
test "apply_text supports reverse" {
  let patch_text =
    #|--- old.txt
    #|+++ new.txt
    #|@@ -1,3 +1,3 @@
    #| one
    #|-two
    #|+TWO
    #| three
    #|
  inspect(
    @cli.apply_text(patch_text, "one\nTWO\nthree\n", reverse=true),
    content=(
      #|one
      #|two
      #|three
    ),
  )
}

///|
test "apply_text reports failed hunks" {
  let patch_text =
    #|--- old.txt
    #|+++ new.txt
    #|@@ -1,3 +1,3 @@
    #| one
    #|-two
    #|+TWO
    #| three
    #|
  inspect(
    @cli.apply_text(patch_text, "not matching\n"),
    content="error: failed to apply 1 hunk(s)",
  )
}

///|
test "diff colors emit ansi sequences" {
  assert_eq(color_added("+ added"), "\u001B[32m+ added\u001B[0m")
  assert_eq(color_removed("- removed"), "\u001B[31m- removed\u001B[0m")
}
