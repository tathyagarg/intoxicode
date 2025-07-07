const std = @import("std");

const Parser = @import("intoxicode").parser.Parser;
const expressions = @import("intoxicode").parser.expressions;

const Expression = expressions.Expression;

const Token = @import("intoxicode").lexer.tokens.Token;
const TokenType = @import("intoxicode").lexer.tokens.TokenType;

test "core.parser.parser.basic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokens = std.ArrayList(Token).init(std.testing.allocator);
    defer tokens.deinit();

    try tokens.append(Token{ .token_type = .Float, .value = "42.1" });
    try tokens.append(Token{ .token_type = .Plus, .value = "+" });
    try tokens.append(Token{ .token_type = .LeftParen, .value = "(" });
    try tokens.append(Token{ .token_type = .String, .value = "\"Hello, World!\"" });
    try tokens.append(Token{ .token_type = .Multiply, .value = "*" });
    try tokens.append(Token{ .token_type = .Float, .value = "3.14" });
    try tokens.append(Token{ .token_type = .RightParen, .value = ")" });
    try tokens.append(Token{ .token_type = .Period, .value = "." });
    try tokens.append(Token{ .token_type = .EOF, .value = "" });

    var p = Parser.init(tokens, allocator);
    const statements = try p.parse();
    defer statements.deinit();

    try std.testing.expect(
        statements.items[0].expression.equals(
            Expression{
                .binary = expressions.Binary{
                    .left = &Expression{ .literal = expressions.Literal{ .number = 42.1 } },
                    .operator = Token{ .token_type = .Plus, .value = "+" },
                    .right = &Expression{ .grouping = expressions.Grouping{
                        .expression = &Expression{ .binary = expressions.Binary{
                            .left = &Expression{ .literal = expressions.Literal{ .string = "\"Hello, World!\"" } },
                            .operator = Token{ .token_type = .Multiply, .value = "*" },
                            .right = &Expression{ .literal = expressions.Literal{ .number = 3.14 } },
                        } },
                    } },
                },
            },
        ),
    );
}

test "core.parser.parser.assign" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokens = std.ArrayList(Token).init(std.testing.allocator);
    defer tokens.deinit();

    try tokens.append(Token{ .token_type = .Identifier, .value = "x" });
    try tokens.append(Token{ .token_type = .Assignment, .value = "=" });
    try tokens.append(Token{ .token_type = .Float, .value = "42.1" });
    try tokens.append(Token{ .token_type = .QuestionMark, .value = "?" });
    try tokens.append(Token{ .token_type = .EOF, .value = "" });

    var p = Parser.init(tokens, allocator);
    const statements = try p.parse();
    defer statements.deinit();

    try std.testing.expectEqualStrings(
        "x",
        statements.items[0].assignment.identifier,
    );

    try std.testing.expect(
        statements.items[0].assignment.expression.equals(
            Expression{ .literal = expressions.Literal{ .number = 42.1 } },
        ),
    );
}

test "core.parser.parser.function_call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokens = std.ArrayList(Token).init(std.testing.allocator);
    defer tokens.deinit();

    try tokens.append(Token{ .token_type = .Identifier, .value = "print" });
    try tokens.append(Token{ .token_type = .LeftParen, .value = "(" });
    try tokens.append(Token{ .token_type = .String, .value = "\"Hello, World!\"" });
    try tokens.append(Token{ .token_type = .Comma, .value = "," });
    try tokens.append(Token{ .token_type = .Float, .value = "3.14" });
    try tokens.append(Token{ .token_type = .RightParen, .value = ")" });
    try tokens.append(Token{ .token_type = .Period, .value = "." });
    try tokens.append(Token{ .token_type = .EOF, .value = "" });

    var p = Parser.init(tokens, allocator);
    const statements = try p.parse();
    defer statements.deinit();

    var expected_args = std.ArrayList(Expression).init(allocator);
    defer expected_args.deinit();

    try expected_args.append(Expression{ .literal = expressions.Literal{ .string = "\"Hello, World!\"" } });
    try expected_args.append(Expression{ .literal = expressions.Literal{ .number = 3.14 } });

    try std.testing.expect(
        statements.items[0].expression.equals(
            Expression{
                .call = expressions.Call{
                    .callee = &Expression{ .identifier = expressions.Identifier{ .name = "print" } },
                    .arguments = expected_args,
                },
            },
        ),
    );
}

test "if" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokens = std.ArrayList(Token).init(std.testing.allocator);
    defer tokens.deinit();

    try tokens.append(Token{ .token_type = .If, .value = "if" });
    try tokens.append(Token{ .token_type = .Identifier, .value = "1" });
    try tokens.append(Token{ .token_type = .GreaterThan, .value = ">" });
    try tokens.append(Token{ .token_type = .Identifier, .value = "0" });
    try tokens.append(Token{ .token_type = .LeftBrace, .value = "{" });
    try tokens.append(Token{ .token_type = .Identifier, .value = "scream" });
    try tokens.append(Token{ .token_type = .LeftParen, .value = "(" });
    try tokens.append(Token{ .token_type = .String, .value = "\"Hello, World!\"" });
    try tokens.append(Token{ .token_type = .RightParen, .value = ")" });
    try tokens.append(Token{ .token_type = .Period, .value = "." });
    try tokens.append(Token{ .token_type = .RightBrace, .value = "}" });
    try tokens.append(Token{ .token_type = .Period, .value = "." });
    try tokens.append(Token{ .token_type = .EOF, .value = "" });

    var p = Parser.init(tokens, allocator);
    const statements = try p.parse();
    defer statements.deinit();
}
