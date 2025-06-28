const std = @import("std");

const loader = @import("intoxicode").loader;

test "core.loader.load_file" {
    const allocator = std.testing.allocator;

    var lines = try loader.load_file(allocator, "examples/01_hello_world.??");
    defer lines.deinit();
}

test "core.loader.nonexistent_file" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(error.FileNotFound, loader.load_file(allocator, "nonexistent_file.??"));
}
