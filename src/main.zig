const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const stack_mod = @import("stack.zig");
const env_mod = @import("env.zig");
const evaluator = @import("evaluator.zig");

const Stack = stack_mod.Stack;
const Environment = env_mod.Environment;
const EvaluatorError = types.EvaluatorError;

/// Función principal que inicializa el entorno de ejecución, la memoria y el ciclo REPL.
/// Configura la codificación UTF-8 en la consola de Windows y utiliza GeneralPurposeAllocator
/// para garantizar la liberación de memoria sin fugas (memory leaks).
pub fn main() !void {
    // En sistemas Windows, configuramos la página de códigos de la consola a UTF-8 (65001)
    // para asegurar la correcta visualización de tildes, acentos y caracteres especiales.
    if (builtin.os.tag == .windows) {
        const kernel32 = struct {
            extern "kernel32" fn SetConsoleOutputCP(wCodePageID: std.os.windows.UINT) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
            extern "kernel32" fn SetConsoleCP(wCodePageID: std.os.windows.UINT) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
        };
        _ = kernel32.SetConsoleOutputCP(65001);
        _ = kernel32.SetConsoleCP(65001);
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    // 1. Mensaje de bienvenida y cabecera
    try stdout.print(
        \\======================================================================
        \\  Proyecto Lenguajes de programación
        \\  Mini-REPL Evaluador Postfijo (RPN) en Lenguaje Zig (0.13.0)
        \\======================================================================
        \\  Escribe expresiones en notación postfija separadas por espacios.
        \\  Ejemplos rápidos:
        \\    x 10 =
        \\    x 5 + 2 *
        \\    begin / end     (ámbito local y sombreado / shadowing)
        \\    vars            (consultar variables activas en memoria)
        \\    stack           (ver contenido actual de la pila)
        \\    help            (tutorial y ayuda completa de comandos)
        \\    exit / quit     (terminar y salir del Mini-REPL)
        \\======================================================================
        \\
    , .{});

    // 2. Inicialización de las estructuras centrales del evaluador
    var stack = Stack.init(allocator);
    defer stack.deinit();

    var env = try Environment.init(allocator);
    defer env.deinit();

    var buffer: [4096]u8 = undefined;

    // 3. Ciclo interactivo del REPL (Read-Eval-Print Loop)
    while (true) {
        // Despliegue dinámico del prompt indicando el nivel de anidamiento de ámbito (scope)
        const level = env.currentLevel();
        if (level == 0) {
            try stdout.print("rpn> ", .{});
        } else {
            try stdout.print("rpn[L{d}]> ", .{level});
        }

        // Lectura de una línea de texto desde stdin
        const line = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch |err| {
            try stdout.print("\n[Error de entrada]: {}\n", .{err});
            break;
        } orelse {
            // Fin de archivo (EOF o Ctrl+D / Ctrl+Z)
            try stdout.print("\nSesión finalizada. ¡Hasta luego!\n", .{});
            break;
        };

        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) {
            continue;
        }

        // Comandos de terminación y salida explícita
        if (std.mem.eql(u8, trimmed, "exit") or std.mem.eql(u8, trimmed, "quit")) {
            try stdout.print("Saliendo del Mini-REPL. ¡Hasta luego!\n", .{});
            break;
        }

        // Procesamiento y evaluación de la línea
        processLine(allocator, trimmed, &stack, &env, stdout) catch |err| {
            try stdout.print("[Error inesperado]: {}\n", .{err});
        };
    }
}

/// Procesa una línea de comandos o expresión RPN completa.
/// Tokeniza, evalúa sobre la pila y el entorno pasados por puntero (*Stack, *Environment)
/// e imprime el resultado o el error correspondiente sin abortar la ejecución.
pub fn processLine(
    allocator: std.mem.Allocator,
    line: []const u8,
    stack: *Stack,
    env: *Environment,
    writer: anytype,
) !void {
    // 1. Tokenización léxica
    var tokens = evaluator.tokenize(allocator, line) catch |err| {
        switch (err) {
            EvaluatorError.InvalidToken => {
                try writer.print("[Error Léxico]: Se encontró un token no reconocido o sintaxis inválida en la línea.\n", .{});
            },
            else => try writer.print("[Error Léxico]: {}\n", .{err}),
        }
        return;
    };
    defer tokens.deinit();

    // 2. Evaluación de los tokens
    if (evaluator.evaluateTokens(tokens.items, stack, env, writer)) {
        // Éxito: si hay elementos en la pila, mostramos el valor en el tope
        if (stack.count() > 0) {
            const raw_top = stack.peek() catch unreachable;
            const top_val = evaluator.resolveValue(raw_top, env) catch raw_top;
            try writer.print("=> {} ({s})\n", .{ top_val, top_val.typeName() });
        }
    } else |err| {
        // Manejo idiomático de errores mediante discriminación de EvaluatorError
        switch (err) {
            EvaluatorError.StackUnderflow => {
                try writer.print("[Error de Pila]: Pila insuficiente (stack underflow). Se requieren más operandos para la operación.\n", .{});
            },
            EvaluatorError.DivisionByZero => {
                try writer.print("[Error Matemático]: División por cero detectada.\n", .{});
            },
            EvaluatorError.TypeMismatch => {
                try writer.print("[Error de Tipos]: Operación no permitida entre los tipos actuales en la pila (chequeo estricto de tipos).\n", .{});
            },
            EvaluatorError.UndefinedVariable => {
                try writer.print("[Error de Entorno]: Variable no declarada o inaccesible en el ámbito activo.\n", .{});
            },
            EvaluatorError.InvalidAssignmentTarget => {
                try writer.print("[Error de Asignación]: El objetivo a asignar debe ser un identificador válido (ej. x 10 =).\n", .{});
            },
            EvaluatorError.ScopeUnderflow => {
                try writer.print("[Error de Alcance]: 'end' sin 'begin'. No se puede cerrar el ámbito global.\n", .{});
            },
            EvaluatorError.InvalidToken => {
                try writer.print("[Error Léxico]: Token inválido.\n", .{});
            },
            EvaluatorError.OutOfMemory => {
                try writer.print("[Error de Memoria]: Memoria agotada durante la ejecución.\n", .{});
            },
        }
    }
}
