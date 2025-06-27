const std = @import("std");
const Allocator = std.mem.Allocator;

const Argument = @import("argument.zig").Argument;
const CliError = @import("../errors.zig").CliError;

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

    arguments: std.StringHashMap(*Argument),

    pub fn init(
        name: []const u8,
        description: ?[]const u8,
        allocator: Allocator,
    ) Parser {
        return Parser{
            .name = name,
            .description = description,
            .arguments = std.StringHashMap(*Argument).init(allocator),
        };
    }

    pub fn deinit(self: *Parser) void {
        self.arguments.deinit();
    }

    pub fn add_argument(
        self: *Parser,
        arg: *Argument,
    ) !void {
        self.arguments.put(arg.name, arg) catch |err| {
            return err;
        };
    }

    pub fn parse(self: *const Parser, args: [][*:0]u8) !void {
        if (args.len == 1 and self.arguments.count() != 0) {
            return CliError.InvalidArgumentList;
        }

        var option: ?*Argument = null;

        for (args[1..]) |arg| {
            const arg_slice = std.mem.span(arg);

            if (std.mem.startsWith(u8, arg_slice, "--")) {
                var iterator = self.arguments.iterator();
                while (iterator.next()) |entry| {
                    const object_option = entry.value_ptr.*.option orelse "";
                    if (std.mem.eql(u8, object_option, arg_slice)) {
                        option = entry.value_ptr.*;
                        break;
                    }
                }
            } else if (std.mem.startsWith(u8, arg_slice, "-")) {
                var iterator = self.arguments.iterator();
                while (iterator.next()) |entry| {
                    const object_flag = entry.value_ptr.*.flag orelse "";
                    if (std.mem.eql(u8, object_flag, arg_slice)) {
                        if (entry.value_ptr.*.has_data) {
                            option = entry.value_ptr.*;
                        } else {
                            entry.value_ptr.*.value = ("on");
                        }
                        break;
                    }
                }
            } else {
                if (option != null) {
                    const value_slice = std.mem.span(arg);
                    option.?.value = value_slice;

                    option = null;
                } else {
                    var iterator = self.arguments.iterator();
                    while (iterator.next()) |entry| {
                        if (entry.value_ptr.*.positional and entry.value_ptr.*.value == null) {
                            entry.value_ptr.*.value = std.mem.span(arg);
                            break;
                        }
                    }
                }
            }
        }

        return;
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

    pub fn get(self: *const Parser, name: []const u8) ?*Argument {
        return self.arguments.get(name);
    }
};
