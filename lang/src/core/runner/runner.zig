const std = @import("std");

const Statement = @import("../parser/parser.zig").statements.Statement;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;
const Identifier = @import("../parser/parser.zig").expressions.Identifier;
const Call = @import("../parser/parser.zig").expressions.Call;
const CustomType = @import("../parser/parser.zig").expressions.CustomType;
const Custom = @import("../parser/parser.zig").expressions.Custom;
const LiteralType = @import("../parser/parser.zig").expressions.LiteralType;

const StdFunction = *const fn (Runner, []*Expression) anyerror!Expression;
const Module = @import("modules/mod.zig").Module;

const stdlib = @import("stdlib.zig");

const FeatureFlags = struct {
    uncertainty: bool = true,
    repitition: bool = true,
};

const run_file = @import("../full_run.zig").run_file;

const WEIGHT_ARRAY = [_]u8{ 1, 1, 1, 1, 1, 2, 2, 2, 3 };
const WEIGHT_LENGTH = WEIGHT_ARRAY.len;

const std_functions = std.StaticStringMap(StdFunction).initComptime(.{
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
    .{ "ord", stdlib.ord },
    .{ "append", stdlib.append },
    .{ "insert", stdlib.insert },
    .{ "remove", stdlib.remove },
    .{ "find_first", stdlib.find_first },
    .{ "find_last", stdlib.find_last },
    .{ "update", stdlib.update },
    .{ "strip_last_n", stdlib.strip_last_n },
    .{ "sin", stdlib.sin },
    .{ "cos", stdlib.cos },
});

const std_modules = std.StaticStringMap(Module).initComptime(.{
    .{ "socket", @import("modules/socket.zig").Socket },
    .{ "fs", @import("modules/fs.zig").Fs },
    .{ "http", @import("modules/http.zig").Http },
});

pub fn require(
    arg_count: usize,
    dtypes: []const []const std.meta.Tag(Literal),
    func_name: []const u8,
    runner: Runner,
    arguments: []*Expression,
) anyerror!void {
    if (arguments.len != arg_count) {
        try runner.stderr.print("{s}() requires exactly {} argument(s), got {}\n", .{ func_name, arg_count, arguments.len });
        std.process.exit(1);
    }

    for (arguments, 0..) |arg, i| {
        for (dtypes[i]) |dtype| {
            if (arg.literal == dtype) {
                break;
            }
        } else {
            try runner.stderr.print("Argument {} of {s} must be one of: \n", .{
                i + 1,
                func_name,
            });
            for (dtypes[i]) |dtype| {
                try runner.stderr.print("  - {s}\n", .{@tagName(dtype)});
            }
            std.process.exit(1);
        }
    }
}

pub const Handler = *const fn (runner: Runner, args: []*Expression) anyerror!Expression;

