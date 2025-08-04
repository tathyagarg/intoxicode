const std = @import("std");

const Expression = @import("../../parser/expressions.zig").Expression;
const Runner = @import("../runner.zig").Runner;
const require = @import("../runner.zig").require;

const Module = @import("mod.zig").Module;
const Handler = @import("../runner.zig").Handler;

const fs = @import("fs.zig");

const native_os = @import("builtin").os.tag;

fn string_to_u8(s: []const u8) u8 {
    var result: u8 = 0;
    for (s) |c| {
        result = result * 10 + (c - '0');
    }

    return result;
}

fn u8_to_u32(parts: [4]u8) u32 {
    return (@as(u32, parts[0]) << 24) |
        (@as(u32, parts[1]) << 16) |
        (@as(u32, parts[2]) << 8) |
        @as(u32, parts[3]);
}

const AF_UNSPEC = 0;
const AF_UNIX = 1;
const AF_INET = 2;
const AF_AX25 = 3;
const AF_IPX = 4;
const AF_APPLETALK = 5;
const AF_NETROM = 6;
const AF_BRIDGE = 7;
const AF_AAL5 = 8;
const AF_X25 = 9;
const AF_INET6 = 10;
const AF_MAX = 12;

const SOCK_STREAM = 1;
const SOCK_DGRAM = 2;
const SOCK_RAW = 3;
const SOCK_RDM = 4;
const SOCK_SEQPACKET = 5;
const SOCK_PACKET = 10;

fn make_fd_num(sock: std.posix.socket_t) anyerror!f32 {
    return switch (native_os) {
        .windows => @floatFromInt(@as(usize, @intFromPtr(sock))),
        else => @floatFromInt(sock),
    };
}

fn make_socket_t(arg: Expression) anyerror!std.posix.socket_t {
    return switch (native_os) {
        .windows => @ptrFromInt(@as(u32, @intFromFloat(arg.literal.number))),
        else => @intFromFloat(arg.literal.number),
    };
}

pub fn socket(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.number}, &.{.number}, &.{.number} }, "socket", runner, args);

    const domain: u32 = @intFromFloat(args[0].literal.number);
    const _type: u32 = @intFromFloat(args[1].literal.number);
    const protocol: u32 = @intFromFloat(args[2].literal.number);

    const socket_fd = try std.posix.socket(domain, _type, protocol);

    return Expression{
        .literal = .{
            .number = try make_fd_num(socket_fd),
        },
    };
}

