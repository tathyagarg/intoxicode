const std = @import("std");

const Runner = @import("runner.zig").Runner;
const Expression = @import("../parser/parser.zig").expressions.Expression;
const Literal = @import("../parser/parser.zig").expressions.Literal;

pub fn scream(self: Runner, args: []Expression) anyerror!Expression {
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

pub fn abs(r: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 1) {
        try r.stderr.print("abs() requires exactly one argument, got {}\n", .{args.len});
        std.process.exit(1);
    }

    const arg = args[0];
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

pub fn min(r: Runner, args: []Expression) anyerror!Expression {
    if (args.len == 0) {
        try r.stderr.print("min() requires at least one argument, got {}\n", .{args.len});
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

pub fn max(r: Runner, args: []Expression) anyerror!Expression {
    if (args.len == 0) {
        try r.stderr.print("max() requires at least one argument, got {}\n", .{args.len});
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

pub fn pow(r: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 2) {
        try r.stderr.print("pow() requires exactly two arguments, got {}\n", .{args.len});
        std.process.exit(1);
    }

    const base = args[0].literal.number;
    const exponent = args[1].literal.number;

    return Expression{
        .literal = Literal{
            .number = std.math.pow(@TypeOf(base), base, @as(@TypeOf(base), exponent)),
        },
    };
}

pub fn sqrt(r: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 1) {
        try r.stderr.print("sqrt() requires exactly one argument, got {}\n", .{args.len});
        std.process.exit(1);
    }

    const value = args[0].literal.number;
    if (value < 0) {
        try r.stderr.print("sqrt() cannot take a negative number, got {}\n", .{value});
        std.process.exit(1);
    }

    return Expression{
        .literal = Literal{
            .number = std.math.sqrt(value),
        },
    };
}

pub fn length(r: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 1) {
        try r.stderr.print("length() requires exactly one argument, got {}\n", .{args.len});
        std.process.exit(1);
    }

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

pub fn to_string(self: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 1) {
        try self.stderr.print("to_string() requires exactly one argument, got {}\n", .{args.len});
        std.process.exit(1);
    }

    const arg = args[0];
    return Expression{
        .literal = Literal{
            .string = try arg.literal.to_string(self.allocator, self),
        },
    };
}
