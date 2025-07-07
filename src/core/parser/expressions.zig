const std = @import("std");
const Token = @import("../lexer/tokens.zig").Token;

pub const Expression = union(enum) {
    binary: Binary,
    grouping: Grouping,
    literal: Literal,
    identifier: Identifier,
    call: Call,
    indexing: Indexing,

    pub fn equals(self: Expression, other: Expression) bool {
        return switch (other) {
            .binary => |b| switch (self) {
                .binary => |self_b| {
                    if (!self_b.operator.equals(b.operator)) return false;
                    if (!self_b.left.equals(b.left.*)) return false;
                    if (!self_b.right.equals(b.right.*)) return false;
                    return true;
                },
                else => false,
            },
            .grouping => |g| switch (self) {
                .grouping => |self_g| self_g.expression.equals(g.expression.*),
                else => false,
            },
            .literal => |l| switch (self) {
                .literal => |self_l| {
                    return switch (self_l) {
                        .number => l.number == self_l.number,
                        .string => std.mem.eql(u8, l.string, self_l.string),
                        .boolean => l.boolean == self_l.boolean,
                        .null => l.null == self_l.null,
                        .array => |arr| {
                            if (l.array.items.len != arr.items.len) return false;
                            for (l.array.items, arr.items) |item, other_item| {
                                if (!item.equals(other_item)) return false;
                            }
                            return true;
                        },
                    };
                },
                else => false,
            },
            .identifier => |id| switch (self) {
                .identifier => |self_id| std.mem.eql(u8, id.name, self_id.name),
                else => false,
            },
            .call => |c| switch (self) {
                .call => |self_c| {
                    if (!self_c.callee.equals(c.callee.*)) return false;
                    if (self_c.arguments.?.items.len != c.arguments.?.items.len) return false;

                    for (self_c.arguments.?.items, c.arguments.?.items) |arg, other_arg| {
                        if (!arg.equals(other_arg)) return false;
                    }
                    return true;
                },
                else => false,
            },
        };
    }

    pub fn pretty_print(self: Expression, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .binary => {
                const left = try self.binary.left.pretty_print(allocator);
                defer allocator.free(left);

                const right = try self.binary.right.pretty_print(allocator);
                defer allocator.free(right);

                return try std.fmt.allocPrint(
                    allocator,
                    "Binary({s} {s} {s})",
                    .{
                        left,
                        self.binary.operator.value,
                        right,
                    },
                );
            },
            .grouping => {
                const inner = try self.grouping.expression.pretty_print(allocator);
                defer allocator.free(inner);

                return try std.fmt.allocPrint(allocator, "Group({s})", .{inner});
            },
            .literal => switch (self.literal) {
                .number => try std.fmt.allocPrint(allocator, "Literal(number = {d})", .{self.literal.number}),
                .string => try std.fmt.allocPrint(allocator, "Literal(string = {s})", .{self.literal.string}),
                .boolean => if (self.literal.boolean) "true" else "false",
                .null => "null",
                .array => |arr| {
                    var items = std.ArrayList([]const u8).init(allocator);
                    for (arr.items) |item| {
                        const item_str = try item.pretty_print(allocator);
                        try items.append(item_str);
                    }
                    const result = try std.fmt.allocPrint(
                        allocator,
                        "Literal(array = [{s}])",
                        .{try std.mem.join(allocator, ", ", items.items)},
                    );
                    items.deinit();
                    return result;
                },
            },
            .identifier => self.identifier.pretty_print(allocator),
            .call => |c| {
                const callee = try c.callee.pretty_print(allocator);
                defer allocator.free(callee);

                var args = std.ArrayList([]const u8).init(allocator);

                for (c.arguments.?.items) |arg| {
                    const arg_str = try arg.pretty_print(allocator);
                    try args.append(arg_str);
                }

                return try std.fmt.allocPrint(
                    allocator,
                    "Call({s} ({d} args))",
                    .{ callee, args.items.len },
                );
            },
            .indexing => |i| {
                const array_str = try i.array.pretty_print(allocator);

                const index_str = try i.index.pretty_print(allocator);

                return try std.fmt.allocPrint(
                    allocator,
                    "Indexing({s}[{s}])",
                    .{ array_str, index_str },
                );
            },
        };
    }

    pub fn deinit(self: Expression) void {
        switch (self) {
            .binary => |b| {
                b.left.deinit();
                b.right.deinit();
            },
            .grouping => |g| g.expression.deinit(),
            .literal => {},
            .identifier => {},
        }
    }

    pub fn get_certainty(self: Expression) f32 {
        return switch (self) {
            .binary => self.binary.certainty,
            .grouping => self.grouping.certainty,
            .literal => 1.0, // literals are always certain
            .identifier => self.identifier.certainty,
            .call => self.call.certainty,
            .indexing => 1.0,
        };
    }

    pub fn set_certainty(self: *Expression, certainty: f32) void {
        switch (self.*) {
            .binary => |*b| b.certainty = certainty,
            .grouping => |*g| g.certainty = certainty,
            .identifier => |*id| id.certainty = certainty,
            .call => |*c| c.certainty = certainty,
            .literal, .indexing => {},
        }
    }
};

pub const Binary = struct {
    left: *const Expression,
    operator: Token,
    right: *const Expression,

    certainty: f32 = 1.0,
};

pub const Grouping = struct {
    expression: *const Expression,

    certainty: f32 = 1.0,
};

pub const Literal = union(enum) {
    number: f32,
    string: []const u8,
    boolean: bool,
    null: ?void,
    array: std.ArrayList(Expression),

    pub fn number_from_string(s: []const u8) !Literal {
        const number = try std.fmt.parseFloat(f32, s);
        return Literal{ .number = number };
    }

    pub fn to_string(self: Literal, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .number => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
            .string => |s| {
                const removed_quotes = s[1 .. s.len - 1];

                var result = std.ArrayList(u8).init(allocator);

                var i: usize = 0;
                while (i < removed_quotes.len) : (i += 1) {
                    const c = removed_quotes[i];
                    if (c == '\\') {
                        i += 1;
                        if (i < removed_quotes.len) {
                            const next_char = removed_quotes[i];
                            switch (next_char) {
                                'n' => try result.append('\n'),
                                't' => try result.append('\t'),
                                'r' => try result.append('\r'),
                                else => try result.append(next_char),
                            }
                        }
                    } else {
                        try result.append(c);
                    }
                }

                return result.toOwnedSlice();
            },
            .boolean => |b| if (b) "true" else "false",
            .null => "null",
            .array => |arr| {
                var result = std.ArrayList(u8).init(allocator);
                try result.append('[');
                for (arr.items) |item| {
                    const item_str = try item.pretty_print(allocator);
                    try result.appendSlice(item_str);
                    try result.appendSlice(", ");
                }
                try result.append(']');
                return result.toOwnedSlice();
            },
        };
    }
};

pub const Identifier = struct {
    name: []const u8,

    certainty: f32 = 1.0,

    pub fn pretty_print(self: Identifier, allocator: std.mem.Allocator) ![]const u8 {
        const message = try std.fmt.allocPrint(allocator, "{s}", .{self.name});

        return message;
    }
};

pub const Call = struct {
    callee: *const Expression,
    arguments: ?std.ArrayList(Expression),

    certainty: f32 = 1.0,

    pub fn deinit(self: Call) void {
        for (self.arguments.items) |arg| arg.deinit();
        self.arguments.deinit();
    }
};

pub const Indexing = struct {
    array: *const Expression,
    index: *const Expression,

    pub fn deinit(self: Indexing) void {
        self.array.deinit();
        self.index.deinit();
    }
};
