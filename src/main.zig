const std = @import("std");

const Allocator = std.mem.Allocator;

// This is used to keep track of values that
// are defined.
const Environment = std.StringHashMap(*Value);

const Expression = union(enum) {
    variable: []const u8,
    lambda: struct {
        name: []const u8,
        body: *Expression,
    },
    application: struct {
        operator: *Expression,
        operand: *Expression,
    },

    fn eval(self: *Expression, environment: *Environment, allocator: Allocator) Allocator.Error!*Value {
        return switch (self.*) {
            .variable => |variable| blk: {
                if (environment.get(variable)) |name| {
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
                        .environment = environment,
                    },
                };

                break :blk closure;
            },
            .application => |application| blk: {
                var left = try application.operator.eval(environment, allocator);
                var right = try application.operand.eval(environment, allocator);

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
        body: *Expression,
        environment: *Environment,
    },
    err: []const u8,

    fn call(self: *Value, argument: *Value, allocator: Allocator) Allocator.Error!*Value {
        return switch (self.*) {
            .closure => |closure| blk: {
                try closure.environment.put(closure.name, argument);

                break :blk try closure.body.eval(closure.environment, allocator);
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
    var environment = Environment.init(std.testing.allocator);
    defer environment.deinit();

    var expression = Expression{ .variable = "x" };

    const undefined_result = try expression.eval(&environment, std.testing.allocator);
    defer std.testing.allocator.destroy(undefined_result);

    try std.testing.expectEqual(
        Value{ .err = "Variable is not defined" },
        undefined_result.*,
    );

    var int_value = try std.testing.allocator.create(Value);
    int_value.* = Value{ .int = 123 };

    try environment.put("x", int_value);

    const int_result = try expression.eval(&environment, std.testing.allocator);
    defer std.testing.allocator.destroy(int_result);

    try std.testing.expectEqual(
        Value{ .int = 123 },
        int_result.*,
    );
}
