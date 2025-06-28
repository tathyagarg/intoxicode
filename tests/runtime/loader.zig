const std = @import("std");

const runtime = @import("intoxicode").runtime;

test "runtime.loader.load_file" {
    const allocator = std.testing.allocator;

    _ = try runtime.loader.load_file(allocator, "examples/01_hello_world.??");
}

test "runtime.loader.nonexistent_file" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(error.FileNotFound, runtime.loader.load_file(allocator, "nonexistent_file.??"));
}
