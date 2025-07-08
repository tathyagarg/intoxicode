test "all" {
    _ = @import("cli/parser.zig");

    _ = @import("core/loader.zig");
    _ = @import("core/lexer.zig");

    // _ = @import("core/parser.zig");
    _ = @import("core/parser/expressions.zig");
    _ = @import("core/parser/parser.zig");

    _ = @import("core/runner/runner.zig");

    _ = @import("core/stdlib/min.zig");
    _ = @import("core/stdlib/max.zig");
    _ = @import("core/stdlib/pow.zig");
}
