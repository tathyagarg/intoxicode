const std = @import("std");

const Runner = @import("runner.zig").Runner;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;

const require = @import("runner.zig").require;

pub fn scream(runner: Runner, args: []*Expression) anyerror!Expression {
    var output = std.ArrayList(u8).init(runner.allocator);
    for (args) |arg| {
        try output.appendSlice(try arg.literal.to_string(runner.allocator, runner));
    }
    try runner.stdout.writeAll(output.items);

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn abs(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .integer, .float }}, "abs", runner, args);

    const arg = args[0];

    return Expression{
        .literal = switch (arg.literal) {
            .integer => |int| Literal{ .integer = @intCast(@abs(int)) },
            .float => |flt| Literal{ .float = @abs(flt) },
            else => unreachable,
        },
    };
}

pub fn min(runner: Runner, args: []*Expression) anyerror!Expression {
    if (args.len == 0) {
        try runner.stderr.print("min() requires at least one argument, got {}\n", .{args.len});
        std.process.exit(1);
    }

    var min_value: ?f32 = null;
    for (args) |arg| {
        switch (arg.literal) {
            .integer => |int| {
                if (min_value == null or @as(f32, @floatFromInt(int)) < min_value.?) {
                    min_value = @floatFromInt(int);
                }
            },
            .float => |flt| {
                if (min_value == null or flt < min_value.?) {
                    min_value = flt;
                }
            },
            else => {
                try runner.stderr.print("min() only accepts numeric arguments, got {}\n", .{arg.literal});
                std.process.exit(1);
            },
        }
    }

    return Expression{
        .literal = Literal{
            .float = min_value.?,
        },
    };
}

pub fn max(runner: Runner, args: []*Expression) anyerror!Expression {
    if (args.len == 0) {
        try runner.stderr.print("max() requires at least one argument, got {}\n", .{args.len});
        std.process.exit(1);
    }

    var max_value: ?f32 = null;
    for (args) |arg| {
        switch (arg.literal) {
            .integer => |int| {
                if (max_value == null or @as(f32, @floatFromInt(int)) > max_value.?) {
                    max_value = @floatFromInt(int);
                }
            },
            .float => |flt| {
                if (max_value == null or flt > max_value.?) {
                    max_value = flt;
                }
            },
            else => {
                try runner.stderr.print("max() only accepts numeric arguments, got {}\n", .{arg.literal});
                std.process.exit(1);
            },
        }
    }

    return Expression{
        .literal = Literal{
            .float = max_value.?,
        },
    };
}

pub fn pow(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{ .integer, .float }, &.{ .integer, .float } }, "pow", runner, args);

    const base: f32 = switch (args[0].literal) {
        .integer => |int| @floatFromInt(int),
        .float => |flt| flt,
        else => unreachable,
    };

    const exponent: f32 = switch (args[1].literal) {
        .integer => |int| @floatFromInt(int),
        .float => |flt| flt,
        else => unreachable,
    };

    return Expression{
        .literal = Literal{
            .float = std.math.pow(@TypeOf(base), base, @as(@TypeOf(base), exponent)),
        },
    };
}

pub fn sqrt(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .integer, .float }}, "sqrt", runner, args);

    const value: f32 = switch (args[0].literal) {
        .integer => |int| @floatFromInt(int),
        .float => |flt| flt,
        else => unreachable,
    };
    if (value < 0) {
        try runner.stderr.print("sqrt() cannot take a negative number, got {}\n", .{value});
        std.process.exit(1);
    }

    return Expression{
        .literal = Literal{
            .float = std.math.sqrt(value),
        },
    };
}

pub fn length(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .string, .array }}, "length", runner, args);

    const arg = args[0];
    return switch (arg.literal) {
        .string => |str| Expression{
            .literal = Literal{
                .integer = @intCast(str.len),
            },
        },
        .array => |array| Expression{
            .literal = Literal{
                .integer = @intCast(array.items.len),
            },
        },
        else => error.InvalidArgumentType,
    };
}

pub fn to_string(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .null, .boolean, .integer, .float, .string, .array }}, "to_string", runner, args);

    const arg = args[0];
    return Expression{
        .literal = Literal{
            .string = try arg.literal.to_string(runner.allocator, runner),
        },
    };
}

pub fn to_number(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .null, .boolean, .string, .integer, .float }}, "to_number", runner, args);

    const arg = args[0];

    return switch (arg.literal) {
        .null => Expression{
            .literal = Literal{
                .integer = 0.0,
            },
        },
        .boolean => |b| Expression{
            .literal = Literal{
                .integer = if (b) 1.0 else 0.0,
            },
        },
        .string => |str| {
            const parsed = std.fmt.parseFloat(f32, str) catch |err| {
                try runner.stderr.print("to_number() could not parse string '{s}': {}\n", .{ str, err });
                std.process.exit(1);
            };

            return Expression{
                .literal = Literal{
                    .float = parsed,
                },
            };
        },
        .integer => |num| Expression{
            .literal = Literal{
                .integer = num,
            },
        },
        .float => |flt| Expression{
            .literal = Literal{
                .float = flt,
            },
        },
        else => {
            try runner.stderr.print("to_number() cannot convert given datatype to number\n", .{});
            std.process.exit(1);
        },
    };
}

