const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn load_file(allocator: std.mem.Allocator, file_path: []const u8) ![]const u8 {
    const file = std.fs.cwd().openFile(file_path, .{}) catch {
        std.debug.panic("File {s} not found", .{file_path});
    };
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try std.fs.cwd().readFileAlloc(allocator, file_path, file_size);

    return buffer;
}
