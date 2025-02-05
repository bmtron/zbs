const root = @import("../root.zig");
const std = @import("std");

pub fn tcpServ() !void {
    // const sock_address: std.posix.sockaddr.in = .{};
    // const address: std.net.Address = .{};
    // const tcp_stream = std.net.tcpConnectToAddress()
}

pub fn ipToU32(ipstr: []const u8) !u32 {
    const stdout = std.io.getStdOut().writer();
    var ip_holder: [4]?[:0]u8 = undefined;

    @memset(ip_holder[0..], null);
    var chk_chr: u8 = 0;
    var chr: u8 = 0; // set it to something that fails the first check
    var count: u8 = 0;
    var holder_count: u8 = 0;
    var result: u32 = 0;
    var multiplier: u8 = 0;
    while (holder_count < 4) { // loop through each octet in ip
        var octet_val: u8 = 0;
        var multiplier_count: u8 = 0;
        if (count > ipstr.len) {
            break;
        }
        chk_chr = ipstr[count];

        while (chk_chr != '.' and ipstr.len > count) { // loop through each char in possible octet
            try stdout.print("here?", .{});
            multiplier = switch (multiplier_count) {
                0 => 100,
                1 => 10,
                2 => 1,
                else => 1,
            };
            if (@as(u16, (ipstr[count] - '0')) * multiplier > 255) {
                multiplier = multiplier / 10;
            }

            chr = (ipstr[count] - '0') * multiplier;

            try stdout.print("chr: {d}\n", .{chr});
            octet_val = octet_val + chr;
            count = count + 1;
            if (count < ipstr.len) {
                chk_chr = ipstr[count];
            }
            multiplier_count = multiplier_count + 1;
        }
        count = count + 1;
        try stdout.print("oct: {d}\n", .{octet_val});
        try stdout.print("mult_cnt: {d}\n", .{multiplier_count});
        if (multiplier_count < 2) {
            while (multiplier_count > 1) {
                octet_val = octet_val / 10;
                multiplier_count = multiplier_count - 1;
            }
        }
        result = result << 8 | octet_val;
        holder_count = holder_count + 1;
    }
    try stdout.print("result: {d}\n", .{result});
    return result;
}

pub fn charSwitch(chr: u8) !u8 {
    const result = switch (chr) {
        else => 0,
    };

    return result;
}

test "expect 192.168.50.1 to be 3232248321" {
    const ip = try ipToU32("192.168.50.1");
    try std.testing.expect(ip == 3232248321);
}
