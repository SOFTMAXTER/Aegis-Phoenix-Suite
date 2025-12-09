# Aegis Phoenix Suite v4.8 by SOFTMAXTER

<p align="center">
  <img width="240" height="240" alt="unnamed" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell diseñado para simplificar la administración, optimización y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y gestores de paquetes en una interfaz de menus modular, interactiva y fácil de usar.

Fue creado para administradores de TI, técnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Caracteristicas Principales

* **Interfaz Modular Guiada por Menús**: Todas las funciones están organizadas en categorías y submenús claros para una navegación intuitiva.
* **Compatibilidad Multi-Idioma (Agnóstico al Idioma)**: Utiliza Identificadores de Seguridad (SIDs) universales en lugar de nombres de grupos hardcodeados, garantizando un funcionamiento perfecto en sistemas en Español, Inglés, Francés, etc.
* **Módulo de Auto-Actualización Robusto**: Comprueba si hay una nueva versión en GitHub al iniciar, la descarga y la instala de forma segura, esperando explícitamente a que el proceso principal finalice.
* **Autoelevación de Privilegios**: El script verifica si se está ejecutando como Administrador y, de no ser así, solicita al usuario que lo reinicie con los permisos necesarios.
* **Registro Completo de Actividad**: Todas las acciones realizadas por el usuario se guardan en un archivo de registro (`Logs/Registro.log`) para una fácil auditoría y depuración.
* **Gestor de Ajustes Dinámico y Extensible**: Catálogos centralizados (`Ajustes.ps1`, `Servicios.ps1`, `Bloatware.ps1`) permiten que los menús se generen dinámicamente, mostrando el estado **[Activado]** o **[Desactivado]** en tiempo real.
* **Reversibilidad Individual**: Cada ajuste del sistema puede ser activado o desactivado de forma individual.
* **Gestor de Software Resiliente (Multi-Motor)**: Integra `Winget` y `Chocolatey` mediante funciones "adaptador" que abstraen la lógica de parseo, haciendo el módulo resistente a cambios en la salida de texto de las herramientas externas.
* **Instalación Automática de Dependencias**: Ofrece instalar Chocolatey si se elige como motor y no está presente.
* **Detección Dinámica de Bloatware**: Escanea el sistema en tiempo real para encontrar aplicaciones, utilizando una lista externa (`Bloatware.ps1`) para proteger apps esenciales.
* **Limpieza Profunda Post-Desinstalación**: Ofrece eliminar carpetas de datos de usuario sobrantes tras desinstalar bloatware.
* **Gestión de Inicio 100% Nativa**: Administra los programas de inicio utilizando **exactamente los mismos valores binarios** que el Administrador de Tareas de Windows.
* **Diagnóstico de Salud de Discos (S.M.A.R.T.)**: Los reportes de inventario incluyen el estado de salud de los discos físicos.
* **Módulos de Diagnóstico y Respaldo Avanzados**: Incluye herramientas profesionales para diagnóstico de red, análisis de logs de eventos y respaldo de datos con `Robocopy`.
* **Reubicación de Carpetas de Usuario**: Permite mover carpetas clave (Escritorio, Documentos, etc.) a otra ubicación, con opción de mover los archivos o solo actualizar el registro.
* **Base de Conocimientos de Errores**: Identifica errores comunes (disco, drivers, red) en los registros de eventos y ofrece soluciones integradas.
* **Monitoreo en Tiempo Real**: Observa los registros de eventos en vivo para detectar problemas mientras ocurren.

---

## Requisitos

* Sistema Operativo Windows 10 o Windows 11.
* Privilegios de Administrador para ejecutar el script.
* Conexión a Internet para la auto-actualización, la gestión de software y la instalación de Chocolatey.

---

## Modo de Uso

1.  Descarga el repositorio como un archivo `.zip` y extráelo.
2.  Asegúrate de que la estructura de carpetas sea la siguiente:
    ```
    TuCarpetaPrincipal/
    │
    ├── Run.bat
    ├── Tools/
    └── Script/
        │
        └── AegisPhoenixSuite.ps1
        └── Catalogos/
            ├── Ajustes.ps1
            ├── Servicios.ps1
            └── Bloatware.ps1
    ```
