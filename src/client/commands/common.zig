const std = @import("std");
const config = @import("config.zig");
const ztypes = @import("types.zig");

pub fn parseConfig(allocator: std.mem.Allocator, cfg_name: [:0]const u8) !struct { config: config.Config, buffer: []u8 } {
    const this_dir = std.fs.cwd();
    const stdout = std.io.getStdOut().writer();

    const open_file = this_dir.openFile(cfg_name, .{}) catch |err| {
        if (err == error.FileNotFound or err == error.FileOpenError) {
            try stdout.print("Config file {s} not found.\n", .{cfg_name});
        } else {
            try stdout.print("Unspecified error opening config file {s}.\n", .{cfg_name});
        }
        return ztypes.CommandError.FileOpenError;
    };
    defer open_file.close();
    const file_size = try open_file.getEndPos();
    const buf: []u8 = try allocator.alloc(u8, file_size);
    _ = open_file.read(buf) catch |err| {
        try stdout.print("Error reading config file.\n", .{});
        return err;
    };
    const parsed = try std.json.parseFromSlice(config.Config, allocator, buf, .{});

    return .{ .config = parsed.value, .buffer = buf };
}
