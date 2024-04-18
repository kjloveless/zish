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
        _ = try zish_execute(allocator, args);
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
  const child = try std.ChildProcess.run(.{ .allocator = allocator, .argv = args });
  if (child.stdout.len != 0) {
    try io.getStdOut().writer().print("{s}", .{child.stdout});
    allocator.free(child.stdout);
    allocator.free(child.stderr);
  }

  return 1;
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
