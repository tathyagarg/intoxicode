const std = @import("std");

const Parser = @import("intoxicode").parser.Parser;

test "cli.parser.help" {
    const parser = Parser{
        .name = "test",
        .description = "This is a test parser.",
        .arguments = &.{},
    };

    const allocator = std.testing.allocator;

    const message = try parser.help(allocator);
    defer allocator.free(message);

    try std.testing.expectEqualStrings(
        message,
        "\x1b[1mNAME\x1b[0m\n" ++
        "    test\n\n" ++
        "\x1b[1mDESCRIPTION\x1b[0m\n" ++
        "    This is a test parser."
    );
}
