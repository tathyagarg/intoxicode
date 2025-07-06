const std = @import("std");

const lexer = @import("intoxicode").lexer;
const loader = @import("intoxicode").loader;

const allocator = std.testing.allocator;

test "core.lexer.advance" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("scream \"Hello, world!\".");

    var lex = lexer.Lexer.init(input, allocator);
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

    var lex = lexer.Lexer.init(input, allocator);
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
    var lex = lexer.Lexer.init(input, allocator);
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
        .Assignment,
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

    try input.append("identifier123 another__ThingY");

    var lex = lexer.Lexer.init(input, allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 3);

    try std.testing.expect(lex.tokens.items[0].token_type == .Identifier);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[0].value, "identifier123"));

    try std.testing.expect(lex.tokens.items[1].token_type == .Identifier);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[1].value, "another__ThingY"));
}

test "core.lexer.keywords" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("if else");

    var lex = lexer.Lexer.init(input, allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 3);

    const expected_keywords: [2][]const u8 = [_][]const u8{
        "if",
        "else",
    };

    const token_types: [2]lexer.tokens.TokenType = [_]lexer.tokens.TokenType{
        .If,
        .Else,
    };

    for (expected_keywords, 0..) |keyword, i| {
        try std.testing.expect(lex.tokens.items[i].token_type == token_types[i]);
        try std.testing.expect(std.mem.eql(u8, lex.tokens.items[i].value, keyword));
    }
}

test "core.lexer.all_kws" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("if else loop maybe fun throwaway try gotcha and or not");

    var lex = lexer.Lexer.init(input, allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 12);

    const expected_keywords: [11][]const u8 = [_][]const u8{
        "if", "else", "loop", "maybe", "fun", "throwaway", "try", "gotcha", "and", "or", "not",
    };

    const token_types: [11]lexer.tokens.TokenType = [_]lexer.tokens.TokenType{
        .If, .Else, .Loop, .Maybe, .Fun, .Throwaway, .Try, .Gotcha, .And, .Or, .Not,
    };

    for (expected_keywords, 0..) |keyword, i| {
        try std.testing.expect(lex.tokens.items[i].token_type == token_types[i]);
        try std.testing.expect(std.mem.eql(u8, lex.tokens.items[i].value, keyword));
    }
}

test "core.lexer.scan_tokens_string" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("\"Hello, world!\"");

    var lex = lexer.Lexer.init(input, allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 2);

    try std.testing.expect(lex.tokens.items[0].token_type == .String);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[0].value, "\"Hello, world!\""));
}

test "core.lexer.scan_tokens_float" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("3.14 2.718");

    var lex = lexer.Lexer.init(input, allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 3);

    try std.testing.expect(lex.tokens.items[0].token_type == .Float);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[0].value, "3.14"));

    try std.testing.expect(lex.tokens.items[1].token_type == .Float);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[1].value, "2.718"));
}

test "core.lexer.scan_tokens_integer" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("42 1000");

    var lex = lexer.Lexer.init(input, allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 3);

    try std.testing.expect(lex.tokens.items[0].token_type == .Integer);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[0].value, "42"));

    try std.testing.expect(lex.tokens.items[1].token_type == .Integer);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[1].value, "1000"));
}

test "core.lexer.scan_tokens_boolean" {
    var input = std.ArrayList([]const u8).init(std.testing.allocator);
    defer input.deinit();

    try input.append("true false");

    var lex = lexer.Lexer.init(input, allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len == 3);

    try std.testing.expect(lex.tokens.items[0].token_type == .Boolean);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[0].value, "true"));

    try std.testing.expect(lex.tokens.items[1].token_type == .Boolean);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[1].value, "false"));
}

test "core.lexer.scan_from_file" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const result = try loader.load_file(arena_allocator, "examples/01_hello_world.??");
    defer result.deinit();

    var lex = lexer.Lexer.init(result, arena_allocator);
    defer lex.deinit();

    try lex.scan_tokens();

    try std.testing.expect(lex.tokens.items.len >= 6);

    try std.testing.expect(lex.tokens.items[0].token_type == .Identifier);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[0].value, "scream"));

    try std.testing.expect(lex.tokens.items[1].token_type == .LeftParen);

    try std.testing.expect(lex.tokens.items[2].token_type == .String);
    try std.testing.expect(std.mem.eql(u8, lex.tokens.items[2].value, "\"Hello world!\\n\""));

    try std.testing.expect(lex.tokens.items[3].token_type == .RightParen);

    try std.testing.expect(lex.tokens.items[4].token_type == .Period);
}
