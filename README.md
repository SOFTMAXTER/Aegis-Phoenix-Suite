# Aegis Phoenix Suite v4.9.1 by SOFTMAXTER

<p align="center">
  <img width="240" height="240" alt="Aegis Phoenix Logo" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell diseñado para simplificar la administración, optimización y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y gestores de paquetes en una interfaz híbrida que combina la eficiencia de la consola con la usabilidad de **nuevas interfaces gráficas (GUI)** modernas y fáciles de usar.

Fue creado para administradores de TI, técnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Novedades v4.9.1:

* **Limpieza Profunda de Navegadores**: Módulo dedicado para purgar cachés de Chrome, Edge, Firefox, Brave y Opera, cerrando procesos de forma segura.
* **Interfaz Gráfica (GUI) Optimizada**: Mejoras en los gestores (Ajustes, Servicios, Inicio, Drivers, Limpieza) con estilo oscuro, tablas ordenables y renderizado `DoubleBuffered` para evitar parpadeos.

## Caracteristicas Principales

* **Experiencia Visual Renovada**: Navegación por menús de consola principales que lanzan herramientas gráficas (Windows Forms) para una gestión detallada.
* **Módulo de Auto-Actualización Robusto**: Comprueba si hay una nueva versión en GitHub al iniciar, la descarga y la instala de forma segura preservando la integridad del sistema.
* **Autoelevación de Privilegios**: El script verifica si se está ejecutando como Administrador y, de no ser así, solicita los permisos necesarios.
* **Registro Completo de Actividad**: Todas las acciones se guardan en `Logs/Registro.log` para auditoría.
* **Gestor de Ajustes Visual y Dinámico**: GUI optimizada con buscador y filtrado por categorías para aplicar tweaks de rendimiento, seguridad, privacidad y UI de Windows 11.
* **Gestor de Servicios Inteligente**: Interfaces gráficas dedicadas para servicios de sistema y de terceros, con diferenciación visual de estados y protección de configuración original.
* **Gestor de Software Resiliente (Multi-Motor)**: Integra `Winget` y `Chocolatey` para actualizaciones y descargas masivas.
* **Gestión de Inicio 100% Nativa**: GUI para administrar programas de inicio (Registro, Carpetas y Tareas) replicando los valores binarios del Administrador de Tareas.
* **Inventario Profesional**: Generación de reportes detallados (TXT, HTML, CSV) incluyendo salud de discos (S.M.A.R.T.), RAM, GPU y actualizaciones.
* **Herramientas de Diagnóstico y Respaldo**: Diagnóstico de red, análisis inteligente de logs de eventos, respaldo de datos de usuario (Robocopy) y reubicación de carpetas de usuario.

---

## Requisitos

* Sistema Operativo Windows 10 o Windows 11.
* Privilegios de Administrador para ejecutar el script.
* Conexión a Internet para la auto-actualización, gestión de software y descarga de herramientas auxiliares (como `EmptyStandbyList.exe`).

---

## Modo de Uso

