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
                defer allocator.destroy(left);

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

    var x_variable = Expression{ .variable = "x" };

    const undefined_result = x_variable.eval(&environment, std.testing.allocator);

    // x is undefined
    try std.testing.expectError(
        error.Undefined,
        undefined_result,
    );

    var int_value = Value{ .int = 123 };

    try environment.put("x", &int_value);

    const int_result = try x_variable.eval(&environment, std.testing.allocator);

    try std.testing.expectEqual(
        int_value,
        int_result.*,
    );

    var identity = Expression{
        .lambda = .{
            .name = "x",
            .body = &x_variable,
        },
    };

    var y_variable = Expression{ .variable = "y" };

    var application = Expression{
        .application = .{
            .operator = &identity,
            .operand = &y_variable,
        },
    };

    const another_undefined_result = application.eval(&environment, std.testing.allocator);

    // y is undefined
    try std.testing.expectError(
        error.Undefined,
        another_undefined_result,
    );

    var str_value = Value{ .str = "some string" };

    try environment.put("y", &str_value);

    const str_result = try application.eval(&environment, std.testing.allocator);

    try std.testing.expectEqual(
        str_value,
        str_result.*,
    );
}
