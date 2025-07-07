const std = @import("std");

const loader = @import("intoxicode").loader;

test "core.loader.load_file" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const result = try loader.load_file(allocator, "examples/01_hello_world.??");
    allocator.free(result);
}

test "core.loader.nonexistent_file" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(error.FileNotFound, loader.load_file(allocator, "nonexistent_file.??"));
}
