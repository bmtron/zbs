const root = @import("../root.zig");
const std = @import("std");

pub fn tcpServ() !void {
    // const sock_address: std.posix.sockaddr.in = .{};
    // const address: std.net.Address = .{};
    // const tcp_stream = std.net.tcpConnectToAddress()
}

pub fn ipToU32(ipstr: []const u8) !u32 {
    var ip_holder: [4]?[:0]u8 = undefined;

    @memset(ip_holder[0..], null);
    var chk_chr: u8 = 0;
    var count: u8 = 0;
    var holder_count: u8 = 0;
    var result: u32 = 0;
    while (holder_count < 4) { // loop through each octet in ip
        var octet_val: u8 = 0;
        if (count > ipstr.len) {
            break;
        }
        chk_chr = ipstr[count];

        while (chk_chr != '.' and ipstr.len > count) { // loop through each char in possible octet

            octet_val = octet_val * 10 + (ipstr[count] - '0');
            count = count + 1;
            if (count < ipstr.len) {
                chk_chr = ipstr[count];
            }
        }
        count = count + 1;
        result = result << 8 | octet_val;
        holder_count = holder_count + 1;
    }
    return result;
}

test "expect 192.168.50.1 to be 3232248321" {
    const ip = try ipToU32("192.168.50.1");
    try std.testing.expect(ip == 3232248321);
}
