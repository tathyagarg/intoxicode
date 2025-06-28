const std = @import("std");

pub const tokens = @import("tokens.zig");
const Token = tokens.Token;
const TokenType = tokens.TokenType;

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
            '=' => try self.add_token(TokenType.Equal),
            else => unreachable,
        }
    }

    pub fn add_raw_token(self: *Lexer, token: Token) !void {
        try self.tokens.append(token);
    }

    pub fn add_token(self: *Lexer, token_type: TokenType) !void {
        const line_number = if (self.start_position > self.position) self.line_number - 1 else self.line_number;

        const end_index = if (self.start_position >= self.position) self.input.items[line_number].len else self.position;
        const value = self.input.items[line_number][self.start_position..end_index];

        const token = Token.init(token_type, value, line_number);

        try self.tokens.append(token);
    }

    pub fn at_end(self: *Lexer) bool {
        if (self.line_number >= self.input.items.len) return true;

        return self.line_number + 1 >= self.input.items.len and self.position >= self.input.items[self.line_number].len;
    }

    pub fn advance(self: *Lexer) void {
        self.current_char = self.input.items[self.line_number][self.position];

        self.next_position();
    }

    pub fn match(self: *Lexer, expected: u8) bool {
        if (self.at_end()) return false;
        if (self.current_char != expected) return false;

        self.advance();
        return true;
    }

    pub fn next_position(self: *Lexer) void {
        self.position += 1;

        if (self.position >= self.input.items[self.line_number].len) {
            self.line_number += 1;
            self.position = 0;
        }
    }
};
