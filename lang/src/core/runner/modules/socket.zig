const std = @import("std");

const Expression = @import("../../parser/expressions.zig").Expression;
const Runner = @import("../runner.zig").Runner;
const require = @import("../runner.zig").require;

const Module = @import("mod.zig").Module;
const Handler = @import("../runner.zig").Handler;

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

pub fn socket(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.number}, &.{.number}, &.{.number} }, "socket", runner, args);

    const domain: u32 = @intFromFloat(args[0].literal.number);
    const _type: u32 = @intFromFloat(args[1].literal.number);
    const protocol: u32 = @intFromFloat(args[2].literal.number);

    const socket_fd = std.c.socket(domain, _type, protocol);
    if (socket_fd < 0) {
        return error.SocketError;
    }

    return Expression{
        .literal = .{
            .number = @floatFromInt(socket_fd),
        },
    };
}

pub fn connect(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.number}, &.{.string}, &.{.number} }, "connect", runner, args);

    const sockfd: c_int = @intFromFloat(args[0].literal.number);
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
    _ = .{sockaddr_ptr};

    try std.posix.connect(sockfd, sockaddr_ptr, @sizeOf(std.posix.sockaddr.in));

    return Expression{
        .literal = .{
            .number = @floatFromInt(0), // Return 0 on success
        },
    };
}

pub const Socket = Module{
    .name = "socket",
    .functions = std.StaticStringMap(Handler).initComptime(.{
        .{ "socket", &socket },
        .{ "connect", &connect },
    }),
    .constants = std.StaticStringMap(Expression).initComptime(.{
        // Address families
        .{ "AF_UNSPEC", Expression{ .literal = .{ .number = @floatFromInt(0) } } },
        .{ "AF_UNIX", Expression{ .literal = .{ .number = @floatFromInt(1) } } },
        .{ "AF_INET", Expression{ .literal = .{ .number = @floatFromInt(2) } } },
        .{ "AF_AX25", Expression{ .literal = .{ .number = @floatFromInt(3) } } },
        .{ "AF_IPX", Expression{ .literal = .{ .number = @floatFromInt(4) } } },
        .{ "AF_APPLETALK", Expression{ .literal = .{ .number = @floatFromInt(5) } } },
        .{ "AF_NETROM", Expression{ .literal = .{ .number = @floatFromInt(6) } } },
        .{ "AF_BRIDGE", Expression{ .literal = .{ .number = @floatFromInt(7) } } },
        .{ "AF_AAL5", Expression{ .literal = .{ .number = @floatFromInt(8) } } },
        .{ "AF_X25", Expression{ .literal = .{ .number = @floatFromInt(9) } } },
        .{ "AF_INET6", Expression{ .literal = .{ .number = @floatFromInt(10) } } },
        .{ "AF_MAX", Expression{ .literal = .{ .number = @floatFromInt(12) } } },

        // Socket types
        .{ "SOCK_STREAM", Expression{ .literal = .{ .number = @floatFromInt(1) } } },
        .{ "SOCK_DGRAM", Expression{ .literal = .{ .number = @floatFromInt(2) } } },
        .{ "SOCK_RAW", Expression{ .literal = .{ .number = @floatFromInt(3) } } },
        .{ "SOCK_RDM", Expression{ .literal = .{ .number = @floatFromInt(4) } } },
        .{ "SOCK_SEQPACKET", Expression{ .literal = .{ .number = @floatFromInt(5) } } },
        .{ "SOCK_PACKET", Expression{ .literal = .{ .number = @floatFromInt(10) } } },
    }),
};
