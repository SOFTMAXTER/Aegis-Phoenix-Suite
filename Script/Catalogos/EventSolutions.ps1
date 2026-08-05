# Catalogo de soluciones del Analizador de Eventos.
# Se carga desde AegisPhoenixSuite.ps1 antes de importar los modulos funcionales.

$script:EventSolutionsCatalog = @{
    '153' = @{
        SourcePatterns = @('*disk*', '*volsnap*')
        Title = 'Error de volumenes de sombra (VSS) - ID 153'
        Symptoms = 'Problemas con copias de seguridad, restauracion del sistema o puntos de restauracion.'
        Solutions = @(
            "Ejecutar 'chkdsk C: /scan' para comprobar el volumen sin forzar un reinicio.",
            "Verificar el servicio 'Volume Shadow Copy' desde services.msc.",
            "Ejecutar 'vssadmin list writers' para comprobar el estado de los escritores VSS.",
            "Si persiste, ejecutar 'sfc /scannow' para comprobar archivos protegidos."
        )
        Resources = @('https://learn.microsoft.com/windows-server/storage/file-server/volume-shadow-copy-service')
    }
    '9' = @{
        SourcePatterns = @('*disk*', '*harddisk*')
        Title = 'Error de comunicacion con disco - ID 9'
        Symptoms = 'Perdida de comunicacion con la unidad, lentitud extrema o errores de E/S.'
        Solutions = @(
            'Respaldar primero los datos importantes antes de ejecutar reparaciones.',
            'Comprobar cables, alimentacion, bahia o puerto de la unidad.',
            "Ejecutar 'chkdsk C: /scan' y revisar el resultado antes de programar una reparacion.",
            'Revisar S.M.A.R.T. y los contadores de confiabilidad de la unidad.'
        )
        Resources = @('https://learn.microsoft.com/windows-server/administration/windows-commands/chkdsk')
    }
    '14' = @{
        SourcePatterns = @('*nvlddmkm*', '*atikmdag*', '*amdkmdag*')
        Title = 'Error de controlador de graficos - ID 14'
        Symptoms = 'Pantalla negra, parpadeo, congelamiento o reinicios durante carga grafica.'
        Solutions = @(
            'Instalar un controlador firmado compatible desde el fabricante del equipo o GPU.',
            'Restaurar cualquier overclocking o undervolting antes de diagnosticar.',
            'Comprobar temperatura, alimentacion y estabilidad de la GPU.',
            'Crear un punto de restauracion antes de realizar una reinstalacion limpia del controlador.'
        )
        Resources = @('https://learn.microsoft.com/windows-hardware/drivers/display/')
    }
    '41' = @{
        SourcePatterns = @('*kernel*', '*power*')
        Title = 'Reinicio no limpio del sistema - ID 41'
        Symptoms = 'Windows detecto que el equipo se reinicio sin completar un apagado normal; el evento no identifica por si solo la causa.'
        Solutions = @(
            'Correlacionar la hora con eventos WHEA, BugCheck, almacenamiento y controladores.',
            'Comprobar temperatura, fuente de alimentacion y conexiones.',
            "Ejecutar 'powercfg /energy' para obtener contexto de energia.",
            'Comprobar memoria y estabilidad del sistema sin asumir que el evento 41 es la causa.'
        )
        Resources = @('https://learn.microsoft.com/troubleshoot/windows-client/performance/event-id-41-restart')
    }
    '4227' = @{
        SourcePatterns = @('*tcpip*', '*dhcp*')
        Title = 'Agotamiento de puertos TCP/IP - ID 4227'
        Symptoms = 'Una aplicacion no pudo crear una conexion saliente porque no habia un puerto local disponible.'
        Solutions = @(
            'Identificar el proceso con mayor numero de conexiones antes de reiniciar la red.',
            "Revisar conexiones con 'Get-NetTCPConnection' agrupadas por OwningProcess.",
            'Actualizar o reparar la aplicacion que abre conexiones sin liberarlas.',
            'Evitar modificar rangos o parametros TCP sin confirmar primero la causa.'
        )
        Resources = @('https://learn.microsoft.com/troubleshoot/windows-client/networking/tcp-ip-port-exhaustion-troubleshooting')
    }
    '7000' = @{
        SourcePatterns = @('*service*', '*control*')
        Title = 'Error al iniciar un servicio - ID 7000'
        Symptoms = 'Un servicio no pudo iniciarse durante el arranque o al ser solicitado.'
        Solutions = @(
            'Identificar el nombre exacto del servicio y conservar el codigo de error del evento.',
            'Comprobar dependencias, cuenta de inicio, permisos y ruta del ejecutable.',
            'Verificar firma y existencia del binario antes de cambiar el tipo de inicio.',
            "Ejecutar 'sfc /scannow' solo si el servicio pertenece a Windows y faltan archivos protegidos."
        )
        Resources = @('https://learn.microsoft.com/windows-server/administration/windows-commands/sc-query')
    }
    '7031' = @{
        SourcePatterns = @('*service*', '*control*')
        Title = 'Servicio terminado inesperadamente - ID 7031'
        Symptoms = 'Un servicio se detuvo de forma inesperada y el Administrador de control de servicios aplico una accion de recuperacion.'
        Solutions = @(
            'Revisar el nombre del servicio, codigo de salida y eventos inmediatamente anteriores.',
            'Comprobar dependencias y la ruta del binario.',
            'Actualizar o reparar el producto propietario del servicio.',
            'No deshabilitar el servicio hasta confirmar su impacto y dependencias.'
        )
        Resources = @('https://learn.microsoft.com/windows-server/administration/windows-commands/sc-qfailure')
    }
}
