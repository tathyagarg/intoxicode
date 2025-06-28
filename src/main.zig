const std = @import("std");
const cli = @import("cli/cli.zig");
const runtime = @import("runtime/runtime.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var parser = cli.Parser.init("my_program", "A simple CLI program", std.heap.page_allocator);

    try parser.add_argument(@constCast(&cli.Argument{
        .name = "file",
        .description = "The file to interpret",
        .option = "--file",
        .flag = "-F",
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

    const file_path = parser.get("file") orelse {
        std.debug.print("No file specified.\n", .{});
        return;
    };

    _ = try runtime.loader.load_file(allocator, file_path.value.?);
}
