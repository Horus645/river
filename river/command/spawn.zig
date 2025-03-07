// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2020 The River Developers
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const os = std.os;

const c = @import("../c.zig");
const util = @import("../util.zig");

const Error = @import("../command.zig").Error;
const Seat = @import("../Seat.zig");

/// Spawn a program.
pub fn spawn(
    _: *Seat,
    args: []const [:0]const u8,
    out: *?[]const u8,
) Error!void {
    if (args.len < 2) return Error.NotEnoughArguments;
    if (args.len > 2) return Error.TooManyArguments;

    const child_args = [_:null]?[*:0]const u8{ "/bin/sh", "-c", args[1], null };

    const pid = os.fork() catch {
        out.* = try std.fmt.allocPrint(util.gpa, "fork/execve failed", .{});
        return Error.Other;
    };

    if (pid == 0) {
        // Clean things up for the child in an intermediate fork
        if (c.setsid() < 0) unreachable;
        if (os.system.sigprocmask(os.SIG.SETMASK, &os.empty_sigset, null) < 0) unreachable;

        const pid2 = os.fork() catch c._exit(1);
        if (pid2 == 0) os.execveZ("/bin/sh", &child_args, std.c.environ) catch c._exit(1);

        c._exit(0);
    }

    // Wait the intermediate child.
    const ret = os.waitpid(pid, 0);
    if (!os.W.IFEXITED(ret.status) or
        (os.W.IFEXITED(ret.status) and os.W.EXITSTATUS(ret.status) != 0))
    {
        out.* = try std.fmt.allocPrint(util.gpa, "fork/execve failed", .{});
        return Error.Other;
    }
}
