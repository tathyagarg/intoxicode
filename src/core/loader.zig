const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn load_file(allocator: Allocator, file_path: []const u8) !std.ArrayList([]const u8) {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const reader = file.reader().any();

    var lines = std.ArrayList([]const u8).init(allocator);

    var line_buffer: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        const trimmed_line = std.mem.trimRight(u8, line, " \t\n\r");
        if (trimmed_line.len == 0) continue;

        try lines.append(trimmed_line);
    }

    return lines;
}
