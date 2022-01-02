const std = @import("std");

const Allocator = std.mem.Allocator;

// This is used to keep track of values that
// are defined.
const Environment = std.StringHashMap(*Value);

const EvaluationError = error{
    Undefined,
    NonFunctionCalled,
} || Allocator.Error;

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

    fn eval(self: *Expression, environment: *Environment, allocator: Allocator) EvaluationError!*Value {
        return switch (self.*) {
            .variable => |variable| blk: {
                if (environment.get(variable)) |name| {
                    break :blk name;
                } else {
                    return error.Undefined;
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

    fn call(self: *Value, argument: *Value, allocator: Allocator) EvaluationError!*Value {
        return switch (self.*) {
            .closure => |closure| blk: {
                try closure.environment.put(closure.name, argument);

                break :blk try closure.body.eval(closure.environment, allocator);
            },
            else => {
                return error.NonFunctionCalled;
            },
        };
    }
};

test "calculus" {
    var environment = Environment.init(std.testing.allocator);
    defer environment.deinit();

    var expression = Expression{ .variable = "x" };

    const undefined_result = expression.eval(&environment, std.testing.allocator);

    try std.testing.expectError(
        error.Undefined,
        undefined_result,
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
