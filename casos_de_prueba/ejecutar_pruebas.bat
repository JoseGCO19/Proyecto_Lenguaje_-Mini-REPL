@echo off
chcp 65001 > nul
echo ======================================================================
echo    Proyecto Lenguajes de programación - Casos de Prueba Mini-REPL
echo ======================================================================
echo.

if not exist "..\zig-out\bin\rpn_evaluator.exe" (
    echo Compilando proyecto con zig build...
    pushd ..
    zig build
    popd
)

echo.
echo [1/5] Ejecutando Caso 1: Aritmética Básica...
echo ----------------------------------------------------------------------
..\zig-out\bin\rpn_evaluator.exe < 01_aritmetica_basica.rpn
echo.

echo [2/5] Ejecutando Caso 2: Comparaciones y Lógica...
echo ----------------------------------------------------------------------
..\zig-out\bin\rpn_evaluator.exe < 02_comparaciones_y_logica.rpn
echo.

echo [3/5] Ejecutando Caso 3: Manejo Controlado de Errores...
echo ----------------------------------------------------------------------
..\zig-out\bin\rpn_evaluator.exe < 03_manejo_errores.rpn
echo.

echo [4/5] Ejecutando Caso 4: Variables y Entorno...
echo ----------------------------------------------------------------------
..\zig-out\bin\rpn_evaluator.exe < 04_variables_y_entorno.rpn
echo.

echo [5/5] Ejecutando Caso 5: Scoping y Shadowing...
echo ----------------------------------------------------------------------
..\zig-out\bin\rpn_evaluator.exe < 05_scoping_y_shadowing.rpn
echo.

echo ======================================================================
echo    TODOS LOS CASOS DE PRUEBA FUERON EJECUTADOS CON ÉXITO
echo ======================================================================
pause
