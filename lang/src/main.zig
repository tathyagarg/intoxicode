const std = @import("std");

const Runner = @import("root.zig").runner.Runner;
const Parser = @import("root.zig").parser.Parser;
const Lexer = @import("root.zig").lexer.Lexer;
const loader = @import("root.zig").loader;

const cli = @import("root.zig").cli;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stdout = std.io.getStdOut().writer();
    var stderr = std.io.getStdErr().writer();

    var cli_parser = cli.Parser.init("intoxicode", "Run drunk code.", allocator);

    var input_file = cli.Argument{
        .name = "file",
        .description = "The intoxicode file to run.",
        .option = "--file",
        .flag = "-f",
    };

    var content = cli.Argument{
        .name = "content",
        .description = "The intoxicode content to run.",
        .option = "--content",
        .flag = "-c",
    };

    try cli_parser.add_argument(&input_file);
    try cli_parser.add_argument(&content);

    const target = @import("builtin").target;

    if (target.os.tag == .windows) {
        const raw_args = try std.process.argsAlloc(allocator);
        var args = try allocator.alloc([*:0]u8, raw_args.len);

        for (raw_args, 0..) |arg, i| {
            args[i] = arg;
        }

        try cli_parser.parse(args);
    } else {
        try cli_parser.parse(std.os.argv);
    }

    const file_value = cli_parser.arguments.get("file").?.value;
    const data = if (file_value == null)
        cli_parser.arguments.get("content").?.value.?
    else
        try loader.load_file(allocator, file_value.?);

    var lexer = Lexer.init(data, allocator);

    try lexer.scan_tokens();

    var parser = try Parser.init(lexer.tokens, allocator);
    const statements = try parser.parse();

    const runner = try Runner.init(
        allocator,
        stdout.any(),
        stderr.any(),
        statements.items,
        if (file_value) |v|
            try std.fs.cwd().realpathAlloc(allocator, v)
        else
            try std.fs.cwd().realpathAlloc(allocator, "."),
    );

    _ = try runner.run();
}
