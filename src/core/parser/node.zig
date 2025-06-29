const std = @import("std");

pub const NodeType = enum {
    Identifier,
    Keyword,
    Literal,
    Operator,
    Comment,
    Function,
    EOF,
};

pub const Node = struct {
    node_type: NodeType,
    value: ?[]const u8 = null,

    children: std.ArrayList(*Node),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType, value: ?[]const u8) Node {
        return Node{
            .node_type = node_type,
            .value = value,
            .children = std.ArrayList(*Node).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Node) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }

        self.children.deinit();
    }

    pub fn add_child(self: *Node, child: Node) !void {
        try self.children.append(child);
    }
};

pub const Statement = struct {
    children: std.ArrayList(*Node),
    certainty: f32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Statement {
        return Statement{
            .children = std.ArrayList(*Node).init(allocator),
            .certainty = 1.0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Statement) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit();
    }

    pub fn add_child(self: *Statement, child: *Node) !void {
        try self.children.append(child);
    }
};

pub const Program = struct {
    statements: std.ArrayList(*Statement),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Program {
        return Program{
            .statements = std.ArrayList(*Statement).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Program) void {
        for (self.statements.items) |statement| {
            statement.deinit();
            self.allocator.destroy(statement);
        }

        self.statements.deinit();
    }

    pub fn add_statement(self: *Program, statement: *Statement) !void {
        try self.statements.append(statement);
    }
};
