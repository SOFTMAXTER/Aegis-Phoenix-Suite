Aegis Phoenix Suite v10.2 by SOFTMAXTER
Aegis Phoenix Suite es un completo script de PowerShell disenado para simplificar la administracion, optimizacion y mantenimiento de los sistemas operativos Windows 10 y 11. El script encapsula complejas operaciones de DISM, directivas de registro, PowerShell y otras herramientas del sistema en una interfaz de menus modular, interactiva y facil de usar.

Fue creado para administradores de TI, tecnicos de soporte y entusiastas de Windows que necesitan aplicar una amplia gama de mejoras, reparaciones y personalizaciones de manera eficiente y controlada.

Caracteristicas Principales
Interfaz Modular Guiada por Menus: Todas las funciones estan organizadas en categorias y submenus claros para una navegacion intuitiva.

Autoelevacion de Privilegios: El lanzador (Lanzador.bat) comprueba si se esta ejecutando como Administrador y, de no ser asi, intenta reiniciarse con los permisos necesarios.

Deteccion Dinamica de Bloatware: Escanea el sistema en tiempo real para encontrar aplicaciones de Microsoft no esenciales, las filtra con una lista de seguridad para proteger componentes criticos y presenta una lista segura y personalizada para su eliminacion.

Gestion Integral del Sistema: Abarca desde la limpieza de archivos temporales hasta la gestion de drivers, refuerzo de seguridad y personalizacion de la interfaz.

Descripciones Integradas: Cada opcion del menu incluye una breve explicacion de su proposito, haciendo la herramienta accesible para usuarios de distintos niveles.

Generacion de Reportes: Crea informes detallados sobre el inventario del sistema (hardware/software) y el estado de salud (energia), guardandolos en carpetas organizadas.

Requisitos
Sistema Operativo Windows 10 (v1909+) o Windows 11.

Privilegios de Administrador para ejecutar el script.

Modo de Uso
Descarga el repositorio como un archivo .zip y extraelo.

IMPORTANTE: Renombra el archivo de script dentro de la carpeta SCRIPT a AegisPhoenixSuite.ps1.

Asegurate de que la estructura de carpetas sea la siguiente:

TuCarpetaPrincipal/
│
├── Lanzador.bat
│
└── SCRIPT/
    │
    └── AegisPhoenixSuite.ps1

Haz doble clic en Lanzador.bat. El script validara los permisos y se iniciara.

Sigue las instrucciones en pantalla, seleccionando las opciones de los menus.

Explicacion Detallada de los Menus
Menu Principal
Al iniciar, se presentan las categorias principales de la suite, disenadas para un acceso rapido y logico.

1. Crear Punto de Restauracion: La accion mas importante antes de realizar cambios. Utiliza el cmdlet Checkpoint-Computer para crear un punto de restauracion del sistema.

2. Modulo de Optimizacion y Limpieza: Accede al submenú con herramientas para mejorar el rendimiento y liberar espacio en disco.

3. Modulo de Mantenimiento y Reparacion: Contiene utilidades para diagnosticar y reparar problemas del sistema operativo.

4. Herramientas Avanzadas: Abre un menu que agrupa todos los modulos de nivel experto para un control total.

2. Modulo de Optimizacion y Limpieza
1. Desactivar Servicios Innecesarios (Estandar): Deshabilita una lista curada de servicios (Fax, PrintSpooler, RemoteRegistry, SysMain, etc.) que no son criticos para la mayoria de los usuarios, liberando memoria RAM.

2. Desactivar Servicios Opcionales (Avanzado): Permite desactivar servicios especificos como TermService (Escritorio Remoto) y WMPNetworkSvc (Uso Compartido de Red de WMP) si no utilizas estas funciones.

3. Modulo de Limpieza Profunda: Abre un submenú con tres niveles de limpieza:

Estandar: Elimina archivos de las carpetas temporales de Windows y del usuario.

Profunda: Realiza la limpieza estandar y ademas vacia la Papelera de Reciclaje, la cache de miniaturas y los informes de error de Windows.

Avanzada: Elimina la cache de sombreadores de DirectX (util para solucionar problemas en juegos) y los archivos de Optimizacion de Entrega.

4. Eliminar Apps Preinstaladas (Dinamico):

Ejecuta Get-AppxPackage para escanear todas las aplicaciones de Microsoft.

Filtra la lista usando una "lista negra" interna para proteger apps esenciales (Store, Calculadora, Fotos, etc.).

Presenta un menu interactivo donde el usuario selecciona que aplicaciones eliminar.

Ejecuta Remove-AppxPackage y Remove-AppxProvisionedPackage para una eliminacion completa.

