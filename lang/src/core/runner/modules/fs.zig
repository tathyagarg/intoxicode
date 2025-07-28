const std = @import("std");

const Expression = @import("../../parser/expressions.zig").Expression;
const Runner = @import("../runner.zig").Runner;
const require = @import("../runner.zig").require;

const Module = @import("mod.zig").Module;
const Handler = @import("../runner.zig").Handler;

const native_os = @import("builtin").os.tag;

pub const Fs = Module{
    .name = "fs",
    .functions = std.StaticStringMap(Handler).init(),
    .constants = std.StaticStringMap(Expression).init(),
};
