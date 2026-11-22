const std = @import("std");

/// Script de construcción de Zig (build.zig) para el proyecto Mini-REPL RPN.
/// Configura el ejecutable principal y la suite de pruebas unitarias.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Ejecutable principal
    const exe = b.addExecutable(.{
        .name = "rpn_evaluator",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // 2. Paso de ejecución: 'zig build run'
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Ejecutar la aplicación interactiva Mini-REPL RPN");
    run_step.dependOn(&run_cmd.step);

    // 3. Paso de pruebas unitarias: 'zig build test'
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test_suite.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Ejecutar todas las pruebas unitarias automatizadas");
    test_step.dependOn(&run_unit_tests.step);
}
