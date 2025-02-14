const std = @import("std");
const ztypes = @import("types.zig");
const TCP_CLIENT_BUF_SIZE: usize = 32768;
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
        var file_name: [:0]const u8 = undefined;

        // searching the arguments for the -fn (file name) or -file flag
        // if none are found, just spit out a debug error for now and return
        var found_file_arg_flag: bool = false;
        for (ctx.args) |arg| {
            if (arg) |g| {
                if (found_file_arg_flag) {
                    file_name = g;

                    break;
                }
                if (std.mem.eql(u8, g, "-fn") or std.mem.eql(u8, g, "-file")) {
                    found_file_arg_flag = true;
                }
            }
        }
        if (!found_file_arg_flag) {
            std.debug.print("EXITING_CLIENT_EARLY_NO_FILE_NAME", .{});
            return;
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
        @memset(send_buf[0..], 0);
        @memcpy(send_buf[0..cmd.len], cmd);
        @memcpy(send_buf[cmd.len .. cmd.len + 1], " ");
        @memcpy(send_buf[cmd.len + 1 .. cmd.len + 1 + final_file_name.len], final_file_name);

        while (true) {
            // ignore first pass of the loop, as it's just metadata.
            // then, we read from the file, and write to the server.
            // each iteration, we keep track of how many bytes were successfully written,
            // and skip that many bytes from the previous iteration.
            // there is special handling on the last loop
            // to ensure we aren't sending a buffer that's too large for the remaining
            // data and ending up with garbage at the end of the file.
            if (loop_count > 0) {
                written_bytes = 0;
                try file.seekTo(seek_skip);
                last_bytes_read = try file.read(send_buf);
                std.debug.print("LAST_BYTES_READ: {d}\n", .{last_bytes_read});
                seek_skip += written_bytes;
                // this means we're at the end of the file
                if (last_bytes_read < TCP_CLIENT_BUF_SIZE) {
                    const final_bytes_result = try handleLastBytes(ctx.allocator, last_bytes_read, &client, &file, seek_skip);
                    if (!final_bytes_result) {
                        std.debug.print("FAILED_FINAL_BYTES\n", .{});
                    }
                    break;
                }
            }

            written_bytes = try client.write(send_buf);
            std.debug.print("Wrote {d} bytes\n", .{written_bytes});

            loop_count += 1;
        }
        file.close();
    }
};

fn handleLastBytes(allocator: std.mem.Allocator, last_bytes_read: usize, client: *std.net.Stream, file: *const std.fs.File, file_pos: usize) !bool {
    const final_buf = try allocator.alloc(u8, last_bytes_read);
    defer allocator.free(final_buf);
    try file.seekTo(file_pos);
    _ = try file.read(final_buf);
    const final_bytes = try client.write(final_buf);
    if (final_bytes > 0) {
        return true;
    }
    return false;
}
