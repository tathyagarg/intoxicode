const std = @import("std");
const native_os = @import("builtin").os.tag;
const Expression = @import("../../parser/expressions.zig").Expression;

pub fn make_fd_num(sock: std.posix.socket_t) anyerror!i32 {
    return switch (native_os) {
        .windows => @as(i32, @intCast(@intFromPtr(sock))),
        else => @intCast(sock),
    };
}

pub fn make_socket_t(arg: Expression) anyerror!std.posix.socket_t {
    return switch (native_os) {
        .windows => @ptrFromInt(@as(u32, @intCast(arg.literal.integer))),
        else => @intCast(arg.literal.integer),
    };
}
