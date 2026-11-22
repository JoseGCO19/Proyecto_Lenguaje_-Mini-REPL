const std = @import("std");
const types = @import("types.zig");
const Value = types.Value;
const EvaluatorError = types.EvaluatorError;

/// Estructura que implementa la Pila de Evaluación LIFO (Last-In, First-Out) para el evaluador RPN.
/// En Zig, los datos y métodos se agrupan en structs sin herencia, usando composición explícita.
pub const Stack = struct {
    items: std.ArrayList(Value),
    allocator: std.mem.Allocator,

    /// Inicializa una nueva instancia de la pila con un asignador de memoria explícito.
    /// Parámetros:
    ///   - allocator: Asignador de memoria de Zig.
    pub fn init(allocator: std.mem.Allocator) Stack {
        return Stack{
            .items = std.ArrayList(Value).init(allocator),
            .allocator = allocator,
        };
    }

    /// Libera toda la memoria dinámica reservada por los elementos de la pila.
    /// Parámetros:
    ///   - self: Puntero mutable a la pila (*Stack). Demuestra el paso por referencia mutable en Zig.
    pub fn deinit(self: *Stack) void {
        for (self.items.items) |val| {
            if (val == .symbol) {
                self.allocator.free(val.symbol);
            }
        }
        self.items.deinit();
    }

    /// Inserta (apila) un nuevo valor en el tope de la pila.
    /// Si el valor es un identificador de símbolo, duplica la cadena usando el asignador propio de la pila.
    /// Parámetros:
    ///   - self: Puntero mutable a la pila (*Stack).
    ///   - val: Valor a insertar pasado por copia/valor (Value).
    pub fn push(self: *Stack, val: Value) !void {
        const stored_val = switch (val) {
            .symbol => |s| Value{ .symbol = try self.allocator.dupe(u8, s) },
            else => val,
        };
        try self.items.append(stored_val);
    }

    /// Extrae (desapila) y retorna el valor ubicado en el tope de la pila.
    /// Nota: si el valor retornado es un símbolo, el receptor adquiere propiedad sobre la cadena.
    /// Parámetros:
    ///   - self: Puntero mutable a la pila (*Stack).
    pub fn pop(self: *Stack) EvaluatorError!Value {
        if (self.items.items.len == 0) {
            return EvaluatorError.StackUnderflow;
        }
        return self.items.pop();
    }

    /// Consulta el valor en el tope de la pila sin desapilarlo ni transferir propiedad.
    /// Parámetros:
    ///   - self: Puntero inmutable (*const Stack), demostrando el principio de mínimo privilegio.
    pub fn peek(self: *const Stack) EvaluatorError!Value {
        if (self.items.items.len == 0) {
            return EvaluatorError.StackUnderflow;
        }
        return self.items.items[self.items.items.len - 1];
    }

    /// Retorna la cantidad actual de elementos en la pila.
    /// Parámetros:
    ///   - self: Puntero de sólo lectura (*const Stack).
    pub fn count(self: *const Stack) usize {
        return self.items.items.len;
    }

    /// Vacía todos los elementos de la pila, liberando las cadenas dinámicas de símbolos.
    /// Parámetros:
    ///   - self: Puntero mutable (*Stack).
    pub fn clear(self: *Stack) void {
        for (self.items.items) |val| {
            if (val == .symbol) {
                self.allocator.free(val.symbol);
            }
        }
        self.items.clearRetainingCapacity();
    }

    /// Imprime el estado completo de la pila de forma amigable (de la base al tope).
    /// Parámetros:
    ///   - self: Puntero inmutable (*const Stack).
    ///   - writer: Interfaz de escritura genérica (anytype) de Zig.
    pub fn printStack(self: *const Stack, writer: anytype) !void {
        if (self.items.items.len == 0) {
            try writer.print("<pila vacía>\n", .{});
            return;
        }
        try writer.print("[Pila ({d} elementos, base -> tope)]:\n", .{self.items.items.len});
        for (self.items.items, 0..) |item, idx| {
            try writer.print("  [{d}]: {} ({s})\n", .{ idx, item, item.typeName() });
        }
    }
};
