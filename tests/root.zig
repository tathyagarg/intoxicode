test "all" {
    _ = @import("cli/parser.zig");

    _ = @import("core/loader.zig");
    _ = @import("core/lexer.zig");

    _ = @import("runtime/execution.zig");
}
