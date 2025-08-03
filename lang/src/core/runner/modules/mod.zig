const std = @import("std");
const Statement = @import("../../parser/statement.zig").Statement;
const Expression = @import("../../parser/expressions.zig").Expression;
const Handler = @import("../runner.zig").Handler;
const CustomType = @import("../../parser/parser.zig").expressions.CustomType;
const Runner = @import("../runner.zig").Runner;

pub const Module = struct {
    name: []const u8,

    functions: std.StaticStringMap(Handler),
    constants: std.StaticStringMap(Expression),
    customs: std.StaticStringMap(*const fn (Runner) anyerror!CustomType) = std.StaticStringMap(*const fn (Runner) anyerror!CustomType).initComptime(.{}),
};
