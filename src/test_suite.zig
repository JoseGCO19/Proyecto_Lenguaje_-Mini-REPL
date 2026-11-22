const std = @import("std");
const types = @import("types.zig");
const stack_mod = @import("stack.zig");
const env_mod = @import("env.zig");
const evaluator = @import("evaluator.zig");

const Stack = stack_mod.Stack;
const Environment = env_mod.Environment;
const Value = types.Value;
const EvaluatorError = types.EvaluatorError;

/// Función auxiliar para evaluar una cadena de texto en los tests unitarios.
fn evalString(allocator: std.mem.Allocator, input: []const u8, stack: *Stack, env: *Environment) !void {
    var tokens = try evaluator.tokenize(allocator, input);
    defer tokens.deinit();
    const null_writer = std.io.null_writer;
    try evaluator.evaluateTokens(tokens.items, stack, env, null_writer);
}

test "Requisito 1: Operaciones aritméticas básicas (+, -, *, /)" {
    const allocator = std.testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();
    var env = try Environment.init(allocator);
    defer env.deinit();

    // Suma: 3 + 4 = 7
    try evalString(allocator, "3 4 +", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 7 }, try stack.pop());

    // Resta: 10 - 4 = 6
    try evalString(allocator, "10 4 -", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 6 }, try stack.pop());

    // Multiplicación: 5 * 6 = 30
    try evalString(allocator, "5 6 *", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 30 }, try stack.pop());

    // División exacta: 20 / 4 = 5
    try evalString(allocator, "20 4 /", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 5 }, try stack.pop());

    // División con decimales: 7 / 2 = 3.5
    try evalString(allocator, "7 2 /", &stack, &env);
    const div_res = try stack.pop();
    try std.testing.expect(div_res == .float);
    try std.testing.expectEqual(@as(f64, 3.5), div_res.float);

    // Operación mixta entero y flotante: 10 + 2.5 = 12.5
    try evalString(allocator, "10 2.5 +", &stack, &env);
    const sum_res = try stack.pop();
    try std.testing.expect(sum_res == .float);
    try std.testing.expectEqual(@as(f64, 12.5), sum_res.float);
}

test "Requisito 1: Manejo de errores de ejecución (división por cero y stack underflow)" {
    const allocator = std.testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();
    var env = try Environment.init(allocator);
    defer env.deinit();

    // División por cero con entero
    const err_div_zero = evalString(allocator, "10 0 /", &stack, &env);
    try std.testing.expectError(EvaluatorError.DivisionByZero, err_div_zero);

    // División por cero con flotante
    const err_div_float = evalString(allocator, "15.5 0.0 /", &stack, &env);
    try std.testing.expectError(EvaluatorError.DivisionByZero, err_div_float);

    // Stack underflow: operador binario sin operandos suficientes
    const err_underflow_empty = evalString(allocator, "+", &stack, &env);
    try std.testing.expectError(EvaluatorError.StackUnderflow, err_underflow_empty);

    const err_underflow_one = evalString(allocator, "5 +", &stack, &env);
    try std.testing.expectError(EvaluatorError.StackUnderflow, err_underflow_one);

    // Token léxico inválido
    const err_invalid_tok = evalString(allocator, "10 @#$", &stack, &env);
    try std.testing.expectError(EvaluatorError.InvalidToken, err_invalid_tok);
}

