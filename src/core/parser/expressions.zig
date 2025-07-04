const std = @import("std");
const Token = @import("../lexer/tokens.zig").Token;

pub const Expression = union(enum) {
    binary: Binary,
    grouping: Grouping,
    literal: Literal,
    identifier: Identifier,
    call: Call,

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
            },
            .identifier => self.identifier.pretty_print(allocator),
            .call => |c| {
                const callee = try c.callee.pretty_print(allocator);
                defer allocator.free(callee);

                var args = std.ArrayList([]const u8).init(allocator);
                defer args.deinit();

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
};

pub const Binary = struct {
    left: *const Expression,
    operator: Token,
    right: *const Expression,
};

pub const Grouping = struct {
    expression: *const Expression,
};

pub const Literal = union(enum) {
    number: f64,
    string: []const u8,
    boolean: bool,

    pub fn number_from_string(s: []const u8) !Literal {
        const number = try std.fmt.parseFloat(f64, s);
        return Literal{ .number = number };
    }
};

pub const Identifier = struct {
    name: []const u8,

    pub fn pretty_print(self: Identifier, allocator: std.mem.Allocator) ![]const u8 {
        const message = try std.fmt.allocPrint(allocator, "{s}", .{self.name});

        return message;
    }
};

pub const Call = struct {
    callee: *const Expression,
    arguments: ?std.ArrayList(Expression),

    pub fn deinit(self: Call) void {
        for (self.arguments.items) |arg| arg.deinit();
        self.arguments.deinit();
    }
};
