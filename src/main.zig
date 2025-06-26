const std = @import("std");
const cli = @import("cli/cli.zig");

pub fn main() !void {
    var arguments = [_]cli.Argument{.{
        .name = "input",
        .description = "The input file to run",
        .required = true,
        .option = "--input",
    }};

    const parser = cli.Parser{
        .name = "intoxicode",
        .description = "A CLI tool to run intoxicode code",

        .arguments = &arguments,
    };

    const allocator = std.heap.page_allocator;
    _ = try parser.parse(allocator, std.os.argv);

    for (parser.arguments) |arg| {
        if (arg.value) |value| {
            std.debug.print("[DBG][main] Argument {s} has value: {s}\n", .{ arg.name, value });
        } else {
            std.debug.print("[DBG][main] Argument {s} has no value\n", .{arg.name});
        }
    }
}
