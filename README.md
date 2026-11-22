# Proyecto Lenguajes de programación
## Componente Práctico: Mini-REPL Evaluador Postfijo (RPN)
**Lenguaje de Programación:** **Zig** (Versión 0.13.0)

---

## 1. Preguntas Frecuentes sobre la Versión de Zig

### 1.1. ¿Por qué se utilizó Zig 0.13.0 y no versiones superiores como 0.14+ o 0.17?
* **Estabilidad y Consistencia Oficial:** Zig 0.13.0 es la versión estable y madura oficial del lenguaje con amplia adopción y documentación validada.
* **Versiones de Desarrollo (*Nightly / Unstable*):** En el repositorio oficial de Zig, cualquier versión por encima de la última rama estable (como las compilaciones etiquetadas 0.14-dev hasta 0.17/0.18-dev) corresponde a versiones en desarrollo activo (*unreleased / nightly builds*). Dado que Zig se encuentra en etapa pre-1.0.0, estas versiones experimentales cambian frecuentemente y de forma abrupta las APIs internas de la biblioteca estándar (`std.Build`, `std.io`, `std.ArrayList`, manejo de memoria y asignadores).
* **Ausencia de dependencias rotas:** Utilizar Zig 0.13.0 garantiza que el proyecto pueda compilarse hoy y en el futuro sin que una actualización diaria (*rolling release*) rompa las llamadas al sistema o el archivo de construcción `build.zig`.

### 1.2. ¿Habría algún problema si alguien con una versión más actualizada compila el programa?
* Si otra persona utiliza una versión en desarrollo (por ejemplo Zig 0.14 o superior), es posible que reciba errores de compilación exclusivamente debido a los cambios continuos que el equipo de desarrollo de Zig introduce en la sintaxis de `build.zig` (por ejemplo, cambios entre `b.path(...)` y llamadas a manejadores de rutas) o cambios en la signatura de lectores de entrada/salida (`std.io`).
* La sintaxis del evaluador y los algoritmos RPN son limpios y canónicos, pero dentro del ecosistema de Zig, **la buena práctica obligatoria en proyectos académicos y profesionales es fijar y utilizar la versión exacta con la que fue concebido el software: Zig 0.13.0.**

---

## 2. Requisitos Previos e Instalación de Zig

El compilador oficial de **Zig 0.13.0** se encuentra instalado en la máquina en:
```
C:\Users\Admin\zig
```
La ruta se encuentra añadida a la variable de entorno `PATH` del usuario y en el perfil de PowerShell.

Para verificar que el compilador se encuentra listo:
```powershell
zig version
```
*Salida esperada:*
```
0.13.0
```

---

## 3. Instrucciones de Compilación y Ubicación del Archivo de Salida

### 3.1. Compilación del Proyecto
Para compilar el proyecto utilizando el sistema oficial de construcción de Zig:
```powershell
zig build
```

### 3.2. ¿Dónde se guarda el archivo de salida compilado?
Al ejecutar `zig build`, Zig genera una estructura de carpetas en la raíz del proyecto:
* **Carpeta de salida:** `zig-out/`
* **Ruta exacta del binario ejecutable:**
  ```
  .\zig-out\bin\rpn_evaluator.exe
  ```
* **Archivo de símbolos de depuración:**
  ```
  .\zig-out\bin\rpn_evaluator.pdb
  ```
* **Caché de compilación incremental:** `.zig-cache/` (usada internamente por Zig para recompilar únicamente los archivos modificados).

### 3.3. Ejecución del Programa
Puedes iniciar el evaluador interactivo de dos formas:

* **Opción A (Directa con el binario compilado):**
  ```powershell
  .\zig-out\bin\rpn_evaluator.exe
  ```
* **Opción B (Compilación y ejecución en un solo paso):**
  ```powershell
  zig build run
  ```

### 3.4. Ejecución de Pruebas Unitarias
El proyecto incluye pruebas automatizadas que verifican los 4 requisitos exigidos:
```powershell
zig build test
```
o directamente:
```powershell
zig test src/test_suite.zig
```

---

## 4. Cómo Salir y Terminar el Mini-REPL

