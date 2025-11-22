# Aegis Phoenix Suite v4.8.0 by SOFTMAXTER

<p align="center">
  <img width="240" height="240" alt="unnamed" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell diseñado para simplificar la administración, optimización y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y gestores de paquetes en una interfaz de menus modular, interactiva y fácil de usar.

Fue creado para administradores de TI, técnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Caracteristicas Principales

* **Interfaz Modular Guiada por Menús**: Todas las funciones están organizadas en categorías y submenús claros para una navegación intuitiva.
* **Módulo de Auto-Actualización Robusto**: Comprueba si hay una nueva versión en GitHub al iniciar, la descarga y la instala de forma segura, esperando explícitamente a que el proceso principal finalice.
* **Autoelevación de Privilegios**: El script verifica si se está ejecutando como Administrador y, de no ser así, solicita al usuario que lo reinicie con los permisos necesarios.
* **Registro Completo de Actividad**: Todas las acciones realizadas por el usuario se guardan en un archivo de registro (`Logs/Registro.log`) para una fácil auditoría y depuración.
* **Gestor de Ajustes Dinámico y Extensible**: Catálogos centralizados (`Ajustes.ps1`, `Servicios.ps1`, `Bloatware.ps1`) permiten que los menús se generen dinámicamente, mostrando el estado **\[Activado]** o **\[Desactivado]** en tiempo real y facilitando la adición de nuevos elementos.
* **Reversibilidad Individual**: Cada ajuste del sistema puede ser activado o desactivado de forma individual.
* **Gestor de Software Resiliente (Multi-Motor)**: Integra `Winget` y `Chocolatey` mediante funciones "adaptador" que abstraen la lógica de parseo, haciendo el módulo resistente a cambios en la salida de texto de las herramientas externas.
* **Instalación Automática de Dependencias**: Ofrece instalar Chocolatey si se elige como motor y no está presente.
* **Detección Dinámica de Bloatware**: Escanea el sistema en tiempo real para encontrar aplicaciones de Microsoft, del fabricante y del usuario, utilizando una lista externa (`Bloatware.ps1`) para proteger apps esenciales.
* **Limpieza Profunda Post-Desinstalación**: Ofrece eliminar carpetas de datos de usuario sobrantes tras desinstalar bloatware.
* **Gestión de Inicio 100% Nativa**: Administra los programas de inicio utilizando **exactamente los mismos valores binarios** que el Administrador de Tareas de Windows, garantizando máxima compatibilidad y reversibilidad.
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
    │
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

* `1. Gestor de Servicios No Esenciales de Windows`: Muestra una lista interactiva de servicios del sistema (definidos en `Servicios.ps1`) para optimizarlos. Permite activarlos, desactivarlos o restaurarlos a su configuración por defecto individualmente.
* `2. Optimizar Servicios de Programas Instalados`: Detecta y muestra servicios instalados por aplicaciones de terceros, permitiendo activarlos, desactivarlos o restaurarlos a su estado original (guardado en un respaldo `JSON`) para reducir el consumo de recursos.
* `3. Módulo de Limpieza Profunda`: Abre un submenú con opciones para eliminar archivos temporales, vaciar la papelera, limpiar cachés de sistema (miniaturas, DirectX) y una limpieza avanzada de componentes de Windows. Utiliza `DISM /StartComponentCleanup /ResetBase` para una limpieza profunda y real de Windows Update y `Windows.old`.
* `4. Eliminar Apps Preinstaladas`: Abre un submenú para elegir entre eliminar bloatware de Microsoft, de terceros (fabricante) o aplicaciones instaladas por el usuario desde la Tienda, protegiendo las apps esenciales listadas en `Bloatware.ps1`.
* `5. Gestionar Programas de Inicio`: Abre una interfaz interactiva que detecta programas en el registro, carpetas de inicio y tareas programadas. Es **100% compatible con el Administrador de Tareas de Windows**, leyendo y escribiendo los mismos valores binarios del registro para habilitar o deshabilitar lo que arranca con Windows.

### 3. Módulo de Mantenimiento y Reparación

