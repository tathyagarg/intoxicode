const std = @import("std");

const Statement = @import("../parser/parser.zig").statements.Statement;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;
const Identifier = @import("../parser/parser.zig").expressions.Identifier;

const StdFunction = *const fn (Runner, []Expression) anyerror!Expression;

const stdlib = @import("stdlib.zig");

pub const Runner = struct {
    allocator: std.mem.Allocator,
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,

    variables: *std.StringHashMap(Expression),
    functions: *std.StringHashMap(Statement),

    std_functions: std.StringHashMap(StdFunction),

    pub fn init(
        allocator: std.mem.Allocator,
        stdout: std.io.AnyWriter,
        stderr: std.io.AnyWriter,
    ) !Runner {
        const variables = try allocator.create(std.StringHashMap(Expression));
        variables.* = std.StringHashMap(Expression).init(allocator);

        const functions = try allocator.create(std.StringHashMap(Statement));
        functions.* = std.StringHashMap(Statement).init(allocator);

        var std_functions = std.StringHashMap(StdFunction).init(allocator);
        std_functions.putNoClobber("scream", stdlib.scream) catch unreachable;
        std_functions.putNoClobber("abs", stdlib.abs) catch unreachable;
        std_functions.putNoClobber("min", stdlib.min) catch unreachable;
        std_functions.putNoClobber("max", stdlib.max) catch unreachable;
        std_functions.putNoClobber("pow", stdlib.pow) catch unreachable;
        std_functions.putNoClobber("sqrt", stdlib.sqrt) catch unreachable;
        std_functions.putNoClobber("length", stdlib.length) catch unreachable;

        return Runner{
            .allocator = allocator,
            .variables = variables,
            .functions = functions,
            .stdout = stdout,
            .stderr = stderr,
            .std_functions = std_functions,
        };
    }

    pub fn deinit(self: Runner) void {
        self.variables.deinit();
    }

    pub fn run(self: Runner, statements: []*Statement, variables: *std.StringHashMap(Expression)) !?Expression {
        for (statements) |statement| {
            const certainty = try statement.get_certainty();
            const roll = std.crypto.random.float(f32);

            if (roll <= certainty) {
                const repetition = std.math.log10(std.math.maxInt(u16)) - std.math.log10(std.crypto.random.int(u16)) + 1;

                for (0..repetition) |_| {
                    switch (statement.*) {
                        .assignment => |assignment| {
                            const key = assignment.identifier;
                            const value = try self.evaluate_expression(assignment.expression, variables);

                            try variables.put(key, value);
                        },
                        .expression => |expr| {
                            _ = try self.evaluate_expression(expr, variables);
                        },
                        .if_statement => |if_stmt| {
                            const condition = try self.evaluate_expression(if_stmt.condition, variables);
                            if (condition.literal.boolean) {
                                _ = try self.run(if_stmt.then_branch.items, variables);
                            } else if (if_stmt.else_branch) |else_branch| {
                                _ = try self.run(else_branch.items, variables);
                            }
                        },
                        .function_declaration => |func_decl| {
                            const key = func_decl.name;

                            // if (self.functions.get(key) == null) {
                            try self.functions.put(key, statement.*);
                            // } else {
                            //     return error.FunctionAlreadyExists;
                            // }
                        },
                        .throwaway_statement => |throwaway| {
                            return try self.evaluate_expression(throwaway.expression, variables);
                        },
                        .try_statement => |try_stmt| {
                            if (self.run(try_stmt.body.items, variables) catch {
                                if (try self.run(try_stmt.catch_block.items, variables)) |catch_result| {
                                    return catch_result;
                                }

                                return null;
                            }) |result| {
                                return result;
                            }
                        },
                        else => {},
                    }
                }
            }
        }
        return null;
    }

    fn evaluate_expression(self: Runner, expr: Expression, variables: *std.StringHashMap(Expression)) anyerror!Expression {
        return switch (expr) {
            .literal => expr,
            .indexing => |indexing| {
                const array_expr = try self.evaluate_expression(indexing.array.*, variables);
                const index_expr = try self.evaluate_expression(indexing.index.*, variables);

                const array = array_expr.literal.array;
                const index = @as(usize, @intFromFloat(index_expr.literal.number));

                if (index < array.items.len) {
                    return Expression{
                        .literal = (try self.evaluate_expression(array.items[index], variables)).literal,
                    };
                } else {
                    return error.IndexOutOfBounds;
                }
            },
            .identifier => |id| {
                if (variables.get(id.name)) |value| {
                    return value;
                } else if (self.std_functions.get(id.name) != null) {
                    return expr;
                } else if (self.functions.get(id.name) != null) {
                    return Expression{
                        .identifier = Identifier{
                            .name = id.name,
                        },
                    };
                }

                return error.VariableNotFound;
            },
            .binary => |binary| {
                const left = try self.evaluate_expression(binary.left.*, variables);
                const right = try self.evaluate_expression(binary.right.*, variables);

                return switch (binary.operator.token_type) {
                    .Plus => Expression{
                        .literal = Literal{
                            .number = left.literal.number + right.literal.number,
                        },
                    },
                    .Minus => Expression{
                        .literal = Literal{
                            .number = left.literal.number - right.literal.number,
                        },
                    },
                    .Multiply => Expression{
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
                    .Equal => Expression{
                        .literal = Literal{
                            .boolean = left.literal.number == right.literal.number,
                        },
                    },
                    .NotEqual => Expression{
                        .literal = Literal{
                            .boolean = left.literal.number != right.literal.number,
                        },
                    },
                    .GreaterThan => Expression{
                        .literal = Literal{
                            .boolean = left.literal.number > right.literal.number,
                        },
                    },
                    .LessThan => Expression{
                        .literal = Literal{
                            .boolean = left.literal.number < right.literal.number,
                        },
                    },
                    .Or => Expression{
                        .literal = Literal{
                            .boolean = left.literal.boolean or right.literal.boolean,
                        },
                    },
                    .And => Expression{
                        .literal = Literal{
                            .boolean = left.literal.boolean and right.literal.boolean,
                        },
                    },
                    else => return error.InvalidBinaryOperation,
                };
            },
            .grouping => |group| {
                return try self.evaluate_expression(group.expression.*, variables);
            },
            .call => |call| {
                const callee = try self.evaluate_expression(call.callee.*, variables);
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
                                const evaluated = try self.evaluate_expression(arg, variables);
                                try arguments.append(evaluated);
                            }
                        }

                        if (self.std_functions.get(id.name)) |func| {
                            return try func(self, arguments.items);
                        } else if (self.functions.get(id.name)) |func_stmt| {
                            return try self.run_function(func_stmt, arguments.items);
                        } else {
                            return error.FunctionNotFound;
                        }
                    },
                    else => return error.InvalidFunctionCall,
                }
            },
        };
    }

    fn run_function(self: Runner, func: Statement, args: []Expression) anyerror!Expression {
        const func_decl = func.function_declaration;

        if (args.len != func_decl.parameters.items.len) {
            return error.InvalidFunctionArguments;
        }

        var local_vars = std.StringHashMap(Expression).init(self.allocator);
        defer local_vars.deinit();

        for (0..args.len) |i| {
            try local_vars.put(func_decl.parameters.items[i], args[i]);
        }

        // Run the function body
        if (try self.run(func_decl.body.items, &local_vars)) |result|
            return result;

        return Expression{
            .literal = Literal{
                .null = null,
            },
        };
    }
};
