const std = @import("std");

const Runner = @import("intoxicode").runner.Runner;
const Expression = @import("intoxicode").parser.expressions.Expression;
const Statement = @import("intoxicode").parser.statements.Statement;
const Identifier = @import("intoxicode").parser.expressions.Identifier;

test "basic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stdout = std.ArrayList(u8).init(allocator);
    defer stdout.deinit();

    var stderr = std.ArrayList(u8).init(allocator);
    defer stderr.deinit();

    const runner = try Runner.init(allocator, stdout.writer().any(), stderr.writer().any());

    var arguments = std.ArrayList(Expression).init(allocator);

    try arguments.append(Expression{
        .literal = .{
            .number = 42,
        },
    });

    try arguments.append(Expression{
        .literal = .{
            .string = "Hello, World!\n",
        },
    });

    var statements = std.ArrayList(Statement).init(allocator);

    try statements.append(Statement{
        .expression = Expression{
            .call = .{
                .callee = &Expression{
                    .identifier = Identifier{
                        .name = "scream",
                    },
                },
                .arguments = arguments,
            },
        },
    });

    try runner.run(
        statements.items,
    );

    try std.testing.expectEqualStrings(
        "42Hello, World!\n",
        stdout.items,
    );
}
