pub const Argument = struct {
    name: []const u8,
    description: ?[]const u8 = null,

    required: bool = false,

    flag: ?[]const u8 = null,
    option: ?[]const u8 = null,

    default_value: ?[]const u8 = null,

    value: ?[]const u8 = null,
};
