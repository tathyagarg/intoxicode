const std = @import("std");

const Expression = @import("expressions.zig").Expression;
const LiteralType = @import("expressions.zig").LiteralType;
const Handler = @import("../runner/runner.zig").Handler;

pub const Statement = union(enum) {
    expression: Expression,
    assignment: Assignment,
    if_statement: IfStatement,
    loop_statement: LoopStatement,
    function_declaration: FunctionDeclaration,
    try_statement: TryStatement,
    throwaway_statement: ThrowawayStatement,
    directive: Directive,
    repeat_statement: RepeatStatement,
    object_statement: ObjectStatement,

    pub fn get_certainty(self: Statement) !f32 {
        return switch (self) {
            .expression => self.expression.get_certainty(),
            .assignment => self.assignment.certainty,
            .if_statement => self.if_statement.certainty,
            .loop_statement => self.loop_statement.certainty,
            .function_declaration => switch (self.function_declaration) {
                .intox => self.function_declaration.intox.certainty,
                .native => 1.0, // Native functions are always certain
            },
            .try_statement => self.try_statement.certainty,
            .throwaway_statement => self.throwaway_statement.certainty,
            .directive => 1.0,
            .repeat_statement => self.repeat_statement.certainty,
            .object_statement => 1.0, // Objects are always certain
        };
    }

    pub fn set_certainty(self: *Statement, certainty: f32) void {
        switch (self.*) {
            .expression => |*e| e.set_certainty(certainty),
            .assignment => |*a| a.certainty = certainty,
            .if_statement => |*i| i.certainty = certainty,
            .loop_statement => |*l| l.certainty = certainty,
            .function_declaration => |*f| switch (f.*) {
                .intox => f.intox.certainty = certainty,
                .native => {}, // Native functions do not have certainty
            },
            .try_statement => |*t| t.certainty = certainty,
            .throwaway_statement => |*t| t.certainty = certainty,
            .directive => {},
            .repeat_statement => |*r| r.certainty = certainty,
            .object_statement => {}, // Objects do not have certainty
        }
    }

    pub fn pretty_print(self: Statement, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .expression => |e| e.pretty_print(allocator),
            .assignment => |a| {
                var builder = std.ArrayList(u8).init(allocator);

                try builder.appendSlice(a.identifier);
                try builder.appendSlice(" = ");

                const expr_str = try a.expression.pretty_print(allocator);
                try builder.appendSlice(expr_str);

                try builder.appendSlice(";\n");

                return try builder.toOwnedSlice();
            },
            .if_statement => |i| i.pretty_print(allocator),
            .function_declaration => "",
            .throwaway_statement => |t| t.pretty_print(allocator),
            .loop_statement => |l| l.pretty_print(allocator),
            .try_statement => |t| t.pretty_print(allocator),
            .directive => |d| d.pretty_print(allocator),
            .repeat_statement => |r| r.pretty_print(allocator),
            .object_statement => |o| o.pretty_print(allocator),
        };
    }
};

pub const Assignment = struct {
    identifier: []const u8,
    expression: Expression,

    certainty: f32 = 1.0,
};

pub const IfStatement = struct {
    condition: Expression,
    then_branch: std.ArrayList(*Statement),
    else_branch: ?std.ArrayList(*Statement),

    certainty: f32 = 1.0,

    pub fn pretty_print(self: IfStatement, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice(try std.fmt.allocPrint(allocator, "if ({s}) {{\n", .{try self.condition.pretty_print(allocator)}));
        for (self.then_branch.items) |s| {
            try builder.appendSlice("    ");
            try builder.appendSlice(try s.pretty_print(allocator));
            try builder.appendSlice("\n");
        }

        try builder.appendSlice("}\n");

        // finally get the combined buffer
        const result = try builder.toOwnedSlice();
        return result;
    }
};

pub const LoopStatement = struct {
    condition: Expression,
    body: std.ArrayList(*Statement),

    certainty: f32 = 1.0,

    pub fn pretty_print(self: LoopStatement, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice("while (");
        try builder.appendSlice(try self.condition.pretty_print(allocator));
        try builder.appendSlice(") {\n");

        for (self.body.items) |s| {
            try builder.appendSlice("    ");
            try builder.appendSlice(try s.pretty_print(allocator));
            try builder.appendSlice("\n");
        }

        try builder.appendSlice("}\n");

        const result = try builder.toOwnedSlice();
        return result;
    }
};

