const std = @import("std");

const Expression = @import("../../parser/expressions.zig").Expression;
const Runner = @import("../runner.zig").Runner;
const require = @import("../runner.zig").require;
const socket = @import("socket.zig");
const utilities = @import("utilities.zig");

const CustomType = @import("../../parser/parser.zig").expressions.CustomType;
const Custom = @import("../../parser/parser.zig").expressions.Custom;
const LiteralType = @import("../../parser/parser.zig").expressions.LiteralType;

const Module = @import("mod.zig").Module;
const Handler = @import("../runner.zig").Handler;

const GET = "GET";
const POST = "POST";
const PUT = "PUT";
const DELETE = "DELETE";

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

fn Response(runner: Runner) !CustomType {
    var fields = std.StringHashMap(LiteralType).init(runner.allocator);
    try fields.put("status_code", LiteralType.integer);
    try fields.put("headers", LiteralType.array);
    try fields.put("body", LiteralType.string);

    return CustomType{
        .name = "Response",
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

    const request_object = try runner.allocator.create(Expression);
    request_object.* = Expression{
        .literal = .{
            .module = Http,
        },
    };

    const request_name = try runner.allocator.create(Expression);
    request_name.* = Expression{
        .identifier = .{ .name = "Request" },
    };

    request_name.* = Expression{ .get_attribute = .{
        .object = request_object,
        .attribute = request_name,
    } };

    const request = Custom{
        .corr_type = request_name,
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

        const header_name = try runner.allocator.create(Expression);
        header_name.* = Expression{
            .identifier = .{ .name = "Header" },
        };

        try headers.*.literal.array.append(Expression{
            .literal = .{
                .custom = Custom{
                    .corr_type = header_name,
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
        } else if (!std.mem.eql(u8, method.literal.string, GET)) {
            body.* = Expression{ .literal = .{ .string = remaining_data.rest() } };
        } else {
            body.* = Expression{ .literal = .{ .null = null } };
        }
    }

    return Expression{
        .literal = .{ .custom = request },
    };
}

pub fn make_request_data(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(1, &.{&.{.custom}}, "make_request_data", runner, args);

    const request = args[0].literal.custom;

    if (request.corr_type.* != .get_attribute or
        !std.mem.eql(u8, request.corr_type.get_attribute.attribute.identifier.name, "Request") or
        !std.mem.eql(u8, request.corr_type.get_attribute.object.literal.module.name, "http"))
    {
        return error.InvalidType;
    }

    var data = std.ArrayList(u8).init(runner.allocator);
    defer data.deinit();

    try data.appendSlice(request.values.get("method").?.literal.string);
    try data.appendSlice(" ");
    try data.appendSlice(request.values.get("url").?.literal.string);
    try data.appendSlice(" ");
    try data.appendSlice(request.values.get("protocol").?.literal.string);
    try data.appendSlice("\r\n");

    const headers = request.values.get("headers").?.literal.array;
    for (headers.items) |header| {
        const name = header.literal.custom.values.get("name").?.literal.string;
        const value = header.literal.custom.values.get("value").?.literal.string;
        try data.appendSlice(name);
        try data.appendSlice(": ");
        try data.appendSlice(value);
        try data.appendSlice("\r\n");
    }
    try data.appendSlice("\r\n");

    const body = request.values.get("body").?.literal.string;
    if (body.len > 0) {
        try data.appendSlice(body);
    }

    return Expression{ .literal = .{ .string = try data.toOwnedSlice() } };
}

pub fn get(runner: Runner, args: []*Expression) anyerror!Expression {
    try require(3, &.{ &.{.integer}, &.{.string}, &.{.array} }, "get", runner, args);

    const fd: std.posix.socket_t = try utilities.make_socket_t(args[0].*);
    const url = args[1].literal.string;
    const headers = args[2];

    const request = try runner.allocator.create(Expression);

    const corr_type_object = try runner.allocator.create(Expression);
    corr_type_object.* = Expression{
        .literal = .{
            .module = Http,
        },
    };

    const corr_type_attribute = try runner.allocator.create(Expression);
    corr_type_attribute.* = Expression{
        .identifier = .{ .name = "Request" },
    };

    const corr_type = try runner.allocator.create(Expression);
    corr_type.* = Expression{
        .get_attribute = .{
            .object = corr_type_object,
            .attribute = corr_type_attribute,
        },
    };

    request.* = Expression{
        .literal = .{
            .custom = .{
                .corr_type = corr_type,
                .values = std.StringHashMap(Expression).init(runner.allocator),
            },
        },
    };

    try request.literal.custom.values.put("method", Expression{ .literal = .{ .string = GET } });
    try request.literal.custom.values.put("url", Expression{ .literal = .{ .string = url } });
    try request.literal.custom.values.put("protocol", Expression{ .literal = .{ .string = "HTTP/1.1" } });
    try request.literal.custom.values.put("headers", headers.*);
    try request.literal.custom.values.put("body", Expression{ .literal = .{ .string = "" } });

    const request_text = try make_request_data(
        runner,
        @as([]*Expression, @ptrCast(@constCast(&[_]*Expression{request}))),
    );
    std.debug.print("GET request data: {s}\n", .{request_text.literal.string});

    _ = .{fd};
    // std.posix.send()

    return request.*;
}

pub const Http = Module{
    .name = "http",
    .functions = std.StaticStringMap(Handler).initComptime(.{
        .{ "request_from_data", &request_from_data },
        .{ "make_request_data", &make_request_data },
        .{ "get", &get },
    }),
    .constants = std.StaticStringMap(Expression).initComptime(.{
        // .{ "get", Expression{ .literal = .{ .string = GET } } },
        .{ "post", Expression{ .literal = .{ .string = POST } } },
        .{ "put", Expression{ .literal = .{ .string = PUT } } },
        .{ "delete", Expression{ .literal = .{ .string = DELETE } } },
    }),
    .customs = std.StaticStringMap(*const fn (Runner) anyerror!CustomType).initComptime(.{
        .{ "Request", &Request },
        .{ "Response", &Response },
        .{ "Header", &Header },
    }),
};