test "Requisito 2: Sistema de tipos y comparaciones (==, !=, <, >)" {
    const allocator = std.testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();
    var env = try Environment.init(allocator);
    defer env.deinit();

    // Error de tipos controlado: intentar sumar un entero y un booleano (5 true +)
    const err_mismatch = evalString(allocator, "5 true +", &stack, &env);
    try std.testing.expectError(EvaluatorError.TypeMismatch, err_mismatch);

    // Comparación de números: 5 == 5 -> true
    try evalString(allocator, "5 5 ==", &stack, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, try stack.pop());

    // Comparación de números: 5 10 < -> true
    try evalString(allocator, "5 10 <", &stack, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, try stack.pop());

    // Comparación de números: 20 10 > -> true
    try evalString(allocator, "20 10 >", &stack, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, try stack.pop());

    // Desigualdad: 10 20 != -> true
    try evalString(allocator, "10 20 !=", &stack, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, try stack.pop());

    // Comparación booleana: true false == -> false
    try evalString(allocator, "true false ==", &stack, &env);
    try std.testing.expectEqual(Value{ .boolean = false }, try stack.pop());

    // Comparación incompatible: 5 true == -> TypeMismatch
    const err_comp_mismatch = evalString(allocator, "5 true ==", &stack, &env);
    try std.testing.expectError(EvaluatorError.TypeMismatch, err_comp_mismatch);
}

test "Requisito 3: Variables, paso de parámetros y asignación en RPN" {
    const allocator = std.testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();
    var env = try Environment.init(allocator);
    defer env.deinit();

    // Asignación simple: x 10 =
    try evalString(allocator, "x 10 =", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 10 }, try stack.pop());

    // Verificamos que x esté guardada en el entorno
    const x_val = env.get("x");
    try std.testing.expect(x_val != null);
    try std.testing.expectEqual(Value{ .int = 10 }, x_val.?);

    // Asignación con expresión: y x 5 + 2 * =   -> (10 + 5) * 2 = 30
    try evalString(allocator, "y x 5 + 2 * =", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 30 }, try stack.pop());

    // Uso de variables en cálculo: x y + -> 10 + 30 = 40
    try evalString(allocator, "x y +", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 40 }, try stack.pop());

    // Error: asignar a un literal no-identificador (5 10 =)
    const err_invalid_target = evalString(allocator, "5 10 =", &stack, &env);
    try std.testing.expectError(EvaluatorError.InvalidAssignmentTarget, err_invalid_target);

    // Error: variable no definida (z 5 +)
    const err_undefined = evalString(allocator, "z 5 +", &stack, &env);
    try std.testing.expectError(EvaluatorError.UndefinedVariable, err_undefined);
}

test "Requisito 4: Alcance Local y Sombreado (Scoping y Shadowing)" {
    const allocator = std.testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();
    var env = try Environment.init(allocator);
    defer env.deinit();

    // Declaramos variable global: x 10 =
    try evalString(allocator, "x 10 =", &stack, &env);
    _ = try stack.pop();

    // Abrimos bloque local con 'begin'
    try evalString(allocator, "begin", &stack, &env);
    try std.testing.expectEqual(@as(usize, 1), env.currentLevel());

    // Sombreamos x en el ámbito local y definimos y local
    try evalString(allocator, "x 99 =", &stack, &env);
    _ = try stack.pop();
    try evalString(allocator, "y 50 =", &stack, &env);
    _ = try stack.pop();

    // Verificamos valores dentro del bloque local: x y + -> 99 + 50 = 149
    try evalString(allocator, "x y +", &stack, &env);
    try std.testing.expectEqual(Value{ .int = 149 }, try stack.pop());

    // Cerramos el bloque local con 'end'
    try evalString(allocator, "end", &stack, &env);
    try std.testing.expectEqual(@as(usize, 0), env.currentLevel());

    // Verificamos que x restauró su valor global original de 10
    const global_x = env.get("x");
    try std.testing.expect(global_x != null);
    try std.testing.expectEqual(Value{ .int = 10 }, global_x.?);

    // Verificamos que y fue destruida y no existe en el entorno global
    const global_y = env.get("y");
    try std.testing.expect(global_y == null);

    // Intentar cerrar el ámbito global debe fallar con ScopeUnderflow
    const err_scope_underflow = evalString(allocator, "end", &stack, &env);
    try std.testing.expectError(EvaluatorError.ScopeUnderflow, err_scope_underflow);
}