Para finalizar la sesión del evaluador en cualquier momento de manera controlada y limpia (liberando toda la memoria sin fugas):

1. **Por comando de texto:**
   Escribe en el prompt:
   ```text
   exit
   ```
   o bien:
   ```text
   quit
   ```
   El programa responderá con el mensaje `Saliendo del Mini-REPL. ¡Hasta luego!` y regresará a la consola del sistema operativo.

2. **Por atajo de teclado:**
   * En **Windows**: Presiona `Ctrl + Z` seguido de la tecla `Enter` (señal de fin de archivo `EOF`), o presiona `Ctrl + C` para interrumpir.
   * En **Linux / macOS**: Presiona `Ctrl + D` (`EOF`) o `Ctrl + C`.

---

## 5. Tutorial Exhaustivo de Comandos del Mini-REPL

El evaluador opera bajo la **Notación Polaca Inversa (RPN)**. A diferencia de la notación infija tradicional (`a + b`), en RPN los operandos se colocan primero y los operadores se colocan después (`a b +`). Los tokens deben estar separados por uno o más espacios.

A continuación se detalla el funcionamiento de cada una de las capacidades del programa:

### 5.1. Operaciones Aritméticas Básicas (`+`, `-`, `*`, `/`)
Operan extrayendo los dos últimos valores colocados en la pila. El primer valor extraído es el operando derecho (`b`) y el segundo es el operando izquierdo (`a`).

* **Suma (`+`):** Suma `a + b`.
  ```text
  rpn> 15 27 +
  => 42 (Int)
  ```
* **Resta (`-`):** Resta `a - b`.
  ```text
  rpn> 50 20 -
  => 30 (Int)
  ```
* **Multiplicación (`*`):** Multiplica `a * b`.
  ```text
  rpn> 6 7 *
  => 42 (Int)
  ```
* **División (`/`):** Divide `a / b`.
  * Si la división entera es exacta, produce un `Int`:
    ```text
    rpn> 84 2 /
    => 42 (Int)
    ```
  * Si la división genera residuo decimal, se promociona automáticamente a `Float`:
    ```text
    rpn> 7 2 /
    => 3.5 (Float)
    ```
  * Si se opera con un número decimal, el cálculo se realiza en punto flotante:
    ```text
    rpn> 10 2.5 +
    => 12.5 (Float)
    ```
* **Expresiones Aritméticas Compuestas:**
  Para evaluar `(3 + 5) * (10 - 2) / 4`:
  ```text
  rpn> 3 5 + 10 2 - * 4 /
  => 16 (Int)
  ```

---

### 5.2. Comparaciones Lógicas y Operadores Booleanos (`==`, `!=`, `<`, `>`, `and`, `or`, `not`)
Permiten evaluar relaciones de orden y lógica formal, depositando en la pila un resultado booleano (`true` o `false`).

* **Igualdad (`==`):**
  ```text
  rpn> 10 10 ==
  => true (Bool)
  
  rpn> true false ==
  => false (Bool)
  ```
* **Desigualdad (`!=`):**
  ```text
  rpn> 10 20 !=
  => true (Bool)
  ```
* **Menor que (`<`) y Mayor que (`>`):**
  ```text
  rpn> 15 30 <
  => true (Bool)

  rpn> 50 20 >
  => true (Bool)
  ```
* **Operador Lógico `and`:** Conjunción booleana binaria.
  ```text
  rpn> true false and
  => false (Bool)
  ```
* **Operador Lógico `or`:** Disyunción booleana binaria.
  ```text
  rpn> true false or
  => true (Bool)
  ```
* **Operador Lógico `not`:** Negación booleana unaria (opera sobre el valor en el tope).
  ```text
  rpn> false not
  => true (Bool)
  ```
* **Expresión Lógica Combinada:**
  Evaluar `(5 < 10) and (20 > 15)`:
  ```text
  rpn> 5 10 < 20 15 > and
  => true (Bool)
  ```

---

### 5.3. Asignación y Manejo de Variables (`=`)
El evaluador sigue una sintaxis postfija estricta para la asignación:

```text
<identificador> <valor_o_expresión> =
```

* **Asignación de un valor directo:**
  ```text
  rpn> x 10 =
  => 10 (Int)
  ```
