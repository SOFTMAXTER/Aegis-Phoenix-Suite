# Aegis Phoenix Suite v4.8.8 by SOFTMAXTER

<p align="center">
  <img width="240" height="240" alt="Aegis Phoenix Logo" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell diseñado para simplificar la administración, optimización y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y gestores de paquetes en una interfaz híbrida que combina la eficiencia de la consola con la usabilidad de **nuevas interfaces gráficas (GUI)** modernas y fáciles de usar.

Fue creado para administradores de TI, técnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Novedades:

* **Interfaz Gráfica (GUI) Implementada**: La mayoría de los gestores (Ajustes, Servicios, Inicio, Drivers, Limpieza, Bloatware) ahora cuentan con ventanas visuales con estilo oscuro, tablas ordenables y casillas de selección.
* **Búsqueda en Tiempo Real**: Se han añadido barras de búsqueda en los módulos de gestión para filtrar instantáneamente listas largas de servicios, ajustes o tareas.
* **Optimización de Rendimiento**: Carga de menús más rápida gracias al uso de caché y renderizado optimizado (`DoubleBuffered`) para evitar parpadeos visuales.
* **Estabilidad Mejorada**: Soluciones robustas para la ejecución de herramientas externas como `cleanmgr.exe` y validaciones de seguridad adicionales en la manipulación de archivos.

## Caracteristicas Principales

* **Experiencia Visual Renovada**: Navegación por menús de consola principales que lanzan herramientas gráficas (Windows Forms) para una gestión detallada.
* **Módulo de Auto-Actualización Robusto**: Comprueba si hay una nueva versión en GitHub al iniciar, la descarga y la instala de forma segura.
* **Autoelevación de Privilegios**: El script verifica si se está ejecutando como Administrador y, de no ser así, solicita los permisos necesarios.
* **Registro Completo de Actividad**: Todas las acciones se guardan en `Logs/Registro.log` para auditoría.
* **Gestor de Ajustes Visual y Dinámico**: Nueva GUI optimizada con buscador y filtrado por categorías para aplicar tweaks de rendimiento, seguridad y privacidad.
* **Gestor de Servicios Inteligente**: Interfaces gráficas dedicadas para servicios de sistema y de terceros, con diferenciación visual de estados (colores) y protección de configuración original mediante Backups JSON.
* **Gestor de Software Resiliente (Multi-Motor)**: Integra `Winget` y `Chocolatey` para actualizaciones y descargas masivas.
* **Limpieza Profunda e Interactiva**: Nuevo panel gráfico para seleccionar qué limpiar (Temporales, Cachés, Papelera, Sistema) con cálculo de espacio en tiempo real.
* **Gestión de Inicio 100% Nativa**: GUI para administrar programas de inicio (Registro, Carpetas y Tareas) replicando los valores binarios del Administrador de Tareas.
* **Diagnóstico de Salud de Discos (S.M.A.R.T.)**: Reportes detallados del estado físico de las unidades.
* **Herramientas de Diagnóstico y Respaldo**: Diagnóstico de red, análisis inteligente de logs de eventos (con reportes HTML) y respaldo de datos de usuario (Robocopy) con validación anti-bucle.
* **Reubicación de Carpetas de Usuario**: Asistente para mover carpetas clave (Escritorio, Documentos) a otra ubicación de forma segura.

---

## Requisitos

* Sistema Operativo Windows 10 o Windows 11.
* Privilegios de Administrador para ejecutar el script.
* Conexión a Internet para la auto-actualización, gestión de software y descarga de herramientas auxiliares.

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

* **1. Crear Punto de Restauración**: Utiliza `Checkpoint-Computer` con gestión robusta del servicio VSS.
* **2. Módulo de Optimizacion y Limpieza**: Accede a las herramientas de rendimiento.
* **3. Módulo de Mantenimiento y Reparación**: Utilidades de diagnóstico y reparación del SO.
* **4. Herramientas Avanzadas**: Módulos de nivel experto (Drivers, Software, Inventario, Tweaks).
* **L. Ver Registro de Actividad (Log)**: Abre el historial de acciones.

### 2. Módulo de Optimización y Limpieza

