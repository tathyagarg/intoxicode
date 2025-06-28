const std = @import("std");

const lexer = @import("intoxicode").lexer;

test "core.lexer.advance" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("scream \"Hello, world!\".");

    var lex = lexer.Lexer.init(input);
    defer lex.deinit();

    lex.advance();

    try std.testing.expect(lex.current_char == 's');
    try std.testing.expect(lex.position == 1);

    lex.advance();
    try std.testing.expect(lex.current_char == 'c');
    try std.testing.expect(lex.position == 2);
}

test "core.lexer.advance_end_of_line" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("abc");
    try input.append("def");

    var lex = lexer.Lexer.init(input);
    defer lex.deinit();

    lex.advance();
    lex.advance();
    lex.advance();

    try std.testing.expect(lex.current_char == 'c');
    try std.testing.expect(lex.line_number == 0);
    try std.testing.expect(lex.position == 3);

    lex.advance();
    lex.advance();
    lex.advance();
    lex.advance();

    try std.testing.expect(lex.current_char == 'f');
    try std.testing.expect(lex.line_number == 1);
    try std.testing.expect(lex.position == 3);
}

test "core.lexer.scan_tokens_basic" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("+-*/%<>=(){}");
    var lex = lexer.Lexer.init(input);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 13);

    const expected_types: [13]lexer.tokens.TokenType = [_]lexer.tokens.TokenType{
        .Plus,
        .Minus,
        .Multiply,
        .Divide,
        .Modulo,
        .LessThan,
        .GreaterThan,
        .Equal,
        .LeftParen,
        .RightParen,
        .LeftBrace,
        .RightBrace,
        .EOF,
    };

    for (expected_types, 0..) |expected_type, i| {
        try std.testing.expect(lex.tokens.items[i].token_type == expected_type);
        try std.testing.expect(lex.tokens.items[i].line == 0);
    }
}

test "core.lexer.scan_tokens_identifier" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("identifier123;");
    try input.append("another__ThingY;");

    var lex = lexer.Lexer.init(input);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 3);

    try std.testing.expect(lex.tokens.items[0].token_type == lexer.tokens.TokenType.Identifier);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[0].value, "identifier123"));

    try std.testing.expect(lex.tokens.items[1].token_type == lexer.tokens.TokenType.Identifier);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[1].value, "another__ThingY"));
}
