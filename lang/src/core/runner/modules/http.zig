const std = @import("std");

const Module = @import("mod.zig").Module;
const Handler = @import("../runner.zig").Handler;
const Expression = @import("../../parser/expressions.zig").Expression;

pub const Http = Module{
    .name = "http",
    .functions = std.StaticStringMap(Handler).initComptime(.{}),
    .constants = std.StaticStringMap(Expression).initComptime(.{
        .{ "get", Expression{ .literal = .{ .string = "GET" } } },
        .{ "post", Expression{ .literal = .{ .string = "POST" } } },
        .{ "put", Expression{ .literal = .{ .string = "PUT" } } },
        .{ "delete", Expression{ .literal = .{ .string = "DELETE" } } },
    }),
};
