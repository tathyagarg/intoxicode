/// CLI Module because existing ones are outdated
/// This module will support:
/// - Positional arguments
/// - Optional arguments
/// - Flags
/// - Named arguments
/// - Default values
/// - Help message
pub const Parser = @import("parser.zig").Parser;
pub const Argument = @import("argument.zig").Argument;
