const std = @import("std");

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
};

const Env = std.StringHashMap(*Value);

fn eval(expr: *Expr, env: *Env, allocator: std.mem.Allocator) *Value {
    return switch (expr.*) {
        .variable => |variable| blk: {
            if (env.get(variable)) |name| {
                break :blk name;
            } else {
                var err = allocator.create(Value) catch unreachable;

                err.* = Value{ .err = "Variable is not defined" };

                break :blk err;
            }
        },
        .lambda => |lambda| blk: {
            var closure = allocator.create(Value) catch unreachable;

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
            var left = eval(application.operator, env, allocator);
            var right = eval(application.operand, env, allocator);

            break :blk call(left, right, allocator);
        },
    };
}

fn call(function: *Value, argument: *Value, allocator: std.mem.Allocator) *Value {
    return switch (function.*) {
        .closure => |closure| blk: {
            closure.env.put(closure.name, argument) catch unreachable;

            break :blk eval(closure.body, closure.env, allocator);
        },
        else => blk: {
            var err = allocator.create(Value) catch unreachable;

            err.* = Value{ .err = "Only functions can be called" };

            break :blk err;
        },
    };
}

const testing = std.testing;

test "calculus" {
    var env = Env.init(testing.allocator);
    defer env.deinit();

    var expr = try testing.allocator.create(Expr);
    defer testing.allocator.destroy(expr);

    expr.* = Expr{ .variable = "x" };

    const undefined_result = eval(expr, &env, testing.allocator);
    defer testing.allocator.destroy(undefined_result);

    try std.testing.expectEqual(
        Value{ .err = "Variable is not defined" },
        undefined_result.*,
    );

    var int_value = try testing.allocator.create(Value);
    int_value.* = Value{ .int = 123 };

    try env.put("x", int_value);

    const int_result = eval(expr, &env, testing.allocator);
    defer testing.allocator.destroy(int_result);

    try std.testing.expectEqual(
        Value{ .int = 123 },
        int_result.*,
    );
}
