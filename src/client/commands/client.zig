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
    pub fn clientUnix(ctx: ztypes.CommandContext) !void {
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
    pub fn clientTcp(ctx: ztypes.CommandContext) !void {
        var client = try std.net.tcpConnectToHost(ctx.allocator, "127.0.0.1", 8089);
        defer client.close();
        var loop_count: u8 = 0;
        const cmd = "file";
        const file_name = "test_file.txt,";
        const send_buf = try ctx.allocator.alloc(u8, 32768);
        @memset(send_buf[0..], 0);
        @memcpy(send_buf[0..cmd.len], cmd);
        @memcpy(send_buf[cmd.len .. cmd.len + 1], " ");
        @memcpy(send_buf[cmd.len + 1 .. cmd.len + 1 + file_name.len], file_name);
        while (true) {
            if (loop_count * send_buf.len > 32769) {
                break;
            }
            const written_bytes = try client.write(send_buf);
            std.debug.print("Wrote {d} bytes\n", .{written_bytes});
            @memset(send_buf[0..], 69);

            loop_count += 1;
        }

        // const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
        // var ip4 = try std.net.Ip4Address.parse("127.0.0.1", 8089);
        // var buf = try ctx.allocator.alloc(u8, 4096);

        // @memset(buf[0..], 69);
        // const sock_address: *std.posix.sockaddr = @ptrCast(&ip4.sa);
        // _ = try std.posix.connect(sock, sock_address, @as(std.posix.socklen_t, @intCast(@sizeOf(std.posix.sockaddr.in))));
        // _ = try std.posix.send(sock, buf, 0);
    }
};
