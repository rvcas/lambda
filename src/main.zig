const std = @import("std");

const Expr = union(enum) {
    variable: [*]u8,
    lambda: struct {
        name: [*]u8,
        body: *Expr,
    },
    application: struct {
        operator: *Expr,
        operand: *Expr,
    },
};

const Value = union(enum) {
    int: usize,
    str: [*]u8,
    closure: struct {
        name: [*]u8,
        body: *Expr,
        env: *Env,
    },
    err: []const u8,
};

const Env = std.AutoHashMap([]u8, Value);

fn eval(expr: *Expr, env: *Env) Value {
    return switch (expr) {
        .variable => |variable| env.get(variable) orelse .{
            .err = "Variable is not defined",
        },
        .lambda => |lambda| .{
            .closure = .{
                .name = lambda.name,
                .body = lambda.body,
                .env = env,
            },
        },
        .application => |application| call(
            eval(application.operator, env),
            eval(application.operand, env),
        ),
    };
}

fn call(function: Value, argument: Value) Value {
    return switch (function) {
        .closure => |closure| blk: {
            closure.env.put(closure.name, argument);

            break :blk eval(closure.body, closure.env);
        },
        else => .{ .err = "Only functions can be called" },
    };
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
