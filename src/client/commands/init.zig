const std = @import("std");
const zbstypes = @import("types.zig");
const config = @import("config.zig");

pub const Command = struct {
    pub fn meta() zbstypes.CommandInterface {
        return .{
            .name = "init",
            .description = "Initialize a new zbs configuration",
            .execute = execute,
        };
    }

    fn execute(ctx: zbstypes.CommandContext) !void {
        const this_dir = std.fs.cwd();

        const open_file = this_dir.openFile("zbs.json", .{}) catch |err| {
            if (err == error.FileNotFound) {
                const config_obj = config.Config.createDefaultConfig();
                const json_string = try std.json.stringifyAlloc(ctx.allocator, config_obj, .{});
                defer ctx.allocator.free(json_string);
                const write_opts: std.fs.Dir.WriteFileOptions = std.fs.Dir.WriteFileOptions{ .sub_path = "zbs.json", .data = json_string, .flags = .{} };
                this_dir.writeFile(write_opts) catch {
                    return zbstypes.CommandError.FileWriteError;
                };
                return;
            }
            return err;
        };
        defer open_file.close();
        // if we didn't error out and can get here, the file is open and the config exists;
        return zbstypes.CommandError.ConfigExists;
    }
};
