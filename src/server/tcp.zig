const root = @import("../root.zig");
const std = @import("std");
const Address = std.net.Address;

pub fn tcpServ(ip: []const u8, port: u16) !void {
    const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(sock);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var ip4: std.net.Ip4Address = try std.net.Ip4Address.parse(ip, port);

    const true_sa: *std.posix.sockaddr = @ptrCast(&ip4.sa);
    _ = try std.posix.bind(sock, true_sa, @as(std.posix.socklen_t, @sizeOf(std.posix.sockaddr.in)));
    _ = try std.posix.listen(sock, 5);
    std.debug.print("listening on port: {d}\n", .{port});

    //client init
    const client_sa_in: *std.posix.sockaddr.in = try allocator.create(std.posix.sockaddr.in);
    defer allocator.destroy(client_sa_in);
    const client_sa: *std.posix.sockaddr = @ptrCast(client_sa_in);
    var client_size = @as(std.posix.socklen_t, @intCast(@sizeOf(std.posix.sockaddr.in)));
    var thread_count: u8 = 0;
    while (true) {
        const client = try std.posix.accept(sock, client_sa, &client_size, 0);
        if (thread_count < 10) {
            const thread = try std.Thread.spawn(.{}, handleClient, .{ allocator, client, &thread_count });
            thread.detach();
            thread_count = thread_count + 1;
            std.debug.print("thread_count: {d}\n", .{thread_count});
        }
    }
    std.posix.close(sock);
}

fn handleClient(allocator: std.mem.Allocator, client: std.posix.socket_t, thread_count: *u8) !void {
    const recv_buf = try allocator.alloc(u8, 4096);
    defer allocator.free(recv_buf);

    var run_loop = true;
    while (run_loop) {
        const bytes_rec = try std.posix.recv(client, recv_buf, 0);
        if (bytes_rec <= 0) break;
        const metadata_init = bytes_rec[0..5];
        if (std.mem.eql(u8, metadata_init, "conf")) {
            run_loop = handleConf();
        }
        if (std.mem.eql(u8, metadata_init, "file")) {
            run_loop = handleFile();
        }
        std.debug.print("data: (string) {c} : (raw) {d}\n", .{ recv_buf[0], recv_buf[0] });
        _ = try std.posix.send(client, "Message recv'd", 0);
    }
    std.posix.close(client);

    // not sure how we would get here, but
    // best to check to prevent underflow
    if (thread_count.* > 0) {
        thread_count.* = thread_count.* - 1;
    }
    std.debug.print("thread_count: {d}\n", .{thread_count.*});
}

fn handleConf() bool {}
fn handleFile() bool {}

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

pub fn u32ToIp(ipnum: u32, allocator: std.mem.Allocator) ![]u8 {
    var result = try allocator.alloc(u8, 4);
    var count: u5 = 0;
    while (count < result.len) {
        const u8max: u8 = 255;
        const shifter: u5 = 8 * (3 - count);
        const shifted: u8 = @as(u8, @truncate(ipnum >> shifter)) & u8max;
        result[count] = shifted;

        count = count + 1;
    }

    return result[0..4];
}

test "expect 192.168.50.1 to be 3232248321" {
    const ip = try ipToU32("192.168.50.1");
    try std.testing.expect(ip == 3232248321);
}
test "expect 3232248321 to be 192.168.50.1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const correct: [4]u8 = .{ 192, 168, 50, 1 };
    const ip = try u32ToIp(3232248321, allocator);
    std.debug.print("{any}\n", .{ip});
    std.debug.print("The ip address is {d}{c}{d}{c}{d}{c}{d}\n", .{ ip[0], '.', ip[1], '.', ip[2], '.', ip[3] });
    try std.testing.expect(std.mem.eql(u8, ip, correct[0..4]));
}