pub const FunctionDeclaration = union(enum) {
    intox: IntoxFunctionDeclaration,
    native: NativeFunctionDeclaration,

    pub fn name(self: FunctionDeclaration) []const u8 {
        return switch (self) {
            .intox => self.intox.name,
            .native => self.native.name,
        };
    }
};

pub const IntoxFunctionDeclaration = struct {
    name: []const u8,
    parameters: std.ArrayList([]const u8),
    body: std.ArrayList(*Statement),

    certainty: f32 = 1.0,

    pub fn pretty_print(self: FunctionDeclaration, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice("function ");
        try builder.appendSlice(self.name);
        try builder.appendSlice("(");

        for (self.parameters.items, 0..) |param, i| {
            if (i > 0) {
                try builder.appendSlice(", ");
            }
            try builder.appendSlice(param);
        }

        try builder.appendSlice(") {\n");

        for (self.body.items) |s| {
            try builder.appendSlice("    ");
            try builder.appendSlice(try s.pretty_print(allocator));
            try builder.appendSlice("\n");
        }

        try builder.appendSlice("}\n");

        const result = try builder.toOwnedSlice();

        return result;
    }
};

pub const NativeFunctionDeclaration = struct {
    name: []const u8,
    handler: Handler,
};

pub const TryStatement = struct {
    body: std.ArrayList(*Statement),
    catch_block: std.ArrayList(*Statement),

    certainty: f32 = 1.0,

    pub fn pretty_print(self: TryStatement, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice("try {\n");

        for (self.body.items) |s| {
            try builder.appendSlice("    ");
            try builder.appendSlice(try s.pretty_print(allocator));
            try builder.appendSlice("\n");
        }

        try builder.appendSlice("} gotcha {\n");

        for (self.catch_block.items) |s| {
            try builder.appendSlice("    ");
            try builder.appendSlice(try s.pretty_print(allocator));
            try builder.appendSlice("\n");
        }

        try builder.appendSlice("}\n");

        const result = try builder.toOwnedSlice();
        return result;
    }
};

pub const ThrowawayStatement = struct {
    expression: Expression,

    certainty: f32 = 1.0,

    pub fn pretty_print(self: ThrowawayStatement, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice("throwaway: ");
        try builder.appendSlice(try self.expression.pretty_print(allocator));
        try builder.appendSlice(";");

        return try builder.toOwnedSlice();
    }
};

pub const Directive = struct {
    name: []const u8,
    arguments: ?std.ArrayList([]const u8),

    pub fn pretty_print(self: Directive, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice("@");
        try builder.appendSlice(self.name);

        if (self.arguments) |args| {
            try builder.appendSlice("(");
            for (args.items, 0..) |arg, i| {
                if (i > 0) {
                    try builder.appendSlice(", ");
                }
                try builder.appendSlice(arg);
            }
            try builder.appendSlice(")");
        }

        return try builder.toOwnedSlice();
    }
};

pub const RepeatStatement = struct {
    body: std.ArrayList(*Statement),
    count: Expression,
    variable: []const u8,

    certainty: f32 = 1.0,

    pub fn pretty_print(self: RepeatStatement, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice("repeat ");
        try builder.appendSlice(self.variable);
        try builder.appendSlice(" = 0 to ");
        try builder.appendSlice(try self.count.pretty_print(allocator));
        try builder.appendSlice(" {\n");

        for (self.body.items) |s| {
            try builder.appendSlice("    ");
            try builder.appendSlice(try s.pretty_print(allocator));
            try builder.appendSlice("\n");
        }

        try builder.appendSlice("}\n");

        const result = try builder.toOwnedSlice();
        return result;
    }
};

pub const ObjectStatement = struct {
    name: []const u8,
    properties: std.StringHashMap(LiteralType),

    pub fn pretty_print(self: ObjectStatement, allocator: std.mem.Allocator) anyerror![]const u8 {
        var builder = std.ArrayList(u8).init(allocator);
        defer builder.deinit();

        try builder.appendSlice("object ");
        try builder.appendSlice(self.name);
        try builder.appendSlice(" {\n");

        var entry_iter = self.properties.iterator();

        while (entry_iter.next()) |entry| {
            try builder.appendSlice("    ");
            try builder.appendSlice(entry.key_ptr.*);
            try builder.appendSlice(": ");
            try builder.appendSlice(entry.value_ptr.*.to_string());
            try builder.appendSlice(",\n");
        }

        try builder.appendSlice("}\n");

        return try builder.toOwnedSlice();
    }
};
