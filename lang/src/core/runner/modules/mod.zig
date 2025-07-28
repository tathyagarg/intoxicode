const std = @import("std");
const Statement = @import("../../parser/statement.zig").Statement;
const Expression = @import("../../parser/expressions.zig").Expression;
const Handler = @import("../runner.zig").Handler;

pub const Module = struct {
    name: []const u8,

    functions: std.StaticStringMap(Handler),
    constants: std.StaticStringMap(Expression),
};
