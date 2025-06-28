const std = @import("std");
const Allocator = std.mem.Allocator;

const execution = @import("execution.zig");

pub fn load_file(allocator: Allocator, file_path: []const u8) !execution.Execution {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const reader = file.reader().any();

    var intox_executer = try execution.Execution.init(allocator);
    defer intox_executer.deinit();
    try intox_executer.add_empty_block(execution.CodeBlockType.main);

    var line_buffer: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        if (line.len == 0) continue;

        try intox_executer.execution_blocks.items[0].add_line(line);
    }

    return intox_executer;
}
