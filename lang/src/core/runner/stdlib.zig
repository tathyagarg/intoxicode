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

pub fn abs(_: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 1) {
        return error.InvalidArgumentCount;
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

pub fn min(_: Runner, args: []Expression) anyerror!Expression {
    if (args.len == 0) {
        return error.InvalidArgumentCount;
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

pub fn max(_: Runner, args: []Expression) anyerror!Expression {
    if (args.len == 0) {
        return error.InvalidArgumentCount;
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

pub fn pow(_: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 2) {
        return error.InvalidArgumentCount;
    }

    const base = args[0].literal.number;
    const exponent = args[1].literal.number;

    return Expression{
        .literal = Literal{
            .number = std.math.pow(@TypeOf(base), base, @as(@TypeOf(base), exponent)),
        },
    };
}

pub fn sqrt(_: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 1) {
        return error.InvalidArgumentCount;
    }

    const value = args[0].literal.number;
    if (value < 0) {
        return error.NegativeSqrt;
    }

    return Expression{
        .literal = Literal{
            .number = std.math.sqrt(value),
        },
    };
}

pub fn length(_: Runner, args: []Expression) anyerror!Expression {
    if (args.len != 1) {
        return error.InvalidArgumentCount;
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
        return error.InvalidArgumentCount;
    }

    const arg = args[0];
    return Expression{
        .literal = Literal{
            .string = try arg.literal.to_string(self.allocator, self),
        },
    };
}