1.  Descarga el repositorio como un archivo `.zip` y extráelo.
2.  Asegúrate de que la estructura de carpetas sea la siguiente:
    ```
    TuCarpetaPrincipal/
    │
    ├── Run.bat
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
* **4. Herramientas Avanzadas**: Módulos de nivel experto (Tweaks, Inventario, Drivers, Software, Admin).
* **L. Ver Registro de Actividad (Log)**: Abre el historial de acciones.

### 2. Módulo de Optimización y Limpieza

* **1. Gestor de Servicios No Esenciales (GUI)**: Nueva interfaz gráfica con buscador y filtros por categoría. Permite deshabilitar o restaurar servicios del sistema con descripciones detalladas.
* **2. Optimizar Servicios de Programas Instalados (GUI)**: Panel visual que detecta servicios no nativos. Crea backups automáticos en JSON y permite alternar su estado.
* **3. Módulo de Limpieza Profunda (GUI)**: Interfaz gráfica que permite "Escanear" el espacio ocupado por temporales, cachés y `Windows.old`. Incluye ejecución robusta de `CleanMgr` y limpieza de cachés de iconos/miniaturas.
* **4. Eliminar Apps Preinstaladas (GUI)**: Gestor visual de Bloatware. Clasifica apps por colores (Verde=Protegido, Naranja=Recomendado). Permite selección múltiple y limpieza de residuos en AppData.
* **5. Gestionar Programas de Inicio (GUI)**: Panel interactivo para habilitar, deshabilitar o eliminar programas de arranque (Registro, Carpetas, Tareas). Muestra rutas y comandos detallados.

### 3. Módulo de Mantenimiento y Reparación

* **1. Verificar y Reparar Archivos del Sistema**: Secuencia inteligente: `DISM /ScanHealth` -> `DISM /RestoreHealth` (si es necesario) -> `sfc /scannow`. Incluye programación de `CHKDSK` con detección de idioma.
* **2. Limpiar Caches de Sistema**: Limpieza de DNS, ARP, Tienda de Windows, Fuentes, SSL y caché de iconos.
* **3. Optimizar Unidades**: Desfragmentación (HDD) o TRIM (SSD) con reportes en tiempo real.
* **4. Generar Reporte de Salud (Energía)**: Diagnósticos `powercfg` (Energy, Battery, Sleep) con barra de progreso visual.
* **5. Purgar Memoria RAM**: Usa `EmptyStandbyList.exe` para liberar memoria en espera (Standby List).
* **6. Diagnostico y Reparacion de Red**: Submenú con GUI y consola para Ping, DNS, Tracert, limpiar caché DNS, renovar IP y Reset completo de pila de red.
* **7. Reconstruir Índice de Búsqueda**: Purgado y regeneración de la base de datos de Windows Search.
* **8. Limpieza Profunda de Cache de Navegadores**: Detecta y limpia cachés de Chrome, Edge, Brave, Opera y Firefox, gestionando el cierre de procesos.

### 4. Herramientas Avanzadas

#### → Gestor de Ajustes del Sistema (GUI Optimizada)

* **Nueva Interfaz**: Ventana gráfica con buscador en tiempo real y filtrado por categorías.
* **Control Total**: Permite activar/desactivar ajustes individuales (Rendimiento, Privacidad, UI, Seguridad).
* **Estado Visual**: Muestra claramente si un ajuste está `[Activado]` (Verde) o `[Desactivado]` (Rojo/Salmón).

#### → Inventario y Reportes del Sistema

* Genera reportes detallados en `.txt`, `.html` (interactivo y moderno) o `.csv`.
* Información exhaustiva: Sistema, Hardware, RAM (detalles de slots), Usuarios, Seguridad, Discos (S.M.A.R.T.), Procesos Top, Updates y Software instalado.

#### → Gestión de Drivers (GUI)

* **Interfaz Visual**: Tabla con todos los drivers de terceros instalados.
* **Backup Selectivo**: Permite marcar drivers específicos o todos para exportar usando `pnputil`.
* **Gestión Total**: Opciones para Instalar (Restaurar) y Eliminar drivers del almacén (con modo forzado).

#### → Gestión de Software (Multi-Motor)

* **Selector de Motor**: Cambia dinámicamente entre `Winget` y `Chocolatey`.
* **Actualizaciones**: Busca actualizaciones disponibles y permite aplicarlas selectivamente mediante GUI.
* **Instalación**: Búsqueda e instalación individual o en masa (desde archivo `.txt`).

#### → Administración de Sistema (Submenú)

1.  **Limpiar Registros de Eventos**: Borrado seguro de logs de Windows (Application, Security, System, Setup).
2.  **Gestionar Tareas Programadas de Terceros (GUI)**: Interfaz para habilitar/deshabilitar/eliminar tareas programadas no nativas.
3.  **Reubicar Carpetas de Usuario**: Asistente seguro para mover carpetas personales (Escritorio, Documentos, etc.) a otra unidad, actualizando el registro.
4.  **Gestor de Claves Wi-Fi (GUI)**: Visualiza todas las redes guardadas, muestra contraseñas, permite exportar (Backup), importar y eliminar perfiles.

#### → Analizador Inteligente de Registros de Eventos

* **Escaneo Rápido**: Detecta patrones de problemas comunes en las últimas 24h.
* **Análisis Profundo**: Filtros personalizados por fecha, severidad y origen.
* **Reporte HTML**: Genera informes interactivos y visuales.
* **Base de Conocimientos**: Soluciones integradas para errores comunes (ID 153, 41, etc.).

#### → Herramienta de Respaldo de Datos de Usuario

* Interfaz para `Robocopy` con modos Copia, Espejo (Mirror) y Mover.
* Validación anti-bucle y cálculo de espacio previo.
* Verificación de integridad (Rápida `/L` o Hash Profundo SHA256).

---

## Autor y Colaboradores

* **Autor Principal**: SOFTMAXTER
* **Desarrollo y Refinamiento**: Colaboración con **Gemini** para optimización de código, seguridad y diseño de interfaces gráficas.

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
