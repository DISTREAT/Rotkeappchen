const std = @import("std");
const rk = @import("lib.zig");

pub fn main() void {
    const iteration_count = 1000000;
    const options = rk.GenerationOptions{ .shared_secret = "secret" };

    var timer = std.time.Timer.start() catch @panic("cannot initialize a timer");

    for (0..iteration_count) |_| {
        std.debug.assert(
            rk.verify(
                options,
                "request 1",
                &rk.generate(options, 0, "request 1"),
            ),
        );
    }

    const time = timer.read();

    std.log.info("completed {d} iterations in {d}ms with an average of {d} ns per iteration", .{
        iteration_count,
        @divTrunc(time, 1000000),
        @divTrunc(time, iteration_count),
    });
}
