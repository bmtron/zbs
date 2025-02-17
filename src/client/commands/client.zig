const std = @import("std");
const ztypes = @import("types.zig");
const TCP_CLIENT_BUF_SIZE: usize = 32768;
const ip_args = [_][]const u8{ "ip", "-ipaddr", "-ip" };
const file_name_args = [_][]const u8{ "fn", "-fn", "-file", "-file-name" };
const port_args = [_][]const u8{ "port", "-port" };

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

    fn contains(list: [50]?[:0]const u8, target: []const u8) bool {
        for (list) |item| {
            if (item) |i| {
                if (std.mem.eql(u8, i, target)) {
                    return true;
                }
            }
        }
        return false;
    }

    fn argFinder(arg_list: [50]?[:0]const u8, targets: []const []const u8) i8 {
        var counter: i8 = 0;
        for (targets) |target| {
            for (arg_list) |arg| {
                if (arg) |a| {
                    if (std.mem.eql(u8, a, target)) {
                        std.debug.print("ARG: {s} : TARGET: {s} : COUNTER: {d} \n", .{ a, target, counter });
                        return counter;
                    }
                }

                counter += 1;
            }
            counter = 0;
        }
        // if we don't find anything, return -1 so we know there is an issue
        return -1;
    }

    pub fn clientTcp(ctx: ztypes.CommandContext) !void {
        const ip_arg_idx = argFinder(ctx.args, &ip_args);
        var ip_address: [:0]const u8 = "127.0.0.1";
        // as long as the arg idx is greater than zero,
        // we can safely do our incasting to get the arg
        // and override the default value.
        // Hope it's something valid!
        if (ip_arg_idx > 0) {
            const converted_idx: u8 = @intCast(ip_arg_idx);
            if (ctx.args[converted_idx + 1]) |arg| {
                ip_address = arg;
            }
        }

        // default port value
        var port: u16 = 8089;
        const port_arg_idx = argFinder(ctx.args, &port_args);
        // default port is always set to
        if (port_arg_idx > 0) {
            const converted_idx: u8 = @intCast(port_arg_idx);
            if (ctx.args[converted_idx + 1]) |arg| {
                port = try std.fmt.parseInt(u16, arg, 10);
            }
        }

        std.debug.print("ip arg idx: {d}\n", .{ip_arg_idx});
        var client = try std.net.tcpConnectToHost(ctx.allocator, ip_address, port);
        defer client.close();
        const cmd = "file";
        var file_name: [:0]const u8 = undefined;

        const file_name_arg_idx = argFinder(ctx.args, &file_name_args);

        if (file_name_arg_idx < 0) {
            std.debug.print("EXITING_CLIENT_EARLY_ERR_NO_FILE_NAME\n", .{});
            return error.NoFileNameProvided;
        } else {
            const converted_idx: u8 = @intCast(file_name_arg_idx);
            if (ctx.args[converted_idx + 1]) |arg| {
                file_name = arg;
            }
        }

        // Ok, so here, we need to terminate the file name string with a character.
        // but obviously, we don't want that character sticking around with the file name
        // when we go to open the file. so we have to do all of this duping and allocating
        // just to add a ','. Feels silly, maybe there's a better way to handle this?
        const temp_file_name = try ctx.allocator.dupeZ(u8, file_name[0..file_name.len]);
        defer ctx.allocator.free(temp_file_name);

        var final_file_name = try ctx.allocator.allocSentinel(u8, file_name.len + 1, 0);
        defer ctx.allocator.free(final_file_name);

        @memcpy(final_file_name[0..file_name.len], file_name);
        final_file_name[file_name.len] = ',';

        const cwd = std.fs.cwd();
        const file = try cwd.openFile(file_name, .{ .mode = .read_only });

        // this is the initialization/metadata step, where we prepare to send
        // the metadata of the file (i.e., the name, and the fact that we're sending a file)
        const send_buf = try ctx.allocator.alloc(u8, TCP_CLIENT_BUF_SIZE);
        var seek_skip: usize = 0;
        var last_bytes_read: usize = 0;
        var written_bytes: usize = 0;
        var total_bytes_written: u64 = 0;
        @memset(send_buf[0..], 0);

        var metadata_buf = try ctx.allocator.alloc(u8, cmd.len + 1 + final_file_name.len);
        @memset(metadata_buf[0..], 0);
        @memcpy(metadata_buf[0..cmd.len], cmd);
        @memcpy(metadata_buf[cmd.len .. cmd.len + 1], " ");
        @memcpy(metadata_buf[cmd.len + 1 .. cmd.len + 1 + final_file_name.len], final_file_name);

        var loop_count: u32 = 0;
        const end_pos = try file.getEndPos();
        while (true) {
            // ignore first pass of the loop, as it's just metadata.
            // then, we read from the file, and write to the server.
            // each iteration, we keep track of how many bytes were successfully written,
            // and skip that many bytes from the previous iteration.
            // there is special handling on the last loop
            // to ensure we aren't sending a buffer that's too large for the remaining
            // data and ending up with garbage at the end of the file.
            if (loop_count > 0) {
                try file.seekTo(seek_skip);

                last_bytes_read = try file.read(send_buf);
                std.debug.print("CURR_SEEK_SKIP: {d} : CURR_TOTAL_BYTES_WRITTEN: {d} : END_POS_BYTES: {d} at loop iteration {d}\n", .{ seek_skip, total_bytes_written, end_pos, loop_count });
                if (last_bytes_read < TCP_CLIENT_BUF_SIZE or (seek_skip + TCP_CLIENT_BUF_SIZE) >= end_pos) {
                    const final_buf = try ctx.allocator.alloc(u8, end_pos - total_bytes_written);
                    defer ctx.allocator.free(final_buf);

                    try file.seekTo(end_pos - final_buf.len);
                    last_bytes_read = try file.read(final_buf);
                    const final_bytes = try client.write(final_buf);
                    if (final_bytes < 0) {
                        std.debug.print("Some final error.\n", .{});
                    }
                    break;
                }
                written_bytes = try client.write(send_buf);

                seek_skip += written_bytes;
            } else {
                _ = try client.write(metadata_buf);
            }

            // reset written bytes on first loop since it's just metadata
            total_bytes_written += written_bytes;

            loop_count += 1;
        }
        file.close();
    }
};

fn handleLastBytes(allocator: std.mem.Allocator, final_buf_size: usize, client: std.net.Stream, file: std.fs.File) !bool {
    if (final_buf_size <= 0) {
        std.debug.print("All bytes already sent, last bytes have been handled.\n", .{});
        return true;
    }
    const final_buf = try allocator.alloc(u8, final_buf_size);
    defer allocator.free(final_buf);
    _ = try file.read(final_buf);
    const final_bytes = try client.write(final_buf);

    if (final_bytes > 0) {
        return true;
    }
    return false;
}
