const std = @import("std");

const Statement = @import("../parser/parser.zig").statements.Statement;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;

const StdFunction = *const fn (Runner, []Expression) anyerror!Expression;

const stdlib = @import("stdlib.zig");

pub const Runner = struct {
    allocator: std.mem.Allocator,
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,

    variables: *std.StringHashMap(Expression),

    std_functions: std.StringHashMap(StdFunction),

    pub fn init(
        allocator: std.mem.Allocator,
        stdout: std.io.AnyWriter,
        stderr: std.io.AnyWriter,
    ) !Runner {
        const variables = try allocator.create(std.StringHashMap(Expression));
        variables.* = std.StringHashMap(Expression).init(allocator);

        var std_functions = std.StringHashMap(StdFunction).init(allocator);
        std_functions.putNoClobber("scream", stdlib.scream) catch unreachable;
        std_functions.putNoClobber("abs", stdlib.abs) catch unreachable;
        std_functions.putNoClobber("min", stdlib.min) catch unreachable;
        std_functions.putNoClobber("max", stdlib.max) catch unreachable;
        std_functions.putNoClobber("pow", stdlib.pow) catch unreachable;

        return Runner{
            .allocator = allocator,
            .variables = variables,
            .stdout = stdout,
            .stderr = stderr,
            .std_functions = std_functions,
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
                .if_statement => |if_stmt| {
                    const condition = try self.evaluate_expression(if_stmt.condition);
                    if (condition.literal.boolean) {
                        try self.run(if_stmt.then_branch.items);
                    } else if (if_stmt.else_branch) |else_branch| {
                        try self.run(else_branch.items);
                    }
                },
                else => {},
            }
        }
    }

    fn evaluate_expression(self: Runner, expr: Expression) anyerror!Expression {
        return switch (expr) {
            .literal => {
                return expr;
            },
            .identifier => |id| {
                if (self.variables.get(id.name)) |value| {
                    return value;
                } else {
                    if (self.std_functions.get(id.name) != null) {
                        return expr;
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
                    .Equal => return Expression{
                        .literal = Literal{
                            .boolean = left.literal.number == right.literal.number,
                        },
                    },
                    .NotEqual => return Expression{
                        .literal = Literal{
                            .boolean = left.literal.number != right.literal.number,
                        },
                    },
                    .GreaterThan => return Expression{
                        .literal = Literal{
                            .boolean = left.literal.number > right.literal.number,
                        },
                    },
                    .LessThan => return Expression{
                        .literal = Literal{
                            .boolean = left.literal.number < right.literal.number,
                        },
                    },
                    .Or => return Expression{
                        .literal = Literal{
                            .boolean = left.literal.boolean or right.literal.boolean,
                        },
                    },
                    .And => return Expression{
                        .literal = Literal{
                            .boolean = left.literal.boolean and right.literal.boolean,
                        },
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
                            .literal = Literal{
                                .null = null,
                            },
                        };
                    },
                    .identifier => |id| {
                        var arguments: std.ArrayList(Expression) = std.ArrayList(Expression).init(self.allocator);

                        if (call.arguments != null) {
                            for (call.arguments.?.items) |arg| {
                                const evaluated = try self.evaluate_expression(arg);
                                try arguments.append(evaluated);
                            }
                        }

                        if (self.std_functions.get(id.name)) |func| {
                            return try func(self, arguments.items);
                        } else {
                            return error.FunctionNotFound;
                        }
                    },
                    else => return error.InvalidFunctionCall,
                }
            },
        };
    }
};
