const std = @import("std");

const loader = @import("intoxicode").loader;

const allocator = std.testing.allocator;

test "core.loader.load_file" {
    const result = try loader.load_file(allocator, "examples/01_hello_world.??");
    result.backing.deinit();
    result.lines.deinit();
}

test "core.loader.nonexistent_file" {
    try std.testing.expectError(error.FileNotFound, loader.load_file(allocator, "nonexistent_file.??"));
}
