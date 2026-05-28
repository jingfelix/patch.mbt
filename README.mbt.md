# jingfelix/patch

MoonBit patch parsing and applying library.

## Structure

- `model`: public patch data model shared by parser and applier.
- `parse`: whatthepatch-style parser entry points.
- `apply`: apply, reverse, and fuzz-aware patch application entry points.
- `tests/integration`: end-to-end tests that exercise the public facade.
- `tests/fixtures`: patch and file fixtures based on the reference projects.
