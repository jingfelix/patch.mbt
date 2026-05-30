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
test "cli parses apply target option" {
  let matches = @cli.command().parse(
    argv=["apply", "--target", "tmp", "tests/fixtures/diff-unified.diff"],
    env={},
  ) catch {
    _ => panic()
  }
  assert_true(
    matches.subcommand is Some(("apply", apply)) &&
    apply.values
    is {
      "target": ["tmp"],
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
test "apply_to_target updates existing file" {
  let dir = "tmp_cli_apply_target"
  let path = "\{dir}/old.txt"
  cleanup_target_dir(dir, path)
  @fs.create_dir(dir)
  @fs.write_string_to_file(path, "one\ntwo\nthree\n")
  let patch_text =
    #|--- old.txt
    #|+++ old.txt
    #|@@ -1,3 +1,3 @@
    #| one
    #|-two
    #|+TWO
    #| three
    #|
  inspect(
    @cli.apply_to_target(patch_text, dir),
    content="applied 1 file(s), created 0 file(s), deleted 0 file(s), skipped 0 file(s), failed 0 hunk(s)",
  )
  inspect(
    @fs.read_file_to_string(path),
    content=(
      #|one
      #|TWO
      #|three
      #|
    ),
  )
  cleanup_target_dir(dir, path)
}

///|
test "apply_to_target creates new file" {
  let dir = "tmp_cli_apply_create"
  let path = "\{dir}/new.txt"
  cleanup_target_dir(dir, path)
  @fs.create_dir(dir)
  let patch_text =
    #|--- /dev/null
    #|+++ new.txt
    #|@@ -0,0 +1,2 @@
    #|+hello
    #|+moonbit
    #|
  inspect(
    @cli.apply_to_target(patch_text, dir),
    content="applied 0 file(s), created 1 file(s), deleted 0 file(s), skipped 0 file(s), failed 0 hunk(s)",
  )
  inspect(
    @fs.read_file_to_string(path),
    content=(
      #|hello
      #|moonbit
      #|
    ),
  )
  cleanup_target_dir(dir, path)
}

///|
test "apply_to_target deletes file" {
  let dir = "tmp_cli_apply_delete"
  let path = "\{dir}/old.txt"
  cleanup_target_dir(dir, path)
  @fs.create_dir(dir)
  @fs.write_string_to_file(path, "one\ntwo\n")
  let patch_text =
    #|--- old.txt
    #|+++ /dev/null
    #|@@ -1,2 +0,0 @@
    #|-one
    #|-two
    #|
  inspect(
    @cli.apply_to_target(patch_text, dir),
    content="applied 0 file(s), created 0 file(s), deleted 1 file(s), skipped 0 file(s), failed 0 hunk(s)",
  )
  assert_false(@fs.path_exists(path))
  cleanup_target_dir(dir, path)
}

///|
test "apply_to_target reverse delete creates file" {
  let dir = "tmp_cli_apply_reverse_delete"
  let path = "\{dir}/old.txt"
  cleanup_target_dir(dir, path)
  @fs.create_dir(dir)
  let patch_text =
    #|--- old.txt
    #|+++ /dev/null
    #|@@ -1,2 +0,0 @@
    #|-one
    #|-two
    #|
  inspect(
    @cli.apply_to_target(patch_text, dir, reverse=true),
    content="applied 0 file(s), created 1 file(s), deleted 0 file(s), skipped 0 file(s), failed 0 hunk(s)",
  )
  inspect(
    @fs.read_file_to_string(path),
    content=(
      #|one
      #|two
      #|
    ),
  )
  cleanup_target_dir(dir, path)
}

///|
test "apply_to_target writes reject file on failed hunk" {
  let dir = "tmp_cli_apply_reject"
  let path = "\{dir}/old.txt"
  cleanup_target_dir(dir, path)
  @fs.create_dir(dir)
  @fs.write_string_to_file(path, "not matching\n")
  let patch_text =
    #|--- old.txt
    #|+++ old.txt
    #|@@ -1,3 +1,3 @@
    #| one
    #|-two
    #|+TWO
    #| three
    #|
  inspect(
    @cli.apply_to_target(patch_text, dir, fuzz=0),
    content="applied 0 file(s), created 0 file(s), deleted 0 file(s), skipped 0 file(s), failed 1 hunk(s)",
  )
  inspect(
    @fs.read_file_to_string(path),
    content=(
      #|not matching
      #|
    ),
  )
  inspect(
    @fs.read_file_to_string(path + ".rej"),
    content=(
      #|@@ rejected hunk 1 @@
      #| one
      #|-two
      #|+TWO
      #| three
      #|
    ),
  )
  cleanup_target_dir(dir, path)
}

///|
test "diff colors emit ansi sequences" {
  assert_eq(color_added("+ added"), "\u001B[32m+ added\u001B[0m")
  assert_eq(color_removed("- removed"), "\u001B[31m- removed\u001B[0m")
}

///|
fn cleanup_target_dir(dir : String, path : String) -> Unit {
  if @fs.path_exists(path + ".rej") {
    @fs.remove_file(path + ".rej") catch {
      _ => ()
    }
  }
  if @fs.path_exists(path) {
    @fs.remove_file(path) catch {
      _ => ()
    }
  }
  if @fs.path_exists(dir) {
    @fs.remove_dir(dir) catch {
      _ => ()
    }
  }
}
