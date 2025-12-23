# Aegis Phoenix Suite v4.8.9 by SOFTMAXTER

<p align="center">
  <img width="250" height="250" alt="Aegis Phoenix Logo" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell diseñado para simplificar la administración, optimización y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y gestores de paquetes en una interfaz híbrida que combina la eficiencia de la consola con la usabilidad de **nuevas interfaces gráficas (GUI)** modernas y fáciles de usar.

Fue creado para administradores de TI, técnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Novedades:

* **Interfaz Gráfica (GUI) Implementada**: La mayoría de los gestores (Ajustes, Servicios, Inicio, Drivers, Limpieza, Bloatware, Tareas, Wi-Fi) ahora cuentan con ventanas visuales con estilo oscuro, tablas ordenables y casillas de selección.
* **Búsqueda en Tiempo Real**: Se han añadido barras de búsqueda en los módulos de gestión para filtrar instantáneamente listas largas de servicios, ajustes, tareas o software.
* **Optimización de Rendimiento**: Carga de menús más rápida gracias al uso de caché y renderizado optimizado (`DoubleBuffered`) para evitar parpadeos visuales.
* **Estabilidad Mejorada**: Soluciones robustas para la ejecución de herramientas externas como `cleanmgr.exe`, gestión de permisos NTFS (`Get-Acl`/`Set-Owner`) y validaciones de seguridad adicionales en la manipulación de archivos.

## Caracteristicas Principales

* **Experiencia Visual Renovada**: Navegación por menús de consola principales que lanzan herramientas gráficas (Windows Forms) para una gestión detallada.
* **Módulo de Auto-Actualización Robusto**: Comprueba si hay una nueva versión en GitHub al iniciar, la descarga y la instala de forma segura mediante un proceso externo.
* **Autoelevación de Privilegios**: El script verifica si se está ejecutando como Administrador y, de no ser así, solicita los permisos necesarios.
* **Registro Completo de Actividad**: Todas las acciones se guardan en `Logs/Registro.log` para auditoría.
* **Gestor de Ajustes Visual y Dinámico**: GUI optimizada con buscador y filtrado por categorías para aplicar tweaks de rendimiento, seguridad y privacidad. Verifica el estado real (Registro/Comando) antes de mostrarlo.
* **Gestor de Servicios Inteligente**: Interfaces gráficas dedicadas para servicios de sistema y de terceros, con diferenciación visual de estados (colores) y protección de configuración original mediante Backups JSON.
* **Gestor de Software Resiliente (Multi-Motor)**: Integra `Winget` y `Chocolatey` para actualizaciones, búsquedas e instalaciones masivas desde archivos de texto.
* **Limpieza Profunda e Interactiva**: Panel gráfico para seleccionar qué limpiar (Temporales, Cachés, Papelera, Sistema). Incluye opción para cerrar navegadores automáticamente y cálculo de espacio en tiempo real.
* **Gestión de Inicio 100% Nativa**: GUI para administrar programas de inicio (Registro, Carpetas y Tareas) replicando los valores binarios del Administrador de Tareas.
* **Diagnóstico de Salud de Discos (S.M.A.R.T.)**: Reportes detallados del estado físico de las unidades integrados en el inventario.
* **Herramientas de Diagnóstico y Respaldo**: Diagnóstico de red completo, análisis inteligente de logs de eventos (con reportes HTML y monitoreo en tiempo real) y respaldo de datos de usuario (`Robocopy`).
* **Reubicación de Carpetas de Usuario**: Asistente para mover carpetas clave (Escritorio, Documentos, etc.) a otra ubicación de forma segura, actualizando el registro y atributos.

---

## Requisitos

* Sistema Operativo Windows 10 o Windows 11.
* Privilegios de Administrador para ejecutar el script.
* Conexión a Internet para la auto-actualización, gestión de software y descarga de herramientas auxiliares (`EmptyStandbyList.exe`, `Chocolatey`).

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
4.  Navega por los menús de consola y abre las nuevas herramientas gráficas según necesites.

---

## Explicación Detallada de los Módulos

### Menú Principal

Al iniciar, se presentan las categorías principales de la suite.

* **1. Crear Punto de Restauración**: Utiliza `Checkpoint-Computer` con gestión robusta del servicio VSS (lo activa temporalmente si es necesario).
* **2. Módulo de Optimizacion y Limpieza**: Accede a las herramientas de rendimiento y debloat.
* **3. Módulo de Mantenimiento y Reparación**: Utilidades de diagnóstico y reparación del SO.
* **4. Herramientas Avanzadas**: Módulos de nivel experto (Drivers, Software, Inventario, Tweaks, Admin).
* **L. Ver Registro de Actividad (Log)**: Abre el historial de acciones en el Bloc de notas.

### 2. Módulo de Optimización y Limpieza

* **1. Gestor de Servicios No Esenciales (GUI)**: Interfaz gráfica con buscador y filtros por categoría. Permite deshabilitar o restaurar servicios del sistema con descripciones detalladas.
* **2. Optimizar Servicios de Terceros (GUI)**: Panel visual que detecta servicios no nativos (Apps). Crea backups automáticos en JSON y permite alternar su estado.
* **3. Módulo de Limpieza Profunda (GUI)**: Interfaz gráfica que permite "Escanear" el espacio ocupado. Incluye limpieza de Temporales, Cachés (reinicio de Explorer), Papelera y Limpieza Profunda (DISM/CleanMgr/Windows.old).
* **4. Eliminar Apps Preinstaladas (GUI)**: Gestor visual de Bloatware. Clasifica apps por colores (Verde=Protegido, Naranja=Recomendado). Permite selección múltiple y limpieza de residuos en AppData.
* **5. Gestionar Programas de Inicio (GUI)**: Panel interactivo para habilitar/deshabilitar programas de arranque (Registro, Carpetas, Tareas). Muestra rutas y comandos detallados.

