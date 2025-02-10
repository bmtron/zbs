const std = @import("std");
const init = @import("commands/init.zig");
const cmdtypes = @import("commands/types.zig");
const dep = @import("commands/deploy.zig");
const common = @import("../common/common.zig");
const client = @import("commands/client.zig");

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    const stdout = std.io.getStdOut().writer();
    _ = args.skip();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var arg_holder: [50]?[:0]const u8 = undefined;
    @memset(arg_holder[0..], null);
    var count: u8 = 0;
    while (args.next()) |arg| {
        arg_holder[count] = arg;
        count = count + 1;
    }

    if (arg_holder[0]) |arg| {
        if (std.mem.eql(u8, arg, "init")) {
            const init_cmd = init.Command.meta();
            init_cmd.execute(.{ .allocator = alloc, .args = arg_holder }) catch |err| {
                if (err == cmdtypes.CommandError.ConfigExists) {
                    try stdout.print("Config file already exists.\n", .{});
                }
                return;
            };
            try stdout.print("Successfully created config file zbs.json.\n", .{});
        }
        if (std.mem.eql(u8, arg, "deploy")) {
            const deploy_cmd = dep.Command.meta();
            deploy_cmd.execute(.{ .allocator = alloc, .args = arg_holder }) catch |err| {
                try stdout.print("Error opening file.\n", .{});
                try stdout.print("{}\n", .{err});
            };
        }
        if (std.mem.eql(u8, arg, "client")) {
            try client.Command.clientTcp(.{ .allocator = alloc, .args = arg_holder });
        }
    }
}

test "simple test" {}
