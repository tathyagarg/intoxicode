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

fn make_handle(arg: Expression) anyerror!std.posix.fd_t {
    return switch (native_os) {
        .windows => @ptrFromInt(@as(u32, @intCast(arg.literal.integer))),
        .macos, .linux => @intCast(arg.literal.integer),
        else => return error.UnsupportedOS,
    };
}

pub fn open(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.string}, &.{.integer} }, "open", runner, args);

    const path: []const u8 = args[0].literal.string;
    const mode: u32 = @intCast(args[1].literal.integer);

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
            .number = switch (native_os) {
                .windows => @floatFromInt(@as(usize, @intFromPtr(file.handle))),
                .macos, .linux => @floatFromInt(file.handle),
                else => return error.UnsupportedOS,
            },
        },
    };
}

pub fn pread(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(4, &.{ &.{.integer}, &.{.string}, &.{.integer}, &.{.integer} }, "pread", runner, args);

    const handle = try make_handle(args[0].*);

    const buffer_size: usize = @intCast(args[3].literal.integer);

    var buffer: []u8 = try runner.allocator.alloc(u8, buffer_size);

    const offset: u32 = @intCast(args[2].literal.integer);

    const size = try std.posix.pread(handle, buffer[0..], offset);

    args[1].* = Expression{ .literal = .{ .string = buffer } };

    return Expression{ .literal = .{ .integer = @intCast(size) } };
}

pub fn read(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.integer}, &.{.string}, &.{.integer} }, "read", runner, args);

    const handle = try make_handle(args[0].*);
    const buffer_size: usize = @intCast(args[2].literal.integer);

    var buffer: []u8 = try runner.allocator.alloc(u8, buffer_size);

    const size = try std.posix.read(handle, buffer[0..]);

    args[1].* = Expression{ .literal = .{ .string = buffer } };

    return Expression{ .literal = .{ .integer = @intCast(size) } };
}

pub fn seek_to(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.integer}, &.{.integer} }, "seek_to", runner, args);

    const handle = try make_handle(args[0].*);
    const offset: u32 = @intCast(args[1].literal.integer);

    try std.posix.lseek_SET(handle, offset);

    return Expression{ .literal = .{ .null = null } };
}

pub fn seek_by(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.integer}, &.{.integer} }, "seek_by", runner, args);

    const handle = try make_handle(args[0].*);
    const offset: i32 = args[1].literal.integer;

    try std.posix.lseek_CUR(handle, offset);

    return Expression{ .literal = .{ .null = null } };
}

pub fn write(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.integer}, &.{.string} }, "write", runner, args);

    const handle = try make_handle(args[0].*);
    const data: []const u8 = args[1].literal.string;

    const size = try std.posix.write(handle, data);

    return Expression{ .literal = .{ .integer = @intCast(size) } };
}

pub fn close(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.integer}}, "close", runner, args);

    const handle = try make_handle(args[0].*);

    std.posix.close(handle);

    return Expression{ .literal = .{ .null = null } };
}

pub fn read_to_zero(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.integer}, &.{.string} }, "read_to_zero", runner, args);

    const handle = try make_handle(args[0].*);

    var buffer: [1]u8 = undefined;
    var res = std.ArrayList(u8).init(runner.allocator);

    while (buffer[0] != 0) {
        _ = try std.posix.read(handle, buffer[0..]);

        if (buffer[0] == 0) {
            break;
        }

        try res.appendSlice(&buffer);
    }

    const string = try res.toOwnedSlice();
    args[1].* = Expression{ .literal = .{ .string = string } };

    return Expression{ .literal = .{ .null = null } };
}

pub fn read_full_buffer(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.integer}, &.{.integer} }, "read_full_buffer", runner, args);

    const handle = try make_handle(args[0].*);
    const chunk_size: usize = @intCast(args[1].literal.integer);

    var buffer: std.ArrayList(u8) = std.ArrayList(u8).init(runner.allocator);
    var chunk: []u8 = try runner.allocator.alloc(u8, chunk_size);

    defer runner.allocator.free(chunk);

    while (true) {
        const size = try std.posix.read(handle, chunk[0..]);

        if (size == 0) {
            break; // EOF
        }

        try buffer.appendSlice(chunk[0..size]);
    }

    const result = try buffer.toOwnedSlice();
    return Expression{ .literal = .{ .string = result } };
}

pub const Fs = Module{
    .name = "fs",
    .functions = std.StaticStringMap(Handler).initComptime(.{
        .{ "open", &open },
        .{ "read", &read },
        .{ "pread", &pread },
        .{ "seek_to", &seek_to },
        .{ "seek_by", &seek_by },
        .{ "write", &write },
        .{ "close", &close },
        .{ "read_to_zero", &read_to_zero },
        .{ "read_full_buffer", &read_full_buffer },
    }),
    .constants = std.StaticStringMap(Expression).initComptime(.{
        .{ "READ", Expression{ .literal = .{ .integer = READ } } },
        .{ "WRITE", Expression{ .literal = .{ .integer = WRITE } } },
    }),
};