### 3. Módulo de Mantenimiento y Reparación

* **1. Verificar y Reparar Archivos del Sistema**: Secuencia inteligente: `DISM /ScanHealth` -> `DISM /RestoreHealth` (solo si hay corrupción) -> `sfc /scannow` -> Opción de `CHKDSK` al reiniciar.
* **2. Limpiar Caches de Sistema**: Limpieza de DNS, Reset de Tienda de Windows (`wsreset`) y purgado de caché de iconos/miniaturas.
* **3. Optimizar Unidades**: Detecta el tipo de disco y aplica Desfragmentación (HDD) o TRIM (SSD).
* **4. Generar Reporte de Salud (Energía)**: Diagnóstico `powercfg /energy` con salida en HTML.
* **5. Purgar Memoria RAM**: Descarga y usa `EmptyStandbyList.exe` para liberar memoria en espera (Standby List).
* **6. Diagnostico y Reparacion de Red (GUI)**: Panel con herramientas de lectura (IP, Ping, Trace) y reparación (Flush DNS, Renew IP, Reset Winsock/TCP-IP).
* **7. Reconstruir Índice de Búsqueda**: Purgado y regeneración de la base de datos de Windows Search (.edb) para solucionar problemas de búsqueda.

### 4. Herramientas Avanzadas

#### → Gestor de Ajustes del Sistema (GUI Optimizada)

* **Nueva Interfaz**: Ventana gráfica con buscador en tiempo real y filtrado por categorías.
* **Control Total**: Permite activar/desactivar ajustes individuales (Rendimiento, Privacidad, UI, Seguridad).
* **Verificación Real**: Comprueba valores de registro o ejecuta comandos de verificación para mostrar el estado actual (`Activado`/`Desactivado`).

#### → Inventario y Reportes del Sistema

* Genera reportes exhaustivos en `.txt`, `.html` (interactivo, moderno y responsivo) o `.csv` (múltiples archivos).
* Información: Windows (Build detallada), CPU, RAM (Slots/Velocidad), GPU, Discos (S.M.A.R.T.), Red, Software instalado, Hotfixes, Usuarios, Puertos abiertos, etc.

#### → Gestión de Drivers (GUI)

* **Interfaz Visual**: Tabla con todos los drivers de terceros instalados (OEM).
* **Backup Selectivo**: Permite marcar drivers específicos o todos para exportar mediante `pnputil`.
* **Restauración Flexible**: Opción para restaurar desde una carpeta completa o seleccionando archivos `.inf` específicos.

#### → Gestión de Software (Multi-Motor)

* **Selector de Motor**: Cambia dinámicamente entre `Winget` y `Chocolatey`.
* **Actualizaciones**: Busca actualizaciones disponibles y permite aplicarlas selectivamente mediante una interfaz de consola interactiva.
* **Instalación**: Búsqueda e instalación individual o en masa (desde un archivo `.txt`).

#### → Administración de Sistema

* **Limpiar Registros de Eventos**: Borrado seguro de logs de Windows (App, System, Security, Setup).
* **Gestionar Tareas Programadas de Terceros (GUI)**: Interfaz para habilitar, deshabilitar o **eliminar** tareas programadas no nativas.
* **Reubicar Carpetas de Usuario**: Asistente seguro para mover carpetas personales (Documentos, Escritorio, etc.) a otra partición, actualizando el registro y atributos de sistema.
* **Gestor de Claves Wi-Fi (GUI)**: Visualiza redes guardadas, desencripta contraseñas, exporta perfiles (XML), restaura y permite eliminar redes antiguas.

#### → Analizador Inteligente de Registros de Eventos

* **Escaneo Rápido**: Detecta patrones de problemas (Discos, Drivers, Apps) en las últimas 24h.
* **Análisis Profundo**: Filtros personalizados por fecha, severidad y origen.
* **Reporte HTML**: Genera informes interactivos con estadísticas y secciones colapsables.
* **Base de Conocimientos**: Muestra soluciones integradas para errores comunes detectados.
* **Monitoreo en Tiempo Real**: Observa eventos en vivo mientras ocurren.

#### → Herramienta de Respaldo de Datos de Usuario

* Interfaz para `Robocopy` con modos:
    * **Copia**: Respaldo incremental estándar.
    * **Espejo**: Sincronización exacta (borra en destino lo que no está en origen).
    * **Mover**: Cortar y Pegar (borra en origen tras copiar).
* **Seguridad**: Validación anti-bucle y cálculo previo de espacio en disco.
* **Verificación**: Opcional Rápida (`/L`) o Profunda (Comparación de Hash SHA256).

---

## Autor y Colaboradores

* **Autor Principal**: SOFTMAXTER
* **Análisis y refinamiento de código**: Realizado en colaboración con **Gemini**, para garantizar calidad, seguridad, optimización de algoritmos y transición a interfaces gráficas.

---

## Cómo Contribuir

¡Las contribuciones son bienvenidas!

1.  Haz un **Fork** de este repositorio.
2.  Crea una nueva rama (`git checkout -b feature/NuevaFuncionalidad`).
3.  Realiza tus cambios y haz **Commit**.
4.  Haz **Push** a tu rama.
5.  Abre un **Pull Request**.

---

## Descargo de Responsabilidad

Este script realiza operaciones avanzadas que modifican el sistema (Registro, Servicios, Archivos de Sistema). El autor no se hace responsable de la pérdida de datos o daños que puedan ocurrir en tu sistema.

**Se recomienda encarecidamente crear una copia de seguridad y utilizar la función "Crear Punto de Restauracion" (Opción 1) antes de aplicar cambios importantes.**
