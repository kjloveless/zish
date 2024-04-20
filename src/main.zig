const std = @import("std");
const io = std.io;
const Allocator = std.mem.Allocator;

const ZISH_TOKEN_DELIMITER: []const u8 = " \t\r\n";

fn zish_loop() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args: [][]const u8 = undefined;
    const status: bool = true;

    while (status) {
        _ = try io.getStdOut().writer().write("> ");
        const line = try zish_read_line(allocator);
        args = try zish_split_line(allocator, line);
        if (args.len != 0) {
            _ = try zish_execute(allocator, args);
        }
        allocator.free(line);
    }
    return;
}

fn zish_read_line(allocator: Allocator) ![]const u8 {
    var input = std.ArrayList(u8).init(allocator);
    defer input.deinit();

    try io.getStdIn().reader().streamUntilDelimiter(input.writer(), '\n', null);
    return try input.toOwnedSlice();
}

fn zish_split_line(allocator: Allocator, line: []const u8) ![][]const u8 {
    var tokens = std.ArrayList([]const u8).init(allocator);
    defer tokens.deinit();

    var it = std.mem.splitAny(u8, line, ZISH_TOKEN_DELIMITER);
    while (it.next()) |token| {
        if (token.len > 0) {
            try tokens.append(token);
        }
    }
    return tokens.toOwnedSlice();
}

fn zish_launch(allocator: Allocator, args: [][]const u8) !u32 {
    const child_process_result = std.ChildProcess.run(.{ .allocator = allocator, .argv = args }) catch |err| {
        // Handle the error here:
        switch (err) {
            error.FileNotFound => {
                // Specific error handling for FileNotFound
                std.debug.print("Command not found.\n", .{});
                return 127; // Common exit code for command not found.
            },
            else => {
                // General error handling for other errors
                std.debug.print("An error occurred: {}\n", .{err});
                return 1;
            },
        }
    };

    // If the code reaches here, `child_process_result` is successfully obtained and not null.
    if (child_process_result.stdout.len != 0) {
        try io.getStdOut().writer().print("{s}", .{child_process_result.stdout});
        allocator.free(child_process_result.stdout);
        allocator.free(child_process_result.stderr);
    }

    return child_process_result.term.Exited;
}

fn zish_cd(allocator: Allocator, args: [][]const u8) !u32 {
    const to_dir = if (args.len > 0) args[1] else ".";
    try std.posix.chdir(to_dir);

    const cur_dir: []u8 = try std.process.getCwdAlloc(allocator);
    std.debug.print("{s}\n", .{cur_dir});
    return 0;
}

fn zish_execute(allocator: Allocator, args: [][]const u8) !u32 {
    if (args.len == 0) {
        return 1;
    }

    if (std.mem.eql(u8, args[0], "exit")) {
        std.process.exit(0);
    }

    if (std.mem.eql(u8, args[0], "cd")) {
        return zish_cd(allocator, args);
    }

    return zish_launch(allocator, args);
}

pub fn main() !void {

    // Load config files, if any.

    // Run command loop.
    try zish_loop();

    // Perform any shutdown/cleanup.
}
