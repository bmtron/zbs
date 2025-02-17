const root = @import("../root.zig");
const std = @import("std");

// custom typedefs
const Address = std.net.Address;
const t_type = u8;

// global constants
const MAX_ARG_LEN: u8 = 50;
const FILE_TRANSFER: t_type = 1;
const T_TYPE_NULL: t_type = 0;
const CLIENT_BUFFER_SIZE = 32768;
const RECEIVE_BUFFER_SIZE = CLIENT_BUFFER_SIZE * 8;

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
}

fn handleClient(allocator: std.mem.Allocator, client: std.posix.socket_t, thread_count: *u8) !void {
    const start_time = std.time.milliTimestamp();
    const recv_buf = try allocator.alloc(u8, RECEIVE_BUFFER_SIZE);
    defer allocator.free(recv_buf);

    const delim = ",";

    // this is used as a flag for the initial loop.
    // possibly more types of transfers to come but i doubt it
    // perhaps refactor this to be simpler and less weird
    var transfer_type: t_type = T_TYPE_NULL;
    var file_name: []u8 = "";
    var file_offset: u64 = 0;

    var dir = std.fs.cwd();
    var file: ?std.fs.File = null;
    defer file.?.close();

    var total_bytes_rec: u64 = 0;
    while (true) {
        const bytes_rec = try std.posix.recv(client, recv_buf, 0);

        std.debug.print("bytes recvd: {d}\n", .{bytes_rec});
        if (bytes_rec <= 0) {
            std.debug.print("BROKEN_LOOP \n", .{});
            break;
        }
        total_bytes_rec += bytes_rec;

        const metadata_init: []u8 = recv_buf[0..4];

        if (std.mem.eql(u8, metadata_init, "file") and transfer_type == T_TYPE_NULL) {
            transfer_type = FILE_TRANSFER;
            std.debug.print("delim: {s}\n", .{delim});
            file_name = try getFileNameFromMetadata(recv_buf[5..], delim[0..], allocator);
            file = dir.openFile(file_name, .{ .mode = .read_write, .lock = .exclusive }) catch try dir.createFile(file_name, .{});
            if (bytes_rec > metadata_init.len + 1 + file_name.len) {
                try handleArtifact(&(file).?, recv_buf[metadata_init.len + 2 + file_name.len .. bytes_rec], &file_offset);
            }
            std.debug.print("transfer_type_status: {any}\n", .{transfer_type});
            continue;
        }

        if (transfer_type == FILE_TRANSFER) {
            // edge case, file should never be null if transfer is FILE_TRANSFER
            // program should have dumped out before this, however this is an extra precaution.
            if (file == null) {
                std.debug.print("NULL_FILE_ACCESS\n", .{});
                std.posix.close(client);
                return error.NullFileAccess;
            } else {
                try handleArtifact(&(file).?, recv_buf[0..bytes_rec], &file_offset);
            }
        }
    }
    const end_time = std.time.milliTimestamp();
    const elapsed = end_time - start_time;

    std.posix.close(client);

    // not sure how we would get here, but
    // best to check to prevent underflow
    if (thread_count.* > 0) {
        thread_count.* = thread_count.* - 1;
    }
    std.debug.print("Transferred {d} Mb of data in {d} milliseconds.\n", .{ (total_bytes_rec / (1024 * 1024)), elapsed });
    std.debug.print("thread_count: {d}\n", .{thread_count.*});
}

// the first sequence passed in to the server is the type of transaction taking place,
// and then some metadata (such as the file name, if the transaction is a file).
// this is just a helper to extract the file name using a delimiter character
// (currently ',' but this should change to something that is perhaps more robust than a comma)
fn getFileNameFromMetadata(name_buf: []u8, delim: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var counter: u64 = 0;
    var slice_end: u64 = 0;
    while (true) {
        if (counter == name_buf.len - 1) break;
        if (std.mem.eql(u8, name_buf[counter .. counter + 1], delim)) {
            slice_end = counter;
            break;
        }
        counter += 1;
    }
    return try allocator.dupe(u8, name_buf[0..slice_end]);
}

// rewrite this and extract it to be more generic.
// should be able to take a list of possible arguments to find and
// return the associated values
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

fn handleArtifact(file: *std.fs.File, recv_buf: []u8, offset: *u64) !void {
    const file_write = try file.*.write(recv_buf);

    offset.* += file_write;
    if (offset.* > 0) {
        try file.*.seekTo(offset.*);
        std.debug.print("SEEKING_TO_POS: {d}\n", .{offset.*});
    }

    // not sure how we would get here, but again,
    // it's an edge case and I'd like to know if
    // this ever happens
    if (file_write < @as(usize, recv_buf.len)) {
        std.debug.print("Wrote less than amount received...\n", .{});
    }
    if (file_write > @as(usize, recv_buf.len)) {
        std.debug.print("Wrote...more??? than amount receive...\n", .{});
    }
}

// Unused and not needed, but still a fun experiment
// part of the learning process, I suppose
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
