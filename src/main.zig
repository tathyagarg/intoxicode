const std = @import("std");
const cli = @import("cli/cli.zig");

pub fn main() !void {
    var arguments = [_]cli.Argument{
        .{
            .name = "input",
            .description = "The input file to run",
            .required = true,
            .option = "--input",
        }
    };

    const parser = cli.Parser{
        .name = "intoxicode",
        .description = "A CLI tool to run intoxicode code",

        .arguments = &arguments,
    };

    const allocator = std.heap.page_allocator;
    const message = try parser.parse(allocator, std.os.argv);
    if (message.len > 0) {
        std.debug.print("{s}\n", .{message});
    } else {
        std.debug.print("No message to display.\n", .{});
    }
}

