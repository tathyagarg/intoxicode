const std = @import("std");

const Expression = @import("../../parser/expressions.zig").Expression;
const Runner = @import("../runner.zig").Runner;
const require = @import("../runner.zig").require;

const CustomType = @import("../../parser/parser.zig").expressions.CustomType;
const Custom = @import("../../parser/parser.zig").expressions.Custom;
const LiteralType = @import("../../parser/parser.zig").expressions.LiteralType;

const Module = @import("mod.zig").Module;
const Handler = @import("../runner.zig").Handler;

fn Header(runner: Runner) !CustomType {
    var fields = std.StringHashMap(LiteralType).init(runner.allocator);
    try fields.put("name", LiteralType.string);
    try fields.put("value", LiteralType.string);

    return CustomType{
        .name = "Header",
        .fields = fields,
    };
}

fn Request(runner: Runner) !CustomType {
    var fields = std.StringHashMap(LiteralType).init(runner.allocator);
    try fields.put("method", LiteralType.string);
    try fields.put("url", LiteralType.string);
    try fields.put("protocol", LiteralType.string);
    try fields.put("headers", LiteralType.array);
    try fields.put("body", LiteralType.string);

    return CustomType{
        .name = "Request",
        .fields = fields,
    };
}

pub fn request_from_data(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.string}}, "request_from_data", runner, args);

    const data: []const u8 = args[0].literal.string;

    var values = std.StringHashMap(Expression).init(runner.allocator);
    try values.put("method", Expression{ .literal = .{ .string = "" } });
    try values.put("url", Expression{ .literal = .{ .string = "" } });
    try values.put("protocol", Expression{ .literal = .{ .string = "" } });
    try values.put("headers", Expression{ .literal = .{ .array = std.ArrayList(Expression).init(runner.allocator) } });
    try values.put("body", Expression{ .literal = .{ .string = "" } });

    const request = Custom{
        .corr_type = .{ .name = "Request" },
        .values = values,
    };

    const method = values.getPtr("method").?;
    const url = values.getPtr("url").?;
    const protocol = values.getPtr("protocol").?;
    const headers = values.getPtr("headers").?;
    const body = values.getPtr("body").?;

    var parts = std.mem.split(u8, data, " ");

    method.* = Expression{ .literal = .{ .string = parts.next().? } };
    url.* = Expression{ .literal = .{ .string = parts.next().? } };

    const remaining = parts.rest();
    var remaining_data = std.mem.splitSequence(u8, remaining, "\r\n");

    protocol.* = Expression{ .literal = .{ .string = remaining_data.next().? } };

    while (remaining_data.next()) |header_line| {
        if (header_line.len == 0) break;

        var header_parts = std.mem.split(u8, header_line, ": ");

        var header_data = std.StringHashMap(Expression).init(runner.allocator);
        try header_data.put("name", Expression{ .literal = .{ .string = header_parts.next().? } });
        try header_data.put("value", Expression{ .literal = .{ .string = header_parts.next().? } });

        try headers.*.literal.array.append(Expression{
            .literal = .{
                .custom = Custom{
                    .corr_type = .{ .name = "Header" },
                    .values = header_data,
                },
            },
        });
    }

    if (remaining_data.rest().len != 0) {
        for (headers.*.literal.array.items) |header| {
            if (std.mem.eql(u8, header.literal.custom.values.get("name").?.literal.string, "Content-Length")) {
                // If Content-Length is present, we can read the body
                const content_length = std.fmt.parseInt(u32, header.literal.custom.values.get("value").?.literal.string, 10) catch |err| {
                    return err;
                };
                if (content_length > 0) {
                    body.* = Expression{ .literal = .{ .string = remaining_data.rest()[0..content_length] } };
                }
                break;
            }
        } else {
            body.* = Expression{ .literal = .{ .string = remaining_data.rest() } };
        }
    }

    return Expression{
        .literal = .{ .custom = request },
    };
}

pub const Http = Module{
    .name = "http",
    .functions = std.StaticStringMap(Handler).initComptime(.{
        .{ "request_from_data", &request_from_data },
    }),
    .constants = std.StaticStringMap(Expression).initComptime(.{
        .{ "get", Expression{ .literal = .{ .string = "GET" } } },
        .{ "post", Expression{ .literal = .{ .string = "POST" } } },
        .{ "put", Expression{ .literal = .{ .string = "PUT" } } },
        .{ "delete", Expression{ .literal = .{ .string = "DELETE" } } },
    }),
    .customs = std.StaticStringMap(*const fn (Runner) anyerror!CustomType).initComptime(.{
        .{ "Request", &Request },
        .{ "Header", &Header },
    }),
};
