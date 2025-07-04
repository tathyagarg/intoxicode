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
};

pub const Assignment = struct {
    identifier: []const u8,
    expression: Expression,

    pub fn deinit(self: Assignment) void {
        self.expression.deinit();
    }
};

pub const IfStatement = struct {
    condition: Expression,
    then_branch: std.ArrayList(Statement),
    else_branch: ?std.ArrayList(Statement),

    pub fn deinit(self: IfStatement) void {
        self.condition.deinit();
        for (self.then_branch.items) |s| s.deinit();
        self.then_branch.deinit();
        if (self.else_branch) |else_branch| {
            for (else_branch.items) |s| s.deinit();
            else_branch.deinit();
        }
    }
};

pub const LoopStatement = struct {
    condition: Expression,
    body: std.ArrayList(Statement),

    pub fn deinit(self: LoopStatement) void {
        self.condition.deinit();
        for (self.body.items) |s| s.deinit();
        self.body.deinit();
    }
};

pub const FunctionDeclaration = struct {
    name: []const u8,
    parameters: std.ArrayList([]const u8),
    body: std.ArrayList(Statement),

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

    pub fn deinit(self: TryStatement) void {
        self.expression.deinit();
        for (self.catch_block.?.items) |s| s.deinit();
        self.catch_block.?.deinit();
    }
};

pub const ThrowawayStatement = struct {
    expression: Expression,

    pub fn deinit(self: ThrowawayStatement) void {
        self.expression.deinit();
    }
};
