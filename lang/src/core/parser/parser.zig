const std = @import("std");

pub const expressions = @import("expressions.zig");
pub const statements = @import("statement.zig");

const Expression = expressions.Expression;
const Statement = statements.Statement;
const Identifier = expressions.Identifier;

const _tokens = @import("../lexer/tokens.zig");
const Token = _tokens.Token;
const TokenType = _tokens.TokenType;

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    current: usize = 0,

    allocator: std.mem.Allocator,

    certainty_mods: *bool,

    pub fn init(tokens: std.ArrayList(Token), allocator: std.mem.Allocator) !Parser {
        const certainty_mods = try allocator.create(bool);
        certainty_mods.* = true;

        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
            .certainty_mods = certainty_mods,
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

    pub fn parse(self: *Parser) anyerror!std.ArrayList(*Statement) {
        var stmts = std.ArrayList(*Statement).init(self.allocator);

        while (!self.is_at_end()) {
            const statement_obj = try self.statement();
            try stmts.append(statement_obj);
        }

        return stmts;
    }

    fn statement(self: *Parser) anyerror!*Statement {
        const found_stmt = if (self.match(&[_]TokenType{.If}))
            try self.if_statement()
        else if (self.match(&[_]TokenType{.Loop}))
            try self.loop_statement()
        else if (self.match(&[_]TokenType{.Fun}))
            try self.function_declaration()
        else if (self.match(&[_]TokenType{.Try}))
            try self.try_statement()
        else if (self.match(&[_]TokenType{.Throwaway}))
            try self.throwaway_statement()
        else if (self.match(&[_]TokenType{.Identifier}))
            try self.assignment_or_expression()
        else if (self.match(&[_]TokenType{.Directive}))
            try self.directive()
        else if (self.match(&[_]TokenType{.Repeat}))
            try self.repeat()
        else
            try self.expression_statement();

        if (self.certainty_mods.*) {
            const next = self.advance();
            const certainty: f32 = switch (next.token_type) {
                .Period => 1.0,
                .QuestionMark => 0.75,
                else => std.debug.panic("Unexpected token after statement: {s} in statement: {s}\n-> {s}", .{
                    next.value,
                    @tagName(found_stmt.*),
                    try found_stmt.pretty_print(self.allocator),
                }),
            };

            found_stmt.set_certainty(certainty);
        }

        return found_stmt;
    }

    fn repeat(self: *Parser) !*Statement {
        const var_name = try self.consume(.Identifier, "Expected variable name after 'repeat' keyword.");

        _ = try self.consume(.To, "Expected 'to' keyword after repeat condition.");

        const count = try self.expression();

        _ = try self.consume(.LeftBrace, "Expected '{' to start repeat block.");

        var body = std.ArrayList(*Statement).init(self.allocator);

        while (!self.is_at_end() and !self.check(.RightBrace)) {
            const stmt = try self.statement();
            try body.append(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}' to end repeat block.");

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement{
            .repeat_statement = statements.RepeatStatement{
                .variable = var_name.value,
                .count = count,
                .body = body,
            },
        };

        return stmt;
    }

    fn directive(self: *Parser) !*Statement {
        const feature = try self.consume(.Identifier, "Expected feature name after '@'");
        const stmt = try self.allocator.create(Statement);

        const arguments = try self.allocator.create(std.ArrayList([]const u8));
        arguments.* = std.ArrayList([]const u8).init(self.allocator);

        if (std.mem.eql(u8, feature.value, "uncertainty") or std.mem.eql(u8, feature.value, "all")) {
            self.certainty_mods.* = false;
        } else if (std.mem.eql(u8, feature.value, "export")) {
            _ = try self.consume(.LeftParen, "Expected '(' after '@export' directive.");

            while (!self.is_at_end() and !self.check(.RightParen)) {
                const exported_func = try self.consume(.Identifier, "Expected function name after '@export' directive.");

                try arguments.append(exported_func.value);
            }

            _ = try self.consume(.RightParen, "Expected ')' after exported functions in '@export' directive.");
        } else if (std.mem.eql(u8, feature.value, "import")) {
            _ = try self.consume(.LeftParen, "Expected '(' after '@import' directive.");

            const imported_file = try self.consume(.String, "Expected file name after '@import' directive.");
            try arguments.append(imported_file.value);

            _ = try self.consume(.RightParen, "Expected ')' after imported functions in '@import' directive.");
        }

        stmt.* = Statement{
            .directive = statements.Directive{
                .name = feature.value,
                .arguments = if (arguments.items.len > 0) arguments.* else null,
            },
        };

        return stmt;
    }

    fn expression_statement(self: *Parser) !*Statement {
        const expr = try self.expression();

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement{
            .expression = expr,
        };

        return stmt;
    }

    fn assignment_or_expression(self: *Parser) !*Statement {
        const identifier = self.previous().value;

        if (self.match(&[_]TokenType{.Assignment})) {
            const expr = try self.expression();

            const stmt = try self.allocator.create(Statement);
            stmt.* = Statement{
                .assignment = statements.Assignment{
                    .identifier = identifier,
                    .expression = expr,
                },
            };

            return stmt;
        }

        if (self.match(&[_]TokenType{.LeftParen})) {
            const args = try self.allocator.create(std.ArrayList(Expression));
            args.* = std.ArrayList(Expression).init(self.allocator);

            while (!self.is_at_end() and !self.check(.RightParen)) {
                const arg = try self.expression();
                try args.append(arg);

                if (!self.match(&[_]TokenType{.Comma})) break;
            }

            _ = try self.consume(.RightParen, "Expected ')' after function arguments.");

            const identifier_expr = try self.allocator.create(Expression);
            identifier_expr.* = Expression{
                .identifier = expressions.Identifier{
                    .name = identifier,
                },
            };

            const stmt = try self.allocator.create(Statement);
            stmt.* = Statement{
                .expression = Expression{
                    .call = expressions.Call{
                        .callee = identifier_expr,
                        .arguments = args.*,
                    },
                },
            };

            return stmt;
        }

        return self.expression_statement();
    }

    fn if_statement(self: *Parser) !*Statement {
        const condition = try self.expression();

        _ = try self.consume(.LeftBrace, "Expected '{' after 'if'.");

        var then_branch = std.ArrayList(*Statement).init(self.allocator);

        while (!self.is_at_end() and !self.check(.RightBrace)) {
            const stmt = try self.statement();
            try then_branch.append(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}' to end 'if' block.");

        var else_branch: ?std.ArrayList(*Statement) = null;
        if (self.match(&[_]TokenType{.Else})) {
            _ = try self.consume(.LeftBrace, "Expected '{' after 'if'.");

            else_branch = std.ArrayList(*Statement).init(self.allocator);

            while (!self.is_at_end() and !self.check(.RightBrace)) {
                const stmt = try self.statement();
                try else_branch.?.append(stmt);
            }

            _ = try self.consume(.RightBrace, "Expected '}' to end 'if' block.");
        }

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement{
            .if_statement = statements.IfStatement{
                .condition = condition,
                .then_branch = then_branch,
                .else_branch = else_branch,
            },
        };

        return stmt;
    }

    fn loop_statement(self: *Parser) !*Statement {
        const condition = try self.expression();
        _ = try self.consume(.LeftBrace, "Expected '{' to start loop body.");

        var body = std.ArrayList(*Statement).init(self.allocator);

        while (!self.is_at_end() and !self.check(.RightBrace)) {
            const stmt = try self.statement();
            try body.append(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}' to end loop body.");

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement{
            .loop_statement = statements.LoopStatement{
                .condition = condition,
                .body = body,
            },
        };

        return stmt;
    }

    fn function_declaration(self: *Parser) !*Statement {
        const name = (try self.consume(.Identifier, "Expected function name after 'fun' keyword.")).value;
        _ = try self.consume(.LeftParen, "Expected '(' after function name.");

        var params = std.ArrayList([]const u8).init(self.allocator);

        while (!self.is_at_end() and !self.check(.RightParen)) {
            if (self.match(&[_]TokenType{.Identifier})) {
                try params.append(self.previous().value);
            } else {
                std.debug.panic("Expected identifier for function parameter.", .{});
            }

            if (!self.match(&[_]TokenType{.Comma})) break;
        }

        _ = try self.consume(.RightParen, "Expected ')' after function parameters.");

        _ = try self.consume(.LeftBrace, "Expected '{' to start function body.");

        var body = std.ArrayList(*Statement).init(self.allocator);

        while (!self.is_at_end() and !self.check(.RightBrace)) {
            const stmt = try self.statement();
            try body.append(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}' to end function body.");

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement{
            .function_declaration = statements.FunctionDeclaration{
                .name = name,
                .parameters = params,
                .body = body,
            },
        };

        return stmt;
    }

    fn try_statement(self: *Parser) !*Statement {
        _ = try self.consume(.LeftBrace, "Expected '{' after 'try'.");

        var body = std.ArrayList(*Statement).init(self.allocator);

        while (!self.is_at_end() and !self.check(.RightBrace)) {
            const stmt = try self.statement();
            try body.append(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}' to end 'try' block.");

        var catch_block = std.ArrayList(*Statement).init(self.allocator);

        _ = try self.consume(.Gotcha, "Expected 'gotcha' after 'try' block.");
        _ = try self.consume(.LeftBrace, "Expected '{' after 'gotcha'.");

        while (!self.is_at_end() and !self.check(.RightBrace)) {
            const stmt = try self.statement();
            try catch_block.append(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}' to end 'gotcha' block.");

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement{
            .try_statement = statements.TryStatement{
                .body = body,
                .catch_block = catch_block,
            },
        };

        return stmt;
    }

    fn throwaway_statement(self: *Parser) !*Statement {
        const expr = try self.expression();

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement{
            .throwaway_statement = statements.ThrowawayStatement{
                .expression = expr,
            },
        };

        return stmt;
    }

    fn expression(self: *Parser) error{ OutOfMemory, InvalidCharacter }!Expression {
        return try self.logical();
    }

    fn logical(self: *Parser) !Expression {
        var expr = try self.equality();

        while (self.match(&[_]TokenType{ .And, .Or })) {
            const operator = self.previous();

            const right = try self.allocator.create(Expression);
            right.* = try self.equality();

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
        var expr = try self.indexing();

        while (self.match(&[_]TokenType{ .Multiply, .Divide, .Modulo })) {
            const operator = self.previous();

            const right = try self.allocator.create(Expression);
            right.* = try self.indexing();

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

    fn indexing(self: *Parser) !Expression {
        var expr = try self.call();

        while (self.match(&[_]TokenType{.LeftBracket})) {
            const index_expr = try self.expression();

            const index = try self.allocator.create(Expression);
            index.* = index_expr;

            _ = try self.consume(.RightBracket, "Expected ']' after index expression.");

            const array = try self.allocator.create(Expression);
            array.* = expr;

            expr = Expression{
                .indexing = expressions.Indexing{
                    .array = array,
                    .index = index,
                },
            };
        }

        return expr;
    }

    fn call(self: *Parser) !Expression {
        var expr = try self.primary();

        while (self.match(&[_]TokenType{.LeftParen})) {
            const args = try self.allocator.create(std.ArrayList(Expression));
            args.* = std.ArrayList(Expression).init(self.allocator);

            while (!self.is_at_end() and !self.check(.RightParen)) {
                const arg = try self.expression();
                try args.append(arg);

                if (!self.match(&[_]TokenType{.Comma})) break;
            }

            _ = try self.consume(.RightParen, "Expected ')' after arguments.");

            const callee = try self.allocator.create(Expression);
            callee.* = expr;

            expr = Expression{
                .call = expressions.Call{
                    .callee = callee,
                    .arguments = args.*,
                },
            };
        }

        return expr;
    }

    fn primary(self: *Parser) !Expression {
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

        if (self.match(&[_]TokenType{.LeftBracket})) {
            const elements = try self.allocator.create(std.ArrayList(Expression));
            elements.* = std.ArrayList(Expression).init(self.allocator);

            while (!self.is_at_end() and !self.check(.RightBracket)) {
                const element = try self.expression();
                try elements.append(element);

                if (!self.match(&[_]TokenType{.Comma})) break;
            }

            _ = try self.consume(.RightBracket, "Expected ']' after array elements.");

            return Expression{
                .literal = expressions.Literal{
                    .array = elements.*,
                },
            };
        }

        if (self.match(&[_]TokenType{ .Integer, .Float, .String, .Identifier, .Boolean, .Null })) {
            const token = self.previous();

            return switch (token.token_type) {
                .Identifier => Expression{
                    .identifier = expressions.Identifier{
                        .name = token.value,
                    },
                },
                .Integer, .Float => Expression{
                    .literal = try expressions.Literal.number_from_string(token.value),
                },
                .String => Expression{
                    .literal = expressions.Literal{
                        .string = token.value,
                    },
                },
                .Boolean => Expression{
                    .literal = expressions.Literal{
                        .boolean = std.mem.eql(u8, token.value, "true"),
                    },
                },
                .Null => Expression{
                    .literal = expressions.Literal{
                        .null = null,
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

        std.debug.panic("Unexpected token: {s} ({})", .{ self.peek().value, self.peek().token_type });
    }
};