pub fn is_digit(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.string}}, "is_digit", runner, args);

    const str = args[0].literal.string;

    return Expression{
        .literal = Literal{
            .boolean = blk: for (str) |c| {
                if (!std.ascii.isDigit(c)) {
                    break :blk false;
                }
            } else {
                break :blk true;
            },
        },
    };
}

pub fn chr(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.integer}}, "chr", runner, args);

    const codepoint: u21 = @intCast(args[0].literal.integer);
    if (codepoint > 0x10FFFF) {
        try runner.stderr.print("chr() codepoint out of range: {}\n", .{codepoint});
        std.process.exit(1);
    }

    const buffer = try runner.allocator.alloc(u8, 1);
    _ = try std.unicode.utf8Encode(codepoint, buffer);

    return Expression{
        .literal = Literal{
            .string = buffer,
        },
    };
}

pub fn ord(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.string}}, "ord", runner, args);

    const string = args[0].literal.string;
    if (string.len > 1) {
        return error.StringNotChar;
    }

    const char = string[0];
    return Expression{ .literal = .{ .integer = @intCast(char) } };
}

pub fn append(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .integer, .float, .string, .array } }, "append", runner, args);

    const array_expr = args[0];
    const value_expr = args[1];

    var array = array_expr.literal.array;
    const value = value_expr;

    array.append(value.*) catch |err| {
        try runner.stderr.print("append() failed to append value: {}\n", .{err});
        std.process.exit(1);
    };

    array_expr.literal.array = array;

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn insert(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.array}, &.{.integer}, &.{ .null, .boolean, .integer, .float, .string, .array } }, "insert", runner, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intCast(args[1].literal.integer);
    const value = args[2];

    if (index < 0 or index > array.items.len) {
        try runner.stderr.print("insert() index out of bounds: {}\n", .{index});
        std.process.exit(1);
    }

    array.insert(index, value.*) catch |err| {
        try runner.stderr.print("insert() failed to insert value: {}\n", .{err});
        std.process.exit(1);
    };

    array_expr.literal.array = array;

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn remove(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{.integer} }, "remove", runner, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intCast(args[1].literal.integer);

    if (index < 0 or index >= array.items.len) {
        try runner.stderr.print("remove() index out of bounds: {}\n", .{index});
        std.process.exit(1);
    }

    _ = array.orderedRemove(index);

    array_expr.literal.array = array;

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn find_first(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .integer, .float, .string, .array } }, "find_first", runner, args);

    const array_expr = args[0];

    const array = array_expr.literal.array;
    const value = args[1];

    for (array.items, 0..) |item, index| {
        if (try value.equals(item, runner)) {
            return Expression{
                .literal = Literal{
                    .integer = @intCast(index),
                },
            };
        }
    }

    return Expression{
        .literal = Literal{
            .integer = -1,
        },
    };
}

pub fn find_last(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .integer, .float, .string, .array } }, "find_last", runner, args);

    const array_expr = args[0];

    const array = array_expr.literal.array;
    const value = args[1];

    for (array.items, (array.items.len - 1)..) |item, index| {
        if (try value.equals(item, runner)) {
            return Expression{
                .literal = Literal{
                    .integer = @intCast(index),
                },
            };
        }
    }

    return Expression{
        .literal = Literal{
            .integer = -1,
        },
    };
}

pub fn update(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.array}, &.{.integer}, &.{ .null, .boolean, .integer, .float, .string, .array } }, "update", runner, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intCast(args[1].literal.integer);
    const value = args[2];

    if (index < 0 or index >= array.items.len) {
        try runner.stderr.print("update() index out of bounds: {}\n", .{index});
        std.process.exit(1);
    }

    array.items[index] = value.*;

    array_expr.literal.array = array;

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn strip_last_n(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.string}, &.{.integer} }, "strip_last_n", runner, args);

    const str = args[0].literal.string;
    const n: usize = @intCast(args[1].literal.integer);

    if (n > str.len) {
        try runner.stderr.print("strip_last_n() cannot strip more characters than the string length: {}\n", .{n});
        std.process.exit(1);
    }

    return Expression{
        .literal = Literal{
            .string = str[0 .. str.len - n],
        },
    };
}

// zig std lib wrappers

pub fn sin(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .integer, .float }}, "sin", runner, args);

    return Expression{
        .literal = Literal{
            .float = @sin(switch (args[0].literal) {
                .integer => |int| @as(f32, @floatFromInt(int)),
                .float => |flt| flt,
                else => unreachable,
            }),
        },
    };
}

pub fn cos(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .integer, .float }}, "cos", runner, args);

    return Expression{
        .literal = Literal{
            .float = @cos(switch (args[0].literal) {
                .integer => |int| @as(f32, @floatFromInt(int)),
                .float => |flt| flt,
                else => unreachable,
            }),
        },
    };
}
