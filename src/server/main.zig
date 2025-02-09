const std = @import("std");
const tcp = @import("tcp.zig");

pub fn main() !void {
    try tcp.tcpServ("127.0.0.1", 8089);
}

pub fn testUnixSocket() !void {
    const protocol_default = 0;
    const sock = try std.posix.socket(std.os.linux.AF.UNIX, std.os.linux.SOCK.STREAM, protocol_default);
    const alloc = std.heap.page_allocator;
    const sa: *std.posix.sockaddr.un = try alloc.create(std.posix.sockaddr.un);
    defer alloc.destroy(sa);
    const pth_lit = "/tmp/test_sock";
    const f = try alloc.alloc(u8, 100000);
    @memset(&f, 0);

    @memset(&sa.path, 0);
    @memcpy(sa.path[0..pth_lit.len], pth_lit);
    sa.family = std.os.linux.AF.UNIX;
    const true_sa: *std.posix.sockaddr = @ptrCast(sa);

    std.fs.deleteFileAbsolute(pth_lit) catch |err| {
        switch (err) {
            std.posix.UnlinkError.FileNotFound => {},
            else => return err,
        }
    };

    _ = try std.posix.bind(sock, true_sa, @as(std.posix.socklen_t, @intCast(@sizeOf(std.posix.sockaddr.un))));
    _ = try std.posix.listen(sock, 5);
    const ca: *std.posix.sockaddr.un = try alloc.create(std.posix.sockaddr.un);
    const true_ca: *std.posix.sockaddr = @ptrCast(ca);
    var ca_size = @as(std.posix.socklen_t, @intCast(@sizeOf(std.posix.sockaddr.un)));
    const client_sock = try std.posix.accept(sock, true_ca, &ca_size, 0);
    var recv_buf = try alloc.alloc(u8, 128);
    defer alloc.free(recv_buf);
    const stdout = std.io.getStdOut().writer();

    @memset(recv_buf[0..128], 0);

    const bytes_rec = try std.posix.recv(client_sock, recv_buf, 0);
    if (bytes_rec > 0) {
        try stdout.print("Received message: {s}\n", .{recv_buf});
    }
    std.posix.close(client_sock);
    std.posix.close(sock);
    std.fs.deleteFileAbsolute(pth_lit) catch {};
}
