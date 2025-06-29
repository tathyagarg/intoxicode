const std = @import("std");
const _tokens = @import("../lexer/tokens.zig");

const Token = _tokens.Token;
const TokenType = _tokens.TokenType;

pub const node = @import("node.zig");

fn get_respective_node_type(token_type: TokenType) node.NodeType {
    return switch (token_type) {
        .Identifier => .Identifier,
        .Integer, .Float, .String => .Literal,
        .Plus, .Minus, .Multiply, .Divide, .Equal, .NotEqual, .LessThan, .GreaterThan => node.NodeType.Operator,
        else => .Keyword,
    };
}

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    program: node.Program,

    allocator: std.mem.Allocator,

    pub fn init(tokens: std.ArrayList(Token), allocator: std.mem.Allocator) Parser {
        return Parser{
            .tokens = tokens,
            .program = node.Program.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.program.deinit();
    }

    pub fn parse(self: *Parser) !void {
        while (self.tokens.items.len > 0) {
            const token = self.tokens.items[0];

            if (self.program.statements.items.len == 0) {
                const new_statement = try self.allocator.create(node.Statement);
                new_statement.* = node.Statement.init(self.allocator);

                try self.program.statements.append(new_statement);
            }
            var curr_statement = self.program.statements.items[self.program.statements.items.len - 1];

            switch (token.token_type) {
                .Period => |_| {
                    curr_statement.certainty = 1.0;

                    const new_statement = try self.allocator.create(node.Statement);
                    new_statement.* = node.Statement.init(self.allocator);

                    try self.program.statements.append(new_statement);
                },
                .EOF => |_| {
                    curr_statement.certainty = 0.0;

                    const new_node = try self.allocator.create(node.Node);
                    new_node.* = node.Node.init(self.allocator, node.NodeType.EOF, null);

                    try curr_statement.add_child(new_node);
                },
                else => {
                    const node_type = get_respective_node_type(token.token_type);

                    const new_node = try self.allocator.create(node.Node);
                    new_node.* = node.Node.init(self.allocator, node_type, token.value);

                    try curr_statement.add_child(new_node);
                },
            }
            _ = self.tokens.orderedRemove(0);
        }
    }
};
