const std = @import("std");

const Statement = @import("../parser/parser.zig").statements.Statement;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;

const std_functions = [_][]const u8{
    "scream",
};

pub const Runner = struct {
    allocator: std.mem.Allocator,
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,

    variables: *std.StringHashMap(Expression),

    pub fn init(
        allocator: std.mem.Allocator,
        stdout: std.io.AnyWriter,
        stderr: std.io.AnyWriter,
    ) !Runner {
        const variables = try allocator.create(std.StringHashMap(Expression));
        variables.* = std.StringHashMap(Expression).init(allocator);

        return Runner{
            .allocator = allocator,
            .variables = variables,
            .stdout = stdout,
            .stderr = stderr,
        };
    }

    pub fn deinit(self: Runner) void {
        self.variables.deinit();
    }

    pub fn run(self: Runner, statements: []*Statement) !void {
        for (statements) |statement| {
            switch (statement.*) {
                .assignment => |assignment| {
                    const key = assignment.identifier;
                    const value = try self.evaluate_expression(assignment.expression);

                    try self.variables.put(key, value);
                },
                .expression => |expr| {
                    _ = try self.evaluate_expression(expr);
                },
                else => {},
            }
        }
    }

    fn evaluate_expression(self: Runner, expr: Expression) !Expression {
        return switch (expr) {
            .literal => {
                return expr;
            },
            .identifier => |id| {
                if (self.variables.get(id.name)) |value| {
                    return value;
                } else {
                    for (std_functions) |func| {
                        if (std.mem.eql(u8, id.name, func)) {
                            return expr;
                        }
                    }

                    return error.VariableNotFound;
                }
            },
            .binary => |binary| {
                const left = try self.evaluate_expression(binary.left.*);
                const right = try self.evaluate_expression(binary.right.*);

                switch (binary.operator.token_type) {
                    .Plus => return Expression{
                        .literal = Literal{
                            .number = left.literal.number + right.literal.number,
                        },
                    },
                    .Minus => return Expression{
                        .literal = Literal{
                            .number = left.literal.number - right.literal.number,
                        },
                    },
                    .Multiply => return Expression{
                        .literal = Literal{
                            .number = left.literal.number * right.literal.number,
                        },
                    },
                    .Divide => {
                        if (right.literal.number == 0) {
                            return error.DivisionByZero;
                        }
                        return Expression{
                            .literal = Literal{
                                .number = left.literal.number / right.literal.number,
                            },
                        };
                    },
                    else => return error.InvalidBinaryOperation,
                }
            },
            .grouping => |group| {
                return try self.evaluate_expression(group.expression.*);
            },
            .call => |call| {
                const callee = try self.evaluate_expression(call.callee.*);
                switch (callee) {
                    .literal => {
                        return Expression{
                            .null = null,
                        };
                    },
                    .identifier => |id| {
                        if (std.mem.eql(u8, id.name, "scream")) {
                            var output = std.ArrayList(u8).init(self.allocator);

                            if (call.arguments != null) {
                                for (call.arguments.?.items) |arg| {
                                    const evaluated = try self.evaluate_expression(arg);
                                    try output.appendSlice(try evaluated.literal.to_string(self.allocator));
                                }
                            }

                            try self.stdout.writeAll(output.items);
                            return Expression{
                                .null = null,
                            };
                        } else {
                            return error.UnknownFunction;
                        }
                    },
                    else => return error.InvalidFunctionCall,
                }
            },
            .null => expr,
        };
    }
};
