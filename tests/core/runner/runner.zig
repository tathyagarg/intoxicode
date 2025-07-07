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
            .string = "\"Hello, World!\n\"",
        },
    });

    var statements = std.ArrayList(*Statement).init(allocator);

    var stmt1 = Statement{
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
    };

    try statements.append(&stmt1);

    try runner.run(
        statements.items,
    );

    try std.testing.expectEqualStrings(
        "42Hello, World!\n",
        stdout.items[0..16],
    );
}

test "variables" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stdout = std.ArrayList(u8).init(allocator);
    defer stdout.deinit();

    var stderr = std.ArrayList(u8).init(allocator);
    defer stderr.deinit();

    const runner = try Runner.init(allocator, stdout.writer().any(), stderr.writer().any());

    var statements = std.ArrayList(*Statement).init(allocator);

    var stmt1 = Statement{
        .assignment = .{
            .identifier = "x",
            .expression = Expression{
                .literal = .{
                    .number = 10,
                },
            },
        },
    };

    try statements.append(&stmt1);

    var stmt2 = Statement{
        .expression = Expression{
            .call = .{
                .callee = &Expression{
                    .identifier = Identifier{
                        .name = "scream",
                    },
                },
                .arguments = std.ArrayList(Expression).init(allocator),
            },
        },
    };

    try stmt2.expression.call.arguments.?.append(Expression{
        .identifier = Identifier{
            .name = "x",
        },
    });

    try statements.append(&stmt2);

    try runner.run(
        statements.items,
    );

    try std.testing.expectEqualStrings(
        "10",
        stdout.items[0..2],
    );
}
