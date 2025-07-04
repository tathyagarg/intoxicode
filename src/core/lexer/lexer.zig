const std = @import("std");

pub const tokens = @import("tokens.zig");
const Token = tokens.Token;
const TokenType = tokens.TokenType;

const Pair = struct {
    key: []const u8,
    value: TokenType,
};

pub const Keywords = [_]Pair{
    .{ .key = "if", .value = TokenType.If },
    .{ .key = "else", .value = TokenType.Else },
    .{ .key = "loop", .value = TokenType.Loop },
    .{ .key = "maybe", .value = TokenType.Maybe },
    .{ .key = "fun", .value = TokenType.Fun },
    .{ .key = "throwaway", .value = TokenType.Throwaway },
    .{ .key = "try", .value = TokenType.Try },
    .{ .key = "gotcha", .value = TokenType.Gotcha },
    .{ .key = "and", .value = TokenType.And },
    .{ .key = "or", .value = TokenType.Or },
    .{ .key = "not", .value = TokenType.Not },
    .{ .key = "null", .value = TokenType.Null },
    .{ .key = "true", .value = TokenType.Boolean },
    .{ .key = "false", .value = TokenType.Boolean },
};

pub fn is_keyword(token: []const u8) bool {
    for (Keywords) |pair| {
        if (std.mem.eql(u8, token, pair.key)) {
            return true;
        }
    }
    return false;
}

pub fn get_keyword_type(token: []const u8) ?TokenType {
    for (Keywords) |pair| {
        if (std.mem.eql(u8, token, pair.key)) {
            return pair.value;
        }
    }
    return null;
}

pub const Lexer = struct {
    input: std.ArrayList([]const u8),

    line_number: usize,
    start_position: usize,
    position: usize,

    current_char: u8,

    tokens: std.ArrayList(Token),

    pub fn init(input: std.ArrayList([]const u8)) Lexer {
        const lexer = Lexer{
            .input = input,
            .line_number = 0,
            .start_position = 0,
            .position = 0,
            .current_char = 0,
            .tokens = std.ArrayList(Token).init(std.testing.allocator),
        };

        return lexer;
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    pub fn scan_tokens(self: *Lexer) !void {
        while (!self.at_end()) {
            self.start_position = self.position;
            try self.scan_token();
        }

        try self.add_raw_token(Token.init(TokenType.EOF, "", self.line_number));
    }

    pub fn scan_token(self: *Lexer) !void {
        self.advance();

        switch (self.current_char) {
            '(' => try self.add_token(TokenType.LeftParen),
            ')' => try self.add_token(TokenType.RightParen),
            '{' => try self.add_token(TokenType.LeftBrace),
            '}' => try self.add_token(TokenType.RightBrace),
            '+' => try self.add_token(TokenType.Plus),
            '-' => try self.add_token(TokenType.Minus),
            '*' => try self.add_token(TokenType.Multiply),
            '/' => try self.add_token(TokenType.Divide),
            '%' => try self.add_token(TokenType.Modulo),
            '<' => try self.add_token(TokenType.LessThan),
            '>' => try self.add_token(TokenType.GreaterThan),
            '.' => try self.add_token(TokenType.Period),
            '?' => try self.add_token(TokenType.QuestionMark),
            '=' => {
                if (self.peek() == '=') {
                    self.advance(); // Consume the '='
                    try self.add_token(TokenType.Equal);
                } else {
                    try self.add_token(TokenType.Assignment);
                }
            },
            '!' => {
                if (self.peek() == '=') {
                    self.advance(); // Consume the '='
                    try self.add_token(TokenType.NotEqual);
                }
            },
            'a'...'z', 'A'...'Z', '_' => {
                var next = self.peek();
                while (!self.at_end() and (next >= 'a' and next <= 'z' or
                    next >= 'A' and next <= 'Z' or
                    next >= '0' and next <= '9' or
                    next == '_'))
                {
                    self.advance();
                    next = self.peek();
                }

                var token_type = TokenType.Identifier;
                const value = self.get_value();

                if (is_keyword(value)) {
                    token_type = get_keyword_type(value).?;
                }

                try self.add_token(token_type);
            },
            '"' => {
                self.advance(); // Consume the opening quote

                while (!self.at_end() and self.current_char != '"') self.advance();

                if (self.current_char != '"') {
                    return error.UnterminatedString; // Unterminated string literal
                }

                try self.add_token(TokenType.String);
            },
            ' ' => {},
            '0'...'9' => {
                while (!self.at_end() and self.current_char >= '0' and self.current_char <= '9' and self.peek() != ';' and self.peek() != ' ') {
                    self.advance();
                }

                if (self.current_char == '.' and (self.peek() >= '0' and self.peek() <= '9')) {
                    self.advance(); // Consume the '.'
                    while (!self.at_end() and self.current_char >= '0' and self.current_char <= '9' and self.peek() != ';' and self.peek() != ' ') {
                        self.advance();
                    }
                    try self.add_token(TokenType.Float);
                } else {
                    // Integer literal
                    try self.add_token(TokenType.Integer);
                }
            },
            else => {
                std.debug.print("Unexpected character: '{c}' at line {d}, position {d}\n", .{
                    self.current_char,
                    self.line_number,
                    self.position,
                });
                unreachable; // Handle unexpected characters
            },
        }
    }

    pub fn add_raw_token(self: *Lexer, token: Token) !void {
        try self.tokens.append(token);
    }

    pub fn get_actual_line(self: *Lexer) usize {
        return if (self.start_position >= self.position)
            self.line_number - 1
        else
            self.line_number;
    }

    pub fn get_value(self: *Lexer) []const u8 {
        const line_number = self.get_actual_line();

        const end_index = if (self.start_position >= self.position) self.input.items[line_number].len else self.position;
        return self.input.items[line_number][self.start_position..end_index];
    }

    pub fn add_token(self: *Lexer, token_type: TokenType) !void {
        const line_number = self.get_actual_line();
        const value = self.get_value();

        const token = Token.init(token_type, value, line_number);

        try self.tokens.append(token);
    }

    pub fn at_end(self: *Lexer) bool {
        if (self.line_number >= self.input.items.len) return true;

        return self.line_number + 1 >= self.input.items.len and self.position >= self.input.items[self.line_number].len;
    }

    pub fn peek(self: *Lexer) u8 {
        if (self.at_end()) return 0;

        if (self.position >= self.input.items[self.line_number].len) {
            return 0; // No next character
        }

        return self.input.items[self.line_number][self.position];
    }

    pub fn peek_next(self: *Lexer) u8 {
        if (self.at_end()) return 0;

        if (self.position + 1 >= self.input.items[self.line_number].len) {
            return 0; // No next character
        }

        return self.input.items[self.line_number][self.position + 1];
    }

    pub fn advance(self: *Lexer) void {
        const overflow = self.position >= self.input.items[self.line_number].len;

        if (overflow) {
            self.line_number += 1;
            self.position = 0;
        }

        if (self.line_number >= self.input.items.len) {
            self.current_char = 0; // End of input
            return;
        }
        self.current_char = self.input.items[self.line_number][self.position];

        if (!overflow) {
            self.next_position();
        }
    }

    pub fn match(self: *Lexer, expected: u8) bool {
        if (self.at_end()) return false;
        if (self.current_char != expected) return false;

        self.advance();
        return true;
    }

    pub fn next_position(self: *Lexer) void {
        self.position += 1;
    }
};
