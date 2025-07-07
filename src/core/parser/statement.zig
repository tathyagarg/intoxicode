const std = @import("std");

const Expression = @import("expressions.zig").Expression;

pub const Statement = union(enum) {
    expression: Expression,
    assignment: Assignment,
    if_statement: IfStatement,
    loop_statement: LoopStatement,
    function_declaration: FunctionDeclaration,
    try_statement: TryStatement,
    throwaway_statement: ThrowawayStatement,

    pub fn deinit(self: Statement) void {
        switch (self) {
            .expression => |e| e.deinit(),
            .declaration => |d| d.deinit(),
            .assignment => |a| a.deinit(),
            .if_statement => |i| i.deinit(),
            .loop_statement => |l| l.deinit(),
            .function_declaration => |f| f.deinit(),
            .try_statement => |t| t.deinit(),
            .throwaway_statement => |t| t.deinit(),
        }
    }

    pub fn get_certainty(self: Statement) !f32 {
        return switch (self) {
            .expression => std.debug.panic("Cannot get certainty of an expression statement", .{}),
            .assignment => self.assignment.certainty,
            .if_statement => self.if_statement.certainty,
            .loop_statement => self.loop_statement.certainty,
            .function_declaration => self.function_declaration.certainty,
            .try_statement => self.try_statement.certainty,
            .throwaway_statement => self.throwaway_statement.certainty,
        };
    }

    pub fn set_certainty(self: *Statement, certainty: f32) !void {
        switch (self.*) {
            .expression => std.debug.panic("Cannot set certainty of an expression statement", .{}),
            .assignment => |*a| a.certainty = certainty,
            .if_statement => |*i| i.certainty = certainty,
            .loop_statement => |*l| l.certainty = certainty,
            .function_declaration => |*f| f.certainty = certainty,
            .try_statement => |*t| t.certainty = certainty,
            .throwaway_statement => |*t| t.certainty = certainty,
        }
    }

    pub fn pretty_print(self: Statement, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .expression => self.expression.pretty_print(allocator),
            .assignment => |a| {
                var builder = std.ArrayList(u8).init(allocator);

                try builder.appendSlice(a.identifier);
                try builder.appendSlice(" = ");

                const expr_str = try a.expression.pretty_print(allocator);
                try builder.appendSlice(expr_str);

                try builder.appendSlice(";\n");

                return try builder.toOwnedSlice();
            },
            .if_statement => self.if_statement.pretty_print(allocator),
            else => unreachable,
        };
    }
};

pub const Assignment = struct {
    identifier: []const u8,
    expression: Expression,

    certainty: f32 = 1.0,

    pub fn deinit(self: Assignment) void {
        self.expression.deinit();
    }
};

pub const IfStatement = struct {
    condition: Expression,
    then_branch: std.ArrayList(*Statement),
    else_branch: ?std.ArrayList(*Statement),

    certainty: f32 = 1.0,

    pub fn deinit(self: IfStatement) void {
        self.condition.deinit();
        for (self.then_branch.items) |s| s.deinit();
        self.then_branch.deinit();
        if (self.else_branch) |else_branch| {
            for (else_branch.items) |s| s.deinit();
            else_branch.deinit();
        }
    }

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

    pub fn deinit(self: LoopStatement) void {
        self.condition.deinit();
        for (self.body.items) |s| s.deinit();
        self.body.deinit();
    }
};

pub const FunctionDeclaration = struct {
    name: []const u8,
    parameters: std.ArrayList([]const u8),
    body: std.ArrayList(*Statement),

    certainty: f32 = 1.0,

    pub fn deinit(self: FunctionDeclaration) void {
        for (self.parameters.items) |param| std.mem.free(param);
        self.parameters.deinit();
        for (self.body.items) |s| s.deinit();
        self.body.deinit();
    }
};

pub const TryStatement = struct {
    expression: Expression,
    catch_block: ?std.ArrayList(Statement),

    certainty: f32 = 1.0,

    pub fn deinit(self: TryStatement) void {
        self.expression.deinit();
        for (self.catch_block.?.items) |s| s.deinit();
        self.catch_block.?.deinit();
    }
};

pub const ThrowawayStatement = struct {
    expression: Expression,

    certainty: f32 = 1.0,

    pub fn deinit(self: ThrowawayStatement) void {
        self.expression.deinit();
    }
};
