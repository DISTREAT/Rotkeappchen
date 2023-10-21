const std = @import("std");
const rk = @import("lib.zig");
const expect = std.testing.expect;

test "Generate and verify" {
    const options = rk.GenerationOptions{ .shared_secret = "secret" };

    const d1 = rk.generate(options, 0, "request 1");

    try expect(rk.verify(options, "request 1", &d1));
    try expect(!rk.verify(options, "request 1", "incorrect solution"));
}

test "Different secrets should result in different digests" {
    // slightest chance of failing, due to desynchronization
    const d1 = rk.generate(.{ .shared_secret = "a" }, 0, "a");
    const d2 = rk.generate(.{ .shared_secret = "b" }, 0, "a");

    try expect(!std.mem.eql(u8, &d1, &d2));
}

test "Different salts should result in different digests" {
    const options = rk.GenerationOptions{ .shared_secret = "secret" };

    // slightest chance of failing, due to desynchronization
    const d1 = rk.generate(options, 0, "a");
    const d2 = rk.generate(options, 0, "b");

    try expect(!std.mem.eql(u8, &d1, &d2));
}

test "Check whether truncated digests can be verified" {
    const options = rk.GenerationOptions{ .shared_secret = "secret" };

    const digest = rk.generate(options, 0, "request 1");
    try expect(rk.verify(options, "request 1", digest[0..5]));
}

test "Realistic tests" {
    const options = rk.GenerationOptions{
        .shared_secret = "secret",
        .expire_eta = 60,
    };

    for (&[_]usize{ 24, 1, 63 }) |delay| {
        const digest = rk.generate(options, 0, "a");
        std.time.sleep(delay * 1000000000);
        try expect(rk.verify(options, "a", &digest));
    }
}

test "Expiration of digests" {
    const options = rk.GenerationOptions{ .shared_secret = "secret", .expire_eta = 1 };

    const digest = rk.generate(options, 0, "request 1");
    std.time.sleep(3 * 1000000000);
    try expect(!rk.verify(options, "request 1", &digest));
}
