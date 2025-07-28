const std = @import("std");

const Expression = @import("../../parser/expressions.zig").Expression;
const Runner = @import("../runner.zig").Runner;
const require = @import("../runner.zig").require;

const Module = @import("mod.zig").Module;
const Handler = @import("../runner.zig").Handler;

const native_os = @import("builtin").os.tag;

const OpenMode = std.fs.File.OpenMode;

const READ = 0x0001;
const WRITE = 0x0002;

pub fn open(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.string}, &.{.number} }, "open", runner, args);

    const path: []const u8 = args[0].literal.string;
    const mode: u32 = @intFromFloat(args[1].literal.number);

    const file = try std.fs.cwd().openFile(
        path,
        .{
            .mode = if (mode == (READ | WRITE))
                .read_write
            else if (mode == READ)
                .read_only
            else if (mode == WRITE)
                .write_only
            else
                return error.InvalidMode,
        },
    );

    return Expression{
        .literal = .{
            .number = @floatFromInt(file.handle),
        },
    };
}

pub fn pread(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(4, &.{ &.{.number}, &.{.string}, &.{.number}, &.{.number} }, "pread", runner, args);

    const handle: c_int = @intFromFloat(args[0].literal.number);
    // const buffer: []u8 = args[1].literal.string;

    const buffer_size: usize = @intFromFloat(args[3].literal.number);

    var buffer: []u8 = try runner.allocator.alloc(u8, buffer_size);

    const offset: u32 = @intFromFloat(args[2].literal.number);

    const size = switch (native_os) {
        .windows => std.os.windows.ReadFile(handle, buffer[0..], offset),
        .macos, .linux => try std.posix.pread(handle, buffer[0..], offset),
        else => return error.UnsupportedOS,
    };

    args[1].* = Expression{ .literal = .{ .string = buffer } };

    return Expression{ .literal = .{ .number = @floatFromInt(size) } };
}

pub fn read(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.number}, &.{.string}, &.{.number} }, "read", runner, args);

    const handle: c_int = @intFromFloat(args[0].literal.number);
    // const buffer: []u8 = args[1].literal.string;

    const buffer_size: usize = @intFromFloat(args[2].literal.number);

    var buffer: []u8 = try runner.allocator.alloc(u8, buffer_size);

    const size = switch (native_os) {
        .windows => std.os.windows.ReadFile(handle, buffer[0..], null),
        .macos, .linux => try std.posix.read(handle, buffer[0..]),
        else => return error.UnsupportedOS,
    };

    args[1].* = Expression{ .literal = .{ .string = buffer } };

    return Expression{ .literal = .{ .number = @floatFromInt(size) } };
}

pub fn seek_to(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.number}, &.{.number} }, "seek_to", runner, args);

    const handle: c_int = @intFromFloat(args[0].literal.number);
    const offset: u32 = @intFromFloat(args[1].literal.number);

    try std.posix.lseek_SET(handle, offset);

    return Expression{ .literal = .{ .null = null } };
}

pub fn seek_by(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.number}, &.{.number} }, "seek_by", runner, args);

    const handle: c_int = @intFromFloat(args[0].literal.number);
    const offset: i32 = @intFromFloat(args[1].literal.number);

    try std.posix.lseek_CUR(handle, offset);

    return Expression{ .literal = .{ .null = null } };
}

pub const Fs = Module{
    .name = "fs",
    .functions = std.StaticStringMap(Handler).initComptime(.{
        .{ "open", &open },
        .{ "read", &read },
        .{ "pread", &pread },
        .{ "seek_to", &seek_to },
        .{ "seek_by", &seek_by },
    }),
    .constants = std.StaticStringMap(Expression).initComptime(.{
        .{ "READ", Expression{ .literal = .{ .number = @floatFromInt(READ) } } },
        .{ "WRITE", Expression{ .literal = .{ .number = @floatFromInt(WRITE) } } },
    }),
};
