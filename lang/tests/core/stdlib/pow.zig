const std = @import("std");

const Runner = @import("intoxicode").runner.Runner;
const Parser = @import("intoxicode").parser.Parser;
const Lexer = @import("intoxicode").lexer.Lexer;
const loader = @import("intoxicode").loader;

test "min" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stdout = std.ArrayList(u8).init(allocator);
    defer stdout.deinit();

    var stderr = std.ArrayList(u8).init(allocator);
    defer stderr.deinit();

    const data = try loader.load_file(allocator, "examples/stdlib/03_pow.??");
    var lexer = Lexer.init(data, allocator);

    try lexer.scan_tokens();

    var parser = Parser.init(lexer.tokens, allocator);
    const statements = try parser.parse();

    const runner = try Runner.init(allocator, stdout.writer().any(), stderr.writer().any(), statements.items);

    try runner.run();

    try std.testing.expectEqualStrings(
        "81",
        stdout.items[0..2],
    );
}
