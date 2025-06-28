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
    Call,

    Try,
    Gotcha,

    Comment,

    And,
    Or,
    Not,

    Semicolon,
    EOF,
};

pub const Token = struct {
    token_type: TokenType,
    value: []const u8,

    line: usize,

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
};
