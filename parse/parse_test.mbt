///|
let unified_fixture =
  #|--- lao	2013-01-05 16:56:19.000000000 -0600
  #|+++ tzu	2013-01-05 16:56:35.000000000 -0600
  #|@@ -1,7 +1,6 @@
  #|-The Way that can be told of is not the eternal Way;
  #|-The name that can be named is not the eternal name.
  #| The Nameless is the origin of Heaven and Earth;
  #|-The Named is the mother of all things.
  #|+The named is the mother of all things.
  #|+
  #| Therefore let there always be non-being,
  #|   so we may see their subtlety,
  #| And let there always be being,
  #|@@ -9,3 +8,6 @@
  #| The two are the same,
  #| But after they are produced,
  #|   they have different names.
  #|+They both may be called deep and profound.
  #|+Deeper and more profound,
  #|+The door of all subtleties!
  #|

///|
test "parse unified diff header and changes" {
  let patch = @parse.parse_patch(unified_fixture)
  assert_eq(patch.diffs.length(), 1)
  let diff = patch.diffs[0]
  guard diff.header is Some(header) else { panic() }
  assert_true(header.old_path is Some("lao"))
  assert_true(header.new_path is Some("tzu"))
  assert_true(header.old_version is Some("2013-01-05 16:56:19.000000000 -0600"))
  assert_true(header.new_version is Some("2013-01-05 16:56:35.000000000 -0600"))
  assert_eq(diff.changes.length(), 15)
  assert_true(diff.changes[0].old is Some(1))
  assert_true(diff.changes[0].new is None)
  assert_true(
    diff.changes[0].line
    is Some("The Way that can be told of is not the eternal Way;"),
  )
  assert_true(diff.changes[2].old is Some(3))
  assert_true(diff.changes[2].new is Some(1))
  assert_true(diff.changes[4].old is None)
  assert_true(diff.changes[4].new is Some(2))
}

///|
test "parse unified diff groups hunks" {
  let diff = @parse.parse_patch(unified_fixture).diffs[0]
  assert_eq(diff.hunks.length(), 2)
  assert_eq(diff.hunks[0].index, 1)
  assert_eq(diff.hunks[0].context.length(), 0)
  assert_eq(diff.hunks[0].middle.length(), 6)
  assert_eq(diff.hunks[0].post.length(), 3)
  assert_eq(diff.hunks[1].index, 2)
  assert_eq(diff.hunks[1].context.length(), 3)
  assert_eq(diff.hunks[1].middle.length(), 3)
  assert_eq(diff.hunks[1].post.length(), 0)
}

///|
test "parse_diffs returns empty for text without unified headers" {
  assert_eq(@parse.parse_diffs("not a patch").length(), 0)
}

///|
let git_log_fixture =
  #|commit abcdef1234567890
  #|Author: Alice Example <alice@example.com>
  #|Date:   Thu May 28 10:00:00 2026 +0000
  #|
  #|    demo: change greeting
  #|
  #|    Body line.
  #|
  #|diff --git a/src/hello.txt b/src/hello.txt
  #|index 1111111..2222222 100644
  #|--- a/src/hello.txt
  #|+++ b/src/hello.txt
  #|@@ -1 +1 @@
  #|-old
  #|+new
  #|

///|
test "parse git log metadata and file diff" {
  let patch = @parse.parse_patch(git_log_fixture)
  assert_true(patch.sha is Some("abcdef1234567890"))
  assert_true(patch.author is Some("Alice Example <alice@example.com>"))
  assert_true(patch.date is Some("Thu May 28 10:00:00 2026 +0000"))
  assert_true(patch.subject is Some("demo: change greeting"))
  guard patch.message is Some(message) else { panic() }
  assert_true(message.has_prefix("commit abcdef1234567890"))
  assert_eq(patch.diffs.length(), 1)
  guard patch.diffs[0].header is Some(header) else { panic() }
  assert_true(header.index_path is Some("src/hello.txt"))
  assert_true(header.old_path is Some("a/src/hello.txt"))
  assert_true(header.new_path is Some("b/src/hello.txt"))
}

///|
let format_patch_fixture =
  #|From abcdef1234567890 Mon Sep 17 00:00:00 2001
  #|From: Alice Example <alice@example.com>
  #|Date: Thu, 28 May 2026 10:00:00 +0000
  #|Subject: demo: change greeting
  #|MIME-Version: 1.0
  #|
  #|Body line.
  #|---
  #| src/hello.txt | 2 +-
  #| 1 file changed, 1 insertion(+), 1 deletion(-)
  #|
  #|diff --git a/src/hello.txt b/src/hello.txt
  #|index 1111111..2222222 100644
  #|--- a/src/hello.txt
  #|+++ b/src/hello.txt
  #|@@ -1 +1 @@
  #|-old
  #|+new
  #|

///|
test "parse format-patch metadata before separator" {
  let patch = @parse.parse_patch(format_patch_fixture)
  assert_true(patch.sha is Some("abcdef1234567890"))
  assert_true(patch.author is Some("Alice Example <alice@example.com>"))
  assert_true(patch.date is Some("Thu, 28 May 2026 10:00:00 +0000"))
  assert_true(patch.subject is Some("demo: change greeting"))
  assert_eq(patch.diffs.length(), 1)
  assert_eq(patch.diffs[0].changes.length(), 2)
}
