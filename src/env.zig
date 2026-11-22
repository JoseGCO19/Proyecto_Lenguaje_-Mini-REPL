const std = @import("std");
const types = @import("types.zig");
const Value = types.Value;
const EvaluatorError = types.EvaluatorError;

/// Representa un ámbito (scope) individual en la jerarquía léxica de variables.
/// Contiene una tabla hash que mapea nombres de variables a sus valores asociados.
pub const Scope = struct {
    bindings: std.StringHashMap(Value),
    allocator: std.mem.Allocator,

    /// Inicializa un nuevo ámbito vacío.
    /// Parámetros:
    ///   - allocator: Asignador de memoria para las claves y entradas del mapa.
    pub fn init(allocator: std.mem.Allocator) Scope {
        return Scope{
            .bindings = std.StringHashMap(Value).init(allocator),
            .allocator = allocator,
        };
    }

    /// Libera toda la memoria de los nombres de variables almacenados en este ámbito.
    /// Parámetros:
    ///   - self: Puntero mutable al ámbito (*Scope).
    pub fn deinit(self: *Scope) void {
        var iter = self.bindings.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.bindings.deinit();
    }

    /// Asigna o actualiza una variable dentro de este ámbito específico.
    /// Parámetros:
    ///   - self: Puntero mutable al ámbito (*Scope).
    ///   - name: Nombre del identificador a registrar.
    ///   - val: Valor concreto asociado a la variable (Int, Float o Bool).
    pub fn put(self: *Scope, name: []const u8, val: Value) !void {
        if (self.bindings.getEntry(name)) |entry| {
            // Ya existía en este ámbito: actualizamos el valor directo
            entry.value_ptr.* = val;
        } else {
            // Nuevo identificador en este ámbito: duplicamos el nombre
            const name_copy = try self.allocator.dupe(u8, name);
            try self.bindings.put(name_copy, val);
        }
    }

    /// Busca una variable únicamente dentro de este ámbito.
    /// Parámetros:
    ///   - self: Puntero inmutable (*const Scope).
    ///   - name: Nombre del identificador.
    pub fn get(self: *const Scope, name: []const u8) ?Value {
        return self.bindings.get(name);
    }
};

/// Estructura que gestiona la pila de entornos / ámbitos (Environment Stack).
/// Implementa reglas de alcance (scoping) y sombreado (shadowing) de acuerdo al estándar
/// de lenguajes de programación estructurados en bloques (Lexical / Block Scoping).
pub const Environment = struct {
    scopes: std.ArrayList(Scope),
    allocator: std.mem.Allocator,

    /// Inicializa el entorno global de variables con un primer ámbito base (nivel 0).
    /// Parámetros:
    ///   - allocator: Asignador de memoria para la pila de ámbitos.
    pub fn init(allocator: std.mem.Allocator) !Environment {
        var scopes_list = std.ArrayList(Scope).init(allocator);
        const global_scope = Scope.init(allocator);
        try scopes_list.append(global_scope);

        return Environment{
            .scopes = scopes_list,
            .allocator = allocator,
        };
    }

    /// Libera recursivamente todos los ámbitos abiertos y sus variables.
    /// Demuestra el paso de parámetros por puntero mutable (*Environment).
    pub fn deinit(self: *Environment) void {
        for (self.scopes.items) |*scope| {
            scope.deinit();
        }
        self.scopes.deinit();
    }

    /// Abre un nuevo bloque de ámbito local temporal (comando 'begin').
    /// Las variables declaradas a partir de aquí residirán en este nuevo ámbito.
    pub fn beginScope(self: *Environment) !void {
        const new_scope = Scope.init(self.allocator);
        try self.scopes.append(new_scope);
    }

    /// Cierra el bloque de ámbito local actual (comando 'end'), destruyendo sus variables
    /// y restaurando el estado y visibilidad de las variables exteriores / globales.
    /// Retorna EvaluatorError.ScopeUnderflow si se intenta cerrar el ámbito global (nivel 0).
    pub fn endScope(self: *Environment) EvaluatorError!void {
        if (self.scopes.items.len <= 1) {
            return EvaluatorError.ScopeUnderflow;
        }
        var top_scope = self.scopes.pop();
        top_scope.deinit();
    }

    /// Retorna el nivel de anidamiento actual (0 = global, 1 = local nivel 1, etc.).
    pub fn currentLevel(self: *const Environment) usize {
        return self.scopes.items.len - 1;
    }

    /// Asigna o modifica una variable.
    /// Cumplimiento estricto del Requisito 4:
    /// "Las variables definidas o modificadas dentro de este ámbito local no deben
    /// sobrescribir permanentemente las variables homónimas del entorno global una vez cerrado el bloque."
    /// Por ello, cualquier asignación dentro de un ámbito local se registra en el ámbito local actual,
    /// sombreando (shadowing) cualquier variable exterior sin modificarla de forma permanente.
    pub fn set(self: *Environment, name: []const u8, val: Value) !void {
        const top_index = self.scopes.items.len - 1;
        try self.scopes.items[top_index].put(name, val);
    }

    /// Busca el valor de una variable recorriendo desde el ámbito más interno (local)
    /// hacia el más externo (global).
    /// Parámetros:
    ///   - self: Puntero inmutable (*const Environment).
    ///   - name: Nombre de la variable a consultar.
    /// Retorna el valor si existe, o null si la variable no está definida en ningún ámbito accesible.
    pub fn get(self: *const Environment, name: []const u8) ?Value {
        var idx = self.scopes.items.len;
        while (idx > 0) {
            idx -= 1;
            if (self.scopes.items[idx].get(name)) |val| {
                return val;
            }
        }
        return null;
    }

    /// Muestra la tabla de variables activas en memoria (comando 'vars').
    /// Muestra el nombre, tipo, valor actual y el ámbito en el que está declarada.
    pub fn printVars(self: *const Environment, writer: anytype) !void {
        var visible_map = std.StringHashMap(struct { val: Value, level: usize, shadowed: bool }).init(self.allocator);
        defer visible_map.deinit();

        for (self.scopes.items, 0..) |*scope, level| {
            var iter = scope.bindings.iterator();
            while (iter.next()) |entry| {
                const var_name = entry.key_ptr.*;
                const var_val = entry.value_ptr.*;
                const is_shadowing = visible_map.contains(var_name);
                try visible_map.put(var_name, .{
                    .val = var_val,
                    .level = level,
                    .shadowed = is_shadowing,
                });
            }
        }

        if (visible_map.count() == 0) {
            try writer.print("<no hay variables declaradas en memoria>\n", .{});
            return;
        }

        try writer.print("--- Tabla de Símbolos en Memoria (Ámbito actual: {s}) ---\n", .{
            if (self.currentLevel() == 0) "Global (Nivel 0)" else "Local Temporal",
        });

        var iter = visible_map.iterator();
        while (iter.next()) |entry| {
            const var_name = entry.key_ptr.*;
            const info = entry.value_ptr.*;
            const scope_desc = if (info.level == 0) "Global" else "Local";
            const shadow_note = if (info.shadowed) " (sombra a variable exterior)" else "";

            try writer.print("  {s} = {} [Tipo: {s}, Ámbito: {s} L{d}{s}]\n", .{
                var_name,
                info.val,
                info.val.typeName(),
                scope_desc,
                info.level,
                shadow_note,
            });
        }
        try writer.print("----------------------------------------------------------\n", .{});
    }
};