3.  Haz doble clic en **`Run.bat`**. El script validará los permisos y se iniciará.
4.  Sigue las instrucciones en pantalla, seleccionando las opciones de los menús.

---

## Explicación Detallada de los Módulos

### Menú Principal

Al iniciar, se presentan las categorías principales de la suite.

* **1. Crear Punto de Restauración**: Utiliza `Checkpoint-Computer` con gestión robusta del servicio VSS para crear un punto de restauración del sistema.
* **2. Módulo de Optimizacion y Limpieza**: Accede al submenú con herramientas para mejorar el rendimiento y liberar espacio en disco.
* **3. Módulo de Mantenimiento y Reparación**: Contiene utilidades para diagnosticar y reparar problemas del sistema operativo.
* **4. Herramientas Avanzadas**: Abre un menú que agrupa todos los módulos de nivel experto.
* **L. Ver Registro de Actividad (Log)**: Abre el archivo `Registro.log` con el historial completo de las acciones realizadas en la suite.

### 2. Módulo de Optimización y Limpieza

* `1. Gestor de Servicios No Esenciales de Windows`: Muestra una lista interactiva de servicios del sistema (definidos en `Servicios.ps1`) para optimizarlos. Utiliza una caché inteligente para evitar lag en la carga del menú.
* `2. Optimizar Servicios de Programas Instalados`: Detecta y muestra servicios instalados por aplicaciones de terceros, permitiendo activarlos, desactivarlos o restaurarlos a su estado original (guardado en un respaldo `JSON`).
* `3. Módulo de Limpieza Profunda`: Abre un submenú con opciones para eliminar archivos temporales, vaciar la papelera, limpiar cachés de sistema y una limpieza avanzada de componentes de Windows. Incorpora una lógica de suma segura para calcular el espacio liberado sin errores.
* `4. Eliminar Apps Preinstaladas`: Abre un submenú para elegir entre eliminar bloatware de Microsoft, de terceros (fabricante) o aplicaciones instaladas por el usuario.
* `5. Gestionar Programas de Inicio`: Abre una interfaz interactiva que detecta programas en el registro, carpetas de inicio y tareas programadas.

### 3. Módulo de Mantenimiento y Reparación

* **1. Verificar y Reparar Archivos del Sistema**: Ejecuta la secuencia profesional **inteligente**: `DISM /ScanHealth`, luego `DISM /RestoreHealth` **solo si es necesario**, y finalmente `sfc /scannow`.
* **2. Limpiar Caches de Sistema**: Ejecuta comandos para limpiar la cache de DNS, de la Tienda de Windows y de iconos.
* **3. Optimizar Unidades**: Ejecuta `Optimize-Volume` para realizar desfragmentación (HDD) o TRIM (SSD) de forma segura.
* **4. Generar Reporte de Salud del Sistema**: Utiliza `powercfg /energy` para generar un informe HTML que diagnostica problemas de consumo de energía.
* **5. Purgar Memoria RAM en Cache**: Descarga y utiliza `EmptyStandbyList.exe` para liberar la memoria marcada como "En espera".
* **6. Diagnostico y Reparacion de Red**: Abre un submenú completo para diagnosticar problemas de conexión y herramientas de reparación (limpiar DNS, renovar IP, restablecer pila de red).
* **7. Reconstruir Índice de Búsqueda**: Purgado y regeneración de la base de datos de Windows Search para solucionar búsquedas lentas o incompletas.

### 4. Herramientas Avanzadas

Este menú da acceso a todos los módulos de nivel experto.

#### → Gestor de Ajustes del Sistema

