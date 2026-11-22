const std = @import("std");
const types = @import("types.zig");
const stack_mod = @import("stack.zig");
const env_mod = @import("env.zig");

const Operator = types.Operator;
const Command = types.Command;
const Value = types.Value;
const Token = types.Token;
const EvaluatorError = types.EvaluatorError;
const Stack = stack_mod.Stack;
const Environment = env_mod.Environment;

/// Resuelve un valor en caso de que sea un identificador (símbolo) consultándolo en la tabla de símbolos.
/// Demuestra el paso de parámetros inmutables (*const Environment) y por copia (Value).
/// Parámetros:
///   - val: Valor a evaluar (puede ser literal Int/Float/Bool o Symbol).
///   - env: Puntero inmutable al entorno de variables (*const Environment).
/// Retorna:
///   - El valor resuelto concreto (Int, Float o Bool).
///   - EvaluatorError.UndefinedVariable si el símbolo no existe en ningún ámbito activo.
pub fn resolveValue(val: Value, env: *const Environment) EvaluatorError!Value {
    switch (val) {
        .symbol => |name| {
            if (env.get(name)) |bound_val| {
                return bound_val;
            } else {
                return EvaluatorError.UndefinedVariable;
            }
        },
        else => return val,
    }
}

/// Desapila un elemento de la pila liberando la memoria del símbolo si fuera necesario.
/// Retorna el valor resuelto (número o booleano).
pub fn popAndResolve(stack: *Stack, env: *const Environment) EvaluatorError!Value {
    const raw = try stack.pop();
    defer {
        if (raw == .symbol) {
            stack.allocator.free(raw.symbol);
        }
    }
    return try resolveValue(raw, env);
}

/// Ejecuta una operación aritmética binaria (+, -, *, /) sobre dos operandos previamente desapilados.
/// Realiza chequeo estricto de tipos en tiempo de ejecución: ambos operandos deben ser numéricos.
/// Parámetros:
///   - op: Operador aritmético a ejecutar.
///   - a: Primer operando (izquierdo en orden infijo, desapilado segundo).
///   - b: Segundo operando (derecho en orden infijo, desapilado primero).
/// Retorna:
///   - El resultado del cálculo como Value (Int o Float).
///   - EvaluatorError.TypeMismatch si alguno de los operandos no es un número.
///   - EvaluatorError.DivisionByZero si el divisor b es cero.
pub fn executeArithmetic(op: Operator, a: Value, b: Value) EvaluatorError!Value {
    // Chequeo de tipos: no se permiten operaciones aritméticas con booleanos (ej. 5 true +)
    if (!a.isNumber() or !b.isNumber()) {
        return EvaluatorError.TypeMismatch;
    }

    switch (op) {
        .Add => {
            if (a == .int and b == .int) {
                const res = std.math.add(i64, a.int, b.int) catch {
                    return Value{ .float = a.asFloat() + b.asFloat() };
                };
                return Value{ .int = res };
            }
            return Value{ .float = a.asFloat() + b.asFloat() };
        },
        .Sub => {
            if (a == .int and b == .int) {
                const res = std.math.sub(i64, a.int, b.int) catch {
                    return Value{ .float = a.asFloat() - b.asFloat() };
                };
                return Value{ .int = res };
            }
            return Value{ .float = a.asFloat() - b.asFloat() };
        },
        .Mul => {
            if (a == .int and b == .int) {
                const res = std.math.mul(i64, a.int, b.int) catch {
                    return Value{ .float = a.asFloat() * b.asFloat() };
                };
                return Value{ .int = res };
            }
            return Value{ .float = a.asFloat() * b.asFloat() };
        },
        .Div => {
            // Chequeo riguroso de división por cero
            if (b.asFloat() == 0.0 or (b == .int and b.int == 0)) {
                return EvaluatorError.DivisionByZero;
            }

            if (a == .int and b == .int) {
                if (@rem(a.int, b.int) == 0) {
                    return Value{ .int = @divTrunc(a.int, b.int) };
                } else {
                    return Value{ .float = a.asFloat() / b.asFloat() };
                }
            }
            return Value{ .float = a.asFloat() / b.asFloat() };
        },
        else => unreachable,
    }
}

