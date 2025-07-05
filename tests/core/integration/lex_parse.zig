const std = @import("std");

const lexer = @import("intoxicode").lexer;
const loader = @import("intoxicode").loader;
const parser = @import("intoxicode").parser;

const Expression = @import("intoxicode").parser.expressions.Expression;

test "core.integration.lex_parse.basic" {
    var arena = std.heap.ArenaAllocator(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const result = try loader.load_file(allocator, "examples/01_hello_world.??");
    var lex = lexer.Lexer.init(result.backing, allocator);

    try lex.scan_tokens();

    var p = parser.Parser.init(lex.tokens, allocator);
    const statements = try p.parse();

    var expected_args = std.ArrayList(Expression).init(allocator);
    try expected_args.append(Expression{
        .literal = .{ .string = "\"Hello, World!\"" },
    });

    try std.testing.expect(
        statements.items[0].expression.equals(
            Expression{
                .call = .{
                    .callee = Expression{
                        .identifier = "scream",
                    },
                    .arguments = expected_args,
                },
            },
        ),
    );
}
