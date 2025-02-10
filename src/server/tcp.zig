const root = @import("../root.zig");
const std = @import("std");
const Address = std.net.Address;
const MAX_ARG_LEN: u8 = 50;
const t_type = u8;
const FILE_TRANSFER: t_type = 1;

pub const TcpServ = struct { address: []const u8, port: u16 };
pub fn tcpServ(tcp_data: *TcpServ) !void {
    const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(sock);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var ip4: std.net.Ip4Address = try std.net.Ip4Address.parse(tcp_data.*.address, tcp_data.*.port);

    const true_sa: *std.posix.sockaddr = @ptrCast(&ip4.sa);
    _ = try std.posix.bind(sock, true_sa, @as(std.posix.socklen_t, @sizeOf(std.posix.sockaddr.in)));
    _ = try std.posix.listen(sock, 5);
    std.debug.print("listening on port: {d}\n", .{tcp_data.*.port});

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
    const recv_buf = try allocator.alloc(u8, 32768);
    defer allocator.free(recv_buf);

    const delim = ",";

    var transfer_type: t_type = 0;
    var file_name: []u8 = "";
    var file_offset: u64 = 0;

    while (true) {
        const bytes_rec = try std.posix.recv(client, recv_buf, 0);
        std.debug.print("initial bytes recvd: {d}\n", .{bytes_rec});
        if (bytes_rec <= 0) break;
        if (bytes_rec <= 100) {
            std.debug.print("data: (string) {c} : (raw) {d}\n", .{ recv_buf, recv_buf });
        }

        const metadata_init: []u8 = recv_buf[0..4];
        std.debug.print("METADATA: {s}\n", .{metadata_init});
        std.debug.print("METADATA_IS_FILE: {any}\n", .{std.mem.eql(u8, metadata_init, "file")});

        if (std.mem.eql(u8, metadata_init, "file") and transfer_type == 0) {
            file_name = getFileNameFromMetadata(recv_buf[5..], delim[0..]); // leaving room for a space
            std.debug.print("The file name is {s}\n", .{file_name});
            transfer_type = FILE_TRANSFER;
        }

        if (transfer_type == FILE_TRANSFER) {
            try handleArtifact(client, file_name, recv_buf[0..], &file_offset);
        }
    }
    std.posix.close(client);

    // not sure how we would get here, but
    // best to check to prevent underflow
    if (thread_count.* > 0) {
        thread_count.* = thread_count.* - 1;
    }
    std.debug.print("thread_count: {d}\n", .{thread_count.*});
}
fn getFileNameFromMetadata(name_buf: []u8, delim: []const u8) []u8 {
    std.debug.print("name_buf_: {s}\n", .{name_buf});
    var counter: u8 = 0;
    var slice_end: u8 = 0;
    while (true) {
        if (counter == name_buf.len - 1) break;
        if (std.mem.eql(u8, name_buf[counter .. counter + 1], delim)) {
            slice_end = counter;
            break;
        }
        counter += 1;
    }
    return name_buf[0..slice_end];
}
fn findArgs(args: *const [50]?[:0]u8) !?[:0]u8 {
    var config_name: ?[:0]u8 = null;
    var count = 0;
    for (args) |arg| {
        if (arg and std.mem.eql(u8, arg, "cfg") or std.mem.eql(u8, arg, "-c")) {
            if (count == MAX_ARG_LEN - 1) {
                config_name = "zbs.json"; // set the config to default, we'll attempt to find it, error if not
                break; // also, just break out of this. it *should* just stop, but idk, maybe something weird happened
            }
            config_name = arg;
        }
        count += 1;
    }
    return config_name;
}

fn handleArtifact(client: std.posix.socket_t, file_name: []const u8, recv_buf: []u8, offset: *u64) !void {
    var dir = std.fs.cwd();
    std.debug.print("file name is: {s}\n", .{file_name});
    var file = dir.openFile(file_name, .{}) catch try dir.createFile(file_name, .{});

    if (offset.* > 0) {
        try file.seekTo(offset.*);
    }
    const file_write = try file.write(recv_buf);

    if (file_write < @as(usize, recv_buf.len)) {
        std.debug.print("Wrote less than amount received...\n", .{});
    }
    if (file_write > @as(usize, recv_buf.len)) {
        std.debug.print("Wrote...more??? than amount receive...\n", .{});
    }
    offset.* += file_write;

    _ = try std.posix.send(client, "Message recv'd", 0);
    file.close();
}

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
