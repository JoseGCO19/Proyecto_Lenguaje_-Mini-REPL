const std = @import("std");

/// Enumeración de los operadores soportados por el evaluador RPN.
/// Representa tanto operadores aritméticos como relacionales y lógicos.
pub const Operator = enum {
    Add, // '+'
    Sub, // '-'
    Mul, // '*'
    Div, // '/'
    Eq, // '=='
    Neq, // '!='
    Lt, // '<'
    Gt, // '>'
    Assign, // '='
    And, // 'and'
    Or, // 'or'
    Not, // 'not'

    /// Convierte el operador a su representación en cadena de texto legible.
    pub fn toString(self: Operator) []const u8 {
        return switch (self) {
            .Add => "+",
            .Sub => "-",
            .Mul => "*",
            .Div => "/",
            .Eq => "==",
            .Neq => "!=",
            .Lt => "<",
            .Gt => ">",
            .Assign => "=",
            .And => "and",
            .Or => "or",
            .Not => "not",
        };
    }
};

/// Enumeración de los comandos especiales del Mini-REPL.
pub const Command = enum {
    Vars, // 'vars' - Consultar tabla de símbolos activa
    Begin, // 'begin' - Iniciar un nuevo bloque de ámbito local
    End, // 'end' - Cerrar el bloque de ámbito local actual
    Stack, // 'stack' - Inspeccionar el contenido actual de la pila
    Clear, // 'clear' - Vaciar la pila de evaluación
    Help, // 'help' - Desplegar manual de ayuda
    Exit, // 'exit' o 'quit' - Salir del REPL
};

/// Tagged Union que representa los valores en el sistema de tipos del evaluador.
/// En Zig, una tagged union asocia una etiqueta enum con el valor concreto,
/// asegurando seguridad de tipos en tiempo de compilación y discriminación en tiempo de ejecución.
pub const Value = union(enum) {
    int: i64,
    float: f64,
    boolean: bool,
    symbol: []const u8, // Identificador de variable (por ejemplo 'x')

    /// Imprime el valor formateado hacia cualquier escritor (writer) compatible con Zig.
    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .int => |v| try writer.print("{d}", .{v}),
            .float => |v| {
                if (@floor(v) == v and !std.math.isNan(v) and !std.math.isInf(v)) {
                    try writer.print("{d:.1}", .{v});
                } else {
                    try writer.print("{d}", .{v});
                }
            },
            .boolean => |v| try writer.print("{s}", .{if (v) "true" else "false"}),
            .symbol => |s| try writer.print("{s}", .{s}),
        }
    }

    /// Retorna una cadena con el nombre amigable del tipo de dato.
    pub fn typeName(self: Value) []const u8 {
        return switch (self) {
            .int => "Int",
            .float => "Float",
            .boolean => "Bool",
            .symbol => "Identificador",
        };
    }

    /// Determina si el valor actual es de tipo numérico (Int o Float).
    pub fn isNumber(self: Value) bool {
        return self == .int or self == .float;
    }

    /// Convierte el valor numérico a f64 para cálculos mixtos.
    /// Asume que isNumber() es verdadero.
    pub fn asFloat(self: Value) f64 {
        return switch (self) {
            .int => |v| @as(f64, @floatFromInt(v)),
            .float => |v| v,
            else => unreachable,
        };
    }
};

/// Tagged Union para los Tokens producidos por el analizador léxico (lexer/tokenizer).
pub const Token = union(enum) {
    value: Value,
    operator: Operator,
    command: Command,
};

/// Conjunto de errores idiomáticos de Zig para el evaluador RPN.
/// Permite un manejo estricto y seguro sin recurrir a excepciones no verificadas o panics.
pub const EvaluatorError = error{
    StackUnderflow, // No hay suficientes elementos en la pila para la operación
    DivisionByZero, // Intento de división entre cero (entero o flotante)
    TypeMismatch, // Incompatibilidad de tipos en una operación
    UndefinedVariable, // Se intentó evaluar una variable no declarada en el entorno
    InvalidAssignmentTarget, // El operando izquierdo del '=' no es un identificador válido
    InvalidToken, // Token léxico no reconocido
    ScopeUnderflow, // Intento de ejecutar 'end' sin un 'begin' previo
    OutOfMemory, // Fallo de asignación de memoria
};
