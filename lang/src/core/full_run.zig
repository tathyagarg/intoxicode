const std = @import("std");

const loader = @import("loader.zig");
const Lexer = @import("lexer/lexer.zig").Lexer;
const Parser = @import("parser/parser.zig").Parser;
const Runner = @import("runner/runner.zig").Runner;

pub fn run_file(allocator: std.mem.Allocator, fname: []const u8) anyerror!Runner {
    const file_contents = try loader.load_file(allocator, fname);

    var lexer = Lexer.init(file_contents, allocator);
    try lexer.scan_tokens();

    var parser = try Parser.init(lexer.tokens, allocator);
    const statements = try parser.parse();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const runner = try Runner.init(allocator, stdout.any(), stderr.any(), statements.items, try std.fs.cwd().realpathAlloc(allocator, fname));
    _ = try runner.run();

    return runner;
}
