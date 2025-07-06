const std = @import("std");

const Statement = @import("../parser/parser.zig").statements.Statement;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;

const StdFunction = *const fn (Runner, []Expression) anyerror!Expression;

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
        std_functions.putNoClobber("scream", scream) catch unreachable;
        std_functions.putNoClobber("abs", abs) catch unreachable;
        std_functions.putNoClobber("min", min) catch unreachable;
        std_functions.putNoClobber("max", max) catch unreachable;

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
                        const arguments: []Expression = if (call.arguments) |args|
                            args.items
                        else
                            &.{};

                        if (self.std_functions.get(id.name)) |func| {
                            return try func(self, arguments);
                        } else {
                            return error.FunctionNotFound;
                        }
                    },
                    else => return error.InvalidFunctionCall,
                }
            },
        };
    }

    fn scream(self: Runner, args: []Expression) anyerror!Expression {
        var output = std.ArrayList(u8).init(self.allocator);
        for (args) |arg| {
            const evaluated = try self.evaluate_expression(arg);
            try output.appendSlice(try evaluated.literal.to_string(self.allocator));
        }
        try self.stdout.writeAll(output.items);

        return Expression{
            .literal = Literal{
                .null = null,
            },
        };
    }

    fn abs(self: Runner, args: []Expression) anyerror!Expression {
        if (args.len != 1) {
            return error.InvalidArgumentCount;
        }

        const arg = try self.evaluate_expression(args[0]);
        if (arg.literal.number < 0) {
            return Expression{
                .literal = Literal{
                    .number = -arg.literal.number,
                },
            };
        } else {
            return arg;
        }
    }

    fn min(self: Runner, args: []Expression) anyerror!Expression {
        if (args.len == 0) {
            return error.InvalidArgumentCount;
        }

        var min_value: ?f64 = null;
        for (args) |arg| {
            const evaluated = try self.evaluate_expression(arg);
            if (min_value == null or evaluated.literal.number < min_value.?) {
                min_value = evaluated.literal.number;
            }
        }

        return Expression{
            .literal = Literal{
                .number = min_value.?,
            },
        };
    }

    fn max(self: Runner, args: []Expression) anyerror!Expression {
        if (args.len == 0) {
            return error.InvalidArgumentCount;
        }

        var max_value: ?f64 = null;
        for (args) |arg| {
            const evaluated = try self.evaluate_expression(arg);
            if (max_value == null or evaluated.literal.number > max_value.?) {
                max_value = evaluated.literal.number;
            }
        }

        return Expression{
            .literal = Literal{
                .number = max_value.?,
            },
        };
    }
};
