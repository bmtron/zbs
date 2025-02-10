const std = @import("std");
const tcp = @import("tcp.zig");

pub fn main() !void {
    var tcp_data = tcp.TcpServ{ .address = "127.0.0.1", .port = 8089 };
    try tcp.tcpServ(&tcp_data);
}
