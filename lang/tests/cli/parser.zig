const std = @import("std");

const Parser = @import("intoxicode").cli.Parser;
const Argument = @import("intoxicode").cli.Argument;
const CliError = @import("intoxicode").errors.CliError;

test "cli.parser.help" {
    var parser = Parser.init("test", "This is a test parser", std.testing.allocator);
    defer parser.deinit();

    const allocator = std.testing.allocator;

    const message = try parser.help(allocator);
    defer allocator.free(message);

    try std.testing.expectEqualStrings(message, "\x1b[1mNAME\x1b[0m\n" ++
        "    test\n\n" ++
        "\x1b[1mDESCRIPTION\x1b[0m\n" ++
        "    This is a test parser");
}

test "cli.parser.add_argument" {
    var parser = Parser.init("test", "This is a test parser", std.testing.allocator);
    defer parser.deinit();

    var output_arg = Argument{
        .name = "output",
        .description = "The output file to write to",
        .option = "--out",
        .flag = "-O",
        .positional = true,
    };

    var verbose_arg = Argument{
        .name = "verbose",
        .description = "Enable verbose output",
        .option = "--verbose",
        .flag = "-v",
        .has_data = false,
    };

    try parser.add_argument(&output_arg);
    try parser.add_argument(&verbose_arg);

    try std.testing.expectEqualStrings(parser.get("output").?.name, "output");
    try std.testing.expectEqualStrings(parser.get("verbose").?.name, "verbose");

    try std.testing.expectEqual(parser.get("nonexistent"), null);
}

test "cli.parser.parse-single" {
    var parser = Parser.init("test", "This is a test parser", std.testing.allocator);
    defer parser.deinit();

    var output_arg = Argument{
        .name = "output",
        .description = "The output file to write to",
        .option = "--out",
        .flag = "-O",
        .positional = true,
    };

    try parser.add_argument(&output_arg);

    var args_const: [3][*:0]const u8 = .{
        "test",
        "--out",
        "file.txt",
    };

    const args: [][*:0]u8 = @ptrCast(&args_const);

    try parser.parse(args);

    try std.testing.expectEqualStrings(parser.get("output").?.value.?, "file.txt");
}

test "cli.parser.parse-multiple" {
    var parser = Parser.init("test", "This is a test parser", std.testing.allocator);
    defer parser.deinit();

    var output_arg = Argument{
        .name = "output",
        .description = "The output file to write to",
        .option = "--out",
        .flag = "-O",
        .positional = true,
    };

    var verbose_arg = Argument{
        .name = "verbose",
        .description = "Enable verbose output",
        .option = "--verbose",
        .flag = "-v",
        .has_data = false,
    };

    try parser.add_argument(&output_arg);
    try parser.add_argument(&verbose_arg);

    var args_const: [4][*:0]const u8 = .{
        "test",
        "--out",
        "file.txt",
        "-v",
    };

    const args: [][*:0]u8 = @ptrCast(&args_const);

    try parser.parse(args);

    try std.testing.expectEqualStrings(parser.get("output").?.value.?, "file.txt");
    try std.testing.expectEqualStrings(parser.get("verbose").?.value.?, "on");
}

test "cli.parser.parse-positional" {
    var parser = Parser.init("test", "This is a test parser", std.testing.allocator);
    defer parser.deinit();

    var positional_arg = Argument{
        .name = "input",
        .description = "The input file to read from",
        .positional = true,
    };

    try parser.add_argument(&positional_arg);

    var args_const: [2][*:0]const u8 = .{
        "test",
        "file.txt",
    };

    const args: [][*:0]u8 = @ptrCast(&args_const);

    try parser.parse(args);

    try std.testing.expectEqualStrings(parser.get("input").?.value.?, "file.txt");
}

test "cli.parser.parse-invalid" {
    var parser = Parser.init("test", "This is a test parser", std.testing.allocator);
    defer parser.deinit();

    var output_arg = Argument{
        .name = "output",
        .description = "The output file to write to",
        .option = "--out",
        .flag = "-O",
        .positional = true,
    };

    try parser.add_argument(&output_arg);

    var args_const: [1][*:0]const u8 = .{
        "test",
    };

    const args: [][*:0]u8 = @ptrCast(&args_const);

    try std.testing.expectError(CliError.InvalidArgumentList, parser.parse(args));
}
