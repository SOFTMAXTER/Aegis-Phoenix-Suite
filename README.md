# Aegis Phoenix Suite v2.0 by SOFTMAXTER

<p align="center">
  <img width="240" height="240" alt="unnamed" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell disenado para simplificar la administracion, optimizacion y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y otras herramientas del sistema en una interfaz de menus modular, interactiva y facil de usar.

Fue creado para administradores de TI, tecnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Caracteristicas Principales

* **Interfaz Modular Guiada por Menus**: Todas las funciones estan organizadas en categorias y submenus claros para una navegacion intuitiva.
* **Autoelevacion de Privilegios**: El lanzador (`Run.bat`) comprueba si se esta ejecutando como Administrador y, de no ser asi, intenta reiniciarse con los permisos necesarios.
* **Logica de Verificacion Inteligente**: Antes de aplicar un cambio, el script comprueba el estado actual del sistema para evitar acciones redundantes y proporcionar un feedback preciso.
* **Deteccion Dinamica de Bloatware**: Escanea el sistema en tiempo real para encontrar aplicaciones de Microsoft no esenciales y presenta una lista segura y personalizada para su eliminacion.
* **Modulo de Restauracion**: Permite revertir de forma segura y selectiva la mayoria de los cambios aplicados por la suite.
* **Gestion Interactiva**: Ofrece control total para gestionar tareas programadas y actualizaciones de software.

---

## Requisitos

* Sistema Operativo Windows 10 (v1909+) o Windows 11.
* Privilegios de Administrador para ejecutar el script.

---

## Modo de Uso

1.  Descarga el repositorio como un archivo `.zip` y extraelo.
2.  **IMPORTANTE:** Renombra el archivo de script dentro de la carpeta `Script` a `AegisPhoenixSuite.ps1`.
3.  Asegurate de que la estructura de carpetas sea la siguiente:
    ```
    TuCarpetaPrincipal/
    │
    ├── Run.bat
    │
    └── Script/
        │
        └── AegisPhoenixSuite.ps1
    ```
4.  Haz doble clic en **`Run.bat`**. El script validara los permisos y se iniciara.
5.  Sigue las instrucciones en pantalla, seleccionando las opciones de los menus.

---

## Explicacion Detallada de los Menus

### Menu Principal

Al iniciar, se presentan las categorias principales de la suite.

* **1. Crear Punto de Restauracion**: Utiliza el cmdlet `Checkpoint-Computer` para crear un punto de restauracion del sistema.
* **2. Modulo de Optimizacion y Limpieza**: Accede al submenú con herramientas para mejorar el rendimiento y liberar espacio en disco.
* **3. Modulo de Mantenimiento y Reparacion**: Contiene utilidades para diagnosticar y reparar problemas del sistema operativo.
* **4. Herramientas Avanzadas**: Abre un menu que agrupa todos los modulos de nivel experto.
* **5. Modulo de Restauracion**: Permite revertir los cambios aplicados por la suite.

### 2. Modulo de Optimizacion y Limpieza

* `1. Desactivar Servicios Innecesarios (Estandar)`: Deshabilita una lista curada de servicios no criticos.
* `2. Desactivar Servicios Opcionales (Avanzado)`: Permite desactivar servicios especificos como el de Escritorio Remoto.
* `3. Modulo de Limpieza Profunda`: Abre un submenú con tres niveles de limpieza (Estandar, Profunda y Avanzada).
* `4. Eliminar Apps Preinstaladas (Dinamico)`: Escanea, filtra y presenta un menu interactivo para eliminar bloatware de forma segura.

### 3. Modulo de Mantenimiento y Reparacion

* `1. Verificar y Reparar Archivos del Sistema`: Ejecuta `sfc /scannow` y `DISM` de forma condicional para reparar la integridad del sistema.
* `2. Limpiar Caches de Sistema`: Ejecuta `ipconfig /flushdns` y `wsreset.exe`.
* `3. Optimizar Unidades`: Ejecuta `Optimize-Volume -DriveLetter C`.
* `4. Generar Reporte de Salud del Sistema`: Utiliza `powercfg /energy` para generar un informe HTML.

### 4. Herramientas Avanzadas

Este menu da acceso a todos los modulos de nivel experto.

#### → L. Gestion de Logs y Tareas Programadas
* `1. Limpiar Registros de Eventos`: Ejecuta `Clear-EventLog`.
* `2. Gestionar Tareas Programadas de Terceros`: Abre un menu interactivo que lista las tareas de terceros, mostrando su estado (Habilitada/Deshabilitada). Permite seleccionar y cambiar el estado de multiples tareas a la vez.

#### → W. Gestion de Software (Winget)
* `1. Buscar y aplicar actualizaciones de software (Interactivo)`: **¡Mejorado!** Ejecuta `winget upgrade`, analiza la salida y presenta una lista interactiva de las actualizaciones encontradas, permitiendo al usuario seleccionar cuales instalar.
* `2. Instalar software en masa`: Lee un archivo de texto y ejecuta `winget install` para cada programa.

### 5. Modulo de Restauracion
* Permite revertir de forma selectiva los cambios realizados en Servicios, Tweaks, Seguridad y Privacidad a sus valores por defecto.

---

## Como Contribuir

¡Las contribuciones son bienvenidas! Si tienes ideas para mejorar Aegis Phoenix Suite o quieres corregir un error, sigue estos pasos:

1.  Haz un **Fork** de este repositorio.
2.  Crea una nueva rama para tu funcionalidad (`git checkout -b feature/NuevaFuncionalidadAsombrosa`).
3.  Realiza tus cambios y haz **Commit** (`git commit -m 'Anade una nueva funcionalidad asombrosa'`).
4.  Haz **Push** a tu rama (`git push origin feature/NuevaFuncionalidadAsombrosa`).
5.  Abre un **Pull Request**.

---

## Descargo de Responsabilidad

Este script realiza operaciones avanzadas que modifican el sistema. El autor, **SOFTMAXTER**, no se hace responsable de la perdida de datos o danos que puedan ocurrir en tu sistema.

**Se recomienda encarecidamente crear una copia de seguridad y utilizar la funcion "Crear Punto de Restauracion" antes de aplicar cambios importantes.**
