const std = @import("std");
const Blake3 = std.crypto.hash.Blake3;

/// Options for generating new captcha digests
pub const GenerationOptions = struct {
    /// A secret to be shared between calculations to prevent third-parties from pre-computing captcha solutions
    shared_secret: []const u8,
    /// Expiration time of digests in seconds (this does not equal the exact time; expire_eta < t < expire_eta * 2)
    expire_eta: usize = 60,
};

/// Generate a new captcha digest
///  count_offset=-1 calculates the last digest
///  count_offset=+1 calculates the next digest
pub fn generate(options: GenerationOptions, count_offset: isize, request_identifying_salt: []const u8) [Blake3.digest_length]u8 {
    const timestamp = std.time.timestamp();
    if (timestamp < 0) @panic("cannot handle negative timestamp");
    const counter: u32 = @truncate(
        @addWithOverflow(@divFloor(
            @as(u64, @bitCast(timestamp)),
            options.expire_eta,
        ), @as(u64, @bitCast(count_offset)))[0],
    );
    var hash = Blake3.init(.{});
    var hash_digest: [Blake3.digest_length]u8 = undefined;
    hash.update(options.shared_secret);
    hash.update(request_identifying_salt);
    hash.update(&[1]u8{@truncate((counter >> 24) & 0xFF)});
    hash.update(&[1]u8{@truncate((counter >> 16) & 0xFF)});
    hash.update(&[1]u8{@truncate((counter >> 8) & 0xFF)});
    hash.update(&[1]u8{@truncate(counter & 0xFF)});
    hash.final(&hash_digest);
    return hash_digest;
}

/// Verify whether a provided captcha digest is valid
///  Handles truncated (first n chars) version of digests too
pub fn verify(options: GenerationOptions, request_identifying_salt: []const u8, challenge_solution: []const u8) bool {
    if (challenge_solution.len > Blake3.digest_length) @panic("the provided challenge solution is longer than the digest length of Blake3");
    if (std.mem.eql(u8, generate(options, 0, request_identifying_salt)[0..challenge_solution.len], challenge_solution) or
        std.mem.eql(u8, generate(options, -1, request_identifying_salt)[0..challenge_solution.len], challenge_solution))
    {
        return true;
    }

    return false;
}
