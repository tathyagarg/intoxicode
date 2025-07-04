const std = @import("std");

pub const TokenType = enum {
    LeftParen,
    RightParen,

    LeftBrace,
    RightBrace,

    Plus,
    Minus,
    Multiply,
    Divide,
    Modulo,

    LessThan,
    GreaterThan,
    Equal,
    NotEqual,

    Period,
    QuestionMark,

    Integer,
    Float,
    String,
    Boolean,
    Null,

    Identifier,

    Assignment,

    If,
    Else,

    Loop,

    Maybe,

    Fun,
    Throwaway, // return

    Try,
    Gotcha,

    Comment,

    And,
    Or,
    Not,

    EOF,
};

pub const Token = struct {
    token_type: TokenType,
    value: []const u8,

    line: usize = 0,

    pub fn init(token_type: TokenType, value: []const u8, line: usize) Token {
        return Token{
            .token_type = token_type,
            .value = value,
            .line = line,
        };
    }

    pub fn is_eof(self: Token) bool {
        return self.token_type == TokenType.EOF;
    }

    pub fn equals(self: Token, other: Token) bool {
        return self.token_type == other.token_type and std.mem.eql(u8, self.value, other.value);
    }
};
