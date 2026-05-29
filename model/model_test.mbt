///|
test "change constructors preserve old and new line semantics" {
  let context = @model.Change::context(3, 1, "same", 1)
  assert_true(context.old is Some(3))
  assert_true(context.new is Some(1))
  assert_true(context.line is Some("same"))
  assert_true(context.is_context())

  let deleted = @model.Change::delete(4, "old", 1)
  assert_true(deleted.old is Some(4))
  assert_true(deleted.new is None)
  assert_true(!deleted.is_context())

  let inserted = @model.Change::insert(2, "new", 1)
  assert_true(inserted.old is None)
  assert_true(inserted.new is Some(2))
  assert_true(!inserted.is_context())
}

///|
test "changes_to_hunks groups and partitions patche-style hunks" {
  let changes = [
    @model.Change::context(1, 1, "before", 1),
    @model.Change::delete(2, "old", 1),
    @model.Change::insert(2, "new", 1),
    @model.Change::context(3, 3, "after", 1),
    @model.Change::context(8, 8, "next before", 2),
    @model.Change::insert(9, "next new", 2),
  ]
  let hunks = @model.changes_to_hunks(changes)
  assert_eq(hunks.length(), 2)
  assert_eq(hunks[0].index, 1)
  assert_eq(hunks[0].context.length(), 1)
  assert_eq(hunks[0].middle.length(), 2)
  assert_eq(hunks[0].post.length(), 1)
  assert_eq(hunks[0].all_.length(), 4)
  assert_eq(hunks[1].index, 2)
  assert_eq(hunks[1].context.length(), 1)
  assert_eq(hunks[1].middle.length(), 1)
  assert_eq(hunks[1].post.length(), 0)
}

///|
test "line and apply result defaults follow patche naming" {
  let line = @model.Line::new(0, "content")
  assert_eq(line.index, 0)
  assert_eq(line.content, "content")
  assert_eq(line.changed, false)
  assert_eq(line.status, true)
  assert_eq(line.flag, false)
  assert_true(line.hunk is None)

  let result = @model.empty_apply_result(["a", "b"])
  assert_eq(result.new_line_list.length(), 2)
  assert_eq(result.new_line_list[1].content, "b")
  assert_eq(result.conflict_hunk_num_list.length(), 0)
  assert_eq(result.failed_hunk_list.length(), 0)
}
