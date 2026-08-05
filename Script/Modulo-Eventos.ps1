# =================================================================
#  Modulo-Eventos
#
#  CONTENIDO   : Show-EventLogAnalyzerMenu
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log             : registro de eventos en el log de la suite
#    - Write-AegisJsonAtomic : escritura atomica de archivos JSON (snapshots/config)
#    - $script:Version       : version actual de la suite
#
#  CARGA       : . "$PSScriptRoot\Modulo-Eventos.ps1"
#
#  NO modificar las firmas de funcion; el nucleo las invoca por nombre.
#
# ==============================================================================
# Copyright (C) 2026 SOFTMAXTER
#
# DUAL LICENSING NOTICE:
# This software is dual-licensed. By default, Aegis Phoenix Suite is 
# distributed under the GNU General Public License v3.0 (GPLv3).
# 
# 1. OPEN SOURCE (GPLv3):
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details: <https://www.gnu.org/licenses/>.
#
# 2. COMMERCIAL LICENSE:
# If you wish to integrate this software into a proprietary/commercial product, 
# distribute it without revealing your source code, or require commercial 
# support, you must obtain a commercial license from the original author.
#
# Please contact softmaxter@hotmail.com for commercial licensing inquiries.
# ==============================================================================

function Get-AegisEventIssueType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Event
    )

    $provider = ([string]$Event.ProviderName).ToLowerInvariant()
    $eventId = [int64]$Event.Id

    # La pareja proveedor/ID es estable entre idiomas. El texto se usa solo
    # como complemento cuando Windows o un proveedor de terceros no expone
    # una pareja conocida.
    if ($provider -match '(^|[-_.])(disk|ntfs|storahci|stornvme|volmgr|partmgr)([-_.]|$)' -and
        $eventId -in @(7, 9, 11, 15, 51, 55, 57, 129, 140, 153, 157)) { return 'Disk Errors' }
    if ($provider -match 'kernel-pnp|driverframeworks-usermode|display|nvlddmkm|atikmdag|amdkmdag' -and
        $eventId -in @(14, 219, 4101, 10110, 10111)) { return 'Driver Issues' }
    if ($provider -match 'whea-logger|memorydiagnostics-results' -and
        $eventId -in @(17, 18, 19, 20, 46, 1101, 1201)) { return 'Memory Problems' }
    if ($provider -match 'dns-client|dhcp|tcpip|wlan-autoconfig' -and
        $eventId -in @(1001, 1002, 1014, 4199, 4227, 4231, 8001, 8002, 8003)) { return 'Network Failures' }
    if ($provider -match 'service control manager|grouppolicy|appxdeployment' -and
        ($eventId -in @(1129, 5973) -or ($eventId -ge 7000 -and $eventId -le 7045))) { return 'Startup Failures' }
    if ($provider -match 'application error|application hang|windows error reporting' -and
        $eventId -in @(1000, 1001, 1002)) { return 'Application Crashes' }
    if (($provider -match 'kernel-power' -and $eventId -eq 41) -or
        ($provider -match 'eventlog' -and $eventId -eq 6008) -or
        ($provider -match 'bugcheck' -and $eventId -eq 1001)) { return 'System Freezes' }
    if ($provider -match 'security-auditing' -and $eventId -in @(4625, 4771, 4776)) { return 'Security Failures' }

    $message = ([string]$Event.Message).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($message)) { return $null }
    $supplementalPatterns = [ordered]@{
        'Disk Errors' = 'bad block|bloque defectuoso|disk reset|reinicio del disco|controller error|error del controlador'
        'Driver Issues' = 'driver_irql_not_less_or_equal|driver_power_state_failure|controlador dejo de responder|driver stopped responding'
        'Memory Problems' = 'memory_management|gestion de memoria|page fault|bad_pool_header|whea_uncorrectable_error'
        'Network Failures' = 'dns.*(fail|error)|dhcp.*(fail|error)|puerta de enlace.*no disponible|gateway.*unavailable'
        'Startup Failures' = 'service.*failed to start|servicio.*no pudo iniciar|group policy.*fail|directiva de grupo.*error'
        'Application Crashes' = 'faulting module|modulo con errores|stopped working|dejo de funcionar|application hang'
        'System Freezes' = 'dpc watchdog violation|critical process died|proceso critico murio|system thread exception'
    }
    foreach ($entry in $supplementalPatterns.GetEnumerator()) {
        if ($message -match $entry.Value) { return $entry.Key }
    }
    return $null
}

function Show-EventLogAnalyzerMenu {
    [CmdletBinding()]
    param()
    Write-Log -LogLevel INFO -Message "EVENTLOG: Usuario entro al Analizador Inteligente de Registros de Eventos."
    
    $logChoice = ''
    do {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "      Analizador Inteligente de Registros de Eventos    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Escaneo Rapido de Eventos Criticos (ultimas 24h)"
        Write-Host "       (Detecta automaticamente patrones de problemas comunes)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [2] Analisis Profundo Personalizado" -ForegroundColor Green
        Write-Host "       (Filtra eventos por severidad, origen, fecha y palabras clave)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Generar Reporte HTML Completo" -ForegroundColor Cyan
        Write-Host "       (Reporte interactivo con busqueda, filtrado y secciones organizadas)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Buscar Soluciones para Errores Comunes"
        Write-Host "       (Base de datos integrada de soluciones para errores frecuentes de Windows)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [5] Monitoreo en Tiempo Real (Experimental)"
        Write-Host "       (Observa eventos mientras trabajas y alerta en problemas criticos)" -ForegroundColor Red
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        $logChoice = Read-Host "Selecciona una opcion"
        switch ($logChoice.ToUpper()) {
            '1' { Invoke-QuickEventScan }
            '2' { Invoke-AdvancedEventAnalysis }
            '3' { Generate-ComprehensiveHtmlReport }
            '4' { Search-EventSolutions }
            '5' { Start-RealTimeMonitoring }
            'V' { continue }
            default { 
                Write-Warning "Opcion no valida." 
                Start-Sleep -Seconds 1
            }
        }
    } while ($logChoice.ToUpper() -ne 'V')
}

# --- FUNCIoN 1: Escaneo Rapido de Eventos Criticos ---

