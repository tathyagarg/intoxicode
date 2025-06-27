const std = @import("std");
const cli = @import("cli/cli.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var parser = cli.Parser.init("my_program", "A simple CLI program", std.heap.page_allocator);

    try parser.add_argument(@constCast(&cli.Argument{
        .name = "output",
        .description = "The output file to write to",
        .option = "--out",
        .flag = "-O",
        .positional = true,
    }));

    try parser.add_argument(@constCast(&cli.Argument{
        .name = "verbose",
        .description = "Enable verbose output",
        .option = "--verbose",
        .flag = "-v",
        .has_data = false,
    }));

    defer parser.deinit();

    parser.parse(std.os.argv) catch {
        const message = try parser.help(allocator);
        std.debug.print("{s}\n", .{message});

        return;
    };

    std.debug.print("Parsed arguments successfully.\n", .{});
    std.debug.print("Output file: {s}\n", .{parser.arguments.get("output").?.value orelse "not specified"});
    std.debug.print("Verbose mode: {s}\n", .{parser.arguments.get("verbose").?.value orelse "off"});
}
