const std = @import("std");
const ztypes = @import("types.zig");

pub const Command = struct {
    pub fn meta() ztypes.CommandInterface {
        return .{
            .name = "client",
            .description = "Initiate a client and send a message to a defined Unix socket.",
            .execute = execute,
        };
    }
    fn execute() !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("noop\n", .{});
    }
    pub fn client(ctx: ztypes.CommandContext) !void {
        const sock = try std.posix.socket(std.os.linux.AF.UNIX, std.os.linux.SOCK.STREAM, 0);
        var sa_un: *std.posix.sockaddr.un = try ctx.allocator.create(std.posix.sockaddr.un);
        sa_un.family = std.os.linux.AF.UNIX;
        const file_path = "/tmp/test_sock";
        var buf = try ctx.allocator.alloc(u8, 128);
        @memset(&sa_un.path, 0);
        @memset(buf[0..], 0);
        @memcpy(sa_un.path[0..file_path.len], file_path);
        if (ctx.args[1]) |arg| {
            @memcpy(buf[0..arg.len], arg);
        } else {
            const message = "Hello from Zig client!\n";
            @memcpy(buf[0..message.len], message);
        }

        const sa: *std.posix.sockaddr = @ptrCast(sa_un);
        _ = try std.posix.connect(sock, sa, @as(std.posix.socklen_t, @intCast(@sizeOf(std.posix.sockaddr.un))));
        _ = try std.posix.send(sock, buf, 0);
    }
};
