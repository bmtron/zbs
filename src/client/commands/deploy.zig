const std = @import("std");
const zbstypes = @import("types.zig");
const common = @import("common.zig");
const config = @import("config.zig");

const SubCommands = struct { location: ?[]const u8, help: ?[]const u8 };
pub const Command = struct {
    pub fn meta() zbstypes.CommandInterface {
        return .{
            .name = "deploy",
            .description = "Initiate a deployment based on the specified config file",
            .execute = execute,
        };
    }

    fn execute(ctx: zbstypes.CommandContext) !void {
        const stdout = std.io.getStdOut().writer();

        var file_name: [:0]const u8 = undefined;
        if (ctx.args.len > 1) {
            if (ctx.args[1]) |arg| {
                file_name = arg;
            }
        } else {
            file_name = "zbs.json";
        }
        try stdout.print("beginning parse of {s}\n", .{file_name});
        const prs_cfg = try common.parseConfig(ctx.allocator, file_name);
        const cfg = prs_cfg.config;
        const buf = prs_cfg.buffer;
        defer ctx.allocator.free(buf);

        try stdout.print("config file version: {s}\n", .{cfg.version});

        try stdout.print("config info: {s}\n", .{cfg.server.host});
    }
};