* **1. Gestor de Servicios No Esenciales (GUI)**: Nueva interfaz gráfica con buscador y filtros por categoría. Permite deshabilitar o restaurar servicios del sistema con descripciones detalladas.
* **2. Optimizar Servicios de Terceros (GUI)**: Panel visual que detecta servicios no nativos. Crea backups automáticos en JSON y permite alternar su estado con colores indicativos.
* **3. Módulo de Limpieza Profunda (GUI)**: Interfaz gráfica que permite "Escanear" el espacio ocupado por temporales, cachés y `Windows.old`. Incluye una ejecución robusta de `CleanMgr` y limpieza de cachés de iconos reiniciando el Explorador.
* **4. Eliminar Apps Preinstaladas (GUI)**: Gestor visual de Bloatware. Clasifica apps por colores (Verde=Protegido, Naranja=Recomendado). Permite selección múltiple y limpieza de residuos en AppData.
* **5. Gestionar Programas de Inicio (GUI)**: Panel interactivo para habilitar/deshabilitar programas de arranque (Registro, Carpetas, Tareas). Muestra rutas y comandos detallados.

### 3. Módulo de Mantenimiento y Reparación

* **1. Verificar y Reparar Archivos del Sistema**: Secuencia inteligente: `DISM /ScanHealth` -> `DISM /RestoreHealth` (si es necesario) -> `sfc /scannow`.
* **2. Limpiar Caches de Sistema**: Limpieza de DNS, Tienda de Windows y caché de iconos.
* **3. Optimizar Unidades**: Desfragmentación (HDD) o TRIM (SSD).
* **4. Generar Reporte de Salud (Energía)**: Diagnóstico `powercfg /energy` en HTML.
* **5. Purgar Memoria RAM**: Usa `EmptyStandbyList.exe` para liberar memoria en espera.
* **6. Diagnostico y Reparacion de Red**: Submenú para Ping, DNS, Tracert, limpiar caché DNS, renovar IP y Reset completo de pila de red.
* **7. Reconstruir Índice de Búsqueda**: Purgado y regeneración de la base de datos de Windows Search.

### 4. Herramientas Avanzadas

#### → Gestor de Ajustes del Sistema (GUI Optimizada)

* **Nueva Interfaz**: Ventana gráfica con buscador en tiempo real y filtrado por categorías.
* **Control Total**: Permite activar/desactivar ajustes individuales (Rendimiento, Privacidad, UI).
* **Estado Visual**: Muestra claramente si un ajuste está `[Activado]` (Verde) o `[Desactivado]` (Rojo/Salmón).
* **Seguridad**: Advierte si un ajuste requiere reiniciar el PC o el Explorador.

#### → Inventario y Reportes del Sistema

* Genera reportes detallados en `.txt`, `.html` (interactivo y moderno) o `.csv`.
* Información: Windows, CPU, RAM (Slots), GPU, Discos (S.M.A.R.T.), Red, Software instalado, Hotfixes, etc.

#### → Gestión de Drivers (GUI)

* **Interfaz Visual**: Tabla con todos los drivers de terceros instalados.
* **Backup Selectivo**: Permite marcar drivers específicos o todos para exportar.
* **Restauración Flexible**: Opción para restaurar desde una carpeta completa o seleccionando archivos `.inf` específicos.

#### → Gestión de Software (Multi-Motor)

* **Selector de Motor**: Cambia entre `Winget` y `Chocolatey`.
* **Actualizaciones**: Busca actualizaciones y permite aplicarlas selectivamente.
* **Instalación**: Búsqueda e instalación individual o en masa (desde `.txt`).

#### → Administración de Sistema

* **Limpiar Registros de Eventos**: Borrado seguro de logs de Windows.
* **Gestionar Tareas Programadas de Terceros (GUI)**: Interfaz para habilitar/deshabilitar tareas programadas no nativas, con buscador y detalles de acciones.
* **Reubicar Carpetas de Usuario**: Asistente seguro para mover carpetas personales y actualizar el registro.

#### → Analizador Inteligente de Registros de Eventos

* **Escaneo Rápido**: Patrones de problemas en las últimas 24h.
* **Análisis Profundo**: Filtros personalizados por fecha, severidad y origen.
* **Reporte HTML**: Genera informes interactivos.
* **Base de Conocimientos**: Soluciones integradas para errores comunes (ID 153, 41, etc.).

#### → Herramienta de Respaldo de Datos de Usuario

* Interfaz para `Robocopy` con modos Simple y Espejo.
* Validación anti-bucle y cálculo de espacio previo.
* Verificación de integridad (Rápida o Hash Profundo).

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

Este script realiza operaciones avanzadas que modifican el sistema. El autor no se hace responsable de la pérdida de datos o daños que puedan ocurrir en tu sistema.

**Se recomienda encarecidamente crear una copia de seguridad y utilizar la función "Crear Punto de Restauracion" (Opción 1) antes de aplicar cambios importantes.**
