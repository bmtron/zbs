const std = @import("std");
const init = @import("commands/init.zig");
const cmdtypes = @import("commands/types.zig");
pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    const stdout = std.io.getStdOut().writer();
    _ = args.skip();

    const next_args = args.next() orelse {
        return error.MissingProgramArguments;
    };
    const arg_slice: []const u8 = next_args[0..];
    if (std.mem.eql(u8, arg_slice, "init")) {
        const init_cmd = init.Command.meta();
        init_cmd.execute(.{ .allocator = std.heap.page_allocator, .args = &.{""} }) catch |err| {
            if (err == cmdtypes.CommandError.ConfigExists) {
                try stdout.print("Config file already exists.\n", .{});
            }
            return;
        };
        try stdout.print("Successfully created config file zbs.json.\n", .{});
    }
}

test "simple test" {}
