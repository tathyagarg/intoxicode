test "all" {
    _ = @import("cli/parser.zig");

    _ = @import("runtime/loader.zig");
    _ = @import("runtime/execution.zig");
}
