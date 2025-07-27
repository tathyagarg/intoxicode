const std = @import("std");

const Runner = @import("runner.zig").Runner;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;

fn require(
    arg_count: usize,
    dtypes: []const []const std.meta.Tag(Literal),
    func_name: []const u8,
    self: Runner,
    arguments: []*Expression,
) anyerror!void {
    if (arguments.len != arg_count) {
        try self.stderr.print("{s}() requires exactly {} argument(s), got {}\n", .{ func_name, arg_count, arguments.len });
        std.process.exit(1);
    }

    for (arguments, 0..) |arg, i| {
        for (dtypes[i]) |dtype| {
            if (arg.literal == dtype) {
                break;
            }
        } else {
            try self.stderr.print("Argument {} of {s} must be one of: \n", .{
                i + 1,
                func_name,
            });
            for (dtypes[i]) |dtype| {
                try self.stderr.print("  - {s}\n", .{@tagName(dtype)});
            }
            std.process.exit(1);
        }
    }
}

pub fn scream(self: Runner, args: []*Expression) anyerror!Expression {
    var output = std.ArrayList(u8).init(self.allocator);
    for (args) |arg| {
        try output.appendSlice(try arg.literal.to_string(self.allocator, self));
    }
    try self.stdout.writeAll(output.items);

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn abs(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "abs", self, args);

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

pub fn min(self: Runner, args: []*Expression) anyerror!Expression {
    if (args.len == 0) {
        try self.stderr.print("min() requires at least one argument, got {}\n", .{args.len});
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

pub fn max(self: Runner, args: []*Expression) anyerror!Expression {
    if (args.len == 0) {
        try self.stderr.print("max() requires at least one argument, got {}\n", .{args.len});
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

pub fn pow(self: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.number}, &.{.number} }, "pow", self, args);

    const base = args[0].literal.number;
    const exponent = args[1].literal.number;

    return Expression{
        .literal = Literal{
            .number = std.math.pow(@TypeOf(base), base, @as(@TypeOf(base), exponent)),
        },
    };
}

pub fn sqrt(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "sqrt", self, args);

    const value = args[0].literal.number;
    if (value < 0) {
        try self.stderr.print("sqrt() cannot take a negative number, got {}\n", .{value});
        std.process.exit(1);
    }

    return Expression{
        .literal = Literal{
            .number = std.math.sqrt(value),
        },
    };
}

pub fn length(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .string, .array }}, "length", self, args);

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

pub fn to_string(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .null, .boolean, .number, .string, .array }}, "to_string", self, args);

    const arg = args[0];
    return Expression{
        .literal = Literal{
            .string = try arg.literal.to_string(self.allocator, self),
        },
    };
}

pub fn to_number(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{ .null, .boolean, .string, .number }}, "to_number", self, args);

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
                try self.stderr.print("to_number() could not parse string '{s}': {}\n", .{ str, err });
                std.process.exit(1);
            };

            return Expression{
                .literal = Literal{
                    .number = parsed,
                },
            };
        },
        .array => {
            try self.stderr.print("to_number() cannot convert array to number\n", .{});
            std.process.exit(1);
        },
        .number => |num| Expression{
            .literal = Literal{
                .number = num,
            },
        },
    };
}

pub fn is_digit(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.string}}, "is_digit", self, args);

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

pub fn chr(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "chr", self, args);

    const codepoint: u21 = @intFromFloat(args[0].literal.number);
    if (codepoint > 0x10FFFF) {
        try self.stderr.print("chr() codepoint out of range: {}\n", .{codepoint});
        std.process.exit(1);
    }

    const buffer = try self.allocator.alloc(u8, 1);
    _ = try std.unicode.utf8Encode(codepoint, buffer);

    return Expression{
        .literal = Literal{
            .string = buffer,
        },
    };
}

pub fn append(self: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .number, .string, .array } }, "append", self, args);

    const array_expr = args[0];
    const value_expr = args[1];

    var array = array_expr.literal.array;
    const value = value_expr;

    array.append(value.*) catch |err| {
        try self.stderr.print("append() failed to append value: {}\n", .{err});
        std.process.exit(1);
    };

    array_expr.literal.array = array;

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn insert(self: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.array}, &.{.number}, &.{ .null, .boolean, .number, .string, .array } }, "insert", self, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intFromFloat(args[1].literal.number);
    const value = args[2];

    if (index < 0 or index > array.items.len) {
        try self.stderr.print("insert() index out of bounds: {}\n", .{index});
        std.process.exit(1);
    }

    array.insert(index, value.*) catch |err| {
        try self.stderr.print("insert() failed to insert value: {}\n", .{err});
        std.process.exit(1);
    };

    array_expr.literal.array = array;

    return Expression{
        .literal = Literal{
            .null = null,
        },
    };
}

pub fn remove(self: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{.number} }, "remove", self, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intFromFloat(args[1].literal.number);

    if (index < 0 or index >= array.items.len) {
        try self.stderr.print("remove() index out of bounds: {}\n", .{index});
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

pub fn find_first(self: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .number, .string, .array } }, "find_first", self, args);

    const array_expr = args[0];

    const array = array_expr.literal.array;
    const value = args[1];

    for (array.items, 0..) |item, index| {
        if (try value.equals(item, self)) {
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

pub fn find_last(self: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.array}, &.{ .null, .boolean, .number, .string, .array } }, "find_last", self, args);

    const array_expr = args[0];

    const array = array_expr.literal.array;
    const value = args[1];

    for (array.items, (array.items.len - 1)..) |item, index| {
        if (try value.equals(item, self)) {
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

pub fn update(self: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.array}, &.{.number}, &.{ .null, .boolean, .number, .string, .array } }, "update", self, args);

    const array_expr = args[0];

    var array = array_expr.literal.array;
    const index: usize = @intFromFloat(args[1].literal.number);
    const value = args[2];

    if (index < 0 or index >= array.items.len) {
        try self.stderr.print("update() index out of bounds: {}\n", .{index});
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

pub fn sin(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "sin", self, args);

    return Expression{
        .literal = Literal{
            .number = @sin(args[0].literal.number),
        },
    };
}

pub fn cos(self: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.number}}, "cos", self, args);

    return Expression{
        .literal = Literal{
            .number = @cos(args[0].literal.number),
        },
    };
}
