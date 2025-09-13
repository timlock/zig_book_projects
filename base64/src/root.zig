//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const padding = '=';

const Table = struct {
    const inner = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    fn get_char(index: u8) u8 {
        return inner[index];
    }

    fn get_index(char: u8) u8 {
        switch (char) {
            'A'...'Z' => return char - 65,
            'a'...'z' => return char - 97 + 26,
            '0'...'9' => return char - 48 + 52,
            '+' => return 62,
            '/' => return 63,
            else => std.debug.panic("encoded char {} is not base64", .{char}),
        }
    }
};

pub fn encode(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    const len = try calc_encode_length(input);
    const encoded = try allocator.alloc(u8, len);
    var next: usize = 0;

    var i: usize = 0;
    while (i < input.len) : (i += 3) {
        if (i + 2 < input.len) {
            encoded[next] = Table.get_char(input[i] >> 2 & 63);
            next += 1;

            encoded[next] = Table.get_char(input[i] << 4 | input[i + 1] >> 4 & 63);
            next += 1;

            encoded[next] = Table.get_char(input[i + 1] << 2 | input[i + 2] >> 6 & 63);
            next += 1;

            encoded[next] = Table.get_char(input[i + 2] & 63);
            next += 1;
        } else if (i + 1 < input.len) {
            encoded[next] = Table.get_char(input[i] >> 2 & 63);
            next += 1;

            encoded[next] = Table.get_char(input[i] << 4 | input[i + 1] >> 4 & 63);
            next += 1;

            encoded[next] = Table.get_char(input[i + 1] << 2 & 63);
            next += 1;

            encoded[next] = padding;
            next += 1;
        } else {
            encoded[next] = Table.get_char(input[i] >> 2 & 63);
            next += 1;

            encoded[next] = Table.get_char(input[i] << 4 & 63);
            next += 1;

            encoded[next] = padding;
            next += 1;

            encoded[next] = padding;
            next += 1;
        }
    }

    return encoded;
}

pub fn decode(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    const len = try calc_decode_length(input);
    const decoded = try allocator.alloc(u8, len);
    var next: usize = 0;

    var i: usize = 0;
    while (i < input.len) : (i += 4) {
        decoded[next] = Table.get_index(input[i]) << 2 | Table.get_index(input[i + 1]) >> 4;
        next += 1;

        if (input[i + 2] != '=') {
            decoded[next] = Table.get_index(input[i + 1]) << 4 | Table.get_index(input[i + 2]) >> 2;
        }
        next += 1;

        if (input[i + 3] != '=') {
            decoded[next] = Table.get_index(input[i + 2]) << 6 | Table.get_index(input[i + 3]);
        }
        next += 1;
    }
    return decoded;
}

fn calc_encode_length(input: []const u8) !usize {
    if (input.len < 3) {
        return 4;
    }

    const groups = try std.math.divCeil(usize, input.len, 3);
    return groups * 4;
}

fn calc_decode_length(input: []const u8) !usize {
    if (input.len < 4) {
        return 3;
    }

    const groups = try std.math.divFloor(usize, input.len, 4);

    const padded_len = groups * 3;

    var i: usize = input.len - 1;
    while (i >= 0) : (i -= 1) {
        if (input[i] != '=') {
            break;
        }
    }
    const paddings = input.len - 1 - i;

    return padded_len - paddings;
}

test "get_char" {
    try std.testing.expectEqual('c', Table.get_char(28));
}

test "get_index" {
    try std.testing.expectEqual(0, Table.get_index('A'));
    try std.testing.expectEqual(25, Table.get_index('Z'));
    try std.testing.expectEqual(26, Table.get_index('a'));
    try std.testing.expectEqual(51, Table.get_index('z'));
    try std.testing.expectEqual(52, Table.get_index('0'));
    try std.testing.expectEqual(61, Table.get_index('9'));
    try std.testing.expectEqual(62, Table.get_index('+'));
    try std.testing.expectEqual(63, Table.get_index('/'));
}

test "encode three characters" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const encoded = try encode(allocator, "123");
    try std.testing.expectEqualStrings("MTIz", encoded);

    const decoded = try decode(allocator, "MTIz");
    try std.testing.expectEqualStrings("123", decoded);
}

test "encode two characters" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const encoded = try encode(allocator, "Hi");
    try std.testing.expectEqualStrings("SGk=", encoded);

    const decoded = try decode(allocator, "SGk=");
    try std.testing.expectEqualStrings("Hi", decoded);
}

test "encode one characters" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const encoded = try encode(allocator, "1");
    try std.testing.expectEqualStrings("MQ==", encoded);

    const decoded = try decode(allocator, "MQ==");
    try std.testing.expectEqualStrings("1", decoded);
}

test "encode base64 characters" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    const encoded = try encode(allocator, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
    try std.testing.expectEqualStrings("QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ejAxMjM0NTY3ODkrLw==", encoded);

    const decoded = try decode(allocator, "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ejAxMjM0NTY3ODkrLw==");
    try std.testing.expectEqualStrings("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", decoded);
}
