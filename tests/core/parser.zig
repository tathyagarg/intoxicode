const std = @import("std");

const lexer = @import("intoxicode").lexer;
const parser = @import("intoxicode").parser;

const allocator = std.heap.page_allocator;

test "core.parser.initialize" {
    var tokens = std.ArrayList(lexer.tokens.Token).init(allocator);
    defer tokens.deinit();

    try tokens.appendSlice(&[_]lexer.tokens.Token{
        .{ .line = 0, .token_type = .Identifier, .value = "test" },
        .{ .line = 0, .token_type = .Plus, .value = "+" },
        .{ .line = 0, .token_type = .Integer, .value = "42" },
        .{ .line = 0, .token_type = .Period, .value = "." },
    });

    var p = parser.Parser.init(tokens, allocator);
    defer p.deinit();
}

test "core.parser.basic_parse" {
    var tokens = std.ArrayList(lexer.tokens.Token).init(allocator);
    defer tokens.deinit();

    try tokens.appendSlice(&[_]lexer.tokens.Token{
        .{ .line = 0, .token_type = .Identifier, .value = "x" },
        .{ .line = 0, .token_type = .Plus, .value = "+" },
        .{ .line = 0, .token_type = .Integer, .value = "42" },
        .{ .line = 0, .token_type = .Period, .value = "." },
        .{ .line = 1, .token_type = .EOF, .value = "" },
    });

    var p = parser.Parser.init(tokens, allocator);
    defer p.deinit();

    try p.parse();

    try std.testing.expect(p.program.statements.items.len == 2);
    try std.testing.expect(p.program.statements.items[0].children.items.len == 3);
    try std.testing.expect(p.program.statements.items[0].certainty == 1.0);

    try std.testing.expect(p.program.statements.items[0].children.items[0].node_type == parser.node.NodeType.Identifier);
    try std.testing.expect(std.mem.eql(u8, p.program.statements.items[0].children.items[0].value.?, "x"));

    try std.testing.expect(p.program.statements.items[0].children.items[1].node_type == parser.node.NodeType.Operator);
    try std.testing.expect(std.mem.eql(u8, p.program.statements.items[0].children.items[1].value.?, "+"));

    try std.testing.expect(p.program.statements.items[0].children.items[2].node_type == parser.node.NodeType.Literal);
    try std.testing.expect(std.mem.eql(u8, p.program.statements.items[0].children.items[2].value.?, "42"));

    try std.testing.expect(p.program.statements.items[1].children.items.len == 1);
    try std.testing.expect(p.program.statements.items[1].children.items[0].node_type == parser.node.NodeType.EOF);
    try std.testing.expect(p.program.statements.items[1].certainty == 0.0);
}
