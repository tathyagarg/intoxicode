const std = @import("std");

pub const CodeBlockType = enum {
    main,
    fun,
    maybe,
    @"try",
    gotcha,
    loop,
};

pub const LineData = struct {
    line: []const u8,
    certainty: f32,
};

pub const CodeBlock = struct {
    lines: std.ArrayList(LineData),
    block_type: CodeBlockType,

    pub fn init(allocator: std.mem.Allocator, block_type: CodeBlockType) CodeBlock {
        return CodeBlock{
            .lines = std.ArrayList(LineData).init(allocator),
            .block_type = block_type,
        };
    }

    pub fn deinit(self: *CodeBlock) void {
        self.lines.deinit();
    }

    pub fn remove_n_lines(self: *CodeBlock, n: usize) void {
        for (0..n) |_| {
            _ = self.lines.pop();
        }
    }

    pub fn add_line(self: *CodeBlock, line: []const u8) !void {
        const trimmed_line = std.mem.trimRight(u8, line, " \t\n\r");

        // we'll start with certainty 1.0 so that the parser or something can update it to something more reasonable later
        try self.lines.insert(0, LineData{ .line = trimmed_line, .certainty = 1.0 });
    }
};

pub const Execution = struct {
    execution_blocks: std.ArrayList(CodeBlock),

    pub fn init(allocator: std.mem.Allocator) !Execution {
        return Execution{
            .execution_blocks = std.ArrayList(CodeBlock).init(allocator),
        };
    }

    pub fn deinit(self: *Execution) void {
        for (self.execution_blocks.items) |*block| {
            block.deinit();
        }
        self.execution_blocks.deinit();
    }

    pub fn add_block(self: *Execution, block: CodeBlock) !void {
        try self.execution_blocks.append(block);
    }

    pub fn add_empty_block(self: *Execution, block_type: CodeBlockType) !void {
        try self.execution_blocks.append(CodeBlock.init(self.execution_blocks.allocator, block_type));
    }

    pub fn display_lines(self: *Execution, block_index: usize) !void {
        if (block_index >= self.execution_blocks.items.len) {
            return error.IndexOutOfBounds;
        }

        const block = self.execution_blocks.items[block_index];

        for (block.lines.items) |line_data| {
            std.debug.print("{s} (certainty: {d})\n", .{ line_data.line, line_data.certainty });
        }
    }
};
