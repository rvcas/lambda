const std = @import("std");

const Allocator = std.mem.Allocator;

const Env = std.StringHashMap(*Value);

const Expr = union(enum) {
    variable: []const u8,
    lambda: struct {
        name: []const u8,
        body: *Expr,
    },
    application: struct {
        operator: *Expr,
        operand: *Expr,
    },

    fn eval(self: *Expr, env: *Env, allocator: Allocator) Allocator.Error!*Value {
        return switch (self.*) {
            .variable => |variable| blk: {
                if (env.get(variable)) |name| {
                    break :blk name;
                } else {
                    var err = try allocator.create(Value);

                    err.* = Value{ .err = "Variable is not defined" };

                    break :blk err;
                }
            },
            .lambda => |lambda| blk: {
                var closure = try allocator.create(Value);

                closure.* = Value{
                    .closure = .{
                        .name = lambda.name,
                        .body = lambda.body,
                        .env = env,
                    },
                };

                break :blk closure;
            },
            .application => |application| blk: {
                var left = try application.operator.eval(env, allocator);
                var right = try application.operand.eval(env, allocator);

                break :blk try left.call(right, allocator);
            },
        };
    }
};

const Value = union(enum) {
    int: usize,
    str: []const u8,
    closure: struct {
        name: []const u8,
        body: *Expr,
        env: *Env,
    },
    err: []const u8,

    fn call(self: *Value, argument: *Value, allocator: Allocator) Allocator.Error!*Value {
        return switch (self.*) {
            .closure => |closure| blk: {
                try closure.env.put(closure.name, argument);

                break :blk try closure.body.eval(closure.env, allocator);
            },
            else => blk: {
                var err = try allocator.create(Value);

                err.* = Value{ .err = "Only functions can be called" };

                break :blk err;
            },
        };
    }
};

test "calculus" {
    var env = Env.init(std.testing.allocator);
    defer env.deinit();

    var expr = Expr{ .variable = "x" };

    const undefined_result = try expr.eval(&env, std.testing.allocator);
    defer std.testing.allocator.destroy(undefined_result);

    try std.testing.expectEqual(
        Value{ .err = "Variable is not defined" },
        undefined_result.*,
    );

    var int_value = try std.testing.allocator.create(Value);
    int_value.* = Value{ .int = 123 };

    try env.put("x", int_value);

    const int_result = try expr.eval(&env, std.testing.allocator);
    defer std.testing.allocator.destroy(int_result);

    try std.testing.expectEqual(
        Value{ .int = 123 },
        int_result.*,
    );
}
