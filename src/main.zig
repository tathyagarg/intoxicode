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

    const data = try loader.load_file(allocator, "examples/01_hello_world.??");
    var lexer = Lexer.init(data, allocator);

    try lexer.scan_tokens();

    var parser = Parser.init(lexer.tokens, allocator);
    const statements = try parser.parse();

    const runner = try Runner.init(allocator, stdout.any(), stderr.any());

    try runner.run(
        statements.items,
    );
}