function Invoke-QuickEventScan {
    Clear-Host
    Write-Host "`n[+] Ejecutando escaneo rapido de eventos criticos..." -ForegroundColor Yellow
    
    $startTime = (Get-Date).AddDays(-1)
    $detectedIssues = @()
    
    # Definir que logs y niveles de severidad analizar
    $eventFilters = @(
        @{LogName="System"; Level=@(1,2); Hours=24},
        @{LogName="Application"; Level=@(1,2); Hours=24},
        @{LogName="Security"; ProviderName="Microsoft-Windows-Security-Auditing"; Id=@(4625,4771,4776)}
    )
    
    foreach ($eventFilter in $eventFilters) {
        try {
            $filterHashtable = @{
                LogName = $eventFilter.LogName
                StartTime = $startTime
            }
            
            if ($eventFilter.Level) {
                $filterHashtable.Add("Level", $eventFilter.Level)
            }
            if ($eventFilter.ProviderName) {
                $filterHashtable.Add("ProviderName", $eventFilter.ProviderName)
            }
            if ($eventFilter.Id) { $filterHashtable.Add("Id", $eventFilter.Id) }
            
            $events = Get-WinEvent -FilterHashtable $filterHashtable -MaxEvents 500 -ErrorAction Stop
            
            if ($events) {
                foreach ($event in $events) {
                    $eventMessage = [string]$event.Message
                    if ([string]::IsNullOrWhiteSpace($eventMessage)) { $eventMessage = '(Mensaje no disponible)' }
                    $eventTime = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    $eventId = $event.Id
                    $eventSource = $event.ProviderName
                    $issueType = Get-AegisEventIssueType -Event $event
                    if ($issueType) {
                        $detectedIssues += [PSCustomObject]@{
                            Time = $eventTime
                            Type = $issueType
                            Source = $eventSource
                            Id = $eventId
                            Message = ($eventMessage -split "`r?`n")[0]
                            Details = $eventMessage
                            Log = $eventFilter.LogName
                            EventObject = $event
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "No se pudieron obtener eventos del log $($eventFilter.LogName): $($_.Exception.Message)"
        }
    }
    
    # Mostrar resultados
    Clear-Host
    if ($detectedIssues.Count -gt 0) {
        Write-Host "`n[!] PROBLEMAS DETECTADOS EN LAS uLTIMAS 24 HORAS:" -ForegroundColor Red
        Write-Host "    Se encontraron $($detectedIssues.Count) eventos criticos que requieren atencion." -ForegroundColor Yellow
        Write-Host "    Limite aplicado: hasta 500 eventos por registro." -ForegroundColor DarkGray
        
        $issuesByType = $detectedIssues | Group-Object Type | Sort-Object Count -Descending
        foreach ($issueGroup in $issuesByType) {
            $color = if ($issueGroup.Count -gt 5) { "Red" } elseif ($issueGroup.Count -gt 2) { "Yellow" } else { "Cyan" }
            Write-Host "`n=== $($issueGroup.Name) ($($issueGroup.Count) eventos) ===" -ForegroundColor $color
            
            $relevantEvents = $issueGroup.Group | Select-Object -First 3
            foreach ($event in $relevantEvents) {
                Write-Host "   [$($event.Time)] $($event.Source) (ID: $($event.Id))" -ForegroundColor Gray
                Write-Host "   $($event.Message)" -ForegroundColor White
            }
            
            if ($issueGroup.Count -gt 3) {
                Write-Host "   ... y $($issueGroup.Count - 3) eventos mas del mismo tipo." -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n[+] Recomendacion:" -ForegroundColor Yellow
        $topIssue = $issuesByType[0].Name
        switch ($topIssue) {
            "Disk Errors" { Write-Host "   Respalda datos importantes, ejecuta 'chkdsk C: /scan' y revisa S.M.A.R.T. antes de programar reparaciones." -ForegroundColor Cyan }
            "Driver Issues" { Write-Host "   Actualiza los controladores, especialmente de video y chipset." -ForegroundColor Cyan }
            "Memory Problems" { Write-Host "   Ejecuta Windows Memory Diagnostic para verificar problemas de RAM." -ForegroundColor Cyan }
            "Network Failures" { Write-Host "   Reinicia tu router y actualiza los controladores de red." -ForegroundColor Cyan }
            "Startup Failures" { Write-Host "   Ejecuta 'sfc /scannow' para reparar archivos del sistema." -ForegroundColor Cyan }
            "Application Crashes" { Write-Host "   Actualiza las aplicaciones problematicas y busca actualizaciones de Windows." -ForegroundColor Cyan }
            "System Freezes" { Write-Host "   Verifica la temperatura del hardware y actualiza BIOS/controladores." -ForegroundColor Cyan }
            "Security Failures" { Write-Host "   Revisa las cuentas, el origen y la frecuencia de los intentos fallidos antes de bloquear o cambiar credenciales." -ForegroundColor Cyan }
            default { Write-Host "   Revisa los eventos detallados y considera buscar soluciones especificas." -ForegroundColor Cyan }
        }
    }
    else {
        Write-Host "`n[OK] No se detectaron problemas criticos en el ultimo dia." -ForegroundColor Green
        Write-Host "    Tu sistema parece estar funcionando correctamente." -ForegroundColor Gray
    }
    
    # Opcion para generar un reporte detallado
    if ($detectedIssues.Count -gt 0) {
        $exportChoice = Read-Host "`nDeseas exportar los resultados a un reporte detallado? (S/N)"
        if ($exportChoice.ToUpper() -eq 'S') {
            Export-DetailedEventReport -Events $detectedIssues
        }
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIoN 2: Analisis Profundo Personalizado ---

function Invoke-AdvancedEventAnalysis {
    Clear-Host
    Write-Host "`n[+] Analisis Profundo Personalizado de Registros de Eventos" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------"
    
    # Parametros de analisis
    $params = @{
        LogName = "System"  # Valor por defecto
        Level = @(1,2,3)    # Critico, Error, Advertencia
        Hours = 24
        Keywords = "*"
        ProviderName = "*"
        MaxEvents = 2000
    }
    
    # Seleccionar log
    Write-Host "`n[1/6] Selecciona el Log a analizar:"
    Write-Host "   [1] System (eventos del sistema)"
    Write-Host "   [2] Application (eventos de aplicaciones)"
    Write-Host "   [3] Security (eventos de seguridad)"
    Write-Host "   [4] Setup (eventos de instalacion)"
    Write-Host "   [5] ForwardedEvents (eventos reenviados)"
    $logChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $logChoice = if ([string]::IsNullOrWhiteSpace($logChoice)) { "1" } else { $logChoice }
    
    switch ($logChoice) {
        "2" { $params.LogName = "Application" }
        "3" { $params.LogName = "Security" }
        "4" { $params.LogName = "Setup" }
        "5" { $params.LogName = "ForwardedEvents" }
        default { $params.LogName = "System" }
    }
    
    # Seleccionar nivel de severidad
    Write-Host "`n[2/6] Selecciona niveles de severidad:"
    Write-Host "   [1] Solo Criticos (nivel 1)"
    Write-Host "   [2] Criticos y Errores (niveles 1-2)"
    Write-Host "   [3] Criticos, Errores y Advertencias (niveles 1-3)"
    Write-Host "   [4] Todos los niveles"
    $levelChoice = Read-Host "Elige una opcion (por defecto: 2)"
    $levelChoice = if ([string]::IsNullOrWhiteSpace($levelChoice)) { "2" } else { $levelChoice }
    
    switch ($levelChoice) {
        "1" { $params.Level = @(1) }
        "3" { $params.Level = @(1,2,3) }
        "4" { $params.Level = $null } # Todos los niveles
        default { $params.Level = @(1,2) }
    }
    
    # Seleccionar periodo de tiempo
    Write-Host "`n[3/6] Selecciona el periodo de tiempo:"
    Write-Host "   [1] ultima hora"
    Write-Host "   [2] ultimas 24 horas (por defecto)"
    Write-Host "   [3] ultimos 7 dias"
    Write-Host "   [4] Personalizado (en horas)"
    $timeChoice = Read-Host "Elige una opcion (por defecto: 2)"
    $timeChoice = if ([string]::IsNullOrWhiteSpace($timeChoice)) { "2" } else { $timeChoice }
    
    switch ($timeChoice) {
        "1" { $params.Hours = 1 }
        "3" { $params.Hours = 168 } # 7 dias
        "4" { 
            $customHours = Read-Host "Introduce el numero de horas para analizar"
            $params.Hours = if ($customHours -match '^\d+$' -and [int]$customHours -gt 0) { [int]$customHours } else { 24 }
        }
        default { $params.Hours = 24 }
    }
    
    # Filtro por origen
    Write-Host "`n[4/6] Filtro por origen (opcional):"
    Write-Host "   Ejemplos: 'disk', 'service', 'Microsoft-Windows-*', '*nvlddmkm*'"
    $providerFilter = Read-Host "Introduce filtro de origen (dejar en blanco para todos)"
    if (-not [string]::IsNullOrWhiteSpace($providerFilter)) {
        $params.ProviderName = $providerFilter
    }
    
    # Filtro por palabras clave
    Write-Host "`n[5/6] Filtro por palabras clave en mensaje (opcional):"
    Write-Host "   Ejemplos: 'error', 'fail*', '*memory*', 'service'"
    $keywordFilter = Read-Host "Introduce palabras clave (dejar en blanco para mostrar todos)"

    Write-Host "`n[6/6] Limite maximo de eventos (100-10000):"
    $maxEventsInput = Read-Host "Introduce el limite (por defecto: 2000)"
    if ($maxEventsInput -match '^\d+$') {
        $params.MaxEvents = [math]::Min(10000, [math]::Max(100, [int]$maxEventsInput))
    }
    
    # Ejecutar analisis
    $startTime = (Get-Date).AddHours(-$params.Hours)
    Write-Host "`n[+] Buscando eventos desde $startTime..." -ForegroundColor Yellow
    
    $filterHashtable = @{
        LogName = $params.LogName
        StartTime = $startTime
    }
    
    if ($params.Level) { $filterHashtable.Add("Level", $params.Level) }
    if ($params.ProviderName -ne "*") { $filterHashtable.Add("ProviderName", $params.ProviderName) }
    
    try {
        Write-Host "   - Obteniendo eventos del registro..." -ForegroundColor Gray
        $events = Get-WinEvent -FilterHashtable $filterHashtable -MaxEvents $params.MaxEvents -ErrorAction Stop
        
        if ($keywordFilter) {
            Write-Host "   - Aplicando filtro de texto: '$keywordFilter'..." -ForegroundColor Gray
            $events = $events | Where-Object {
                $message = [string]$_.Message
                -not [string]::IsNullOrWhiteSpace($message) -and $message -like "*$keywordFilter*"
            }
        }
        
        $events = $events | Sort-Object TimeCreated -Descending
        $totalEventsFound = $events.Count
        
        if ($totalEventsFound -eq 0) {
            Write-Host "`n[INFO] No se encontraron eventos que coincidan con los criterios de busqueda." -ForegroundColor Green
        }
        else {
            Write-Host "`n[OK] Se encontraron $totalEventsFound eventos (limite configurado: $($params.MaxEvents))." -ForegroundColor Green
            
            # Mostrar resultados paginados
            $pageSize = 10
            $currentPage = 0
            $totalPages = [math]::Ceiling($totalEventsFound / $pageSize)
            $selectedEvents = @()
            
            do {
                Clear-Host
                Write-Host "`n[+] RESULTADOS DEL ANaLISIS ($totalEventsFound eventos encontrados)" -ForegroundColor Cyan
                Write-Host "    Mostrando pagina $($currentPage + 1) de $totalPages" -ForegroundColor Gray
                
                $startIndex = $currentPage * $pageSize
                $endIndex = [math]::Min($startIndex + $pageSize - 1, $totalEventsFound - 1)
                
                for ($i = $startIndex; $i -le $endIndex; $i++) {
                    $event = $events[$i]
                    $severityColor = switch ($event.Level) {
                        1 { "Red" }     # Critico
                        2 { "Red" }     # Error
                        3 { "Yellow" }  # Advertencia
                        4 { "Gray" }    # Informacion
                        default { "White" }
                    }
                    
                    $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    $source = $event.ProviderName
                    $id = $event.Id
                    $message = ($event.Message -split "`r`n")[0]
                    
                    Write-Host "`n[$($i+1)] [$time] [$source] (ID: $id)" -ForegroundColor $severityColor
                    Write-Host "    $message" -ForegroundColor White
                }
                
                if ($totalPages -gt 1) {
                    Write-Host "`n[Navegacion] [S] Siguiente pagina  [A] Anterior pagina  [M] Marcar eventos  [T] Todas las paginas  [V] Volver" -ForegroundColor Cyan
                } else {
                    Write-Host "`n[Navegacion] [M] Marcar eventos  [V] Volver" -ForegroundColor Cyan
                }
                
                $navChoice = Read-Host "Elige una opcion"
                
                switch ($navChoice.ToUpper()) {
                    "S" { if ($currentPage -lt $totalPages - 1) { $currentPage++ } }
                    "A" { if ($currentPage -gt 0) { $currentPage-- } }
                    "T" { $pageSize = $totalEventsFound; $totalPages = 1 } # Mostrar todos
                    "M" {
                        $selection = Read-Host "Introduce los numeros de los eventos a marcar (separados por comas, ej: 1,3,5)"
                        $indices = $selection -split ',' | ForEach-Object { $_.Trim() }
                        
                        foreach ($index in $indices) {
                            if ($index -match '^\d+$' -and [int]$index -ge 1 -and [int]$index -le $totalEventsFound) {
                                $actualIndex = [int]$index - 1
                                $selectedEvents += $events[$actualIndex]
                            }
                        }
                        
                        if ($selectedEvents.Count -gt 0) {
                            Write-Host "`nSe han marcado $($selectedEvents.Count) eventos para exportacion." -ForegroundColor Green
                        }
                    }
                    "V" { break }
                }
            } while ($navChoice.ToUpper() -ne 'V')
            
            # Opcion para exportar resultados
            if ($totalEventsFound -gt 0) {
                Write-Host ""
                $exportOptions = @()
                if ($selectedEvents.Count -gt 0) {
                    $exportOptions += "   [S] Exportar SOLO los eventos marcados ($($selectedEvents.Count))"
                }
                $exportOptions += "   [T] Exportar TODOS los eventos encontrados ($totalEventsFound)"
                $exportOptions += "   [N] No exportar"
                
                Write-Host ($exportOptions -join "`n") -ForegroundColor Gray
                $exportChoice = Read-Host "`nDeseas exportar estos resultados a un archivo? (S/T/N)"
                
                if ($exportChoice.ToUpper() -eq 'S' -and $selectedEvents.Count -gt 0) {
                    Export-EventResults -Events $selectedEvents -FileNamePrefix "Eventos_Seleccionados"
                }
                elseif ($exportChoice.ToUpper() -eq 'T') {
                    Export-EventResults -Events $events -FileNamePrefix "Eventos_Completos"
                }
            }
        }
    }
    catch {
        Write-Error "No se pudieron recuperar los eventos. Error: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "Error al obtener eventos: $($_.Exception.Message)"
        Read-Host "`nPresiona Enter para continuar"
    }
}

# --- FUNCIoN 3: Generar Reporte HTML Completo ---

function Generate-ComprehensiveHtmlReport {
    Clear-Host
    Write-Host "`n[+] Generando Reporte HTML Completo de Registros de Eventos..." -ForegroundColor Cyan
    
    $startTime = (Get-Date).AddDays(-30)
    $getReportEvents = {
        param([hashtable]$Filter)
        try {
            return @(Get-WinEvent -FilterHashtable $Filter -MaxEvents 50 -ErrorAction Stop)
        } catch {
            Write-Warning "No se pudo leer '$($Filter.LogName)': $($_.Exception.Message)"
            return @()
        }
    }
    $reportData = @{
        SystemCritical = @(& $getReportEvents @{LogName='System'; Level=1; StartTime=$startTime})
        SystemErrors = @(& $getReportEvents @{LogName='System'; Level=2; StartTime=$startTime})
        ApplicationErrors = @(& $getReportEvents @{LogName='Application'; Level=2; StartTime=$startTime})
        SecurityFailures = @(& $getReportEvents @{LogName='Security'; ProviderName='Microsoft-Windows-Security-Auditing'; Id=@(4625,4771,4776); StartTime=$startTime})
    }
    
    # Calcular estadisticas
    $totalEvents = 0
    $eventCounts = @{}
    foreach ($key in $reportData.Keys) {
        $count = if ($reportData[$key]) { $reportData[$key].Count } else { 0 }
        $eventCounts[$key] = $count
        $totalEvents += $count
    }
    
    # Generar HTML
    $parentDir = Split-Path -Parent $PSScriptRoot
    $reportDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $reportPath = Join-Path -Path $reportDir -ChildPath "Reporte_Eventos_Completo_$timestamp.html"
    
    # CSS y JavaScript para el reporte interactivo (Unificado con Inventario)
    $css = @"
    <style>
        :root { 
            --bg-color: #f4f7f9;
            --main-text-color: #2c3e50;
            --primary-color: #2980b9;
            --secondary-color: #34495e;
            --card-bg-color: #ffffff;
            --header-text-color: #ecf0f1;
            --border-color: #dfe6e9;
            --danger-color: #c0392b;
            --warning-color: #f39c12;
            --shadow: 0 5px 15px rgba(0,0,0,0.08);
        }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: var(--main-text-color); background-color: var(--bg-color); max-width: 1400px; margin: auto; padding: 20px; }
        .header { background: linear-gradient(135deg, var(--secondary-color) 0%, var(--primary-color) 100%); color: var(--header-text-color); padding: 30px; border-radius: 8px; margin-bottom: 30px; box-shadow: var(--shadow); }
        h1, h2 { margin: 0; font-weight: 600; }
        h1 { font-size: 2.8em; display: flex; align-items: center; } h1 i { margin-right: 15px; }
        h2 { color: var(--secondary-color); border-bottom: 2px solid var(--border-color); padding-bottom: 10px; margin: 0 0 20px 0; font-size: 1.8em; display: flex; align-items: center; } h2 i { margin-right: 10px; color: var(--primary-color); }
        .timestamp { font-size: 1em; opacity: 0.9; margin-top: 5px; }
        .section { background-color: var(--card-bg-color); border-radius: 8px; padding: 25px; margin-bottom: 25px; box-shadow: var(--shadow); }
        
        .summary {
            background-color: #e3f2fd;
            border-left: 4px solid var(--primary-color);
            padding: 15px;
            margin-bottom: 25px;
            border-radius: 0 8px 8px 0;
        }
        .category {
            background: var(--card-bg-color);
            border-radius: 8px;
            box-shadow: var(--shadow);
            margin-bottom: 25px;
            overflow: hidden;
        }
        .category-header {
            background: var(--primary-color);
            color: white;
            padding: 12px 20px;
            font-weight: bold;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .category-header.critical { background: var(--danger-color); }
        .category-header.error { background: var(--warning-color); color: var(--main-text-color); }
        .category-header.security { background: #9b59b6; }
        .event-list { padding: 0 15px; }

        .event {
            border-bottom: 1px solid var(--border-color);
            padding: 12px 0;
            transition: background-color 0.2s;
        }
        .event:hover {
            background-color: #f1f5f8;
        }
        .event-time {
            color: #7f8c8d;
            font-size: 14px;
            margin-bottom: 4px;
        }
        .event-source {
            font-weight: bold;
            color: var(--main-text-color);
        }
        .event-id {
            color: #7f8c8d;
            margin-left: 10px;
        }
        .event-message {
            margin-top: 5px;
            line-height: 1.4;
            color: var(--main-text-color);
        }
        .search-box {
            margin: 20px 0;
            text-align: right;
        }
        .search-box input {
            padding: 10px 15px;
            width: 98%;
            border: 1px solid var(--border-color);
            border-radius: 5px;
            font-size: 1em;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            color: #7f8c8d;
            font-size: 0.8em;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .stat-card {
            background: var(--card-bg-color);
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .stat-number {
            font-size: 28px;
            font-weight: bold;
            margin: 5px 0;
        }
        .stat-critical { color: var(--danger-color); }
        .stat-error { color: var(--warning-color); }
        .stat-security { color: #9b59b6; }
        .stat-total { color: var(--main-text-color); }

        /* --- INICIO: CSS de Barra de Navegacion --- */
        .navbar {
            background-color: var(--secondary-color);
            overflow: visible;
            position: sticky;
            top: 0;
            width: 100%;
            z-index: 1000;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            padding: 8px 5px;
        }
        .navbar a {
            color: var(--header-text-color);
            background-color: var(--primary-color);
            text-align: center;
            padding: 10px 15px;
            text-decoration: none;
            font-size: 0.9em;
            font-weight: 600;
            border-radius: 5px;
            margin: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
            transition: all 0.2s ease-out;
        }
        .navbar a:hover {
            background-color: var(--primary-color);
            color: #ffffff;
        }
        /* --- FIN: CSS de Barra de Navegacion --- */

    </style>
    <script>
        function toggleCategory(categoryId) {
            const content = document.getElementById(categoryId);
            const isHidden = content.style.display === 'none' || content.style.display === '';
            content.style.display = isHidden ? 'block' : 'none';
        }
        
        function searchEvents() {
            const filter = document.getElementById('searchInput').value.toLowerCase();
            const events = document.querySelectorAll('.event');
            
            events.forEach(event => {
                const text = event.textContent.toLowerCase();
                event.style.display = text.includes(filter) ? '' : 'none';
            });
        }
        
        function copyToClipboard(text) {
            navigator.clipboard.writeText(text)
                .then(() => alert('Copiado al portapapeles'))
                .catch(err => console.error('Error al copiar: ', err));
        }
    </script>
"@
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte Completo de Registros de Eventos - Aegis Phoenix Suite</title>
    $css
</head>
<body>
    <div class="navbar">
        <a href="#summary">Resumen</a>
        <a href="#category-systemcritical">Criticos</a>
        <a href="#category-systemerrors">Errores Sistema</a>
        <a href="#category-applicationerrors">Errores Apps</a>
        <a href="#category-securityfailures">Seguridad</a>
    </div>
    <div class="header">
        <h1>Reporte Completo de Registros de Eventos</h1>
        <p class="timestamp">Generado el: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") para el equipo: $($env:COMPUTERNAME)</p>
    </div>
    
    <div class="summary section" id="summary">
        <h2>Resumen Ejecutivo - ultimos 30 Dias</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <div>Total de Eventos</div>
                <div class="stat-number stat-total">$totalEvents</div>
            </div>
            <div class="stat-card">
                <div>Eventos Criticos</div>
                <div class="stat-number stat-critical">$($eventCounts['SystemCritical'])</div>
            </div>
            <div class="stat-card">
                <div>Errores de Sistema</div>
                <div class="stat-number stat-error">$($eventCounts['SystemErrors'])</div>
            </div>
            <div class="stat-card">
                <div>Fallos de Seguridad</div>
                <div class="stat-number stat-security">$($eventCounts['SecurityFailures'])</div>
            </div>
        </div>
        <p>Este reporte muestra los eventos mas importantes de los registros de Windows en los ultimos 30 dias. Cada categoria esta limitada a los 50 eventos mas recientes.</p>
    </div>
    
    <div class="search-box">
        <input type="text" id="searchInput" onkeyup="searchEvents()" placeholder="Buscar en todos los eventos...">
    </div>
"@
    
    # Generar secciones para cada categoria de eventos
    $categories = @(
        @{ Name = "Eventos Criticos del Sistema"; Key = "SystemCritical"; Class = "critical"; Icon = "exclamation-circle" },
        @{ Name = "Errores del Sistema"; Key = "SystemErrors"; Class = "error"; Icon = "times-circle" },
        @{ Name = "Errores de Aplicaciones"; Key = "ApplicationErrors"; Class = "error"; Icon = "window-close" },
        @{ Name = "Fallos de Seguridad"; Key = "SecurityFailures"; Class = "security"; Icon = "user-secret" }
    )
    
    foreach ($category in $categories) {
        $events = $reportData[$category.Key]
        $eventId = "category-" + $category.Key.ToLower()
        
        $htmlContent += @"
    
    <div class="category">
        <div class="category-header $($category.Class)" onclick="toggleCategory('$eventId')">
            <span>$($category.Name) ($($events.Count))</span>
            <span>Mostrar/ocultar</span>
        </div>
        <div id="$eventId" class="event-list">
"@
        
        if ($events.Count -eq 0) {
            $htmlContent += "            <div class='event'><p>No se encontraron eventos en esta categoria.</p></div>"
        }
        else {
            foreach ($event in $events) {
                $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                $source = [System.Net.WebUtility]::HtmlEncode([string]$event.ProviderName)
                $id = $event.Id
                $safeMessage = ""

                if (-not [string]::IsNullOrWhiteSpace($event.Message)) {
                    $safeLines = @([string]$event.Message -split "`r?`n" | Select-Object -First 3 | ForEach-Object {
                        [System.Net.WebUtility]::HtmlEncode($_)
                    })
                    $safeMessage = $safeLines -join "<br>"
                } else {
                    $safeMessage = "(Mensaje no disponible o ilegible)"
                }
                
                $htmlContent += @"
            <div class="event">
                <div class="event-time">[$time]</div>
                <div class="event-source">$source <span class="event-id">(ID: $id)</span></div>
                <div class="event-message">$safeMessage</div>
            </div>
"@
            }
        }
        
        $htmlContent += @"
        </div>
    </div>
"@
    }
    
    $htmlContent += @"
    
    <div class="footer">
        <p>Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER</p>
    </div>
</body>
</html>
"@
    
    # Guardar el reporte
    try {
        Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8 -Force
        Write-Host "`n[OK] Reporte HTML generado correctamente en: '$reportPath'" -ForegroundColor Green
        
        $openChoice = Read-Host "`nDeseas abrir el reporte ahora? (S/N)"
        if ($openChoice.ToUpper() -eq 'S') {
            Start-Process $reportPath
        }
    }
    catch {
        Write-Error "No se pudo generar el reporte HTML. Error: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "Error al generar reporte HTML: $($_.Exception.Message)"
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIoN 4: Buscar Soluciones para Errores Comunes ---

function Search-EventSolutions {
    Clear-Host
    Write-Host "`n[+] Buscar Soluciones para Errores Comunes de Windows" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------"
    
    $solutionsDb = $script:EventSolutionsCatalog
    if (-not $solutionsDb) {
        Write-Error "El catalogo EventSolutions.ps1 no fue cargado."
        Read-Host "`nPresiona Enter para continuar..."
        return
    }
    
    # Buscar eventos criticos recientes para mostrar soluciones relevantes
    Write-Host "   - Analizando eventos recientes para encontrar errores conocidos..." -ForegroundColor Gray
    try {
        $recentEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=@(1,2); StartTime=(Get-Date).AddDays(-7)} -MaxEvents 100 -ErrorAction Stop)
    } catch {
        Write-Warning "No se pudieron leer los eventos recientes: $($_.Exception.Message)"
        $recentEvents = @()
    }
    
    $matchesFound = @()
    foreach ($event in $recentEvents) {
        $eventId = $event.Id.ToString()
        $eventSource = ([string]$event.ProviderName).ToLowerInvariant()
        
        if ($solutionsDb.ContainsKey($eventId)) {
            $solution = $solutionsDb[$eventId]
            $sourceMatch = $false
            
            foreach ($pattern in $solution.SourcePatterns) {
                if ($eventSource -like $pattern) {
                    $sourceMatch = $true
                    break
                }
            }
            
            if ($sourceMatch) {
                $matchesFound += [PSCustomObject]@{
                    Event = $event
                    Solution = $solution
                }
            }
        }
    }
    
    Clear-Host
    if ($matchesFound.Count -gt 0) {
        Write-Host "`n[OK] Se encontraron soluciones para $($matchesFound.Count) errores conocidos:" -ForegroundColor Green
        
        $index = 1
        foreach ($match in $matchesFound) {
            $event = $match.Event
            $solution = $match.Solution
            
            Write-Host "`n===== [Error #$index] =====" -ForegroundColor Cyan
            Write-Host "Fecha: $($event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))"
            Write-Host "Origen: $($event.ProviderName) | ID: $($event.Id)"
            Write-Host "Mensaje: " -NoNewline
            $firstLine = ($event.Message -split "`r`n")[0]
            Write-Host "$firstLine" -ForegroundColor White
            
            Write-Host "`n[+] $([char]0x1b)[1m$($solution.Title)$([char]0x1b)[0m" -ForegroundColor Yellow
            Write-Host "Sintomas: $($solution.Symptoms)" -ForegroundColor Gray
            
            Write-Host "`nSoluciones:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $solution.Solutions.Count; $i++) {
                Write-Host "   [$(($i+1))] $($solution.Solutions[$i])" -ForegroundColor White
            }
            
            if ($solution.Resources.Count -gt 0) {
                Write-Host "`nRecursos adicionales:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $solution.Resources.Count; $i++) {
                    Write-Host "   - $($solution.Resources[$i])" -ForegroundColor Gray
                }
            }
            
            $index++
            Write-Host ""
        }
        
        # Ofrecer exportar las soluciones
        $exportChoice = Read-Host "`nDeseas exportar estas soluciones a un archivo de texto? (S/N)"
        if ($exportChoice.ToUpper() -eq 'S') {
            $parentDir = Split-Path -Parent $PSScriptRoot
            $reportDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory | Out-Null
            }
            
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
            $solutionPath = Join-Path -Path $reportDir -ChildPath "Soluciones_Eventos_$timestamp.txt"
            
            $exportContent = @"
=== SOLUCIONES PARA ERRORES COMUNES DE WINDOWS ===
Generado el: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") 
Sistema: $($env:COMPUTERNAME)

"@
            
            $index = 1
            foreach ($match in $matchesFound) {
                $event = $match.Event
                $solution = $match.Solution
                
                $exportContent += @"
===== [Error #$index] =====
Fecha: $($event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
Origen: $($event.ProviderName) | ID: $($event.Id)
Mensaje: $($event.Message -split "`r`n")[0]

+ $($solution.Title)
Sintomas: $($solution.Symptoms)

Soluciones:
"@
                
                for ($i = 0; $i -lt $solution.Solutions.Count; $i++) {
                    $exportContent += "   [$(($i+1))] $($solution.Solutions[$i])`n"
                }
                
                if ($solution.Resources.Count -gt 0) {
                    $exportContent += "`nRecursos adicionales:`n"
                    for ($i = 0; $i -lt $solution.Resources.Count; $i++) {
                        $exportContent += "   - $($solution.Resources[$i])`n"
                    }
                }
                
                $exportContent += "`n" + ("=" * 50) + "`n`n"
                $index++
            }
            
            $exportContent += @"
Reporte generado por Aegis Phoenix Suite v$($script:Version)
by SOFTMAXTER
"@
            
            Set-Content -Path $solutionPath -Value $exportContent -Encoding UTF8
            Write-Host "`n[OK] Soluciones exportadas a: '$solutionPath'" -ForegroundColor Green
        }
    }
    else {
        Write-Host "`n[INFO] No se encontraron errores comunes que coincidan con nuestra base de conocimientos." -ForegroundColor Yellow
        Write-Host "Puedes intentar:" -ForegroundColor Gray
        Write-Host "   1. Buscar en internet el ID del evento junto con 'solucion'"
        Write-Host "   2. Usar el Analisis Profundo Personalizado para filtrar eventos especificos"
        Write-Host "   3. Generar el Reporte HTML Completo para revisar todos los eventos"
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIoN 5: Monitoreo en Tiempo Real (Experimental) ---

function Start-RealTimeMonitoring {
    Clear-Host
    Write-Host "`n[+] Monitoreo en Tiempo Real de Eventos del Sistema" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------"
    Write-Host "   Este modo experimental muestra eventos a medida que ocurren."
    Write-Host "   Presiona Q o Ctrl+C para detener el monitoreo en cualquier momento."
    Write-Warning "Este modo puede generar mucho texto en la consola."
    
    $confirm = Read-Host "`nEstas seguro de que deseas iniciar el monitoreo en tiempo real? (S/N)"
    if ($confirm.ToUpper() -ne 'S') {
        Write-Host "`n[INFO] Monitoreo cancelado por el usuario." -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para continuar..."
        return
    }
    
    # Configurar filtros para el monitoreo
    Write-Host "`n[1/4] Selecciona el tipo de eventos a monitorear:"
    Write-Host "   [1] Solo Criticos y Errores (recomendado)"
    Write-Host "   [2] Criticos, Errores y Advertencias"
    Write-Host "   [3] Todos los niveles"
    $levelChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $levelChoice = if ([string]::IsNullOrWhiteSpace($levelChoice)) { "1" } else { $levelChoice }
    
    $levelFilter = @(1, 2)  # Por defecto: criticos y errores
    switch ($levelChoice) {
        "2" { $levelFilter = @(1, 2, 3) }
        "3" { $levelFilter = $null }  # Todos los niveles
    }
    
    # Seleccionar logs a monitorear
    Write-Host "`n[2/4] Selecciona que registros monitorear:"
    Write-Host "   [1] System (recomendado)"
    Write-Host "   [2] System y Application"
    Write-Host "   [3] System, Application y Security"
    $logChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $logChoice = if ([string]::IsNullOrWhiteSpace($logChoice)) { "1" } else { $logChoice }
    
    $logNames = @("System")
    switch ($logChoice) {
        "2" { $logNames += "Application" }
        "3" { $logNames += "Application", "Security" }
    }
    
    # Duracion del monitoreo
    Write-Host "`n[3/4] Duracion del monitoreo (en minutos):"
    Write-Host "   [1] 5 minutos (recomendado para pruebas)"
    Write-Host "   [2] 15 minutos"
    Write-Host "   [3] 30 minutos"
    Write-Host "   [4] 60 minutos"
    Write-Host "   [M] Manual (introduce minutos)"
    $durationChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $durationChoice = if ([string]::IsNullOrWhiteSpace($durationChoice)) { "1" } else { $durationChoice }
    
    $durationMinutes = 5  # Por defecto
    switch ($durationChoice) {
        "2" { $durationMinutes = 15 }
        "3" { $durationMinutes = 30 }
        "4" { $durationMinutes = 60 }
        "M" { 
            $customDuration = Read-Host "Introduce la duracion en minutos"
            $durationMinutes = if ($customDuration -match '^\d+$' -and [int]$customDuration -gt 0) { [int]$customDuration } else { 5 }
        }
    }

    Write-Host "`n[4/4] Intervalo de consulta (1-30 segundos):"
    $pollInput = Read-Host "Introduce el intervalo (por defecto: 2)"
    $pollSeconds = 2
    if ($pollInput -match '^\d+$') {
        $pollSeconds = [math]::Min(30, [math]::Max(1, [int]$pollInput))
    }

    $parentDir = Split-Path -Parent $PSScriptRoot
    $logDir = Join-Path -Path $parentDir -ChildPath 'Logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    $bookmarkPath = Join-Path $logDir 'EventMonitorBookmarks.json'
    $resumeChoice = 'N'
    if (Test-Path -LiteralPath $bookmarkPath) {
        $resumeChoice = Read-Host 'Deseas reanudar desde los marcadores guardados? (S/N, por defecto N)'
    }
    
    $endTime = (Get-Date).AddMinutes($durationMinutes)
    $elapsedMinutes = 0
    
    # Preparar para el monitoreo
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "      MONITOREO EN TIEMPO REAL - $durationMinutes minutos      " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "Iniciado: $(Get-Date -Format 'HH:mm:ss')"
    Write-Host "Finalizara: $($endTime.ToString('HH:mm:ss'))"
    Write-Host "Registros: $($logNames -join ', ')"
    Write-Host "Niveles: $(if ($levelFilter) { $levelFilter -join ', ' } else { 'Todos' })"
    Write-Host ""
    Write-Host "Intervalo: $pollSeconds segundo(s)"
    Write-Host "[INFO] Presiona Q o Ctrl+C en cualquier momento para detener el monitoreo."
    Write-Host ""
    
    $eventCount = 0
    $criticalCount = 0
    $errorCount = 0
    $monitorEvents = [System.Collections.Generic.List[object]]::new()
    $unavailableLogs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $lastRecordByLog = @{}
    $lastTimeByLog = @{}

    if ($resumeChoice.ToUpperInvariant() -eq 'S') {
        try {
            $savedBookmarks = Get-Content -LiteralPath $bookmarkPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($bookmark in @($savedBookmarks.Logs)) {
                if ($bookmark.LogName -in $logNames) {
                    $lastRecordByLog[[string]$bookmark.LogName] = [int64]$bookmark.RecordId
                    $lastTimeByLog[[string]$bookmark.LogName] = [datetime]$bookmark.TimeCreated
                }
            }
        } catch {
            Write-Warning "No fue posible leer los marcadores anteriores: $($_.Exception.Message)"
        }
    }

    foreach ($logName in $logNames) {
        try {
            $newest = Get-WinEvent -LogName $logName -MaxEvents 1 -ErrorAction Stop
            if (-not $lastRecordByLog.ContainsKey($logName) -or [int64]$lastRecordByLog[$logName] -gt [int64]$newest.RecordId) {
                $lastRecordByLog[$logName] = [int64]$newest.RecordId
                $lastTimeByLog[$logName] = [datetime]$newest.TimeCreated
            }
        } catch {
            $lastRecordByLog[$logName] = 0L
            $lastTimeByLog[$logName] = Get-Date
            [void]$unavailableLogs.Add($logName)
            Write-Warning "No se pudo inicializar el marcador de '$logName': $($_.Exception.Message)"
        }
    }
    
    try {
        # Sondeo incremental por canal: evita callbacks en otro runspace y
        # consultas EventLogWatcher incompatibles con varios registros.
        $startTime = Get-Date
        Write-Host "[+] Monitoreo iniciado correctamente." -ForegroundColor Green
        Write-Host ""
        
        while ((Get-Date) -lt $endTime) {
            try {
                if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq [ConsoleKey]::Q) {
                    Write-Host "`n[INFO] Cancelacion solicitada por el usuario." -ForegroundColor Yellow
                    break
                }
            } catch { }

            foreach ($logName in $logNames) {
                $lastRecord = [int64]$lastRecordByLog[$logName]
                $levelClause = ''
                if ($levelFilter) {
                    $levelClause = ' and (' + (($levelFilter | ForEach-Object { "Level=$_" }) -join ' or ') + ')'
                }
                $filterXPath = "*[System[(EventRecordID > $lastRecord)$levelClause]]"

                try {
                    # Sin coincidencias es un estado normal de sondeo, no un
                    # error del canal. El limite evita cargar una acumulacion
                    # ilimitada al reanudar un marcador antiguo.
                    foreach ($event in @(Get-WinEvent -LogName $logName -FilterXPath $filterXPath -Oldest -MaxEvents 5000 -ErrorAction SilentlyContinue)) {
                        $eventCount++
                        if ($event.Level -eq 1) { $criticalCount++ }
                        elseif ($event.Level -eq 2) { $errorCount++ }

                        $level = switch ($event.Level) {
                            1 { "CRITICO" }
                            2 { "ERROR" }
                            3 { "ADVERTENCIA" }
                            4 { "INFORMACION" }
                            default { "OTRO" }
                        }
                        $levelColor = switch ($event.Level) {
                            1 { "Red" }
                            2 { "Red" }
                            3 { "Yellow" }
                            4 { "Gray" }
                            default { "White" }
                        }
                        $message = [string]$event.Message
                        if ([string]::IsNullOrWhiteSpace($message)) { $message = "(Mensaje no disponible)" }
                        $firstLine = ($message -split "`r?`n")[0]

                        $monitorEvents.Add([PSCustomObject]@{
                            Time = $event.TimeCreated
                            Level = $level
                            Log = $logName
                            Source = $event.ProviderName
                            Id = $event.Id
                            RecordId = $event.RecordId
                            Message = $message
                        })
                        $lastRecordByLog[$logName] = [int64]$event.RecordId
                        $lastTimeByLog[$logName] = [datetime]$event.TimeCreated
                        Write-Host "[$($event.TimeCreated.ToString('HH:mm:ss'))] [$level] [$($event.ProviderName)] (ID: $($event.Id))" -ForegroundColor $levelColor
                        Write-Host "   $firstLine" -ForegroundColor White
                    }
                } catch {
                    if ($unavailableLogs.Add($logName)) {
                        Write-Warning "No se puede leer '$logName': $($_.Exception.Message)"
                    }
                }
            }
            $currentElapsed = [math]::Floor(((Get-Date) - $startTime).TotalMinutes)
            if ($currentElapsed -gt $elapsedMinutes) {
                $elapsedMinutes = $currentElapsed
                $remainingMinutes = $durationMinutes - $elapsedMinutes
                
                if ($remainingMinutes -gt 0) {
                    $progress = ($elapsedMinutes / $durationMinutes) * 100
                    Write-Host "   [PROGRESO] Tiempo transcurrido: $elapsedMinutes/$durationMinutes minutos - Eventos detectados: $eventCount (Criticos: $criticalCount, Errores: $errorCount)" -ForegroundColor Cyan
                }
            }
            $sleepUntil = (Get-Date).AddSeconds($pollSeconds)
            while ((Get-Date) -lt $sleepUntil) {
                try {
                    if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq [ConsoleKey]::Q) {
                        $endTime = Get-Date
                        break
                    }
                } catch { }
                Start-Sleep -Milliseconds 100
            }
        }
    }
    catch {
        Write-Error "Error durante el monitoreo: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "Error en monitoreo en tiempo real: $($_.Exception.Message)"
    }
    finally {
        try {
            $bookmarkData = [ordered]@{
                SchemaVersion = 1
                UpdatedAt = (Get-Date).ToString('o')
                Logs = @($logNames | ForEach-Object {
                    [ordered]@{
                        LogName = $_
                        RecordId = [int64]$lastRecordByLog[$_]
                        TimeCreated = ([datetime]$lastTimeByLog[$_]).ToString('o')
                    }
                })
            }
            Write-AegisJsonAtomic -InputObject $bookmarkData -Path $bookmarkPath
        } catch {
            Write-Warning "No fue posible guardar los marcadores: $($_.Exception.Message)"
        }

        # Mostrar resumen final
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "         RESUMEN DEL MONITOREO EN TIEMPO REAL          " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Duracion total: $durationMinutes minutos"
        Write-Host "Eventos detectados: $eventCount"
        Write-Host "   - CRiTICOS: $criticalCount" -ForegroundColor Red
        Write-Host "   - ERRORES: $errorCount" -ForegroundColor Red
        Write-Host "   - Otros niveles: $($eventCount - $criticalCount - $errorCount)" -ForegroundColor Gray
        Write-Host ""
        
        if ($eventCount -gt 0) {
            $exportChoice = Read-Host "Deseas exportar estos eventos a un archivo de registro? (S/N)"
            if ($exportChoice.ToUpper() -eq 'S') {
                $parentDir = Split-Path -Parent $PSScriptRoot
                $logDir = Join-Path -Path $parentDir -ChildPath "Logs"
                if (-not (Test-Path $logDir)) {
                    New-Item -Path $logDir -ItemType Directory | Out-Null
                }
                
                $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
                $logPath = Join-Path -Path $logDir -ChildPath "Monitoreo_En_Tiempo_Real_$timestamp.log"
                
                $logContent = @"
=== MONITOREO EN TIEMPO REAL DE EVENTOS ===
Inicio: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))
Fin: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duracion: $durationMinutes minutos
Registros monitoreados: $($logNames -join ', ')
Niveles monitoreados: $(if ($levelFilter) { $levelFilter -join ', ' } else { 'Todos' })
------------------------------------------------
Total de eventos detectados: $eventCount
   - CRiTICOS: $criticalCount
   - ERRORES: $errorCount
   - Otros niveles: $($eventCount - $criticalCount - $errorCount)

EVENTOS CAPTURADOS
------------------------------------------------
$($monitorEvents | Format-List Time,Level,Log,Source,Id,RecordId,Message | Out-String -Width 240)
"@
                
                Set-Content -Path $logPath -Value $logContent -Encoding UTF8
                Write-Host "`n[OK] Resumen exportado a: '$logPath'" -ForegroundColor Green
            }
        }
        
        Read-Host "`nPresiona Enter para continuar..."
    }
}

# --- FUNCIONES AUXILIARES ---

function Export-DetailedEventReport {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Events
    )
    
    $parentDir = Split-Path -Parent $PSScriptRoot
    $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
    if (-not (Test-Path $diagDir)) {
        New-Item -Path $diagDir -ItemType Directory | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Eventos_Detallado_$timestamp.html"
    
    # CSS mejorado y unificado
    $css = @"
    <style>
        :root { 
            --bg-color: #f4f7f9;
            --main-text-color: #2c3e50;
            --primary-color: #2980b9;
            --secondary-color: #34495e;
            --card-bg-color: #ffffff;
            --header-text-color: #ecf0f1;
            --border-color: #dfe6e9;
            --danger-color: #c0392b;
            --warning-color: #f39c12;
            --shadow: 0 5px 15px rgba(0,0,0,0.08);
        }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: var(--main-text-color); background-color: var(--bg-color); max-width: 1400px; margin: auto; padding: 20px; }
        .header { background: linear-gradient(135deg, var(--secondary-color) 0%, var(--primary-color) 100%); color: var(--header-text-color); padding: 30px; border-radius: 8px; margin-bottom: 30px; box-shadow: var(--shadow); }
        h1, h2 { margin: 0; font-weight: 600; }
        h1 { font-size: 2.8em; display: flex; align-items: center; } h1 i { margin-right: 15px; }
        h2 { color: var(--secondary-color); border-bottom: 2px solid var(--border-color); padding-bottom: 10px; margin: 0 0 20px 0; font-size: 1.8em; display: flex; align-items: center; } h2 i { margin-right: 10px; color: var(--primary-color); }
        .timestamp { font-size: 1em; opacity: 0.9; margin-top: 5px; }
        
        .summary, .recommendations {
            background-color: var(--card-bg-color);
            border-radius: 8px;
            padding: 25px;
            margin-bottom: 25px;
            box-shadow: var(--shadow);
        }
        
        .issue-section {
            background-color: var(--card-bg-color);
            border-radius: 8px;
            box-shadow: var(--shadow);
            margin-bottom: 25px;
            overflow: hidden;
        }
        .issue-header {
            padding: 12px 20px;
            font-weight: bold;
            color: white;
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
        }
        
        .issue-header.critical { background: var(--danger-color); }
        .issue-header.warning { background: var(--warning-color); color: var(--main-text-color); }
        .issue-header.info { background: var(--primary-color); }
        .summary li.critical { color: var(--danger-color); font-weight: bold; }
        .summary li.warning { color: var(--warning-color); font-weight: bold; }
        .summary li.info { color: var(--main-text-color); }
        /* --- Fin de la adicion --- */

        .event { 
            padding: 12px 15px; 
            border-bottom: 1px solid var(--border-color); 
            transition: background-color 0.2s;
        }
        .event:hover { background-color: #f1f5f8; }
        .event:last-child { border-bottom: none; }
        .event-time { color: #7f8c8d; font-size: 14px; }
        .event-source { font-weight: bold; color: var(--main-text-color); }
        .event-message { margin-top: 5px; color: #212529; }
        
        .footer { text-align: center; margin-top: 40px; color: #7f8c8d; font-size: 0.8em; }
        .search-box { margin: 20px 0; text-align: right; }
        .search-box input { padding: 10px 15px; width: 98%; border: 1px solid var(--border-color); border-radius: 5px; font-size: 1em; }

        .navbar {
            background-color: var(--secondary-color);
            overflow: visible;
            position: sticky;
            top: 0;
            width: 100%;
            z-index: 1000;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            padding: 8px 5px;
        }
        .navbar a {
            color: var(--header-text-color);
            background-color: var(--primary-color);
            text-align: center;
            padding: 10px 15px;
            text-decoration: none;
            font-size: 0.9em;
            font-weight: 600;
            border-radius: 5px;
            margin: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
            transition: all 0.2s ease-out;
        }
        .navbar a:hover {
            background-color: var(--primary-color);
            color: #ffffff;
        }
        /* --- FIN: CSS de Barra de Navegacion --- */

    </style>
    <script>
        function searchEvents() {
            const filter = document.getElementById('searchInput').value.toLowerCase();
            const events = document.getElementsByClassName('event');
            
            for (let i = 0; i < events.length; i++) {
                const event = events[i];
                const text = event.textContent.toLowerCase();
                event.style.display = text.includes(filter) ? '' : 'none';
            }
        }
        
        function toggleSection(sectionId) {
            const section = document.getElementById(sectionId);
            const isHidden = section.style.display === 'none' || section.style.display === '';
            section.style.display = isHidden ? 'block' : 'none';
        }
    </script>
"@
    
    # Generar contenido HTML
    $htmlContent = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte Detallado de Eventos del Sistema - Aegis Phoenix Suite</title>
    $css
</head>
<body>
    <div class="navbar">
        <a href="#summary">Resumen</a>
        <a href="#detailed-events">Eventos</a>
        <a href="#recommendations">Recomendaciones</a>
    </div>
    <div class="header">
        <h1>Reporte Detallado de Eventos del Sistema</h1>
        <p class="timestamp">Generado el: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") para el equipo: $($env:COMPUTERNAME)</p>
    </div>
    
    <div class="summary" id="summary">
        <h2>Resumen Ejecutivo</h2>
        <p>Se detectaron <strong>$($Events.Count)</strong> eventos criticos en las ultimas 24 horas.</p>
        
        <h3>Patrones de Problemas Detectados:</h3>
        <ul>
"@
    
    $issuesByType = $Events | Group-Object Type | Sort-Object Count -Descending
    foreach ($issueGroup in $issuesByType) {
        $severityClass = if ($issueGroup.Count -gt 5) { "critical" } elseif ($issueGroup.Count -gt 2) { "warning" } else { "info" }
        $safeGroupName = [System.Net.WebUtility]::HtmlEncode([string]$issueGroup.Name)
        $htmlContent += "            <li class='$severityClass'>- ${safeGroupName}: <strong>$($issueGroup.Count)</strong> eventos</li>`n"
    }
    
    $htmlContent += @"
        </ul>
    </div>
    
    <div class="search-box">
        <input type="text" id="searchInput" onkeyup="searchEvents()" placeholder="Buscar en eventos...">
    </div>
    
    <h2 id="detailed-events">Eventos Detallados</h2>
"@
    
    # Agrupar eventos por tipo
    $currentSection = 1
    foreach ($issueGroup in $issuesByType) {
        $sectionId = "section-$currentSection"
        $severityClass = if ($issueGroup.Count -gt 5) { "critical" } elseif ($issueGroup.Count -gt 2) { "warning" } else { "info" }
        $safeGroupName = [System.Net.WebUtility]::HtmlEncode([string]$issueGroup.Name)
        
        $htmlContent += @"
    
    <div class="issue-section">
        <div class="issue-header $severityClass" onclick="toggleSection('$sectionId')">
            <span>$safeGroupName ($($issueGroup.Count) eventos)</span>
            <span>Mostrar/ocultar</span>
        </div>
        <div id="$sectionId">
"@
        
        foreach ($event in $issueGroup.Group) {
            
            $safeMessage = ""
            if (-not [string]::IsNullOrWhiteSpace($event.Message)) {
                $safeMessage = @([string]$event.Message -split "`r?`n" | Select-Object -First 3 | ForEach-Object {
                    [System.Net.WebUtility]::HtmlEncode($_)
                }) -join "<br>"
            } else {
                $safeMessage = "(Mensaje no disponible o ilegible)"
            }
            $safeTime = [System.Net.WebUtility]::HtmlEncode([string]$event.Time)
            $safeSource = [System.Net.WebUtility]::HtmlEncode([string]$event.Source)
            $safeLog = [System.Net.WebUtility]::HtmlEncode([string]$event.Log)
            
            $htmlContent += @"
            <div class="event">
                <div class="event-time">[$safeTime]</div>
                <div class="event-source">Fuente: $safeSource (ID: $($event.Id) | Log: $safeLog)</div>
                <div class="event-message">$safeMessage</div>
            </div>
"@
        }
        
        $htmlContent += @"
        </div>
    </div>
"@
        
        $currentSection++
    }
    
    # Recomendaciones
    $htmlContent += @"
    
    <div class="recommendations" id="recommendations">
        <h2>Recomendaciones de Accion</h2>
"@
    
    foreach ($issueGroup in $issuesByType) {
        $htmlContent += @"
        <h3>$($issueGroup.Name)</h3>
        <ul>
"@
        switch ($issueGroup.Name) {
            "Disk Errors" { 
                $htmlContent += @"
            <li>Ejecuta <strong>chkdsk C: /f</strong> y reinicia el equipo</li>
            <li>Verifica la salud del disco con CrystalDiskInfo o similar</li>
            <li>Revisa los cables de conexion del disco (SATA/Power)</li>
"@
            }
            "Driver Issues" { 
                $htmlContent += @"
            <li>Actualiza los controladores, especialmente de video y chipset</li>
            <li>Usa DDU (Display Driver Uninstaller) para una limpieza profunda de controladores de video</li>
            <li>Verifica en el Administrador de dispositivos si hay dispositivos con problemas (!)</li>
"@
            }
            "Memory Problems" { 
                $htmlContent += @"
            <li>Ejecuta Windows Memory Diagnostic (mdsched.exe)</li>
            <li>Si tienes modulos de RAM adicionales, prueba eliminando uno a la vez</li>
            <li>Verifica la configuracion de XMP/DOCP en la BIOS si aplicable</li>
"@
            }
            "Network Failures" { 
                $htmlContent += @"
            <li>Reinicia tu router y modem</li>
            <li>Actualiza los controladores de red</li>
            <li>Ejecuta los comandos: <strong>ipconfig /release</strong>, <strong>ipconfig /renew</strong>, <strong>ipconfig /flushdns</strong></li>
"@
            }
            "Startup Failures" { 
                $htmlContent += @"
            <li>Ejecuta <strong>sfc /scannow</strong> para reparar archivos del sistema</li>
            <li>Ejecuta <strong>DISM /Online /Cleanup-Image /RestoreHealth</strong></li>
            <li>Verifica los servicios de inicio criticos en services.msc</li>
"@
            }
            "Application Crashes" { 
                $htmlContent += @"
            <li>Actualiza las aplicaciones problematicas a la ultima version</li>
            <li>Revisa si hay actualizaciones disponibles de Windows</li>
            <li>Considera reinstalar la aplicacion problematica</li>
"@
            }
            "System Freezes" { 
                $htmlContent += @"
            <li>Verifica las temperaturas del sistema con HWMonitor</li>
            <li>Actualiza la BIOS/UEFI a la ultima version disponible</li>
            <li>Revisa si hay conflictos de hardware en el Administrador de dispositivos</li>
"@
            }
            default { 
                $htmlContent += @"
            <li>Busca en linea el ID del evento especifico ($($issueGroup.Group[0].Id)) combinado con el origen ($($issueGroup.Group[0].Source))</li>
            <li>Considera usar el Foro de Microsoft o comunidades especializadas para soluciones especificas</li>
"@
            }
        }
        $htmlContent += @"
        </ul>
"@
    }
    
    $htmlContent += @"
    </div>
    
    <div class="footer">
        <p>Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER</p>
    </div>
</body>
</html>
"@
    
    # Guardar el reporte
    Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8
    
    Write-Host "`n[OK] Reporte detallado generado en: '$reportPath'" -ForegroundColor Green
    $openChoice = Read-Host "Deseas abrir el reporte ahora? (S/N)"
    if ($openChoice.ToUpper() -eq 'S') {
        Start-Process $reportPath
    }
}

function Export-EventResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Events,
        [string]$FileNamePrefix = "Resultados_Eventos"
    )
    
    $parentDir = Split-Path -Parent $PSScriptRoot
    $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
    if (-not (Test-Path $diagDir)) {
        New-Item -Path $diagDir -ItemType Directory | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $txtPath = Join-Path -Path $diagDir -ChildPath "$FileNamePrefix_$timestamp.txt"
    $csvPath = Join-Path -Path $diagDir -ChildPath "$FileNamePrefix_$timestamp.csv"
    
    # Exportar a TXT (formato legible)
    $txtContent = @"
=== RESULTADOS DEL ANALISIS DE EVENTOS ===
Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Sistema: $($env:COMPUTERNAME)
Numero total de eventos: $($Events.Count)
============================================================

"@
    
    $index = 1
    foreach ($event in $Events) {
        $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        $source = $event.ProviderName
        $id = $event.Id
        $level = switch ($event.Level) {
            1 { "CRiTICO" }
            2 { "ERROR" }
            3 { "ADVERTENCIA" }
            4 { "INFORMACION" }
            default { "OTRO" }
        }
        
        $txtContent += @"
[$index] $time | $level | $source (ID: $id)
------------------------------------------------------------
$($event.Message)
============================================================

"@
        $index++
    }
    
    $txtContent += @"
Reporte generado por Aegis Phoenix Suite v$($script:Version)
by SOFTMAXTER
"@
    
    Set-Content -Path $txtPath -Value $txtContent -Encoding UTF8
    
    # Exportar a CSV (para analisis de datos)
    $eventsForCsv = $Events | Select-Object @{
        Name = "FechaHora"
        Expression = { $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") }
    }, @{
        Name = "Nivel"
        Expression = { 
            switch ($_.Level) {
                1 { "CRiTICO" }
                2 { "ERROR" }
                3 { "ADVERTENCIA" }
                4 { "INFORMACION" }
                default { "OTRO" }
            }
        }
    }, @{
        Name = "Origen"
        Expression = { $_.ProviderName }
    }, @{
        Name = "ID"
        Expression = { $_.Id }
    }, @{
        Name = "Mensaje"
        Expression = { ($_.Message -split "`r`n")[0] }
    }, @{
        Name = "Log"
        Expression = { $_.LogName }
    }
    
    $eventsForCsv | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
    
    Write-Host "`n[OK] Resultados exportados correctamente:" -ForegroundColor Green
    Write-Host "   - TXT (legible): $txtPath"
    Write-Host "   - CSV (analisis): $csvPath"
    
    $openChoice = Read-Host "`nDeseas abrir la carpeta con los resultados? (S/N)"
    if ($openChoice.ToUpper() -eq 'S') {
        Start-Process $diagDir
    }
}