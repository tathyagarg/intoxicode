const std = @import("std");

const Runner = @import("root.zig").runner.Runner;
const Expression = @import("root.zig").parser.expressions.Expression;
const Statement = @import("root.zig").parser.statements.Statement;
const Identifier = @import("root.zig").parser.expressions.Identifier;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const runner = try Runner.init(allocator);

    var statements = std.ArrayList(Statement).init(allocator);

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

    statements.append(Statement{
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
    }) catch unreachable;

    try runner.run(
        statements.items,
    );
}
