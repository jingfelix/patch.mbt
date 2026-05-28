# patch.mbt Implementation Plan

This project should progress in small, reviewable commits. The implementation
order is: make data shape stable, make behavior correct, then make the CLI
pleasant to use.

## 1. Stabilize the public model

Use `patche` as the primary reference for the public API style.

- Keep a top-level `Patch` object with commit metadata fields such as `sha`,
  `author`, `date`, `subject`, `message`, and a list of parsed file diffs.
- Keep file-level `Diff` objects close to whatthepatch, but extend them with
  grouped `Hunk` data like `patche` does.
- Keep `Change` as the normalized old/new line-number representation:
  context lines have both `old` and `new`, deletions have only `old`, additions
  have only `new`.
- Keep apply results explicit: new lines, failed/rejected hunks, and metadata
  about fuzz/offset decisions.
- Decide and document error shape before the parser and applier depend on it.

Exit criteria:

- `model` package has stable field names and semantics.
- `.mbti` output reflects the intended public API.
- Unit tests cover basic construction and hunk grouping invariants.

## 2. Implement unified diff parsing

Start with the core common format:

- `--- old`
- `+++ new`
- `@@ -old,count +new,count @@`
- context, add, delete, and `\ No newline at end of file` lines

Exit criteria:

- Parse `tests/fixtures/diff-unified.diff`.
- Assert header fields, hunk ranges, changes, and grouped hunks.

## 3. Implement git patch metadata parsing

Support the metadata formats used by `patche` and common Git patches:

- `commit ...`
- `From ...`
- `Author:` / `From:`
- `Date:`
- `Subject:`
- message body before the first diff block
- `diff --git`, `index`, `new file mode`, `deleted file mode`

Exit criteria:

- Git patch and email patch fixtures parse into `Patch` metadata.
- File headers still parse correctly after metadata.

## 4. Implement strict apply and reverse

Implement hunk application without fuzz first.

- Verify source lines match the old/context side exactly.
- Apply additions and deletions in hunk order.
- Reverse by swapping old/new sides.

Exit criteria:

- `lao + diff = tzu`.
- `tzu + reverse(diff) = lao`.
- Failed strict matches return structured failures.

## 5. Implement fuzz apply

Add GNU patch-style fuzz behavior after strict apply works.

- Default `fuzz = 2`.
- Search for hunks after trimming leading/trailing context.
- Track selected offset and fuzz for each applied hunk.
- Preserve failed hunks for diagnostics and CLI output.

Exit criteria:

- Offset and context-trim fixtures pass.
- Failed fuzz attempts are represented in `ApplyResult`.

## 6. Broaden parser format coverage

Use `whatthepatch` as the main reference for additional parsing formats.

- Context diff.
- Default diff.
- SVN/CVS headers.
- Git binary patches as recognized, non-applicable diffs.

Do not implement ed/rcs/binary application until the unified path is solid.

Exit criteria:

- Additional fixtures parse or fail with intentional structured errors.

## 7. Bring in CI gradually

Start from simple MoonBit checks, then borrow useful ideas from the reference
repositories only when the local commands are stable.

- After steps 1-2: add CI for `moon fmt --check` if available, `moon check`,
  and `moon test`.
- After steps 4-5: add integration-test fixtures to CI, including apply and
  reverse behavior.
- After CLI file-system apply exists: add end-to-end CLI tests in temporary
  directories.
- Later, compare selected results against reference behavior from
  `whatthepatch`, `patche`, or GNU `patch` where practical.

Exit criteria:

- CI starts small and fast.
- CI expands only when corresponding local tests are reliable.
- Reference-project CI patterns are copied intentionally, not wholesale.

## 8. Connect the CLI to real behavior

The CLI already uses `moonbitlang/core/argparse` and
`xingwangzhe/style_print`.

- `patch show <patch-file>` should parse and summarize patches.
- `patch apply <patch-file> --target <dir> --reverse --fuzz 2` should apply
  patches to files.
- Use color for added/removed lines and diagnostics.

Exit criteria:

- CLI commands call parser/apply library APIs.
- CLI has blackbox or integration tests for success and failure paths.

## 9. Implement file-system apply

Support real patch application across files.

- Multi-file patches.
- `/dev/null` new and deleted files.
- `a/` and `b/` path prefix handling.
- Target directory handling.
- Rejected hunk reporting.

Exit criteria:

- Temporary-directory integration tests cover create, modify, delete, reverse,
  and failure cases.

## 10. Polish errors and publishing metadata

Prepare for library and CLI use.

- Make parse/apply errors readable and stable.
- Improve README examples.
- Fill package metadata in `moon.mod`.
- Run package checks before publishing.

Exit criteria:

- Public API examples compile.
- CLI examples run.
- Package is ready for `moon package` and later `moon publish`.
