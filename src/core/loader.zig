const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn load_file(allocator: std.mem.Allocator, file_path: []const u8) !std.ArrayList([]const u8) {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var lines = std.ArrayList([]const u8).init(allocator);

    const reader = file.reader().any();
    var line_buf: [1024]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        const trimmed = std.mem.trimRight(u8, line, " \t\n\r");
        if (trimmed.len == 0) continue;

        try lines.append(try allocator.dupe(u8, trimmed));
    }

    return lines;
}
