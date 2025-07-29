const std = @import("std");
const Token = @import("../lexer/tokens.zig").Token;
const Runner = @import("../runner/runner.zig").Runner;
const Module = @import("../runner/modules/mod.zig").Module;

const FunctionDeclaration = @import("statement.zig").FunctionDeclaration;
const Handler = @import("../runner/runner.zig").Handler;

pub const Expression = union(enum) {
    binary: Binary,
    grouping: Grouping,
    literal: Literal,
    identifier: Identifier,
    call: Call,
    indexing: Indexing,
    get_attribute: GetAttribute,

    pub fn equals(self: Expression, other: Expression, runner: Runner) !bool {
        return switch (other) {
            .binary => |b| switch (self) {
                .binary => |self_b| {
                    if (!self_b.operator.equals(b.operator)) return false;
                    if (!try self_b.left.equals(b.left.*, runner)) return false;
                    if (!try self_b.right.equals(b.right.*, runner)) return false;
                    return true;
                },
                else => false,
            },
            .grouping => |g| switch (self) {
                .grouping => |self_g| self_g.expression.equals(g.expression.*, runner),
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
                                if (!try item.equals(other_item, runner)) return false;
                            }
                            return true;
                        },
                        .module => |mod| std.mem.eql(u8, l.module.name, mod.name),
                        .function => false,
                    };
                },
                else => false,
            },
            .identifier => |id| switch (self) {
                .identifier => |self_id| std.mem.eql(u8, id.name, self_id.name),
                else => false,
            },
            .call => |c| {
                const this_value = try runner.evaluate_expression(self, runner.variables);
                const other_value = try runner.evaluate_expression(c.callee.*, runner.variables);

                return try this_value.equals(other_value, runner);
            },
            .indexing => |i| switch (self) {
                .indexing => |self_i| {
                    const left_array = try runner.evaluate_expression(self_i.array.*, runner.variables);
                    const left_index = try runner.evaluate_expression(self_i.index.*, runner.variables);

                    const right_index = try runner.evaluate_expression(self_i.index.*, runner.variables);
                    const right_array = try runner.evaluate_expression(i.array.*, runner.variables);

                    const left_element = try runner.evaluate_expression(
                        left_array.literal.array.items[@intFromFloat(left_index.literal.number)],
                        runner.variables,
                    );
                    const right_element = try runner.evaluate_expression(
                        right_array.literal.array.items[@intFromFloat(right_index.literal.number)],
                        runner.variables,
                    );

                    return try left_element.equals(right_element, runner);
                },
                else => false,
            },
            .get_attribute => false,
        };
    }

    pub fn pretty_print(self: Expression, allocator: std.mem.Allocator) anyerror![]const u8 {
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
                .module => |mod| {
                    const module_name = mod.name;
                    return try std.fmt.allocPrint(allocator, "Literal(module = {s})", .{module_name});
                },
                .function => |f| try std.fmt.allocPrint(allocator, "Function({s})", .{f.name}),
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
            .get_attribute => |ga| try ga.pretty_print(allocator),
        };
    }

    pub fn get_certainty(self: Expression) f32 {
        return switch (self) {
            .binary => self.binary.certainty,
            .grouping => self.grouping.certainty,
            .literal => 1.0, // literals are always certain
            .identifier => self.identifier.certainty,
            .call => self.call.certainty,
            .indexing => 1.0,
            .get_attribute => 1.0, // attributes are certain if the object is certain
        };
    }

    pub fn set_certainty(self: *Expression, certainty: f32) void {
        switch (self.*) {
            .binary => |*b| b.certainty = certainty,
            .grouping => |*g| g.certainty = certainty,
            .identifier => |*id| id.certainty = certainty,
            .call => |*c| c.certainty = certainty,
            .get_attribute, .literal, .indexing => {},
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
    function: Function,
    module: Module,

    pub fn number_from_string(s: []const u8) !Literal {
        const number = try std.fmt.parseFloat(f32, s);
        return Literal{ .number = number };
    }

    pub fn to_string(self: Literal, allocator: std.mem.Allocator, runner: Runner) ![]const u8 {
        return switch (self) {
            .number => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
            .string => |s| {
                const removed_quotes = s;

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
                    const item_str = try (try runner.evaluate_expression(item, runner.variables)).literal.to_string(allocator, runner);
                    try result.appendSlice(item_str);
                    try result.appendSlice(", ");
                }
                _ = result.pop();
                _ = result.pop();

                try result.append(']');
                return result.toOwnedSlice();
            },
            .module => |mod| {
                return try std.fmt.allocPrint(allocator, "Module({s})", .{mod.name});
            },
            .function => |f| f.name,
        };
    }
};

pub const Function = struct {
    name: []const u8,
    handler: union(enum) {
        intox: FunctionDeclaration,
        native: Handler,
    },
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
};

pub const Indexing = struct {
    array: *const Expression,
    index: *const Expression,
};

pub const GetAttribute = struct {
    object: *const Expression,
    attribute: *const Expression,

    pub fn pretty_print(self: GetAttribute, allocator: std.mem.Allocator) ![]const u8 {
        const object_str = try self.object.pretty_print(allocator);
        defer allocator.free(object_str);

        const attribute_str = try self.attribute.pretty_print(allocator);
        defer allocator.free(attribute_str);

        return try std.fmt.allocPrint(allocator, "GetAttribute({s} ~ {s})", .{ object_str, attribute_str });
    }
};
