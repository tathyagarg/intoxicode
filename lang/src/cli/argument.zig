pub const Argument = struct {
    name: []const u8,
    description: ?[]const u8 = null,

    flag: ?[]const u8 = null,
    option: ?[]const u8 = null,
    positional: bool = false,

    has_data: bool = true,

    default_value: ?[]const u8 = null,

    value: ?[]const u8 = null,
};
