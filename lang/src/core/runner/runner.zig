const std = @import("std");

const Statement = @import("../parser/parser.zig").statements.Statement;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;
const Identifier = @import("../parser/parser.zig").expressions.Identifier;
const Call = @import("../parser/parser.zig").expressions.Call;

const StdFunction = *const fn (Runner, []*Expression) anyerror!Expression;

const stdlib = @import("stdlib.zig");

const FeatureFlags = struct {
    uncertainty: bool = true,
    repitition: bool = true,
};

const run_file = @import("../full_run.zig").run_file;

const WEIGHT_ARRAY = [_]u8{ 1, 1, 1, 1, 1, 2, 2, 2, 3 };
const WEIGHT_LENGTH = WEIGHT_ARRAY.len;

var std_functions = std.StaticStringMap(StdFunction).initComptime(.{
    .{ "scream", stdlib.scream },
    .{ "abs", stdlib.abs },
    .{ "min", stdlib.min },
    .{ "max", stdlib.max },
    .{ "pow", stdlib.pow },
    .{ "sqrt", stdlib.sqrt },
    .{ "length", stdlib.length },
    .{ "to_string", stdlib.to_string },
    .{ "to_number", stdlib.to_number },
    .{ "is_digit", stdlib.is_digit },
    .{ "chr", stdlib.chr },
    .{ "append", stdlib.append },
    .{ "insert", stdlib.insert },
    .{ "remove", stdlib.remove },
    .{ "find_first", stdlib.find_first },
    .{ "find_last", stdlib.find_last },
    .{ "update", stdlib.update },
    .{ "sin", stdlib.sin },
    .{ "cos", stdlib.cos },
});