/// Ejecuta una comparación lógica relacional o de igualdad (==, !=, <, >).
/// Parámetros:
///   - op: Operador relacional a aplicar.
///   - a: Primer operando.
///   - b: Segundo operando.
/// Retorna:
///   - Value con variante .boolean correspondiente.
///   - EvaluatorError.TypeMismatch si se intenta comparar tipos incompatibles.
pub fn executeComparison(op: Operator, a: Value, b: Value) EvaluatorError!Value {
    switch (op) {
        .Eq => {
            if (a == .boolean and b == .boolean) {
                return Value{ .boolean = (a.boolean == b.boolean) };
            } else if (a.isNumber() and b.isNumber()) {
                return Value{ .boolean = (a.asFloat() == b.asFloat()) };
            } else {
                return EvaluatorError.TypeMismatch;
            }
        },
        .Neq => {
            if (a == .boolean and b == .boolean) {
                return Value{ .boolean = (a.boolean != b.boolean) };
            } else if (a.isNumber() and b.isNumber()) {
                return Value{ .boolean = (a.asFloat() != b.asFloat()) };
            } else {
                return EvaluatorError.TypeMismatch;
            }
        },
        .Lt => {
            if (a.isNumber() and b.isNumber()) {
                return Value{ .boolean = (a.asFloat() < b.asFloat()) };
            } else {
                return EvaluatorError.TypeMismatch;
            }
        },
        .Gt => {
            if (a.isNumber() and b.isNumber()) {
                return Value{ .boolean = (a.asFloat() > b.asFloat()) };
            } else {
                return EvaluatorError.TypeMismatch;
            }
        },
        else => unreachable,
    }
}

/// Ejecuta operadores lógicos booleanos ('and', 'or', 'not').
/// Parámetros:
///   - op: Operador lógico.
///   - stack: Puntero mutable a la pila (*Stack).
///   - env: Puntero inmutable al entorno (*const Environment).
pub fn executeLogical(op: Operator, stack: *Stack, env: *const Environment) EvaluatorError!void {
    if (op == .Not) {
        const a = try popAndResolve(stack, env);
        if (a != .boolean) {
            return EvaluatorError.TypeMismatch;
        }
        try stack.push(Value{ .boolean = !a.boolean });
        return;
    }

    const b = try popAndResolve(stack, env);
    const a = try popAndResolve(stack, env);

    if (a != .boolean or b != .boolean) {
        return EvaluatorError.TypeMismatch;
    }

    const result = switch (op) {
        .And => a.boolean and b.boolean,
        .Or => a.boolean or b.boolean,
        else => unreachable,
    };
    try stack.push(Value{ .boolean = result });
}

/// Ejecuta la operación de asignación en notación postfija: `<identificador> <expresion> =`.
/// Por ejemplo: `x 10 =` o `x 5 2 + =`.
/// Parámetros:
///   - stack: Puntero mutable a la pila (*Stack).
///   - env: Puntero mutable al entorno (*Environment).
/// Retorna:
///   - EvaluatorError.StackUnderflow si la pila no tiene al menos 2 elementos.
///   - EvaluatorError.InvalidAssignmentTarget si el destino no es un símbolo/identificador.
pub fn executeAssignment(stack: *Stack, env: *Environment) EvaluatorError!void {
    // 1. Desapilamos el valor a asignar y lo resolvemos si era otro símbolo
    const raw_val = try stack.pop();
    defer {
        if (raw_val == .symbol) {
            stack.allocator.free(raw_val.symbol);
        }
    }
    const resolved_val = try resolveValue(raw_val, env);

    // 2. Desapilamos el identificador destino
    const target = try stack.pop();
    defer {
        if (target == .symbol) {
            stack.allocator.free(target.symbol);
        }
    }

    switch (target) {
        .symbol => |var_name| {
            // Registramos la variable en el entorno
            env.set(var_name, resolved_val) catch return EvaluatorError.OutOfMemory;
            // Devolvemos el valor asignado a la pila como resultado evaluado
            try stack.push(resolved_val);
        },
        else => {
            return EvaluatorError.InvalidAssignmentTarget;
        },
    }
}

