const std = @import("std");

const execution = @import("intoxicode").execution;

test "intox.execution.add_block" {
    const allocator = std.testing.allocator;

    var exec = try execution.Execution.init(allocator);
    defer exec.deinit();

    const block = execution.CodeBlock.init(allocator, .main);

    try exec.add_block(block);

    try std.testing.expect(exec.execution_blocks.items.len == 1);
}

test "intox.execution.add_empty_block" {
    const allocator = std.testing.allocator;

    var exec = try execution.Execution.init(allocator);
    defer exec.deinit();

    try exec.add_empty_block(execution.CodeBlockType.fun);

    try std.testing.expect(exec.execution_blocks.items.len == 1);
    try std.testing.expect(exec.execution_blocks.items[0].block_type == .fun);
}

test "intox.execution.add_multiple_blocks" {
    const allocator = std.testing.allocator;

    var exec = try execution.Execution.init(allocator);
    defer exec.deinit();

    const block1 = execution.CodeBlock.init(allocator, .main);
    const block2 = execution.CodeBlock.init(allocator, .fun);

    try exec.add_block(block1);
    try exec.add_block(block2);

    try std.testing.expect(exec.execution_blocks.items.len == 2);
    try std.testing.expect(exec.execution_blocks.items[0].block_type == .main);
    try std.testing.expect(exec.execution_blocks.items[1].block_type == .fun);
}

test "intox.execution.add_block_and_empty_blocks" {
    const allocator = std.testing.allocator;

    var exec = try execution.Execution.init(allocator);
    defer exec.deinit();

    const block1 = execution.CodeBlock.init(allocator, .main);
    const block2 = execution.CodeBlock.init(allocator, .fun);

    try exec.add_block(block1);
    try exec.add_empty_block(execution.CodeBlockType.maybe);
    try exec.add_block(block2);

    try std.testing.expect(exec.execution_blocks.items.len == 3);
    try std.testing.expect(exec.execution_blocks.items[0].block_type == .main);
    try std.testing.expect(exec.execution_blocks.items[1].block_type == .maybe);
    try std.testing.expect(exec.execution_blocks.items[2].block_type == .fun);
}

test "intox.execution.codeblock.add_line" {
    const allocator = std.testing.allocator;

    var block = execution.CodeBlock.init(allocator, .main);
    defer block.deinit();

    const line = "This is a test line";
    try block.add_line(line);

    try std.testing.expect(block.lines.items.len == 1);
    try std.testing.expect(std.mem.eql(u8, block.lines.items[0].line, "This is a test line"));
    try std.testing.expect(block.lines.items[0].certainty == 1.0);
}

test "intox.execution.codeblock.add_multiple_lines" {
    const allocator = std.testing.allocator;

    var block = execution.CodeBlock.init(allocator, .main);
    defer block.deinit();

    const line1 = "First line";
    const line2 = "Second line";

    try block.add_line(line1);
    try block.add_line(line2);

    try std.testing.expect(block.lines.items.len == 2);
    try std.testing.expect(std.mem.eql(u8, block.lines.items[0].line, "Second line"));
    try std.testing.expect(std.mem.eql(u8, block.lines.items[1].line, "First line"));
}

test "intox.execution.codeblock.remove_n_lines" {
    const allocator = std.testing.allocator;

    var block = execution.CodeBlock.init(allocator, .main);
    defer block.deinit();

    const line1 = "First line";
    const line2 = "Second line";
    const line3 = "Third line";

    try block.add_line(line1);
    try block.add_line(line2);
    try block.add_line(line3);

    try std.testing.expect(block.lines.items.len == 3);

    block.remove_n_lines(2);

    try std.testing.expect(block.lines.items.len == 1);
    try std.testing.expect(std.mem.eql(u8, block.lines.items[0].line, "Third line"));
}
