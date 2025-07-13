const std = @import("std");

const Statement = @import("../parser/parser.zig").statements.Statement;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;
const Identifier = @import("../parser/parser.zig").expressions.Identifier;
const Call = @import("../parser/parser.zig").expressions.Call;

const StdFunction = *const fn (Runner, []Expression) anyerror!Expression;

const stdlib = @import("stdlib.zig");

const FeatureFlags = struct {
    uncertainty: bool = true,
    repitition: bool = true,
};

const WEIGHT_ARRAY = [_]u8{ 1, 1, 1, 1, 1, 2, 2, 2, 3 };
const WEIGHT_LENGTH = WEIGHT_ARRAY.len;

pub const Runner = struct {
    allocator: std.mem.Allocator,
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,

    variables: *std.StringHashMap(Expression),
    functions: *std.StringHashMap(Statement),
    statements: []*Statement,

    std_functions: std.StringHashMap(StdFunction),

    certain_count: *usize,
    max_certains_available: usize,

    features: *FeatureFlags,

    pub fn init(
        allocator: std.mem.Allocator,
        stdout: std.io.AnyWriter,
        stderr: std.io.AnyWriter,
        statements: []*Statement,
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
        std_functions.putNoClobber("to_string", stdlib.to_string) catch unreachable;

        const certain_count = try allocator.create(usize);
        certain_count.* = 0;

        const features = try allocator.create(FeatureFlags);
        features.* = .{};

        return Runner{
            .allocator = allocator,

            .variables = variables,
            .functions = functions,
            .statements = statements,

            .stdout = stdout,
            .stderr = stderr,
            .std_functions = std_functions,

            .certain_count = certain_count,
            .max_certains_available = @max(2, statements.len / 4),

            .features = features,
        };
    }

    pub fn run(self: Runner) !void {
        _ = try self.run_snippet(self.statements, self.variables);
    }

    fn calculate_certainty(self: Runner, statement: Statement) !f32 {
        if (!self.features.uncertainty) {
            return 1.0;
        }
        var certainty = try statement.get_certainty();
        if (certainty == 1) {
            if (self.certain_count.* >= self.max_certains_available) {
                certainty = 0.75;
            } else {
                self.certain_count.* = self.certain_count.* + 1;
            }
        }

        return certainty;
    }

    fn run_snippet(self: Runner, statements: []*Statement, variables: *std.StringHashMap(Expression)) !?Expression {
        for (statements) |statement| {
            const certainty = try self.calculate_certainty(statement.*);
            const roll = std.crypto.random.float(f32);

            if ((roll <= certainty) or !self.features.uncertainty) {
                const repetition: u8 = if (!self.features.repitition)
                    1
                else
                    WEIGHT_ARRAY[std.crypto.random.intRangeAtMost(u8, 0, WEIGHT_LENGTH - 1)];

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
                                return try self.run_snippet(if_stmt.then_branch.items, variables);
                            } else if (if_stmt.else_branch) |else_branch| {
                                return try self.run_snippet(else_branch.items, variables);
                            }
                        },
                        .function_declaration => |func_decl| {
                            try self.functions.put(func_decl.name, statement.*);
                        },
                        .throwaway_statement => |throwaway| {
                            return try self.evaluate_expression(throwaway.expression, variables);
                        },
                        .try_statement => |try_stmt| {
                            if (self.run_snippet(try_stmt.body.items, variables) catch {
                                if (try self.run_snippet(try_stmt.catch_block.items, variables)) |catch_result| {
                                    return catch_result;
                                }

                                return null;
                            }) |result| {
                                return result;
                            }
                        },
                        .loop_statement => |loop_stmt| {
                            while (true) {
                                const condition = try self.evaluate_expression(loop_stmt.condition, variables);
                                if (!condition.literal.boolean) {
                                    break;
                                }
                                if (try self.run_snippet(loop_stmt.body.items, variables)) |result| {
                                    return result;
                                }
                            }
                        },
                        .directive => |directive| {
                            const target = directive.name;

                            if (std.mem.eql(u8, target, "uncertainty")) {
                                self.features.uncertainty = false;
                            } else if (std.mem.eql(u8, target, "repitition")) {
                                self.features.repitition = false;
                            } else if (std.mem.eql(u8, target, "all")) {
                                self.features.uncertainty = false;
                                self.features.repitition = false;
                            } else {
                                try self.stderr.print("Unknown directive: {s}\n", .{target});
                                std.process.exit(1);
                            }
                        },
                        // else => {},
                    }
                }
            }
        }
        return null;
    }

    pub fn evaluate_expression(
        self: Runner,
        expr: Expression,
        variables: *std.StringHashMap(Expression),
    ) anyerror!Expression {
        return switch (expr) {
            .literal => switch (expr.literal) {
                .array => |array| {
                    for (array.items, 0..) |item, index| {
                        array.items[index] = try self.evaluate_expression(item, variables);
                    }
                    return Expression{
                        .literal = Literal{
                            .array = array,
                        },
                    };
                },
                else => return expr,
            },
            .indexing => |indexing| {
                const array_expr = try self.evaluate_expression(indexing.array.*, variables);
                const index_expr = try self.evaluate_expression(indexing.index.*, variables);

                const array = array_expr.literal.array;
                const index = @as(usize, @intFromFloat(index_expr.literal.number));

                if (index < array.items.len) {
                    return Expression{
                        .literal = array.items[index].literal,
                    };
                } else {
                    try self.stderr.print("Index out of bounds: {d} for array of length {d}\n", .{
                        index,
                        array.items.len,
                    });
                    std.process.exit(1);
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

                try self.stderr.print("Undefined variable: {s}\n", .{id.name});
                std.process.exit(1);
            },
            .binary => |binary| {
                const left = try self.evaluate_expression(binary.left.*, variables);
                const right = try self.evaluate_expression(binary.right.*, variables);

                return switch (binary.operator.token_type) {
                    .Plus => switch (left.literal) {
                        .number => Expression{
                            .literal = Literal{
                                .number = left.literal.number + right.literal.number,
                            },
                        },
                        .string => Expression{
                            .literal = Literal{
                                .string = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{
                                    left.literal.string,
                                    right.literal.string,
                                }),
                            },
                        },
                        else => {
                            try self.stderr.print("Invalid left operand for '+' operator: {s}\n", .{try left.literal.to_string(self.allocator, self)});
                            std.process.exit(1);
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
                            try self.stderr.print("Division by zero error\n", .{});
                            std.process.exit(1);
                        }
                        return Expression{
                            .literal = Literal{
                                .number = left.literal.number / right.literal.number,
                            },
                        };
                    },
                    .Modulo => {
                        if (right.literal.number == 0) {
                            try self.stderr.print("Modulo by zero error\n", .{});
                            std.process.exit(1);
                        }
                        return Expression{
                            .literal = Literal{
                                .number = @mod(left.literal.number, right.literal.number),
                            },
                        };
                    },
                    .Equal => Expression{
                        .literal = Literal{
                            .boolean = try left.equals(right, self),
                        },
                    },
                    .NotEqual => Expression{
                        .literal = Literal{
                            .boolean = !try left.equals(right, self),
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
                    else => {
                        try self.stderr.print("Invalid binary operator: {}\n", .{binary.operator.token_type});
                        std.process.exit(1);
                    }
                };
            },
            .grouping => |group| {
                return try self.evaluate_expression(group.expression.*, variables);
            },
            .call => |call| {
                return try self.call_function(call, variables);
            },
        };
    }

    fn call_function(
        self: Runner,
        call: Call,
        variables: *std.StringHashMap(Expression),
    ) !Expression {
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
                    try self.stderr.print("Undefined function: {s}\n", .{id.name});
                    std.process.exit(1);
                }
            },
            else => {
                try self.stderr.print("Invalid function call: {s}\n", .{try callee.literal.to_string(self.allocator, self)});
                std.process.exit(1);
            }
        }
    }

    fn run_function(self: Runner, func: Statement, args: []Expression) anyerror!Expression {
        const func_decl = func.function_declaration;

        if (args.len != func_decl.parameters.items.len) {
            try self.stderr.print("Function '{s}' expects {d} arguments, got {d}\n", .{
                func_decl.name,
                func_decl.parameters.items.len,
                args.len,
            });
            std.process.exit(1);
        }

        var local_vars = std.StringHashMap(Expression).init(self.allocator);
        defer local_vars.deinit();

        for (0..args.len) |i| {
            try local_vars.put(func_decl.parameters.items[i], args[i]);
        }

        // Run the function body
        if (try self.run_snippet(func_decl.body.items, &local_vars)) |result|
            return result;

        return Expression{
            .literal = Literal{
                .null = null,
            },
        };
    }
};