pub const Runner = struct {
    allocator: std.mem.Allocator,
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,

    variables: *std.StringHashMap(*Expression),
    modules: *std.StringHashMap(Module),
    functions: *std.StringHashMap(Statement),
    customs: *std.StringHashMap(CustomType),
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

        const modules = try allocator.create(std.StringHashMap(Module));
        modules.* = std.StringHashMap(Module).init(allocator);

        const customs = try allocator.create(std.StringHashMap(CustomType));
        customs.* = std.StringHashMap(CustomType).init(allocator);

        // const zig_functions = try allocator.create(std.StringHashMap(Handler));
        // zig_functions.* = std.StringHashMap(Handler).init(allocator);

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
            .modules = modules,
            .customs = customs,
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
                            try self.functions.put(func_decl.name(), statement.*);
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

                                if (std_modules.get(import_target)) |mod| {
                                    try self.modules.put(mod.name, mod);

                                    for (mod.functions.kvs.keys, 0..mod.functions.kvs.len) |key, _| {
                                        _ = .{key};
                                        // try self.zig_functions.put(try std.mem.join(self.allocator, "_", &.{ mod.name, key }), mod.functions.get(key).?);
                                    }

                                    for (mod.constants.kvs.keys, 0..mod.constants.kvs.len) |key, _| {
                                        const value = mod.constants.get(key).?;
                                        const expr = try self.allocator.create(Expression);
                                        expr.* = value;
                                        try self.variables.put(try std.mem.join(self.allocator, "_", &.{ mod.name, key }), expr);
                                    }

                                    for (mod.customs.kvs.keys, 0..mod.customs.kvs.len) |key, _| {
                                        const custom = try mod.customs.get(key).?(self);
                                        try self.customs.put(try std.mem.join(self.allocator, "_", &.{ mod.name, key }), custom);
                                    }
                                } else {
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
                                }
                            } else {
                                try self.stderr.print("Unknown directive: {s}\n", .{target});
                                std.process.exit(1);
                            }
                        },
                        .repeat_statement => |repeat_stmt| {
                            const name = repeat_stmt.variable;

                            const count = try self.evaluate_expression(repeat_stmt.count, variables);
                            if (count.literal != .integer) {
                                try self.stderr.print(
                                    "Repeat count must be an integer, got: {s}\n",
                                    .{try count.literal.to_string(self.allocator, self)},
                                );
                                std.process.exit(1);
                            }

                            const repeat_count = count.literal.integer;
                            if (repeat_count == 0) {
                                continue;
                            }

                            const name_expr = try self.allocator.create(Expression);
                            name_expr.* = Expression{
                                .literal = Literal{
                                    .integer = 0,
                                },
                            };

                            for (0..@as(usize, @intCast(repeat_count))) |i| {
                                if (variables.getPtr(name)) |existing| {
                                    existing.*.* = Expression{
                                        .literal = Literal{
                                            .integer = @as(i32, @intCast(i)),
                                        },
                                    };
                                } else {
                                    try variables.put(name, name_expr);
                                    name_expr.* = Expression{
                                        .literal = Literal{
                                            .integer = @as(i32, @intCast(i)),
                                        },
                                    };
                                }

                                if (try self.run_snippet(repeat_stmt.body.items, variables)) |result| {
                                    return result;
                                }
                            }
                        },
                        .object_statement => |object_stmt| {
                            const object_name = object_stmt.name;
                            const object = try self.allocator.create(CustomType);

                            object.* = CustomType{
                                .name = object_name,
                                .fields = object_stmt.properties,
                            };

                            if (self.customs.get(object_name)) |_| {
                                try self.stderr.print("Custom type '{s}' already exists\n", .{object_name});
                                std.process.exit(1);
                            }

                            try self.customs.put(object_name, object.*);
                        },
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

                const index = @as(usize, @intCast(index_expr.literal.integer));
                switch (array_expr.literal) {
                    .array => |a| {
                        if (index < a.items.len) {
                            return Expression{
                                .literal = a.items[index].literal,
                            };
                        } else {
                            try self.stderr.print("Index out of bounds: {d} for array of length {d}\n", .{
                                index,
                                a.items.len,
                            });
                            std.process.exit(1);
                        }
                    },
                    .string => |s| {
                        if (index < s.len) {
                            return Expression{ .literal = .{ .integer = @as(i32, @intCast(s[index])) } };
                        } else {
                            try self.stderr.print("Index out of bounds: {d} for string of length {d}\n", .{
                                index,
                                s.len,
                            });
                            std.process.exit(1);
                        }
                    },
                    else => unreachable,
                }
            },
            .identifier => |id| {
                if (variables.get(id.name)) |value| {
                    return value.*;
                    // } else if (self.zig_functions.get(id.name) != null) {
                    //     return expr;
                } else if (std_functions.get(id.name) != null) {
                    return expr;
                } else if (self.functions.get(id.name) != null) {
                    return Expression{
                        .identifier = Identifier{
                            .name = id.name,
                        },
                    };
                } else if (self.modules.get(id.name)) |mod| {
                    return Expression{
                        .literal = Literal{
                            .module = mod,
                        },
                    };
                }

                return expr;
            },
            .binary => |binary| {
                const left = try self.evaluate_expression(binary.left.*, variables);
                const right = try self.evaluate_expression(binary.right.*, variables);

                return switch (binary.operator.token_type) {
                    .Plus => switch (left.literal) {
                        .integer => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .integer = left.literal.integer + right.literal.integer,
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .float = @as(f32, @floatFromInt(left.literal.integer)) + right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '+' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        .float => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .float = left.literal.float + @as(f32, @floatFromInt(right.literal.integer)),
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .float = left.literal.float + right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '+' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
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
                    .Minus => switch (left.literal) {
                        .integer => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .integer = left.literal.integer - right.literal.integer,
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .float = @as(f32, @floatFromInt(left.literal.integer)) - right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '-' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        .float => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .float = left.literal.float - @as(f32, @floatFromInt(right.literal.integer)),
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .float = left.literal.float - right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '-' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        else => {
                            try self.stderr.print("Invalid left operand for '-' operator: {s}\n", .{try left.literal.to_string(self.allocator, self)});
                            std.process.exit(1);
                        },
                    },
                    .Multiply => switch (left.literal) {
                        .integer => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .integer = left.literal.integer * right.literal.integer,
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .float = @as(f32, @floatFromInt(left.literal.integer)) * right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '*' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        .float => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .float = left.literal.float * @as(f32, @floatFromInt(right.literal.integer)),
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .float = left.literal.float * right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '*' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        else => {
                            try self.stderr.print("Invalid left operand for '*' operator: {s}\n", .{try left.literal.to_string(self.allocator, self)});
                            std.process.exit(1);
                        },
                    },
                    .Divide => {
                        if ((right.literal == .integer and right.literal.integer == 0) or (right.literal == .float and right.literal.float == 0.0)) {
                            try self.stderr.print("Division by zero error\n", .{});
                            std.process.exit(1);
                        }

                        return switch (left.literal) {
                            .integer => switch (right.literal) {
                                .integer => Expression{
                                    .literal = Literal{
                                        .integer = @divTrunc(left.literal.integer, right.literal.integer),
                                    },
                                },
                                .float => Expression{
                                    .literal = Literal{
                                        .float = @as(f32, @floatFromInt(left.literal.integer)) / right.literal.float,
                                    },
                                },
                                else => {
                                    try self.stderr.print("Invalid right operand for '/' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                    std.process.exit(1);
                                },
                            },
                            .float => switch (right.literal) {
                                .integer => Expression{
                                    .literal = Literal{
                                        .float = left.literal.float / @as(f32, @floatFromInt(right.literal.integer)),
                                    },
                                },
                                .float => Expression{
                                    .literal = Literal{
                                        .float = left.literal.float / right.literal.float,
                                    },
                                },
                                else => {
                                    try self.stderr.print("Invalid right operand for '/' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                    std.process.exit(1);
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid left operand for '/' operator: {s}\n", .{try left.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        };
                    },
                    .Modulo => {
                        if ((right.literal == .integer and right.literal.integer == 0) or (right.literal == .float and right.literal.float == 0.0)) {
                            try self.stderr.print("Modulo by zero error\n", .{});
                            std.process.exit(1);
                        }

                        return switch (left.literal) {
                            .integer => switch (right.literal) {
                                .integer => Expression{
                                    .literal = Literal{
                                        .integer = @mod(left.literal.integer, right.literal.integer),
                                    },
                                },
                                .float => Expression{
                                    .literal = Literal{
                                        .float = @mod(@as(f32, @floatFromInt(left.literal.integer)), right.literal.float),
                                    },
                                },
                                else => {
                                    try self.stderr.print("Invalid right operand for '%' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                    std.process.exit(1);
                                },
                            },
                            .float => switch (right.literal) {
                                .integer => Expression{
                                    .literal = Literal{
                                        .float = @mod(left.literal.float, @as(f32, @floatFromInt(right.literal.integer))),
                                    },
                                },
                                .float => Expression{
                                    .literal = Literal{
                                        .float = @mod(left.literal.float, right.literal.float),
                                    },
                                },
                                else => {
                                    try self.stderr.print("Invalid right operand for '%' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                    std.process.exit(1);
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid left operand for '%' operator: {s}\n", .{try left.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
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
                    .GreaterThan => switch (left.literal) {
                        .integer => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .boolean = left.literal.integer > right.literal.integer,
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .boolean = @as(f32, @floatFromInt(left.literal.integer)) > right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '>' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        .float => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .boolean = left.literal.float > @as(f32, @floatFromInt(right.literal.integer)),
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .boolean = left.literal.float > right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '>' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        else => {
                            try self.stderr.print("Invalid left operand for '>' operator: {s}\n", .{try left.literal.to_string(self.allocator, self)});
                            std.process.exit(1);
                        },
                    },
                    .LessThan => switch (left.literal) {
                        .integer => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .boolean = left.literal.integer < right.literal.integer,
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .boolean = @as(f32, @floatFromInt(left.literal.integer)) < right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '<' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        .float => switch (right.literal) {
                            .integer => Expression{
                                .literal = Literal{
                                    .boolean = left.literal.float < @as(f32, @floatFromInt(right.literal.integer)),
                                },
                            },
                            .float => Expression{
                                .literal = Literal{
                                    .boolean = left.literal.float < right.literal.float,
                                },
                            },
                            else => {
                                try self.stderr.print("Invalid right operand for '<' operator: {s}\n", .{try right.literal.to_string(self.allocator, self)});
                                std.process.exit(1);
                            },
                        },
                        else => {
                            try self.stderr.print("Invalid left operand for '<' operator: {s}\n", .{try left.literal.to_string(self.allocator, self)});
                            std.process.exit(1);
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
            .grouping => |group| try self.evaluate_expression(group.expression.*, variables),
            .call => |call| try self.call_function(call, variables),
            .get_attribute => |ga| {
                const module_expr = try self.evaluate_expression(ga.object.*, variables);
                switch (module_expr.literal) {
                    .module => {
                        const module = module_expr.literal.module;
                        switch (ga.attribute.*) {
                            .identifier => |attribute| {
                                if (module.constants.get(attribute.name)) |value| {
                                    return value;
                                } else if (module.functions.get(attribute.name)) |handler| {
                                    return Expression{
                                        .literal = .{
                                            .function = .{
                                                .name = attribute.name,
                                                .handler = .{
                                                    .native = handler,
                                                },
                                            },
                                        },
                                    };
                                } else {
                                    try self.stderr.print("Module '{s}' has no attribute '{s}'\n", .{ module.name, attribute.name });
                                    std.process.exit(1);
                                }
                            },
                            .literal => |literal| {
                                if (literal != .custom) {
                                    try self.stderr.print("Expected a custom type attribute, got: {s}\n", .{try literal.to_string(self.allocator, self)});
                                    std.process.exit(1);
                                }

                                // const custom: Custom = literal.custom;

                                // const corr_type = try self.allocator.create(Expression);
                                // corr_type.* = Expression{
                                //     .get_attribute = .{
                                //         .object = &module_expr,
                                //         .attribute = custom.corr_type,
                                //     },
                                // };

                                // const lit = try self.allocator.create(Literal);
                                // lit.* = Literal{
                                //     .custom = .{
                                //         .corr_type = corr_type,
                                //         .values = custom.values,
                                //     },
                                // };

                                const custom = try self.allocator.create(Custom);
                                const corr_type = try self.allocator.create(Expression);
                                corr_type.* = Expression{
                                    .get_attribute = .{
                                        .object = &module_expr,
                                        .attribute = literal.custom.corr_type,
                                    },
                                };

                                custom.* = Custom{
                                    .corr_type = corr_type,
                                    .values = literal.custom.values,
                                };

                                const final_expr = try self.allocator.create(Expression);
                                final_expr.* = Expression{
                                    .literal = Literal{
                                        .custom = custom.*,
                                    },
                                };

                                return final_expr.*;

                                // return Expression{
                                //     .literal = .{
                                //         .custom = custom.*,
                                //         // .custom = .{
                                //         //     .corr_type = &.{
                                //         //         .get_attribute = .{
                                //         //             .object = &module_expr,
                                //         //             .attribute = literal.custom.corr_type,
                                //         //         },
                                //         //     },
                                //         //     .values = literal.custom.values,
                                //         // },
                                //     },
                                // };
                            },
                            else => unreachable,
                        }
                    },
                    .custom => {
                        const custom = module_expr.literal.custom;

                        const attribute = ga.attribute.identifier;

                        if (custom.values.get(attribute.name)) |value| {
                            return value;
                        } else {
                            try self.stderr.print("Custom type '{s}' has no attribute '{s}'\n", .{ try custom.corr_type.pretty_print(self.allocator), attribute.name });
                            std.process.exit(1);
                        }
                    },
                    else => {
                        try self.stderr.print("Expected a module or custom type, got: {s}\n", .{try module_expr.literal.to_string(self.allocator, self)});
                        std.process.exit(1);
                    },
                }
            },
            .custom => |custom| {
                return Expression{
                    .literal = Literal{
                        .custom = custom,
                    },
                };
            },
        };
    }

    fn call_function(
        self: Runner,
        call: Call,
        variables: *std.StringHashMap(*Expression),
    ) !Expression {
        const callee = try self.evaluate_expression(call.callee.*, variables);

        var arguments: std.ArrayList(*Expression) = std.ArrayList(*Expression).init(self.allocator);

        if (call.arguments != null) {
            for (call.arguments.?.items) |arg| {
                switch (arg) {
                    .identifier => |idtfr| {
                        if (variables.get(idtfr.name)) |value| {
                            try arguments.append(value);
                        } else {
                            try self.stderr.print("Undefined variable: {s}\n", .{idtfr.name});

                            var iter = variables.iterator();
                            while (iter.next()) |variable| {
                                try self.stderr.print("  - {s}: {s}\n", .{ variable.key_ptr.*, try variable.value_ptr.*.pretty_print(self.allocator) });
                            }

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

        switch (callee) {
            .literal => |l| {
                if (l != .function) return Expression{ .literal = .{ .null = null } };

                return switch (l.function.handler) {
                    .intox => |i| try self.run_function(Statement{ .function_declaration = i }, arguments.items),
                    .native => |native| try native(self, arguments.items),
                };
            },
            .identifier => |id| {
                if (std_functions.get(id.name)) |func| {
                    return try func(self, arguments.items);
                    // } else if (self.zig_functions.get(id.name)) |func_stmt| {
                    //     return try func_stmt(self, arguments.items);
                } else if (self.functions.get(id.name)) |func_stmt| {
                    return try self.run_function(func_stmt, arguments.items);
                } else {
                    var module_iter = self.modules.iterator();
                    while (module_iter.next()) |mod| {
                        if (mod.value_ptr.*.functions.get(id.name)) |func_stmt| {
                            return func_stmt(self, arguments.items);
                        }
                    }

                    try self.stderr.print("Undefined function: {s}\n", .{id.name});
                    std.process.exit(1);
                }
            },
            .get_attribute => |ga| {
                const module_expr = try self.evaluate_expression(ga.object.*, variables);
                if (module_expr.literal != .module) {
                    try self.stderr.print("Expected a module, got: {s}\n", .{try module_expr.literal.to_string(self.allocator, self)});
                    std.process.exit(1);
                }

                const module = module_expr.literal.module;

                const attribute = ga.attribute.identifier;

                if (module.functions.get(attribute.name)) |func_stmt| {
                    return try func_stmt(self, arguments.items);
                } else {
                    try self.stderr.print("Module '{s}' has no function '{s}'\n", .{ module.name, attribute.name });
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
        const func_decl = func.function_declaration.intox;

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