* Centro de control para modificaciones del sistema (Rendimiento, Seguridad, Privacidad, UI) definidas en `Ajustes.ps1`.
* **Desinstalación de OneDrive Mejorada**: Incluye una búsqueda dinámica del desinstalador en múltiples rutas del sistema para asegurar su eliminación correcta en cualquier versión de Windows.
* **Menús Dinámicos con Caché**: Muestra ajustes con su estado actual de forma instantánea gracias a un sistema de caché de estados.

#### → Inventario y Reportes del Sistema

* Genera un reporte de inventario de hardware y software en formatos `.txt`, `.html` (interactivo con navegación y buscadores) o `.csv`.
* Incluye información clave: versión detallada de Windows, CPU, RAM, GPU, discos (con salud S.M.A.R.T.), red, software, etc.

#### → Gestión de Drivers

* **Copia de Seguridad**: Exporta todos los drivers del sistema a una carpeta especificada.
* **Listar Drivers de Terceros**: Muestra los drivers no provenientes de Microsoft.
* **Restaurar Drivers**: Instala masivamente drivers (`.inf`) desde una copia de seguridad.

#### → Gestión de Software (Multi-Motor Refactorizado)

* **Selector de Motor**: Permite cambiar entre `Winget` y `Chocolatey`.
* `1. Buscar y aplicar actualizaciones`: Unifica los resultados y presenta una lista interactiva para seleccionar y aplicar actualizaciones.
* `2. Buscar e Instalar un software específico`: Llama al adaptador de búsqueda del motor activo y permite instalar.
* `3. Instalar software en masa`: Lee un archivo `.txt` con IDs de paquetes y los instala usando el motor activo.

#### → Administración de Sistema

* **Limpiar Registros de Eventos de Windows**: Permite borrar los registros principales de forma segura.
* **Gestionar Tareas Programadas de Terceros**: Presenta un gestor interactivo para listar, habilitar o deshabilitar tareas programadas no nativas.
* **Reubicar Carpetas de Usuario**: Mueve carpetas clave a una nueva ubicación base. Incluye validaciones de seguridad para evitar bucles o rutas incorrectas.

#### → Analizador Inteligente de Registros de Eventos

* **Escaneo Rápido**: Detecta automáticamente patrones de problemas comunes en las últimas 24 horas.
* **Análisis Profundo**: Permite filtrar eventos por severidad, origen, fecha y palabras clave.
* **Reporte HTML Completo**: Genera informes interactivos.
* **Buscar Soluciones**: Base de conocimientos integrada para errores comunes.

#### → Herramienta de Respaldo de Datos de Usuario (Robocopy)

* Utiliza `Robocopy` para crear respaldos de archivos personales.
* Ofrece modo **Simple** (copiar/actualizar) y modo **Sincronización** (espejo).
* Incluye validación anti-bucle para evitar errores críticos al seleccionar carpetas.
* Opciones de **verificación**: Rápida o Profunda (Hash SHA256).

---

## Autor y Colaboradores

* **Autor Principal**: SOFTMAXTER
* **Análisis y refinamiento de código**: Realizado en colaboración con **Gemini**, para garantizar calidad, seguridad y compatibilidad internacional del script.

---

## Cómo Contribuir

¡Las contribuciones son bienvenidas! Si tienes ideas para mejorar Aegis Phoenix Suite, quieres añadir una nueva funcionalidad o corregir un error, por favor sigue estos pasos:

1.  Haz un **Fork** de este repositorio.
2.  Crea una nueva rama para tu funcionalidad (`git checkout -b feature/NuevaFuncionalidadAsombrosa`).
3.  Realiza tus cambios y haz **Commit** (`git commit -m 'Añade una nueva funcionalidad asombrosa'`).
4.  Haz **Push** a tu rama (`git push origin feature/NuevaFuncionalidadAsombrosa`).
5.  Abre un **Pull Request**.

---

## Descargo de Responsabilidad

Este script realiza operaciones avanzadas que modifican el sistema. El autor no se hace responsable de la pérdida de datos o daños que puedan ocurrir en tu sistema.

**Se recomienda encarecidamente crear una copia de seguridad y utilizar la función "Crear Punto de Restauracion" antes de aplicar cambios importantes.**