/// Analizador léxico (Lexer / Tokenizer): convierte una línea de texto en una lista de Tokens.
/// Parámetros:
///   - allocator: Asignador de memoria para la lista de tokens.
///   - line: Cadena de texto de entrada con la expresión RPN.
pub fn tokenize(allocator: std.mem.Allocator, line: []const u8) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();

    var iter = std.mem.tokenizeAny(u8, line, " \t\r\n");
    while (iter.next()) |token_str| {
        // 1. Operadores aritméticos y de asignación
        if (std.mem.eql(u8, token_str, "+")) {
            try tokens.append(.{ .operator = .Add });
        } else if (std.mem.eql(u8, token_str, "-")) {
            try tokens.append(.{ .operator = .Sub });
        } else if (std.mem.eql(u8, token_str, "*")) {
            try tokens.append(.{ .operator = .Mul });
        } else if (std.mem.eql(u8, token_str, "/")) {
            try tokens.append(.{ .operator = .Div });
        } else if (std.mem.eql(u8, token_str, "=")) {
            try tokens.append(.{ .operator = .Assign });
        }
        // 2. Operadores de comparación y relacionales
        else if (std.mem.eql(u8, token_str, "==")) {
            try tokens.append(.{ .operator = .Eq });
        } else if (std.mem.eql(u8, token_str, "!=")) {
            try tokens.append(.{ .operator = .Neq });
        } else if (std.mem.eql(u8, token_str, "<")) {
            try tokens.append(.{ .operator = .Lt });
        } else if (std.mem.eql(u8, token_str, ">")) {
            try tokens.append(.{ .operator = .Gt });
        }
        // 3. Operadores lógicos por palabra clave
        else if (std.mem.eql(u8, token_str, "and")) {
            try tokens.append(.{ .operator = .And });
        } else if (std.mem.eql(u8, token_str, "or")) {
            try tokens.append(.{ .operator = .Or });
        } else if (std.mem.eql(u8, token_str, "not")) {
            try tokens.append(.{ .operator = .Not });
        }
        // 4. Comandos del REPL
        else if (std.mem.eql(u8, token_str, "vars")) {
            try tokens.append(.{ .command = .Vars });
        } else if (std.mem.eql(u8, token_str, "begin")) {
            try tokens.append(.{ .command = .Begin });
        } else if (std.mem.eql(u8, token_str, "end")) {
            try tokens.append(.{ .command = .End });
        } else if (std.mem.eql(u8, token_str, "stack")) {
            try tokens.append(.{ .command = .Stack });
        } else if (std.mem.eql(u8, token_str, "clear")) {
            try tokens.append(.{ .command = .Clear });
        } else if (std.mem.eql(u8, token_str, "help")) {
            try tokens.append(.{ .command = .Help });
        } else if (std.mem.eql(u8, token_str, "exit") or std.mem.eql(u8, token_str, "quit")) {
            try tokens.append(.{ .command = .Exit });
        }
        // 5. Literales Booleanos
        else if (std.mem.eql(u8, token_str, "true")) {
            try tokens.append(.{ .value = Value{ .boolean = true } });
        } else if (std.mem.eql(u8, token_str, "false")) {
            try tokens.append(.{ .value = Value{ .boolean = false } });
        }
        // 6. Literales Numéricos (Enteros y Flotantes con signo opcional)
        else if (parseNumber(token_str)) |num_val| {
            try tokens.append(.{ .value = num_val });
        }
        // 7. Identificadores de Variables
        else if (isValidIdentifier(token_str)) {
            try tokens.append(.{ .value = Value{ .symbol = token_str } });
        }
        // 8. Token no válido
        else {
            return EvaluatorError.InvalidToken;
        }
    }

    return tokens;
}

fn parseNumber(str: []const u8) ?Value {
    if (str.len == 0) return null;

    if (std.mem.indexOfScalar(u8, str, '.') != null) {
        if (std.fmt.parseFloat(f64, str)) |f| {
            return Value{ .float = f };
        } else |_| {
            return null;
        }
    }

    if (std.fmt.parseInt(i64, str, 10)) |i| {
        return Value{ .int = i };
    } else |_| {
        return null;
    }
}

