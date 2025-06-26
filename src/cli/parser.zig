const std = @import("std");
const Allocator = std.mem.Allocator;

const Argument = @import("argument.zig").Argument;

const help_text: []const u8 =
    \\{[bold]s}NAME{[reset]s}
    \\    {[name]s}
    \\
    \\{[bold]s}DESCRIPTION{[reset]s}
    \\    {[description]s}
;

pub const Parser = struct {
    name: []const u8,
    description: ?[]const u8 = null,

    arguments: []Argument,

    pub fn parse(self: *const Parser, allocator: Allocator, args: [][*:0]u8) ![]const u8 {
        if (args.len == 1 and self.arguments.len != 0) {
            return self.help(allocator);
        }

        var option: ?*Argument = null;

        for (args[1..]) |arg| {
            const arg_slice = std.mem.span(arg);

            if (std.mem.startsWith(u8, arg_slice, "--")) {
                std.debug.print("[DBG][cli:parser] Found long option: {s}\n", .{arg});
                const option_name = arg_slice[2..];
                for (self.arguments, 0..) |_, i| {
                    var arg_data = &self.arguments[i];

                    if (arg_data.option == null) continue;

                    if (std.mem.eql(u8, arg_data.option.?[2..], option_name)) {
                        std.debug.print("[DBG][cli:parser] Matched argument: {s}\n", .{arg_data.option.?});
                        option = arg_data;
                        break;
                    }
                }
            } else if (std.mem.startsWith(u8, arg_slice, "-")) {
                std.debug.print("[DBG][cli:parser] Found short option: {s}\n", .{arg});
                const option_name = arg_slice[1..];

                for (self.arguments, 0..) |_, i| {
                    var arg_data = &self.arguments[i];

                    if (arg_data.flag == null) continue;

                    if (std.mem.eql(u8, arg_data.flag.?[1..], option_name)) {
                        std.debug.print("[DBG][cli:parser] Matched argument: {s}\n", .{arg_data.flag.?});
                        option = arg_data;
                        break;
                    }
                }
            } else {
                if (option != null) {
                    std.debug.print("[DBG][cli:parser] Found named argument: {s} with value: {s}\n", .{ option.?.name, arg });

                    const value_slice = std.mem.span(arg);
                    option.?.value = value_slice;

                    option = null;
                } else {
                    std.debug.print("[DBG][cli:parser] Found positional argument: {s}\n", .{arg});
                }
            }
        }

        return "";
    }

    pub fn help(self: *const Parser, allocator: Allocator) ![]const u8 {
        const message = try std.fmt.allocPrint(
            allocator,
            help_text,
            .{
                .bold = "\x1b[1m",
                .reset = "\x1b[0m",
                .name = self.name,
                .description = self.description orelse "No description provided.",
            },
        );

        return message;
    }
};

test "cli.parser.help" {
    const parser = Parser{
        .name = "test",
        .description = "This is a test parser.",
        .arguments = &.{},
    };

    try parser.help();
}