* **Asignación del resultado de una expresión previa:**
  Para asignar a la variable `y` el valor de `(x + 5) * 2`:
  ```text
  rpn> y x 5 + 2 * =
  => 30 (Int)
  ```
* **Uso de variables en cálculos posteriores:**
  Las variables registradas se pueden utilizar en cualquier expresión posterior por su nombre:
  ```text
  rpn> x y +
  => 40 (Int)
  ```
* **Actualización del valor de una variable:**
  ```text
  rpn> x 100 =
  => 100 (Int)
  ```

---

### 5.4. Comando `vars` (Consulta de Variables en Memoria)
Muestra en formato tabular todas las variables activas en el entorno, su valor actual, su tipo de dato (`Int`, `Float`, `Bool`), su nivel de anidamiento (`Global` o `Local`) y si están sombreando a otra variable exterior.

```text
rpn> vars
--- Tabla de Símbolos en Memoria (Ámbito actual: Global (Nivel 0)) ---
  x = 100 [Tipo: Int, Ámbito: Global L0]
  y = 30 [Tipo: Int, Ámbito: Global L0]
----------------------------------------------------------
```

---

### 5.5. Comandos de Alcance Local y Sombreado: `begin` y `end`
Permiten crear bloques de alcance léxico temporal (*block scoping*).

* **Comando `begin`:** Abre un nuevo bloque local.
  * Incrementa el nivel de ámbito.
  * El prompt cambia visualmente para reflejar el nivel activo (ej. `rpn[L1]>`).
  * Las variables creadas o actualizadas dentro del bloque quedan encapsuladas en este ámbito.
  ```text
  rpn> begin
  [Bloque local iniciado: Nivel 1]
  ```

* **Sombreado (*Shadowing*):**
  Si dentro del bloque reasignas una variable que ya existía en el entorno global (ej. `x`), el evaluador no destruye la variable global, sino que crea una instancia local que **sombrea** a la global:
  ```text
  rpn[L1]> x 99 =
  => 99 (Int)

  rpn[L1]> temporal 50 =
  => 50 (Int)

  rpn[L1]> vars
  --- Tabla de Símbolos en Memoria (Ámbito actual: Local Temporal) ---
    x = 99 [Tipo: Int, Ámbito: Local L1 (sombra a variable exterior)]
    y = 30 [Tipo: Int, Ámbito: Global L0]
    temporal = 50 [Tipo: Int, Ámbito: Local L1]
  ----------------------------------------------------------
  ```

* **Comando `end`:** Cierra el bloque local actual.
  * Destruye todas las variables declaradas dentro del bloque.
  * **Restaura el valor original** de cualquier variable global que haya sido sombreada.
  ```text
  rpn[L1]> end
  [Bloque local finalizado: Nivel actual 0]

  rpn> x
  => 100 (Int)

  rpn> temporal
  [Error de Entorno]: Variable no declarada o inaccesible en el ámbito activo.
  ```

---

### 5.6. Comandos de Utilidad: `stack`, `clear` y `help`

* **Comando `stack`:** Muestra todos los elementos presentes en la pila de evaluación, indicando el índice, el valor y el tipo desde la base hasta el tope.
  ```text
  rpn> 10 20 30
  => 30 (Int)

  rpn> stack
  [Pila (3 elementos, base -> tope)]:
    [0]: 10 (Int)
    [1]: 20 (Int)
    [2]: 30 (Int)
  ```

* **Comando `clear`:** Vacía la pila de evaluación por completo y libera su memoria dinámica.
  ```text
  rpn> clear
  [Pila vaciada]

  rpn> stack
  <pila vacía>
  ```

* **Comando `help`:** Muestra en pantalla un resumen rápido con la sintaxis de todos los operadores y comandos disponibles.
  ```text
  rpn> help
  ```

---

### 5.7. Manejo Controlado de Errores (Sin abortar el programa)
El evaluador detecta cualquier condición anómala y emite un mensaje descriptivo sin interrumpir la ejecución:

* **División por cero:**
  ```text
  rpn> 10 0 /
  [Error Matemático]: División por cero detectada.
  ```