fn isValidIdentifier(str: []const u8) bool {
    if (str.len == 0) return false;
    const first = str[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') return false;

    for (str[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
    }
    return true;
}

/// Evalúa una secuencia de tokens sobre la pila y el entorno pasados explícitamente.
/// Demuestra mutabilidad y paso por referencia (*Stack, *Environment) según el Requisito 3.
pub fn evaluateTokens(
    tokens: []const Token,
    stack: *Stack,
    env: *Environment,
    writer: anytype,
) EvaluatorError!void {
    for (tokens) |tok| {
        switch (tok) {
            .value => |val| {
                stack.push(val) catch return EvaluatorError.OutOfMemory;
            },
            .operator => |op| {
                switch (op) {
                    .Add, .Sub, .Mul, .Div => {
                        const b = try popAndResolve(stack, env);
                        const a = try popAndResolve(stack, env);
                        const res = try executeArithmetic(op, a, b);
                        stack.push(res) catch return EvaluatorError.OutOfMemory;
                    },
                    .Eq, .Neq, .Lt, .Gt => {
                        const b = try popAndResolve(stack, env);
                        const a = try popAndResolve(stack, env);
                        const res = try executeComparison(op, a, b);
                        stack.push(res) catch return EvaluatorError.OutOfMemory;
                    },
                    .Assign => {
                        try executeAssignment(stack, env);
                    },
                    .And, .Or, .Not => {
                        try executeLogical(op, stack, env);
                    },
                }
            },
            .command => |cmd| {
                switch (cmd) {
                    .Vars => {
                        env.printVars(writer) catch {};
                    },
                    .Begin => {
                        env.beginScope() catch return EvaluatorError.OutOfMemory;
                        writer.print("[Bloque local iniciado: Nivel {d}]\n", .{env.currentLevel()}) catch {};
                    },
                    .End => {
                        try env.endScope();
                        writer.print("[Bloque local finalizado: Nivel actual {d}]\n", .{env.currentLevel()}) catch {};
                    },
                    .Stack => {
                        stack.printStack(writer) catch {};
                    },
                    .Clear => {
                        stack.clear();
                        writer.print("[Pila vaciada]\n", .{}) catch {};
                    },
                    .Help => {
                        printHelp(writer) catch {};
                    },
                    .Exit => {},
                }
            },
        }
    }
}

pub fn printHelp(writer: anytype) !void {
    try writer.print(
        \\======================================================================
        \\                    AYUDA DEL EVALUADOR MINI-REPL RPN
        \\======================================================================
        \\ Operaciones Aritméticas (Postfijas):
        \\   +           Suma: a b +
        \\   -           Resta: a b -
        \\   *           Multiplicación: a b *
        \\   /           División (con detección de división por cero): a b /
        \\
        \\ Comparaciones y Lógica:
        \\   ==          Igualdad de tipos homogéneos: a b ==
        \\   !=          Desigualdad: a b !=
        \\   <           Menor que (números): a b <
        \\   >           Mayor que (números): a b >
        \\   and, or     Operadores lógicos binarios: bool bool and
        \\   not         Negación lógica unaria: bool not
        \\
        \\ Variables y Asignación:
        \\   <var> <val> =    Asigna una variable en notación postfija.
        \\                    Ejemplo: x 10 =
        \\                    Ejemplo: y x 5 + 2 * =
        \\   vars             Muestra las variables activas en memoria.
        \\
        \\ Alcance Local y Sombreado (Scoping & Shadowing):
        \\   begin            Abre un nuevo entorno local temporal.
        \\   end              Cierra el entorno local y descarta variables locales.
        \\
        \\ Comandos de Utilidad:
        \\   stack            Muestra todos los elementos en la pila.
        \\   clear            Limpia la pila de evaluación.
        \\   help             Muestra este mensaje de ayuda.
        \\   exit / quit      Termina la sesión del REPL.
        \\======================================================================
        \\
    , .{});
}
