const std = @import("std");
pub const expressions = @import("expressions.zig");

const Expression = expressions.Expression;

const _tokens = @import("../lexer/tokens.zig");
const Token = _tokens.Token;
const TokenType = _tokens.TokenType;

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    current: usize = 0,

    allocator: std.mem.Allocator,

    pub fn init(tokens: std.ArrayList(Token), allocator: std.mem.Allocator) Parser {
        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
        };
    }

    fn consume(self: *Parser, token_type: TokenType, message: []const u8) !Token {
        if (self.check(token_type)) {
            return self.advance();
        }

        std.debug.panic("Expected token type: {}, but found: {}. {s}", .{
            token_type,
            self.peek().token_type,
            message,
        });
    }

    fn peek(self: *Parser) Token {
        return self.tokens.items[self.current];
    }

    fn previous(self: *Parser) Token {
        return self.tokens.items[self.current - 1];
    }

    fn is_at_end(self: *Parser) bool {
        return self.peek().token_type == .EOF;
    }

    fn advance(self: *Parser) Token {
        if (!self.is_at_end()) self.current += 1;
        return self.previous();
    }

    fn check(self: *Parser, token_type: TokenType) bool {
        if (self.is_at_end()) return false;
        return self.peek().token_type == token_type;
    }

    fn match(self: *Parser, token_types: []const TokenType) bool {
        for (token_types) |token_type| {
            if (self.check(token_type)) {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    pub fn parse(self: *Parser) !Expression {
        return try self.expression();
    }

    fn expression(self: *Parser) error{ OutOfMemory, InvalidCharacter }!Expression {
        return try self.equality();
    }

    fn equality(self: *Parser) !Expression {
        var expr = try self.comparison();

        while (self.match((&[_]TokenType{ .Equal, .NotEqual })[0..])) {
            const operator = self.previous();

            const right = try self.allocator.create(Expression);
            right.* = try self.comparison();

            const left = try self.allocator.create(Expression);
            left.* = expr;

            expr = Expression{
                .binary = expressions.Binary{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            };
        }

        return expr;
    }

    fn comparison(self: *Parser) !Expression {
        var expr = try self.term();

        while (self.match((&[_]TokenType{ .GreaterThan, .LessThan })[0..])) {
            const operator = self.previous();

            const right = try self.allocator.create(Expression);
            right.* = try self.term();

            const left = try self.allocator.create(Expression);
            left.* = expr;

            expr = Expression{
                .binary = expressions.Binary{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            };
        }

        return expr;
    }

    fn term(self: *Parser) !Expression {
        var expr = try self.factor();

        while (self.match(&[_]TokenType{ .Plus, .Minus })) {
            const operator = self.previous();

            const right = try self.allocator.create(Expression);
            right.* = try self.factor();

            const left = try self.allocator.create(Expression);
            left.* = expr;

            expr = Expression{
                .binary = expressions.Binary{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            };
        }

        return expr;
    }

    fn factor(self: *Parser) !Expression {
        var expr = try self.primary();

        while (self.match(&[_]TokenType{ .Multiply, .Divide })) {
            const operator = self.previous();

            const right = try self.allocator.create(Expression);
            right.* = try self.primary();

            const left = try self.allocator.create(Expression);
            left.* = expr;

            expr = Expression{
                .binary = expressions.Binary{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            };
        }

        return expr;
    }

    fn primary(self: *Parser) !Expression {
        if (self.match(&[_]TokenType{ .Integer, .Float, .String, .Identifier })) {
            const token = self.previous();

            return switch (token.token_type) {
                .Identifier => Expression{
                    .identifier = expressions.Identifier{
                        .name = token.value,
                    },
                },
                .Integer, .Float => Expression{ .literal = try expressions.Literal.number_from_string(token.value) },
                .String => Expression{
                    .literal = expressions.Literal{
                        .string = token.value,
                    },
                },
                else => unreachable,
            };
        }

        if (self.match(&[_]TokenType{.LeftParen})) {
            const expr = try self.allocator.create(Expression);
            expr.* = try self.expression();

            _ = try self.consume(.RightParen, "Expected ')' after expression.");

            return Expression{
                .grouping = expressions.Grouping{
                    .expression = expr,
                },
            };
        }

        std.debug.panic("Unexpected token: {s}", .{self.peek().value});
    }
};
