# Aegis Phoenix Suite v4.7 by SOFTMAXTER

<p align="center">
  <img width="240" height="240" alt="unnamed" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell diseñado para simplificar la administración, optimización y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y gestores de paquetes en una interfaz de menus modular, interactiva y fácil de usar.

Fue creado para administradores de TI, técnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Caracteristicas Principales

* **Interfaz Modular Guiada por Menús**: Todas las funciones están organizadas en categorías y submenús claros para una navegación intuitiva.
* **Módulo de Auto-Actualización**: Comprueba si hay una nueva versión en el repositorio oficial de GitHub al iniciar y ofrece descargarla e instalarla automáticamente.
* **Autoelevación de Privilegios**: El script verifica si se está ejecutando como Administrador y, de no ser así, solicita al usuario que lo reinicie con los permisos necesarios.
* **Registro Completo de Actividad**: Todas las acciones realizadas por el usuario se guardan en un archivo de registro (`Logs/Registro.log`) para una fácil auditoría y depuración.
* **Gestor de Ajustes Dinámico**: Un catálogo centralizado de ajustes de Rendimiento, Seguridad, Privacidad y UI permite que los menús se generen dinámicamente, mostrando el estado **[Activado]** o **[Desactivado]** de cada opción en tiempo real.
* **Reversibilidad Individual**: Cada ajuste del sistema puede ser activado o desactivado de forma individual, eliminando la necesidad de una restauración global.
* **Gestor de Software Multi-Motor**: Integra `Winget` y `Chocolatey`, permitiendo al usuario cambiar de motor para buscar, instalar y actualizar software, maximizando la cobertura de paquetes.
* **Instalación Automática de Dependencias**: Si se elige un motor de software (como Chocolatey) y no está instalado, el script ofrece instalarlo automáticamente.
* **Detección Dinámica de Bloatware**: Escanea el sistema en tiempo real para encontrar aplicaciones de Microsoft, del fabricante y del usuario, presentando listas seguras y personalizadas para su eliminación.
* **Limpieza Profunda Post-Desinstalación**: Después de eliminar bloatware, ofrece buscar y eliminar carpetas de datos de usuario sobrantes para una limpieza completa.
* **Gestión de Inicio Nativa**: Administra los programas de inicio utilizando el mismo mecanismo que el Administrador de Tareas de Windows para una compatibilidad total.
* **Diagnóstico de Salud de Discos (S.M.A.R.T.)**: Los reportes de inventario incluyen el estado de salud de los discos físicos para detectar fallos de hardware a tiempo.
* **Módulos de Diagnóstico y Respaldo Avanzados**: Incluye herramientas profesionales para el diagnóstico de red, análisis de registros de eventos y respaldo de datos de usuario con `Robocopy`.

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
            └── Servicios.ps1
    ```
3.  Haz doble clic en **`Run.bat`**. El script validará los permisos y se iniciará.
4.  Sigue las instrucciones en pantalla, seleccionando las opciones de los menús.

---

## Explicación Detallada de los Módulos

### Menú Principal

Al iniciar, se presentan las categorías principales de la suite.

* **1. Crear Punto de Restauración**: Utiliza el cmdlet `Checkpoint-Computer` para crear un punto de restauración del sistema.
* **2. Módulo de Optimizacion y Limpieza**: Accede al submenú con herramientas para mejorar el rendimiento y liberar espacio en disco.
* **3. Módulo de Mantenimiento y Reparación**: Contiene utilidades para diagnosticar y reparar problemas del sistema operativo.
* **4. Herramientas Avanzadas**: Abre un menú que agrupa todos los módulos de nivel experto.
* **L. Ver Registro de Actividad (Log)**: Abre el archivo `Registro.log` con el historial completo de las acciones realizadas en la suite.

### 2. Módulo de Optimización y Limpieza

* `1. Gestor de Servicios No Esenciales de Windows`: Muestra una lista interactiva de servicios del sistema que pueden ser optimizados. Permite activarlos, desactivarlos o restaurarlos a su configuración por defecto de forma individual.
* `2. Optimizar Servicios de Programas Instalados`: Detecta y muestra servicios instalados por aplicaciones de terceros, permitiendo activarlos, desactivarlos o restaurarlos a su estado original (guardado en un respaldo) para reducir el consumo de recursos en segundo plano.
* `3. Módulo de Limpieza Profunda`: Abre un submenú con opciones para eliminar archivos temporales, vaciar la papelera, limpiar cachés de sistema (miniaturas, DirectX) y una limpieza avanzada de componentes de Windows (restos de actualizaciones, `Windows.old`).
* `4. Eliminar Apps Preinstaladas`: Abre un submenú para elegir entre eliminar bloatware de Microsoft (preinstalado con Windows), de terceros (preinstalado por el fabricante) o aplicaciones instaladas por el usuario desde la Tienda.
* `5. Gestionar Programas de Inicio`: Abre una interfaz interactiva que detecta programas en el registro, carpetas de inicio y tareas programadas. Es **100% compatible con el Administrador de Tareas de Windows**, leyendo y escribiendo los mismos valores del sistema para habilitar o deshabilitar lo que arranca con Windows.

### 3. Módulo de Mantenimiento y Reparación

* `1. Verificar y Reparar Archivos del Sistema`: Ejecuta la secuencia profesional `DISM /ScanHealth`, `DISM /RestoreHealth` (condicionalmente) y `sfc /scannow` para reparar la integridad del sistema.
* `2. Limpiar Caches de Sistema`: Ejecuta comandos para limpiar la cache de DNS (`ipconfig /flushdns`) y de la Tienda de Windows (`wsreset.exe`).
* `3. Optimizar Unidades`: Ejecuta `Optimize-Volume -DriveLetter C` para realizar desfragmentación (HDD) o TRIM (SSD) de forma segura.
* `4. Generar Reporte de Salud del Sistema`: Utiliza `powercfg /energy` para generar un informe HTML que diagnostica problemas de consumo de energía y batería.
* `5. Purgar Memoria RAM en Cache`: Libera la memoria marcada como "En espera" (Standby List). Útil para escenarios específicos como benchmarks o antes de ejecutar aplicaciones de alto consumo.
* `6. Diagnostico y Reparacion de Red`: Abre un submenú completo para diagnosticar problemas de conexión, incluyendo `ping`, `tracert`, `nslookup` y herramientas de reparación para limpiar la caché de DNS, renovar la IP y restablecer la pila de red (TCP/IP y Winsock).

### 4. Herramientas Avanzadas

Este menú da acceso a todos los módulos de nivel experto.

#### → Gestor de Ajustes del Sistema
* Este es el centro de control para todas las modificaciones del sistema (Rendimiento, Seguridad, Privacidad y UI).
* **Menús Dinámicos**: Elige una categoría y el script mostrará una lista de ajustes con su estado actual (`[Activado]` o `[Desactivado]`).
* **Reversibilidad Individual**: Selecciona cualquier ajuste para activarlo o desactivarlo al instante. No hay un "Módulo de Restauración" porque cada cambio es reversible individualmente.
* **Descripciones Integradas**: Cada ajuste muestra una descripción clara de su función directamente en el menú.

#### → Inventario y Reportes del Sistema
* Genera un reporte de inventario de hardware y software en diferentes formatos (`.txt`, `.html` o `.csv` para software) dentro de una carpeta `Reportes`.
* El informe incluye información clave como modelo del sistema, versión de Windows, procesador, memoria, software instalado y el **estado de salud de los discos físicos (S.M.A.R.T.)**.

#### → Gestión de Drivers
* Abre un módulo interactivo para la administración de drivers de Windows.
* **Copia de Seguridad**: Permite exportar todos los drivers del sistema a una carpeta especificada, ideal para reinstalaciones.
* **Listar Drivers de Terceros**: Muestra una tabla con los drivers instalados que no son de Microsoft, para una fácil identificación.
* **Restaurar Drivers**: Instala masivamente drivers desde una copia de seguridad, utilizando `pnputil.exe` para agregar y instalar cada paquete `.inf` encontrado.

#### → Gestión de Software (Multi-Motor)
* **Selector de Motor**: Permite cambiar entre `Winget` y `Chocolatey` como el gestor de paquetes a utilizar.
* `1. Buscar y aplicar actualizaciones`: Busca paquetes desactualizados en todos los motores disponibles, presenta una lista interactiva unificada y permite al usuario seleccionar qué aplicaciones actualizar.
* `2. Buscar e Instalar un software específico`: Permite buscar un programa en el catálogo del motor activo y seleccionarlo de una lista para instalarlo directamente.
* `3. Instalar software en masa`: Lee un archivo de texto con IDs de paquetes y ejecuta el comando de instalación del motor seleccionado para cada uno.
* Alternativa recomendada: <a href="https://github.com/marticliment/UniGetUI" target="_blank">UniGetUI</a>

#### → Administración de Sistema
* Abre un submenú con herramientas administrativas.
* **Limpiar Registros de Eventos de Windows**: Permite borrar los registros de eventos principales (Aplicación, Seguridad, Sistema, Instalación).
* **Gestionar Tareas Programadas de Terceros**: Presenta un gestor interactivo para listar, habilitar o deshabilitar tareas programadas que no pertenecen al núcleo del sistema operativo.

#### → Analizador Rápido de Registros de Eventos
* Genera reportes HTML interactivos de los eventos más importantes del sistema.
* Permite generar un reporte completo (errores críticos, de sistema, de aplicación) o buscar eventos por un origen específico (ej. "Disk", "nvlddmkm") para diagnosticar problemas concretos.

#### → Herramienta de Respaldo de Datos de Usuario (Robocopy)
* Utiliza la robusta herramienta `Robocopy` para crear respaldos de archivos personales.
* Ofrece un modo de respaldo simple (copiar/actualizar) y un modo de sincronización completa (espejo).
* Permite respaldar las carpetas de perfil de usuario (Escritorio, Documentos, etc.) o seleccionar una carpeta/archivo personalizado a través de un diálogo gráfico.

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