3. Modulo de Mantenimiento y Reparacion
1. Verificar y Reparar Archivos del Sistema: Ejecuta sfc /scannow y DISM /Online /Cleanup-Image /RestoreHealth para reparar la integridad de los archivos del sistema.

2. Limpiar Caches de Sistema: Ejecuta ipconfig /flushdns para resolver problemas de conexion y wsreset.exe para limpiar la cache de la Tienda Windows.

3. Optimizar Unidades: Ejecuta Optimize-Volume -DriveLetter C que aplica TRIM en SSDs y desfragmentacion en HDDs.

4. Generar Reporte de Salud del Sistema: Utiliza powercfg /energy para generar un informe HTML detallado sobre la eficiencia energetica y posibles problemas, y lo abre automaticamente.

4. Herramientas Avanzadas
Este menu da acceso a todos los modulos de nivel experto.

→ T. Tweaks de Sistema y Rendimiento
1. Desactivar Aceleracion del Raton: Modifica claves en HKCU:\Control Panel\Mouse para un movimiento 1:1.

2. Desactivar VBS: Ejecuta bcdedit /set hypervisorlaunchtype off para mejorar el rendimiento en juegos.

3. Aumentar prioridad de CPU: Modifica Win32PrioritySeparation en el registro para dar mas recursos a la ventana activa.

4-6. Anadir Menus Contextuales: Anade claves al registro para tener atajos a "Abrir en Terminal Windows", "Copiar como Ruta de Acceso" y "Matar Tareas que no Responden".

7. Desactivar Almacenamiento Reservado: Ejecuta dism /Online /Set-ReservedStorageState /State:Disabled.

8. Habilitar Mensajes de Estado Detallados: Activa VerboseStatus en el registro para un diagnostico de arranque/apagado mas claro.

9. Deshabilitar Copilot: Aplica una directiva en HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot para desactivar Copilot a nivel de sistema.

→ I. Inventario y Reportes del Sistema
Utiliza Get-ComputerInfo, Get-WmiObject, Get-ItemProperty y Get-NetAdapter para recopilar informacion detallada de hardware, software y red, y la guarda en un archivo .txt en la carpeta AegisPhoenixSuite_Reportes.

→ D. Gestion de Drivers
1. Copia de Seguridad de Drivers: Ejecuta Export-WindowsDriver -Online para guardar todos los drivers de terceros en una carpeta elegida por el usuario.

2. Listar drivers de terceros: Usa Get-WindowsDriver -Online y filtra los que no son de Microsoft.

→ L. Gestion de Logs y Tareas Programadas
1. Limpiar Registros de Eventos: Ejecuta Clear-EventLog en los registros de Aplicacion, Seguridad, Sistema y Setup.

2. Analizar Tareas Programadas: Usa Get-ScheduledTask para listar tareas de terceros activas.

→ W. Gestion de Software (Winget)
1. Actualizar TODO el software: Ejecuta winget upgrade --all de forma silenciosa.

2. Instalar software en masa: Lee un archivo de texto proporcionado por el usuario y ejecuta winget install para cada programa listado.

→ H. Refuerzo de Seguridad (Hardening)
1. Activar Proteccion contra Ransomware: Habilita el Acceso Controlado a Carpetas de Microsoft Defender.

2. Deshabilitar protocolo inseguro SMBv1: Usa Disable-WindowsOptionalFeature para eliminar este componente vulnerable.

3. Deshabilitar PowerShell v2.0: Usa Disable-WindowsOptionalFeature para eliminar esta version antigua y menos segura.

→ U. Personalizacion Avanzada de UI
Modifica claves del registro para cambiar la alineacion de la barra de tareas de Windows 11 y para restaurar el explorador de archivos clasico con cinta de opciones.

→ P. Privacidad
Modifica diversas claves del registro y directivas para desactivar el ID de publicidad, el seguimiento de ubicacion, las sugerencias de contenido y la recoleccion de datos de escritura.

Notas Importantes
COPIA DE SEGURIDAD: Es altamente recomendable realizar una copia de seguridad de tus archivos importantes antes de utilizar las funciones de este script.

CONOCIMIENTOS TÉCNICOS: Se recomienda tener conocimientos basicos sobre el sistema operativo Windows y las implicaciones de los cambios a realizar.

Descargo de Responsabilidad
Este script realiza operaciones avanzadas que modifican el sistema. El autor, SOFTMAXTER, no se hace responsable de la perdida de datos o danos que puedan ocurrir en tu sistema.

Se recomienda encarecidamente crear una copia de seguridad y utilizar la funcion "Crear Punto de Restauracion" antes de aplicar cambios importantes.
