const std = @import("std");
const tcp = @import("tcp.zig");

pub fn main() !void {
    var tcp_data = tcp.TcpServ{ .address = "0.0.0.0", .port = 8089 };
    try tcp.tcpServ(&tcp_data);
}
