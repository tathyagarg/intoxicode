const std = @import("std");

const Runner = @import("root.zig").runner.Runner;
const Parser = @import("root.zig").parser.Parser;
const Lexer = @import("root.zig").lexer.Lexer;
const loader = @import("root.zig").loader;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stdout = std.io.getStdOut().writer();
    var stderr = std.io.getStdErr().writer();

    const data = try loader.load_file(allocator, "examples/05_functions.??");
    var lexer = Lexer.init(data, allocator);

    try lexer.scan_tokens();

    var parser = Parser.init(lexer.tokens, allocator);
    const statements = try parser.parse();

    // std.debug.print("Parsed statements:\n\n{s}\n", .{try statements.items[0].pretty_print(allocator)});

    const runner = try Runner.init(allocator, stdout.any(), stderr.any());

    _ = try runner.run(
        statements.items,
        runner.variables,
    );
}
