const std = @import("std");
pub const CommandError = error{ OutOfMemory, FileOpenError, ConfigExists, InvalidArguments, MissingProgramArguments, FileCreationError, FileWriteError // will add more later...
};

pub const CommandContext = struct {
    allocator: std.mem.Allocator,
    args: []const []const u8,
};

pub const CommandInterface = struct {
    name: []const u8,
    description: []const u8,
    execute: fn (ctx: CommandContext) CommandError!void,
};
