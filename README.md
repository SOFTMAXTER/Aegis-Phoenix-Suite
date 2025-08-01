# Aegis Phoenix Suite v3.0 by SOFTMAXTER

<p align="center">
  <img width="240" height="240" alt="unnamed" src="https://github.com/user-attachments/assets/a553a8e6-17a4-43d4-b479-05a1dd217c8f" />
</p>

**Aegis Phoenix Suite** es un completo script de PowerShell disenado para simplificar la administracion, optimizacion y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de `DISM`, directivas de registro, `PowerShell` y gestores de paquetes en una interfaz de menus modular, interactiva y facil de usar.

Fue creado para administradores de TI, tecnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente, controlada y reversible.

## Caracteristicas Principales

* **Interfaz Modular Guiada por Menus**: Todas las funciones estan organizadas en categorias y submenus claros para una navegacion intuitiva.
* **Autoelevacion de Privilegios**: El lanzador (`Run.bat`) comprueba si se esta ejecutando como Administrador y, de no ser asi, intenta reiniciarse con los permisos necesarios.
* **Gestor de Ajustes Dinamico**: Un catalogo centralizado de ajustes permite que los menus se generen dinamicamente, mostrando el estado **[Activado]** o **[Desactivado]** de cada opcion en tiempo real.
* **Reversibilidad Individual**: Cada ajuste del sistema puede ser activado o desactivado de forma individual, eliminando la necesidad de una restauracion global.
* **Gestor de Software Multi-Motor**: Integra `Winget` y `Chocolatey`, permitiendo al usuario cambiar de motor para buscar, instalar y actualizar software, maximizando la cobertura de paquetes.
* **Instalacion Automatica de Dependencias**: Si se elige Chocolatey y no esta instalado, el script ofrece instalarlo automaticamente.
* **Deteccion Dinamica de Bloatware**: Escanea el sistema en tiempo real para encontrar aplicaciones de Microsoft y de terceros, presentando listas seguras y personalizadas para su eliminacion.

---

## Requisitos

* Sistema Operativo Windows 10 (v1909+) o Windows 11.
* Privilegios de Administrador para ejecutar el script.
* Conexion a Internet para la gestion de software y la instalacion de Chocolatey.

---

## Modo de Uso

1.  Descarga el repositorio como un archivo `.zip` y extraelo.
2.  Asegurate de que la estructura de carpetas sea la siguiente:
    ```
    TuCarpetaPrincipal/
    │
    ├── Run.bat
    │
    └── SCRIPT/
        │
        └── AegisPhoenixSuite.ps1
    ```
3.  Haz doble clic en **`Run.bat`**. El script validara los permisos y se iniciara.
4.  Sigue las instrucciones en pantalla, seleccionando las opciones de los menus.

---

## Explicacion Detallada de los Menus

### Menu Principal

Al iniciar, se presentan las categorias principales de la suite.

* **1. Crear Punto de Restauracion**: Utiliza el cmdlet `Checkpoint-Computer` para crear un punto de restauracion del sistema.
* **2. Modulo de Optimizacion y Limpieza**: Accede al submenú con herramientas para mejorar el rendimiento y liberar espacio en disco.
* **3. Modulo de Mantenimiento y Reparacion**: Contiene utilidades para diagnosticar y reparar problemas del sistema operativo.
* **4. Herramientas Avanzadas**: Abre un menu que agrupa todos los modulos de nivel experto.

### 2. Modulo de Optimizacion y Limpieza

* `1. Desactivar Servicios Innecesarios (Estandar)`: Deshabilita una lista curada de servicios no criticos.
* `2. Desactivar Servicios Opcionales (Avanzado)`: Permite desactivar servicios especificos como el de Escritorio Remoto.
* `3. Modulo de Limpieza Profunda`: Abre un submenú con tres niveles de limpieza (Estandar, Profunda y Avanzada).
* `4. Eliminar Apps Preinstaladas (Dinamico)`: Abre un submenú para elegir entre eliminar bloatware de Microsoft o de terceros (fabricantes de PC). Escanea, filtra y presenta un menu interactivo para una eliminacion segura.

### 3. Modulo de Mantenimiento y Reparacion

* `1. Verificar y Reparar Archivos del Sistema`: Ejecuta `sfc /scannow` y `DISM` de forma condicional para reparar la integridad del sistema.
* `2. Gestionar Programas de Inicio`: Abre una interfaz interactiva para habilitar o deshabilitar aplicaciones que arrancan con Windows.
* `3. Optimizar Unidades`: Ejecuta `Optimize-Volume -DriveLetter C`.
* `4. Generar Reporte de Salud del Sistema`: Utiliza `powercfg /energy` para generar un informe HTML.

### 4. Herramientas Avanzadas

Este menu da acceso a todos los modulos de nivel experto.

#### → A. Gestor de Ajustes del Sistema
* Este es el nuevo centro de control para todas las modificaciones del sistema (Rendimiento, Seguridad, Privacidad y UI).
* **Menus Dinamicos**: Elige una categoria y el script mostrara una lista de ajustes con su estado actual (`[Activado]` o `[Desactivado]`).
* **Reversibilidad Individual**: Selecciona cualquier ajuste para activarlo o desactivarlo al instante. Ya no hay un "Modulo de Restauracion" porque cada cambio es reversible individualmente.
* **Descripciones Integradas**: Cada ajuste muestra una descripcion clara de su funcion directamente en el menu.

#### → W. Gestion de Software (Multi-Motor)
* **Selector de Motor**: Permite cambiar entre `Winget` y `Chocolatey` como el gestor de paquetes a utilizar.
* `1. Buscar y aplicar actualizaciones (Interactivo)`: Ejecuta el comando de actualizacion del motor seleccionado, presenta una lista interactiva y permite al usuario seleccionar qué aplicaciones actualizar.
* `2. Instalar software en masa`: Lee un archivo de texto y ejecuta el comando de instalacion del motor seleccionado para cada programa.
* `3. Buscar e Instalar un software especifico`: Permite buscar un programa en el catalogo del motor activo y seleccionarlo de una lista para instalarlo directamente.

---

## Como Contribuir

¡Las contribuciones son bienvenidas! Si tienes ideas para mejorar Aegis Phoenix Suite, quieres anadir una nueva funcionalidad o corregir un error, por favor sigue estos pasos:

1.  Haz un **Fork** de este repositorio.
2.  Crea una nueva rama para tu funcionalidad (`git checkout -b feature/NuevaFuncionalidadAsombrosa`).
3.  Realiza tus cambios y haz **Commit** (`git commit -m 'Anade una nueva funcionalidad asombrosa'`).
4.  Haz **Push** a tu rama (`git push origin feature/NuevaFuncionalidadAsombrosa`).
5.  Abre un **Pull Request**.

---

## Descargo de Responsabilidad

Este script realiza operaciones avanzadas que modifican el sistema. El autor, **SOFTMAXTER**, no se hace responsable de la perdida de datos o danos que puedan ocurrir en tu sistema.

**Se recomienda encarecidamente crear una copia de seguridad y utilizar la funcion "Crear Punto de Restauracion" antes de aplicar cambios importantes.**