* **Discrepancia de tipos (*Type Mismatch*):**
  ```text
  rpn> 5 true +
  [Error de Tipos]: Operación no permitida entre los tipos actuales en la pila (chequeo estricto de tipos).
  ```
* **Pila insuficiente (*Stack Underflow*):**
  ```text
  rpn> +
  [Error de Pila]: Pila insuficiente (stack underflow). Se requieren más operandos para la operación.
  ```
* **Destino de asignación inválido:**
  ```text
  rpn> 5 10 =
  [Error de Asignación]: El objetivo a asignar debe ser un identificador válido (ej. x 10 =).
  ```
* **Cierre de bloque inválido:**
  ```text
  rpn> end
  [Error de Alcance]: 'end' sin 'begin'. No se puede cerrar el ámbito global.
  ```

---

## 6. Sesión de Prueba de Ejemplo Completa

A continuación se presenta una transcripción continua de una sesión de prueba integral:

```text
======================================================================
  Proyecto Lenguajes de programación
  Mini-REPL Evaluador Postfijo (RPN) en Lenguaje Zig (0.13.0)
======================================================================
  Escribe expresiones en notación postfija separadas por espacios.
  Ejemplos rápidos:
    x 10 =
    x 5 + 2 *
    begin / end     (ámbito local y sombreado / shadowing)
    vars            (consultar variables activas en memoria)
    stack           (ver contenido actual de la pila)
    help            (tutorial y ayuda completa de comandos)
    exit / quit     (terminar y salir del Mini-REPL)
======================================================================
rpn> x 10 =
=> 10 (Int)
rpn> y x 5 + 2 * =
=> 30 (Int)
rpn> x y +
=> 40 (Int)
rpn> vars
--- Tabla de Símbolos en Memoria (Ámbito actual: Global (Nivel 0)) ---
  x = 10 [Tipo: Int, Ámbito: Global L0]
  y = 30 [Tipo: Int, Ámbito: Global L0]
----------------------------------------------------------
=> 40 (Int)
rpn> begin
[Bloque local iniciado: Nivel 1]
=> 40 (Int)
rpn[L1]> x 99 =
=> 99 (Int)
rpn[L1]> z 50 =
=> 50 (Int)
rpn[L1]> x y +
=> 129 (Int)
rpn[L1]> vars
--- Tabla de Símbolos en Memoria (Ámbito actual: Local Temporal) ---
  x = 99 [Tipo: Int, Ámbito: Local L1 (sombra a variable exterior)]
  y = 30 [Tipo: Int, Ámbito: Global L0]
  z = 50 [Tipo: Int, Ámbito: Local L1]
----------------------------------------------------------
=> 129 (Int)
rpn[L1]> end
[Bloque local finalizado: Nivel actual 0]
=> 129 (Int)
rpn> x
=> 10 (Int)
rpn> z
[Error de Entorno]: Variable no declarada o inaccesible en el ámbito activo.
rpn> 10 0 /
[Error Matemático]: División por cero detectada.
rpn> 5 true +
[Error de Tipos]: Operación no permitida entre los tipos actuales en la pila (chequeo estricto de tipos).
rpn> exit
Saliendo del Mini-REPL. ¡Hasta luego!
```

---

## 7. Casos de Prueba Listos para Ejecución

En la carpeta [casos_de_prueba/](file:///c:/Users/Admin/Downloads/UNIVERSIDAD/SEMESTRE%20VI-VIII/LENGUAJES%20DE%20PROGRAMACION%20%28CAO604%29/Proyecto/Proyecto_Lenguajes/casos_de_prueba) se encuentran los siguientes archivos con baterías de prueba preparadas:

1. `01_aritmetica_basica.rpn` (Operaciones aritméticas y tipos numéricos).
2. `02_comparaciones_y_logica.rpn` (Comparaciones booleanas y de igualdad).
3. `03_manejo_errores.rpn` (División por cero, stack underflow y type mismatch).
4. `04_variables_y_entorno.rpn` (Asignación RPN y comando `vars`).
5. `05_scoping_y_shadowing.rpn` (Bloques locales con `begin`/`end` y sombreado).

Para ejecutar todos los casos en una sola orden:
```cmd
casos_de_prueba\ejecutar_pruebas.bat
```
