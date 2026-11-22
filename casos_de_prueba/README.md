# Casos de Prueba - Proyecto Lenguajes de programación

Esta carpeta contiene scripts de prueba estructurados en formato RPN para verificar de forma exhaustiva cada uno de los cuatro requisitos exigidos en el enunciado del proyecto.

## Archivos de Prueba

| Archivo | Requisito Evaluado | Descripción |
| :--- | :--- | :--- |
| `01_aritmetica_basica.rpn` | **Requisito 1** | Suma (`+`), resta (`-`), multiplicación (`*`), división entera y decimal (`/`), operaciones combinadas y estado de la pila. |
| `02_comparaciones_y_logica.rpn` | **Requisito 1 y 2** | Operadores de comparación (`==`, `!=`, `<`, `>`) y operadores lógicos booleanos (`and`, `or`, `not`). |
| `03_manejo_errores.rpn` | **Requisito 1 y 2** | Validación de manejo de errores controlado: división por cero, subdesbordamiento de pila (*stack underflow*), discrepancia de tipos (`5 true +`), tokens inválidos y recuperación continua sin abortar. |
| `04_variables_y_entorno.rpn` | **Requisito 3** | Declaración y actualización de variables en orden postfijo (`x 10 =`, `y x 5 + 2 * =`), uso de variables en expresiones y comando `vars`. |
| `05_scoping_y_shadowing.rpn` | **Requisito 4** | Apertura y cierre de bloques locales (`begin` / `end`), sombreado (*shadowing*) de variables globales y preservación intacta del entorno exterior tras el cierre del bloque. |

## Cómo Ejecutar los Casos de Prueba

### Opción 1: Ejecución automática de todos los casos
En Windows, haz doble clic o ejecuta desde la terminal el archivo por lotes:
```cmd
ejecutar_pruebas.bat
```

### Opción 2: Ejecución individual por tubería (Piping)
Desde la raíz del proyecto, puedes redirigir la entrada estándar directamente al binario compilado:
```powershell
.\zig-out\bin\rpn_evaluator.exe < casos_de_prueba\01_aritmetica_basica.rpn
.\zig-out\bin\rpn_evaluator.exe < casos_de_prueba\02_comparaciones_y_logica.rpn
.\zig-out\bin\rpn_evaluator.exe < casos_de_prueba\03_manejo_errores.rpn
.\zig-out\bin\rpn_evaluator.exe < casos_de_prueba\04_variables_y_entorno.rpn
.\zig-out\bin\rpn_evaluator.exe < casos_de_prueba\05_scoping_y_shadowing.rpn
```