pub fn connect(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.number}, &.{.string}, &.{.number} }, "connect", runner, args);

    const sockfd: std.posix.socket_t = try make_socket_t(args[0].*);
    const address_raw: []const u8 = args[1].literal.string;
    const port_raw: u16 = @intFromFloat(args[2].literal.number);

    const port: [2]u8 = [_]u8{
        @as(u8, @intCast(port_raw >> 8)),
        @as(u8, @intCast(port_raw & 0xFF)),
    };

    var parts_raw = std.mem.split(u8, address_raw, ".");
    var address: [4]u8 = undefined;

    var i: usize = 0;

    while (parts_raw.next()) |part| : (i += 1) {
        const part_value = string_to_u8(part);
        address[i] = part_value;
    }

    // const res_address: u32 = u8_to_u32(parts);

    const sockaddr_in = switch (native_os) {
        .macos => std.posix.sockaddr{
            .len = @sizeOf(std.posix.sockaddr.in),
            .family = std.c.AF.INET,
            .data = port ++ address ++ [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        .linux => std.posix.sockaddr{
            .family = std.c.AF.INET,
            .data = port ++ address ++ [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        .windows => std.os.windows.ws2_32.sockaddr{
            .family = std.c.AF.INET,
            .data = port ++ address ++ [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        else => return error.UnsupportedOS,
    };

    const sockaddr_ptr: *const std.posix.sockaddr = @ptrCast(&sockaddr_in);

    try std.posix.connect(sockfd, sockaddr_ptr, @sizeOf(std.posix.sockaddr.in));

    return Expression{
        .literal = .{
            .number = @floatFromInt(0), // Return 0 on success
        },
    };
}

pub fn bind(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.number}, &.{.string}, &.{.number} }, "bind", runner, args);

    const sockfd: std.posix.socket_t = try make_socket_t(args[0].*);
    const address_raw: []const u8 = args[1].literal.string;
    const port_raw: u16 = @intFromFloat(args[2].literal.number);

    const port: [2]u8 = [_]u8{
        @as(u8, @intCast(port_raw >> 8)),
        @as(u8, @intCast(port_raw & 0xFF)),
    };

    var parts_raw = std.mem.split(u8, address_raw, ".");
    var address: [4]u8 = undefined;

    var i: usize = 0;

    while (parts_raw.next()) |part| : (i += 1) {
        const part_value = string_to_u8(part);
        address[i] = part_value;
    }

    const sockaddr_in = switch (native_os) {
        .macos => std.posix.sockaddr{
            .len = @sizeOf(std.posix.sockaddr.in),
            .family = std.c.AF.INET,
            .data = port ++ address ++ [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        .linux => std.posix.sockaddr{
            .family = std.c.AF.INET,
            .data = port ++ address ++ [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        .windows => std.os.windows.ws2_32.sockaddr{
            .family = std.c.AF.INET,
            .data = port ++ address ++ [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        else => return error.UnsupportedOS,
    };

    const sockaddr_ptr: *const std.posix.sockaddr = @ptrCast(&sockaddr_in);
    _ = .{sockaddr_ptr};

    try std.posix.bind(sockfd, sockaddr_ptr, @sizeOf(std.posix.sockaddr.in));

    return Expression{
        .literal = .{
            .number = @floatFromInt(0), // Return 0 on success
        },
    };
}

pub fn listen(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(2, &.{ &.{.number}, &.{.number} }, "listen", runner, args);

    const sockfd: std.posix.socket_t = try make_socket_t(args[0].*);
    const backlog: u31 = @intFromFloat(args[1].literal.number);

    try std.posix.listen(sockfd, backlog);

    return Expression{ .literal = .{ .null = null } };
}

pub fn accept(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(4, &.{ &.{.number}, &.{.string}, &.{.number}, &.{.number} }, "accept", runner, args);

    const sockfd: std.posix.socket_t = try make_socket_t(args[0].*);
    var sockaddr: std.c.sockaddr = undefined;
    var socklen: u32 = undefined;

    const client_fd: std.posix.socket_t = try std.posix.accept(sockfd, &sockaddr, &socklen, 0);

    return Expression{
        .literal = .{
            .number = try make_fd_num(client_fd),
        },
    };
    // return Expression{ .literal = .{ .number = @floatFromInt(client_fd) } };
}

pub const Socket = Module{
    .name = "socket",
    .functions = std.StaticStringMap(Handler).initComptime(.{
        .{ "socket", &socket },
        .{ "connect", &connect },
        .{ "close", &fs.close },
        .{ "bind", &bind },
        .{ "listen", &listen },
        .{ "accept", &accept },
    }),
    .constants = std.StaticStringMap(Expression).initComptime(.{
        // Address families
        .{ "AF_UNSPEC", Expression{ .literal = .{ .number = @floatFromInt(AF_UNSPEC) } } },
        .{ "AF_UNIX", Expression{ .literal = .{ .number = @floatFromInt(AF_UNIX) } } },
        .{ "AF_INET", Expression{ .literal = .{ .number = @floatFromInt(AF_INET) } } },
        .{ "AF_AX25", Expression{ .literal = .{ .number = @floatFromInt(AF_AX25) } } },
        .{ "AF_IPX", Expression{ .literal = .{ .number = @floatFromInt(AF_IPX) } } },
        .{ "AF_APPLETALK", Expression{ .literal = .{ .number = @floatFromInt(AF_APPLETALK) } } },
        .{ "AF_NETROM", Expression{ .literal = .{ .number = @floatFromInt(AF_NETROM) } } },
        .{ "AF_BRIDGE", Expression{ .literal = .{ .number = @floatFromInt(AF_BRIDGE) } } },
        .{ "AF_AAL5", Expression{ .literal = .{ .number = @floatFromInt(AF_AAL5) } } },
        .{ "AF_X25", Expression{ .literal = .{ .number = @floatFromInt(AF_X25) } } },
        .{ "AF_INET6", Expression{ .literal = .{ .number = @floatFromInt(AF_INET6) } } },
        .{ "AF_MAX", Expression{ .literal = .{ .number = @floatFromInt(AF_MAX) } } },

        // Socket types
        .{ "SOCK_STREAM", Expression{ .literal = .{ .number = @floatFromInt(SOCK_STREAM) } } },
        .{ "SOCK_DGRAM", Expression{ .literal = .{ .number = @floatFromInt(SOCK_DGRAM) } } },
        .{ "SOCK_RAW", Expression{ .literal = .{ .number = @floatFromInt(SOCK_RAW) } } },
        .{ "SOCK_RDM", Expression{ .literal = .{ .number = @floatFromInt(SOCK_RDM) } } },
        .{ "SOCK_SEQPACKET", Expression{ .literal = .{ .number = @floatFromInt(SOCK_SEQPACKET) } } },
        .{ "SOCK_PACKET", Expression{ .literal = .{ .number = @floatFromInt(SOCK_PACKET) } } },
    }),
};
