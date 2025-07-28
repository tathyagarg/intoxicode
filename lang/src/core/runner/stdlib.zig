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
    try require(1, &.{&.{.number}}, "abs", runner, args);

    const arg = args[0];
    if (arg.literal.number < 0) {
        return Expression{
            .literal = Literal{
                .number = -arg.literal.number,
            },
        };
    } else {
        return arg.*;
    }
}

pub fn min(runner: Runner, args: []*Expression) anyerror!Expression {
    if (args.len == 0) {
        try runner.stderr.print("min() requires at least one argument, got {}\n", .{args.len});
        std.process.exit(1);
    }

    var min_value: ?f32 = null;
    for (args) |arg| {
        if (min_value == null or arg.literal.number < min_value.?) {
            min_value = arg.literal.number;
        }
    }

    return Expression{
        .literal = Literal{
            .number = min_value.?,
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
        if (max_value == null or arg.literal.number > max_value.?) {
            max_value = arg.literal.number;
        }
    }

    return Expression{
        .literal = Literal{
            .number = max_value.?,
        },
    };
}

pub fn pow(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.number}, &.{.number} }, "pow", runner, args);

    const base = args[0].literal.number;
    const exponent = args[1].literal.number;

    return Expression{
        .literal = Literal{
            .number = std.math.pow(@TypeOf(base), base, @as(@TypeOf(base), exponent)),
        },
    };
}

pub fn sqrt(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "sqrt", runner, args);

    const value = args[0].literal.number;
    if (value < 0) {
        try runner.stderr.print("sqrt() cannot take a negative number, got {}\n", .{value});
        std.process.exit(1);
    }

    return Expression{
        .literal = Literal{
            .number = std.math.sqrt(value),
        },
    };
}

pub fn length(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .string, .array }}, "length", runner, args);

    const arg = args[0];
    return switch (arg.literal) {
        .string => |str| Expression{
            .literal = Literal{
                .number = @floatFromInt(str.len),
            },
        },
        .array => |array| Expression{
            .literal = Literal{
                .number = @floatFromInt(array.items.len),
            },
        },
        else => error.InvalidArgumentType,
    };
}

pub fn to_string(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .null, .boolean, .number, .string, .array }}, "to_string", runner, args);

    const arg = args[0];
    return Expression{
        .literal = Literal{
            .string = try arg.literal.to_string(runner.allocator, runner),
        },
    };
}

pub fn to_number(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .null, .boolean, .string, .number }}, "to_number", runner, args);

    const arg = args[0];

    return switch (arg.literal) {
        .null => Expression{
            .literal = Literal{
                .number = 0.0,
            },
        },
        .boolean => |b| Expression{
            .literal = Literal{
                .number = if (b) 1.0 else 0.0,
            },
        },
        .string => |str| {
            const parsed = std.fmt.parseFloat(f32, str) catch |err| {
                try runner.stderr.print("to_number() could not parse string '{s}': {}\n", .{ str, err });
                std.process.exit(1);
            };

            return Expression{
                .literal = Literal{
                    .number = parsed,
                },
            };
        },
        .module, .array => {
            try runner.stderr.print("to_number() cannot convert given datatype to number\n", .{});
            std.process.exit(1);
        },
        .number => |num| Expression{
            .literal = Literal{
                .number = num,
            },
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
    try require(1, &.{&.{.number}}, "chr", runner, args);

    const codepoint: u21 = @intFromFloat(args[0].literal.number);
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

pub fn append(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .number, .string, .array } }, "append", runner, args);

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
    try require(3, &.{ &.{.array}, &.{.number}, &.{ .null, .boolean, .number, .string, .array } }, "insert", runner, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intFromFloat(args[1].literal.number);
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
    try require(2, &.{ &.{.array}, &.{.number} }, "remove", runner, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intFromFloat(args[1].literal.number);

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
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .number, .string, .array } }, "find_first", runner, args);

    const array_expr = args[0];

    const array = array_expr.literal.array;
    const value = args[1];

    for (array.items, 0..) |item, index| {
        if (try value.equals(item, runner)) {
            return Expression{
                .literal = Literal{
                    .number = @floatFromInt(index),
                },
            };
        }
    }

    return Expression{
        .literal = Literal{
            .number = -1.0,
        },
    };
}

pub fn find_last(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .number, .string, .array } }, "find_last", runner, args);

    const array_expr = args[0];

    const array = array_expr.literal.array;
    const value = args[1];

    for (array.items, (array.items.len - 1)..) |item, index| {
        if (try value.equals(item, runner)) {
            return Expression{
                .literal = Literal{
                    .number = @floatFromInt(index),
                },
            };
        }
    }

    return Expression{
        .literal = Literal{
            .number = -1.0,
        },
    };
}

pub fn update(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.array}, &.{.number}, &.{ .null, .boolean, .number, .string, .array } }, "update", runner, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intFromFloat(args[1].literal.number);
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

// zig std lib wrappers

pub fn sin(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "sin", runner, args);

    return Expression{
        .literal = Literal{
            .number = @sin(args[0].literal.number),
        },
    };
}

pub fn cos(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "cos", runner, args);

    return Expression{
        .literal = Literal{
            .number = @cos(args[0].literal.number),
        },
    };
}