pub const Runner = struct {
    allocator: std.mem.Allocator,
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,

    variables: *std.StringHashMap(*Expression),
    functions: *std.StringHashMap(Statement),
    statements: []*Statement,

    certain_count: *usize,
    max_certains_available: usize,

    features: *FeatureFlags,

    location: []const u8,

    exports: *std.StringHashMap(Statement),

    pub fn init(
        allocator: std.mem.Allocator,
        stdout: std.io.AnyWriter,
        stderr: std.io.AnyWriter,
        statements: []*Statement,
        location: []const u8,
    ) !Runner {
        const variables = try allocator.create(std.StringHashMap(*Expression));
        variables.* = std.StringHashMap(*Expression).init(allocator);

        const functions = try allocator.create(std.StringHashMap(Statement));
        functions.* = std.StringHashMap(Statement).init(allocator);

        const exports = try allocator.create(std.StringHashMap(Statement));
        exports.* = std.StringHashMap(Statement).init(allocator);

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

            .certain_count = certain_count,
            .max_certains_available = @max(2, statements.len / 4),

            .features = features,

            .exports = exports,
            .location = location,
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

    fn run_snippet(self: Runner, statements: []*Statement, variables: *std.StringHashMap(*Expression)) !?Expression {
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
                            const value = try self.allocator.create(Expression);
                            value.* = try self.evaluate_expression(assignment.expression, variables);

                            if (variables.getPtr(key)) |existing| {
                                existing.*.* = value.*;
                            } else {
                                try variables.put(key, value);
                            }
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
                            } else if (std.mem.eql(u8, target, "export")) {
                                for (directive.arguments.?.items) |arg| {
                                    if (self.functions.get(arg)) |func_stmt| {
                                        try self.exports.put(arg, func_stmt);
                                    } else {
                                        try self.stderr.print("Function '{s}' not found for export\n", .{arg});
                                        std.process.exit(1);
                                    }
                                }
                            } else if (std.mem.eql(u8, target, "import")) {
                                const dirname = std.fs.path.dirname(try std.fs.cwd().realpathAlloc(self.allocator, self.location)) orelse ".";
                                const import_target = directive.arguments.?.items[0];

                                var imported_file = try self.allocator.alloc(u8, dirname.len + import_target.len + 1); // self.location.dirname().?; // directive.arguments.?.items[0];

                                @memcpy(imported_file[0..dirname.len], dirname);
                                @memcpy(imported_file[dirname.len .. dirname.len + 1], "/");
                                @memcpy(imported_file[dirname.len + 1 ..], import_target);

                                var sub_runner: Runner = undefined;

                                if (!std.mem.eql(u8, imported_file[imported_file.len - 3 .. imported_file.len], ".??")) {
                                    var target_file = try self.allocator.alloc(u8, imported_file.len + "/huh.??".len);

                                    @memcpy(target_file[0..imported_file.len], imported_file);
                                    @memcpy(target_file[imported_file.len..], "/huh.??");

                                    imported_file = target_file;
                                }

                                sub_runner = try run_file(self.allocator, imported_file);
                                var export_iterator = sub_runner.exports.iterator();

                                while (export_iterator.next()) |exported| {
                                    if (self.exports.get(exported.key_ptr.*) != null) {
                                        try self.stderr.print(
                                            "Export '{s}' already exists, cannot import again\n",
                                            .{exported.key_ptr.*},
                                        );
                                        std.process.exit(1);
                                    }
                                    try self.functions.put(exported.key_ptr.*, exported.value_ptr.*);
                                }
                            } else {
                                try self.stderr.print("Unknown directive: {s}\n", .{target});
                                std.process.exit(1);
                            }
                        },
                        .repeat_statement => |repeat_stmt| {
                            const name = repeat_stmt.variable;

                            const count = try self.evaluate_expression(repeat_stmt.count, variables);
                            if (count.literal != .number) {
                                try self.stderr.print(
                                    "Repeat count must be a number, got: {s}\n",
                                    .{try count.literal.to_string(self.allocator, self)},
                                );
                                std.process.exit(1);
                            }

                            const repeat_count = @as(usize, @intFromFloat(count.literal.number));
                            if (repeat_count == 0) {
                                continue;
                            }

                            const name_expr = try self.allocator.create(Expression);
                            name_expr.* = Expression{
                                .literal = Literal{
                                    .number = @floatFromInt(0),
                                },
                            };

                            for (0..repeat_count) |i| {
                                if (variables.getPtr(name)) |existing| {
                                    existing.*.* = Expression{
                                        .literal = Literal{
                                            .number = @floatFromInt(i),
                                        },
                                    };
                                }

                                if (try self.run_snippet(repeat_stmt.body.items, variables)) |result| {
                                    return result;
                                }
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
        variables: *std.StringHashMap(*Expression),
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
                    return value.*;
                } else if (std_functions.get(id.name) != null) {
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
                    },
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
        variables: *std.StringHashMap(*Expression),
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
                var arguments: std.ArrayList(*Expression) = std.ArrayList(*Expression).init(self.allocator);

                if (call.arguments != null) {
                    for (call.arguments.?.items) |arg| {
                        switch (arg) {
                            .identifier => |idtfr| {
                                if (variables.get(idtfr.name)) |value| {
                                    try arguments.append(value);
                                } else {
                                    try self.stderr.print("Undefined variable: {s}\n", .{idtfr.name});
                                    std.process.exit(1);
                                }
                            },
                            else => |expr| {
                                const tmp = try self.allocator.create(Expression);
                                tmp.* = try self.evaluate_expression(expr, variables);
                                try arguments.append(tmp);
                            },
                        }
                    }
                }

                if (std_functions.get(id.name)) |func| {
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
            },
        }
    }

    fn run_function(self: Runner, func: Statement, args: []*Expression) anyerror!Expression {
        const func_decl = func.function_declaration;

        if (args.len != func_decl.parameters.items.len) {
            try self.stderr.print("Function '{s}' expects {d} arguments, got {d}\n", .{
                func_decl.name,
                func_decl.parameters.items.len,
                args.len,
            });
            std.process.exit(1);
        }

        var local_vars = std.StringHashMap(*Expression).init(self.allocator);
        defer local_vars.deinit();

        for (0..args.len) |i| {
            try local_vars.put(func_decl.parameters.items[i], args[i]);
        }

        if (try self.run_snippet(func_decl.body.items, &local_vars)) |result|
            return result;

        return Expression{
            .literal = Literal{
                .null = null,
            },
        };
    }
};
