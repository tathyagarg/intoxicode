const std = @import("std");

const expressions = @import("intoxicode").parser.expressions;
const Expression = expressions.Expression;
const Binary = expressions.Binary;
const Grouping = expressions.Grouping;
const Literal = expressions.Literal;

const Token = @import("intoxicode").lexer.tokens.Token;

const allocator = std.testing.allocator;

test "core.parser.expressions.basic" {
    const binary = Expression{ .binary = Binary{
        .left = &Expression{ .literal = Literal{ .number = 42.1 } },
        .operator = Token{ .token_type = .Plus, .value = "+" },
        .right = &Expression{ .grouping = Grouping{
            .expression = &Expression{ .binary = Binary{
                .left = &Expression{ .literal = Literal{ .string = "\"Hello, World!\"" } },
                .operator = Token{ .token_type = .Multiply, .value = "*" },
                .right = &Expression{ .literal = Literal{ .number = 3.14 } },
            } },
        } },
    } };

    const message = try binary.pretty_print(allocator);
    defer allocator.free(message);

    try std.testing.expectEqualStrings(
        "Binary(Literal(number = 42.1) + Group(Binary(Literal(string = \"Hello, World!\") * Literal(number = 3.14))))",
        message,
    );
}