* **1. Verificar y Reparar Archivos del Sistema**: Ejecuta la secuencia profesional **inteligente**: `DISM /ScanHealth`, luego `DISM /RestoreHealth` **solo si es necesario**, y finalmente `sfc /scannow` para reparar la integridad del sistema.
* **2. Limpiar Caches de Sistema`: Ejecuta comandos para limpiar la cache de DNS (`ipconfig /flushdns`), de la Tienda de Windows (`wsreset.exe`) y de iconos.
* **3. Optimizar Unidades**: Ejecuta `Optimize-Volume -DriveLetter C` para realizar desfragmentación (HDD) o TRIM (SSD) de forma segura.
* **4. Generar Reporte de Salud del Sistema**: Utiliza `powercfg /energy` para generar un informe HTML que diagnostica problemas de consumo de energía y batería.
* **5. Purgar Memoria RAM en Cache**: Descarga y utiliza `EmptyStandbyList.exe` para liberar la memoria marcada como "En espera". Útil para escenarios específicos.
* **6. Diagnostico y Reparacion de Red**: Abre un submenú completo para diagnosticar problemas de conexión (`ping`, `tracert`, `nslookup`) y herramientas de reparación (limpiar DNS, renovar IP, restablecer pila de red).

### 4. Herramientas Avanzadas

Este menú da acceso a todos los módulos de nivel experto.

#### → Gestor de Ajustes del Sistema

* Centro de control para modificaciones del sistema (Rendimiento, Seguridad, Privacidad, UI) definidas en `Ajustes.ps1`.
* **Menús Dinámicos**: Muestra ajustes con su estado actual (`[Activado]`/`[Desactivado]`) obtenido mediante la función `Get-TweakState`.
* **Reversibilidad Individual**: Permite activar/desactivar cada ajuste usando `Set-TweakState`.
* **Descripciones Integradas**: Muestra la descripción de cada ajuste directamente en el menú.

#### → Inventario y Reportes del Sistema

* Genera un reporte de inventario de hardware y software en formatos `.txt`, `.html` (interactivo con navegación y buscadores) o `.csv` (múltiples archivos).
* Incluye información clave: versión detallada de Windows, CPU, RAM, GPU (con VRAM y driver), discos (con **estado de salud S.M.A.R.T.**), red, software, updates, usuarios, admins, puertos abiertos, plan de energía, etc.

#### → Gestión de Drivers

* Abre un módulo interactivo para la administración de drivers.
* **Copia de Seguridad**: Exporta todos los drivers del sistema a una carpeta especificada.
* **Listar Drivers de Terceros**: Muestra los drivers no provenientes de Microsoft.
* **Restaurar Drivers**: Instala masivamente drivers (`.inf`) desde una copia de seguridad usando `pnputil.exe`.

#### → Gestión de Software (Multi-Motor Refactorizado)

* **Selector de Motor**: Permite cambiar entre `Winget` y `Chocolatey`.
* **Arquitectura Resiliente**: Utiliza funciones "adaptador" (`Get-AegisWingetUpdates`, `Search-AegisChocoPackage`, etc.) que aíslan la lógica de ejecución y parseo de cada motor. Esto hace que el módulo sea robusto frente a cambios en la salida de `winget` o `choco`.
* `1. Buscar y aplicar actualizaciones`: Llama a los adaptadores de ambos motores, unifica los resultados y presenta una lista interactiva para seleccionar y aplicar actualizaciones.
* `2. Buscar e Instalar un software específico`: Llama al adaptador de búsqueda del motor activo y presenta una lista interactiva para seleccionar e instalar.
* `3. Instalar software en masa`: Lee un archivo `.txt` con IDs de paquetes y los instala usando el motor activo.
* Alternativa recomendada: <a href="https://github.com/marticliment/UniGetUI" target="_blank">UniGetUI</a>

#### → Administración de Sistema

* Abre un submenú con herramientas administrativas.
* **Limpiar Registros de Eventos de Windows**: Permite borrar los registros principales (Aplicación, Seguridad, Sistema, Instalación) de forma segura.
* **Gestionar Tareas Programadas de Terceros**: Presenta un gestor interactivo para listar, habilitar o deshabilitar tareas programadas que no son de Microsoft o del sistema.
* **Reubicar Carpetas de Usuario**: Mueve carpetas clave (Escritorio, Documentos, Descargas, Imágenes, Música, Videos) a una nueva ubicación base seleccionada por el usuario. Ofrece dos modos:
    * **Mover y Registrar**: Utiliza `Robocopy` para mover todo el contenido de forma robusta y luego actualiza las rutas en el registro.
    * **Solo Registrar**: Útil si los archivos ya se movieron manualmente o si se apunta a una ubicación vacía. Solo actualiza las rutas en el registro.

#### → Analizador Inteligente de Registros de Eventos

* **Escaneo Rápido**: Detecta automáticamente patrones de problemas comunes (Disco, Drivers, Memoria, Red, etc.) en las últimas 24 horas.
* **Análisis Profundo**: Permite filtrar eventos por severidad, origen, fecha y palabras clave.
* **Reporte HTML Completo**: Genera informes interactivos con búsqueda y filtrado.
* **Buscar Soluciones**: Base de conocimientos integrada que ofrece soluciones probadas para códigos de error comunes.
* **Monitoreo en Tiempo Real**: Modo experimental para observar eventos críticos y errores a medida que ocurren en el sistema.

#### → Herramienta de Respaldo de Datos de Usuario (Robocopy)

* Utiliza `Robocopy` para crear respaldos de archivos personales.
* Ofrece modo **Simple** (copiar/actualizar) y modo **Sincronización** (espejo).
* Permite respaldar las carpetas estándar del perfil o seleccionar carpetas/archivos personalizados.
* Incluye opciones de **verificación** post-respaldo: Rápida (`Robocopy /L`) o Profunda (comparación de Hash SHA256).

---

## Autor y Colaboradores

* **Autor Principal**: SOFTMAXTER
* **Análisis y refinamiento de código**: Realizado en colaboración con **Gemini**, para garantizar calidad del script.

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
