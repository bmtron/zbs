const std = @import("std");
const init = @import("commands/init.zig");
const cmdtypes = @import("commands/types.zig");
const dep = @import("commands/deploy.zig");
const common = @import("commands/common.zig");

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    const stdout = std.io.getStdOut().writer();
    _ = args.skip();

    const alloc = std.heap.page_allocator;
    var arg_holder = std.ArrayList([:0]const u8).init(alloc);
    defer arg_holder.deinit();

    var count: u8 = 0;
    while (args.next()) |arg| {
        try arg_holder.append(arg);
        //arg_holder[count] = arg;
        count = count + 1;
    }
    try stdout.print("arg count: {d}\n", .{count});
    try stdout.print("arg_holder_len: {d}\n", .{arg_holder.items.len});

    if (std.mem.eql(u8, arg_holder.items[0], "init")) {
        const init_cmd = init.Command.meta();
        init_cmd.execute(.{ .allocator = std.heap.page_allocator, .args = arg_holder }) catch |err| {
            if (err == cmdtypes.CommandError.ConfigExists) {
                try stdout.print("Config file already exists.\n", .{});
            }
            return;
        };
        try stdout.print("Successfully created config file zbs.json.\n", .{});
    }
    if (std.mem.eql(u8, arg_holder.items[0], "deploy")) {
        const deploy_cmd = dep.Command.meta();
        deploy_cmd.execute(.{ .allocator = alloc, .args = arg_holder }) catch |err| {
            try stdout.print("Error opening file.\n", .{});
            try stdout.print("{}\n", .{err});
        };
    }
}

test "simple test" {}
