# =================================================================
#  Modulo-Sistema
#
#  CONTENIDO   : Create-RestorePoint, Repair-SystemFiles, Clear-RAMCache, Clear-SystemCaches, Optimize-Drives, Generate-SystemReport, Rebuild-SearchIndex
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Invoke-AegisNativeProcess      : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#    - $script:Version                : version actual de la suite
#
#  CARGA       : . "$PSScriptRoot\Modulo-Sistema.ps1"
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

function Create-RestorePoint {
    # 1. Verificamos y aseguramos que la Proteccion del Sistema este habilitada en C:
    try {
        Write-Host "[INFO] Verificando el estado de la Proteccion del Sistema en la unidad C:..." -ForegroundColor Gray
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    } catch {
        Write-Error "No se pudo habilitar la Proteccion del Sistema en la unidad C:. Esta funcion es necesaria para crear puntos de restauracion."
        Write-Error "Por favor, habilitala manualmente desde 'Propiedades del Sistema > Proteccion del Sistema'. Error: $($_.Exception.Message)"
        Read-Host "`nOcurrio un error. Presiona Enter para continuar..."
        return
    }

    # 2. Gestionamos el servicio VSS
    $vssService = Get-Service -Name VSS -ErrorAction SilentlyContinue
    if (-not $vssService) {
        Write-Error "El servicio 'Volume Shadow Copy' (VSS) no se encuentra en este sistema."
        Read-Host "`nPresiona Enter para continuar..."
        return
    }

    # CORRECCION AQUI: La propiedad correcta es .StartType, no .StartupType
    $originalStartupType = $vssService.StartType
    $originalStatus = $vssService.Status
    
    # Validacion de seguridad por si acaso
    if ($null -eq $originalStartupType) { $originalStartupType = "Manual" }

    $serviceNeedsChange = $false

    try {
        if ($originalStartupType -eq 'Disabled') {
            $serviceNeedsChange = $true
            Write-Host "[INFO] El servicio VSS esta deshabilitado. Habilitandolo temporalmente..." -ForegroundColor Gray
            Set-Service -Name VSS -StartupType Manual
        }
        
        if ((Get-Service VSS).Status -eq 'Stopped') {
            $serviceNeedsChange = $true
            Write-Host "[INFO] Iniciando el servicio VSS..." -ForegroundColor Gray
            Start-Service -Name VSS -ErrorAction Stop
        }

        # 3. Creamos el punto de restauracion
        Write-Host "[+] Creando punto de restauracion. Esto puede tardar unos minutos..." -ForegroundColor Yellow
        Checkpoint-Computer -Description "Aegis Phoenix Suite v$($script:Version)" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        
        Write-Host "[OK] Punto de restauracion creado exitosamente." -ForegroundColor Green
        Write-Log -LogLevel ACTION -Message "SISTEMA: Se creo un punto de restauracion."

    } catch {
        Write-Error "Fallo la creacion del punto de restauracion. Error: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "SISTEMA: Fallo la creacion del punto de restauracion. Error: $($_.Exception.Message)"
        Read-Host "`nOcurrio un error. Presiona Enter para continuar..."
    } finally {
        # 4. Restauramos el estado original del servicio
        if ($serviceNeedsChange) {
            Write-Host "[INFO] Restaurando el estado original del servicio VSS..." -ForegroundColor Gray
            
            try {
                # Solo intentamos restaurar si tenemos un valor valido
                if ($null -ne $originalStartupType) {
                    Set-Service -Name VSS -StartupType $originalStartupType -ErrorAction SilentlyContinue
                }
                
                if ($originalStatus -eq 'Stopped' -and (Get-Service VSS).Status -eq 'Running') {
                    Stop-Service -Name VSS -ErrorAction SilentlyContinue
                }
                Write-Host "[OK] Estado del servicio VSS restaurado." -ForegroundColor Green
            } catch {
                Write-Warning "No se pudo restaurar el estado exacto del servicio VSS (StartType: $originalStartupType)."
            }
        }
    }

    Read-Host "`nProceso finalizado. Presiona Enter para volver al menu principal..."
}

function Invoke-ExplorerRestart {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Host "`n[+] Reiniciando el Explorador de Windows para aplicar los cambios visuales..." -ForegroundColor Yellow
    Write-Log -LogLevel ACTION -Message "Reiniciando el Explorador de Windows a peticion del usuario."

    if ($PSCmdlet.ShouldProcess("explorer.exe", "Reiniciar")) {
        try {
            # Obtener todos los procesos del Explorador (puede haber mas de uno)
            $explorerProcesses = Get-Process -Name explorer -ErrorAction Stop
            
            # Detener los procesos
            $explorerProcesses | Stop-Process -Force
            Write-Host "   - Proceso(s) detenido(s)." -ForegroundColor Gray
            
            # CORRECCIoN: Esperar a que terminen uno por uno de forma segura
            foreach ($proc in $explorerProcesses) {
                try { 
                    $proc.WaitForExit() 
                } catch { 
                    # Si el proceso ya no existe, ignoramos el error
                }
            }
            
            # Iniciar un nuevo proceso del explorador
            Start-Process "explorer.exe"
            Write-Host "   - Proceso iniciado." -ForegroundColor Gray
            Write-Host "[OK] El Explorador de Windows se ha reiniciado." -ForegroundColor Green
        }
        catch {
            Write-Error "No se pudo reiniciar el Explorador de Windows. Es posible que deba reiniciar la sesion manualmente. Error: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "Fallo el reinicio del Explorador de Windows. Motivo: $($_.Exception.Message)"
            # Intento de emergencia para iniciar explorer por si se quedo detenido
            Start-Process "explorer.exe" -ErrorAction SilentlyContinue
        }
    }
}

# =========================================================================================
# MODULO DE GESTION DE SERVICIOS DE SISTEMA INECESARIOS
# =========================================================================================

function Get-AegisOnlineImageHealth {
    [CmdletBinding()]
    param()

    if (-not (Get-Command 'Repair-WindowsImage' -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{
            State='Unknown'; RestartNeeded=$false
            Error='Repair-WindowsImage no esta disponible.'
        }
    }

    try {
        $image = Repair-WindowsImage -Online -CheckHealth -NoRestart -ErrorAction Stop
        $rawState = [string]$image.ImageHealthState
        $state = switch ($rawState) {
            'Healthy'       { 'Healthy' }
            'Repairable'    { 'Repairable' }
            'NonRepairable' { 'NonRepairable' }
            default         { 'Unknown' }
        }
        $restartNeeded = $false
        if ($image.PSObject.Properties['RestartNeeded']) {
            $restartNeeded = [bool]$image.RestartNeeded
        }
        return [PSCustomObject]@{
            State=$state; RestartNeeded=$restartNeeded; Error=$null
        }
    } catch {
        return [PSCustomObject]@{
            State='Unknown'; RestartNeeded=$false; Error=$_.Exception.Message
        }
    }
}

function Get-AegisFileContentSinceOffset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [ValidateRange(0, [long]::MaxValue)][long]$Offset
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $stream = $null
    $reader = $null
    try {
        $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
        if ($Offset -gt $stream.Length) { $Offset = 0 }
        [void]$stream.Seek($Offset, [System.IO.SeekOrigin]::Begin)
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true, 4096)
        return $reader.ReadToEnd()
    } catch {
        Write-Log -LogLevel WARN -Message "REPAIR: No se pudo leer el nuevo contenido de '$Path': $($_.Exception.Message)"
        return ''
    } finally {
        if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
    }
}

function Get-AegisSfcOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$ProcessResult,
        [AllowEmptyString()][string]$CbsDelta = ''
    )

    if ($ProcessResult.TimedOut) { return 'TimedOut' }
    if ($CbsDelta -match '(?im)\[SR\].*(Cannot repair|Could not reproject|Repair failed|Cannot verify component)') {
        return 'Unrepaired'
    }
    # No se usa el texto generico "Repair complete": CBS puede escribirlo al
    # cerrar una transaccion aunque no hubiera archivos dañados.
    if ($CbsDelta -match '(?im)\[SR\].*(Repairing corrupted file|Repaired file)') {
        return 'Repaired'
    }
    if (-not $ProcessResult.Succeeded) { return 'Failed' }
    if ($CbsDelta -match '(?im)\[SR\]') { return 'Healthy' }
    return 'Unknown'
}

function Repair-SystemFiles {
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "      Verificacion y Reparacion de Archivos de Sistema " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Esta utilidad ejecutara secuencialmente:" -ForegroundColor Yellow
    Write-Host "   1. DISM ScanHealth    (Diagnostico de imagen)"
    Write-Host "   2. DISM RestoreHealth (Reparacion de imagen - Si es necesario)"
    Write-Host "   3. SFC /Scannow       (Reparacion de archivos de sistema)"
    Write-Host "   4. CHKDSK             (Analisis del sistema de archivos NTFS - Opcional)"
    Write-Host ""
    Write-Host "   [TIEMPO ESTIMADO]: 15 a 45 minutos." -ForegroundColor Gray
    Write-Host "   [ADVERTENCIA]: El sistema puede ir lento durante el proceso." -ForegroundColor Red
    Write-Host ""
    Write-Host "   [C] CONTINUAR con la reparacion" -ForegroundColor Green
    Write-Host "   [V] VOLVER al menu anterior" -ForegroundColor Red
    Write-Host ""

    $choice = Read-Host "Elige una opcion"

    # --- 1. Salida Rapida (Logica de Inventory) ---
    if ($choice.ToUpper() -ne 'C') {
        return
    }

    # --- Inicio del proceso real ---
    Write-Log -LogLevel INFO -Message "Usuario confirmo inicio de la secuencia de reparacion (SFC/DISM/CHKDSK)."
    Write-Host "`n[+] Iniciando la secuencia de reparacion..." -ForegroundColor Cyan
    
    $repairsMade = $false
    $chkdskScheduled = $false
    $restartRecommended = $false
    $issuesRemain = $false
    $dismScanSucceeded = $false
    $dismHealthBefore = [PSCustomObject]@{ State='Unknown'; RestartNeeded=$false; Error=$null }

    # --- PASO 1: Reparar la Imagen de Windows con DISM ---
    Write-Host "`n[+] PASO 1/4: Ejecutando DISM para escanear la salud de la imagen..." -ForegroundColor Yellow
    Write-Host "--- Salida en tiempo real de DISM /ScanHealth ---" -ForegroundColor DarkCyan
    
    try {
        $dismScan = Invoke-AegisNativeProcess -FilePath 'DISM.exe' -ArgumentList @('/Online','/Cleanup-Image','/ScanHealth') -TimeoutSeconds 7200 -StreamOutput
        $dismScanSucceeded = $true
        Write-Host "[OK] Escaneo de DISM completado (codigo $($dismScan.ExitCode))." -ForegroundColor Green
        Write-Log -LogLevel INFO -Message "REPAIR/DISM ScanHealth: Finalizo con codigo $($dismScan.ExitCode); salida mostrada en tiempo real."
    } catch {
        Write-Log -LogLevel WARN -Message "DISM: ScanHealth fallo: $($_.Exception.Message)"
        Write-Warning "ScanHealth no pudo finalizar. Se intentara obtener el estado estructurado antes de decidir si reparar."
    }

    $dismHealthBefore = Get-AegisOnlineImageHealth
    if ($dismHealthBefore.RestartNeeded) { $restartRecommended = $true }
    if ($dismHealthBefore.Error) {
        Write-Log -LogLevel WARN -Message "REPAIR/DISM: No se pudo consultar ImageHealthState: $($dismHealthBefore.Error)"
    }

    $runRestoreHealth = $false
    switch ($dismHealthBefore.State) {
        'Healthy' {
            Write-Host "[OK] Estado estructurado DISM: almacén de componentes saludable." -ForegroundColor Green
        }
        'Repairable' {
            Write-Warning "DISM detecto corrupcion reparable en el almacen de componentes."
            $runRestoreHealth = $true
        }
        'NonRepairable' {
            Write-Error "DISM clasifico la imagen como no reparable automaticamente. Se requiere una fuente compatible con esta compilacion."
            Write-Log -LogLevel ERROR -Message "REPAIR/DISM: ImageHealthState=NonRepairable."
            $issuesRemain = $true
        }
        default {
            $reason = if ($dismScanSucceeded) {
                'ScanHealth termino, pero no fue posible obtener ImageHealthState.'
            } else {
                'ScanHealth y la consulta estructurada no pudieron determinar el estado.'
            }
            Write-Warning $reason
            $runRestoreHealth = ((Read-Host '¿Deseas ejecutar DISM RestoreHealth como intento de reparacion? (S/N)').ToUpperInvariant() -eq 'S')
            if (-not $runRestoreHealth) { $issuesRemain = $true }
        }
    }

    # RestoreHealth solo se ejecuta ante corrupcion reparable o confirmacion
    # explicita cuando el estado estructurado no esta disponible.
    Write-Host "`n[+] PASO 2/4: DISM RestoreHealth condicionado por el diagnostico..." -ForegroundColor Yellow
    if ($runRestoreHealth) {
        Write-Host "--- Salida en tiempo real de DISM /RestoreHealth ---" -ForegroundColor DarkCyan
        try {
            $dismRestore = Invoke-AegisNativeProcess -FilePath 'DISM.exe' -ArgumentList @('/Online','/Cleanup-Image','/RestoreHealth') -TimeoutSeconds 10800 -StreamOutput
            Write-Host "[OK] RestoreHealth completado (codigo $($dismRestore.ExitCode))." -ForegroundColor Green
            Write-Log -LogLevel INFO -Message "REPAIR/DISM RestoreHealth: Finalizo con codigo $($dismRestore.ExitCode); salida mostrada en tiempo real."

            $dismHealthAfter = Get-AegisOnlineImageHealth
            if ($dismHealthAfter.RestartNeeded) { $restartRecommended = $true }
            if ($dismHealthBefore.State -eq 'Repairable' -and $dismHealthAfter.State -eq 'Healthy') {
                $repairsMade = $true
                Write-Host "[OK] La corrupcion reparable fue corregida y el almacen quedo saludable." -ForegroundColor Green
            } elseif ($dismHealthAfter.State -eq 'Healthy') {
                Write-Host "[OK] El estado posterior de la imagen es saludable; no se afirmara que hubo reparacion porque el estado inicial era desconocido." -ForegroundColor Green
            } elseif ($dismHealthAfter.State -in @('Repairable','NonRepairable')) {
                $issuesRemain = $true
                Write-Warning "RestoreHealth finalizo, pero el estado posterior sigue siendo '$($dismHealthAfter.State)'."
            } elseif ($dismHealthAfter.State -eq 'Unknown') {
                $issuesRemain = $true
                Write-Warning "RestoreHealth termino, pero no fue posible confirmar el estado final de la imagen."
                Write-Log -LogLevel WARN -Message "REPAIR/DISM: RestoreHealth codigo 0; estado posterior desconocido. $($dismHealthAfter.Error)"
            }
        } catch {
            $issuesRemain = $true
            Write-Log -LogLevel WARN -Message "DISM: RestoreHealth fallo: $($_.Exception.Message)"
            Write-Warning "DISM no pudo completar RestoreHealth. Revisa el log antes de continuar."
        }
    } else {
        $skipReason = if ($dismHealthBefore.State -eq 'Healthy') { 'el almacen ya esta saludable' } else { 'no se autorizo o no corresponde la reparacion' }
        Write-Host "[OMITIDO] RestoreHealth no se ejecutara porque $skipReason." -ForegroundColor Gray
    }

    # --- PASO 3: Reparar Archivos del Sistema con SFC ---
    Write-Host "`n[+] PASO 3/4: Ejecutando SFC para verificar los archivos del sistema..." -ForegroundColor Yellow
    Write-Host "--- Salida en tiempo real de SFC /Scannow ---" -ForegroundColor DarkCyan
    $cbsPath = Join-Path $env:SystemRoot 'Logs\CBS\CBS.log'
    [long]$cbsOffset = 0
    if (Test-Path -LiteralPath $cbsPath -PathType Leaf) {
        $cbsOffset = (Get-Item -LiteralPath $cbsPath -ErrorAction SilentlyContinue).Length
    }

    try {
        $sfcResult = Invoke-AegisNativeProcess -FilePath 'sfc.exe' -ArgumentList @('/scannow') -TimeoutSeconds 10800 -StreamOutput -NoThrow
        $cbsDelta = Get-AegisFileContentSinceOffset -Path $cbsPath -Offset $cbsOffset
        $sfcOutcome = Get-AegisSfcOutcome -ProcessResult $sfcResult -CbsDelta $cbsDelta

        switch ($sfcOutcome) {
            'Healthy' {
                Write-Host "[OK] SFC no registro reparaciones ni archivos sin corregir." -ForegroundColor Green
                Write-Log -LogLevel INFO -Message "REPAIR/SFC: Estado=Healthy; codigo $($sfcResult.ExitCode)."
            }
            'Repaired' {
                $repairsMade = $true
                $restartRecommended = $true
                Write-Host "[REPARADO] SFC corrigio archivos protegidos del sistema." -ForegroundColor Green
                Write-Log -LogLevel ACTION -Message "REPAIR/SFC: Estado=Repaired; codigo $($sfcResult.ExitCode)."
            }
            'Unrepaired' {
                $issuesRemain = $true
                Write-Warning "SFC detecto archivos que no pudo reparar. Revisa CBS.log para conocer los componentes afectados."
                Write-Log -LogLevel ERROR -Message "REPAIR/SFC: Estado=Unrepaired; codigo $($sfcResult.ExitCode)."
            }
            'TimedOut' {
                $issuesRemain = $true
                Write-Warning "SFC excedio el tiempo maximo y fue detenido."
                Write-Log -LogLevel ERROR -Message "REPAIR/SFC: Estado=TimedOut."
            }
            'Failed' {
                $issuesRemain = $true
                Write-Warning "SFC no pudo completar la operacion (codigo $($sfcResult.ExitCode))."
                Write-Log -LogLevel ERROR -Message "REPAIR/SFC: Estado=Failed; codigo $($sfcResult.ExitCode)."
            }
            default {
                $issuesRemain = $true
                Write-Warning "SFC termino, pero CBS.log no permitio clasificar de forma fiable si hubo reparaciones."
                Write-Log -LogLevel WARN -Message "REPAIR/SFC: Estado=Unknown; codigo $($sfcResult.ExitCode)."
            }
        }
    } catch {
        $issuesRemain = $true
        Write-Warning "No se pudo ejecutar o clasificar SFC: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "REPAIR/SFC: Fallo no controlado: $($_.Exception.Message)"
    }

    # --- PASO 4 (UNIVERSAL): CHKDSK PROFUNDO ---
    Write-Host "`n[+] PASO 4/4 (OPCIONAL): Comprobacion de disco adaptada al sistema" -ForegroundColor Cyan
    Write-Host "    CHKDSK /scan analiza NTFS en linea. Solo se ofrecera una reparacion al reiniciar si el codigo lo requiere." -ForegroundColor Gray
    
    $chkdskChoice = Read-Host "`nDeseas ejecutar ahora el analisis en linea CHKDSK /scan? (S/N)"
    
    if ($chkdskChoice.ToUpper() -eq 'S') {
        try {
            $driveLetter = $env:SystemDrive.TrimEnd(':')
            $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
            if ($volume.FileSystem -ne 'NTFS') { throw "CHKDSK /scan solo se habilita para NTFS; detectado: $($volume.FileSystem)." }
            Write-Host "--- Salida en tiempo real de CHKDSK $env:SystemDrive /scan ---" -ForegroundColor DarkCyan
            $scanResult = Invoke-AegisNativeProcess -FilePath 'chkdsk.exe' -ArgumentList @($env:SystemDrive, '/scan') -TimeoutSeconds 7200 -ValidExitCodes @(0,1,2) -StreamOutput -NoThrow

            $offerOfflineRepair = $false
            switch ([int]$scanResult.ExitCode) {
                0 {
                    Write-Host "[OK] CHKDSK no encontro errores en el volumen." -ForegroundColor Green
                    Write-Log -LogLevel INFO -Message "REPAIR/CHKDSK: Codigo 0; sin errores."
                }
                1 {
                    $repairsMade = $true
                    Write-Host "[REPARADO] CHKDSK encontro errores y los corrigio en linea." -ForegroundColor Green
                    Write-Log -LogLevel ACTION -Message "REPAIR/CHKDSK: Codigo 1; errores encontrados y corregidos."
                }
                2 {
                    $issuesRemain = $true
                    $offerOfflineRepair = $true
                    Write-Warning "CHKDSK devolvio codigo 2: hubo limpieza o no se pudo completar una correccion sin /f."
                    Write-Log -LogLevel WARN -Message "REPAIR/CHKDSK: Codigo 2; se ofrecera reparacion al reiniciar."
                }
                3 {
                    $issuesRemain = $true
                    $offerOfflineRepair = $true
                    Write-Warning "CHKDSK no pudo verificar o corregir todos los errores (codigo 3)."
                    Write-Log -LogLevel ERROR -Message "REPAIR/CHKDSK: Codigo 3; errores no corregidos."
                }
                default {
                    $issuesRemain = $true
                    $offerOfflineRepair = $true
                    $failureReason = if ($scanResult.TimedOut) { 'tiempo de espera agotado' } else { "codigo $($scanResult.ExitCode)" }
                    Write-Warning "CHKDSK no finalizo correctamente: $failureReason."
                    Write-Log -LogLevel ERROR -Message "REPAIR/CHKDSK: Fallo con $failureReason."
                }
            }

            if ($offerOfflineRepair) {
                $scheduleChoice = Read-Host "¿Deseas programar la comprobacion y reparacion NTFS para el siguiente arranque? (S/N)"
                if ($scheduleChoice.ToUpperInvariant() -eq 'S') {
                    Invoke-AegisNativeProcess -FilePath 'chkntfs.exe' -ArgumentList @('/C', $env:SystemDrive) -TimeoutSeconds 60 | Out-Null
                    Write-Host "[OK] Comprobacion programada para el siguiente arranque." -ForegroundColor Green
                    Write-Log -LogLevel ACTION -Message "REPAIR: Se programo comprobacion de $env:SystemDrive con chkntfs /C."
                    $chkdskScheduled = $true
                } else {
                    Write-Warning "La reparacion pendiente no fue programada."
                }
            }
        } catch {
            $issuesRemain = $true
            Write-Error "Error al invocar CHKDSK: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "REPAIR/CHKDSK: $($_.Exception.Message)"
        }
    } else {
        Write-Host "   - Analisis de disco omitido por el usuario." -ForegroundColor Gray
    }

    # --- Conclusion ---
    Write-Host "`n[+] Secuencia de reparacion completada." -ForegroundColor Green

    if ($issuesRemain) {
        Write-Warning "Quedaron incidencias sin confirmar o sin reparar. Revisa Registro.log, DISM.log y CBS.log."
    }

    if ($chkdskScheduled -or $restartRecommended) {
        $msg = if ($chkdskScheduled) {
            "Se programo una comprobacion de disco para el siguiente arranque."
        } else {
            "Una reparacion indico que es recomendable reiniciar para completar los cambios."
        }
        Write-Host "[RECOMENDACION] $msg" -ForegroundColor Cyan
        $choice = Read-Host "`nDeseas reiniciar ahora? (S/N)"
        if ($choice.ToUpper() -eq 'S') {
            Write-Host "Reiniciando el sistema en 60 segundos..." -ForegroundColor Yellow
            Invoke-AegisNativeProcess -FilePath 'shutdown.exe' -ArgumentList @('/r','/t','60','/c','Aegis Phoenix: reinicio para completar mantenimiento') -TimeoutSeconds 30 | Out-Null
            Write-Host "Puedes cancelar durante la cuenta regresiva ejecutando: shutdown /a" -ForegroundColor Cyan
        }
    } elseif ($repairsMade) {
        Write-Host "[OK] Se realizaron reparaciones y no se detecto un reinicio pendiente." -ForegroundColor Green
    } elseif (-not $issuesRemain) {
        Write-Host "[OK] No se detectaron daños que requieran reparacion o reinicio." -ForegroundColor Green
    } else {
        Write-Host "[INFO] No se programo un reinicio automatico." -ForegroundColor Gray
    }

    Read-Host "`nPresiona Enter para volver..."
}

# ===================================================================
# MODULO DE Purgado de cache de RAM (Nativo C#)
# ===================================================================

function Clear-RAMCache {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    Write-Log -LogLevel INFO -Message "SISTEMA: Usuario abrio la funcion experimental de purgado de memoria Standby."
    
    Write-Host "`n[EXPERIMENTAL] Purgado de Memoria Standby" -ForegroundColor Yellow
    Write-Warning "Usa una API no documentada de Windows. La memoria en espera es cache util y vaciarla puede REDUCIR el rendimiento."
    Write-Warning "No es una optimizacion rutinaria; usala solo para diagnosticar presion de memoria despues de medir el sistema."
    if ((Read-Host "Escribe EXPERIMENTAL para continuar").ToUpperInvariant() -ne 'EXPERIMENTAL') { return }

    # --- 1. MOTOR C# NATIVO PARA GESTION DE MEMORIA ---
    $csharpMemoryPurger = @"
    using System;
    using System.Runtime.InteropServices;

    public class AegisMemoryPurger
    {
        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool OpenProcessToken(IntPtr ProcessHandle, UInt32 DesiredAccess, out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out LUID lpLuid);

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, [MarshalAs(UnmanagedType.Bool)] bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, UInt32 Zero, IntPtr Null1, IntPtr Null2);

        [DllImport("ntdll.dll")]
        static extern UInt32 NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);

        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool CloseHandle(IntPtr hObject);

        [StructLayout(LayoutKind.Sequential)]
        struct LUID {
            public uint LowPart;
            public int HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct TOKEN_PRIVILEGES {
            public uint PrivilegeCount;
            public LUID Luid;
            public uint Attributes;
        }

        const uint TOKEN_QUERY = 0x0008;
        const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
        const string SE_PROFILE_SINGLE_PROCESS_NAME = "SeProfileSingleProcessPrivilege";
        const uint SE_PRIVILEGE_ENABLED = 0x00000002;

        public static bool ExecutePurge()
        {
            IntPtr tokenHandle = IntPtr.Zero;
            IntPtr pCommand = IntPtr.Zero;
            try {
                // 1. Obtener el token del proceso actual
                if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out tokenHandle)) return false;

                // 2. Buscar el LUID del privilegio necesario para tocar la memoria Standby
                LUID luid;
                if (!LookupPrivilegeValue(null, SE_PROFILE_SINGLE_PROCESS_NAME, out luid)) return false;

                // 3. Ajustar privilegios
                TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
                tp.PrivilegeCount = 1;
                tp.Luid = luid;
                tp.Attributes = SE_PRIVILEGE_ENABLED;
                if (!AdjustTokenPrivileges(tokenHandle, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) return false;
                if (Marshal.GetLastWin32Error() == 1300) return false; // ERROR_NOT_ALL_ASSIGNED

                // 4. Llamada API a NtSetSystemInformation
                // SystemMemoryListInformation (Clase 80), Comando 4 (EmptyStandbyList)
                int infoClass = 80; 
                int command = 4;    
                
                pCommand = Marshal.AllocHGlobal(Marshal.SizeOf(command));
                Marshal.WriteInt32(pCommand, command);
                
                uint status = NtSetSystemInformation(infoClass, pCommand, Marshal.SizeOf(command));

                // Si status es 0 (STATUS_SUCCESS), la operacion fue un exito
                return (status == 0);
            } catch {
                return false;
            } finally {
                if (pCommand != IntPtr.Zero) Marshal.FreeHGlobal(pCommand);
                if (tokenHandle != IntPtr.Zero) CloseHandle(tokenHandle);
            }
        }
    }
"@

    # Compilar el código solo si no existe ya en la sesión actual
    if (-not ([System.Management.Automation.PSTypeName]'AegisMemoryPurger').Type) {
        try {
            Add-Type -TypeDefinition $csharpMemoryPurger -Language CSharp
        } catch {
            Write-Error "   [ERROR] No se pudo compilar el motor de purgado en memoria: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "RAM CLEAN: Error compilando AegisMemoryPurger."
            return
        }
    }

    # --- 2. MEDICION PREVIA (Snapshot) ---
    $ramBefore = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
    Write-Host "   - RAM Disponible Inicial: $([math]::Round($ramBefore / 1KB, 0)) MB" -ForegroundColor Gray

    # --- 3. EJECUCION DE PURGADO ---
    if ($PSCmdlet.ShouldProcess("Memoria del Sistema", "Purgar lista de espera (Motor Nativo)")) {
        Write-Host "   - Inyectando instruccion al Kernel de Windows..." -ForegroundColor DarkGray
        
        $success = [AegisMemoryPurger]::ExecutePurge()
        
        if ($success) {
            # Pequeña pausa para que el SO actualice los contadores en WMI
            Start-Sleep -Seconds 1 

            # --- 4. MEDICION POSTERIOR ---
            $ramAfter = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
            $freedKB = $ramAfter - $ramBefore
            
            # Normalizar si sale negativo por fluctuaciones naturales de uso del sistema
            if ($freedKB -lt 0) { $freedKB = 0 }
            
            $freedMB = [math]::Round($freedKB / 1KB, 0)
            
            Write-Host "`n   [EXITO] Operacion finalizada." -ForegroundColor Green
            Write-Host "   -> Memoria Recuperada: " -NoNewline
            Write-Host "$freedMB MB" -ForegroundColor Yellow
            
            Write-Log -LogLevel ACTION -Message "RAM CLEAN: Se purgo la memoria Standby con API nativa. Recuperados aprox: $freedMB MB."
        } else {
            Write-Error "   [FALLO] El Kernel rechazo la orden. Asegurate de ejecutar como Administrador real."
            Write-Log -LogLevel ERROR -Message "RAM CLEAN: NtSetSystemInformation devolvio un error."
        }
    }
    
    Read-Host "`nPresiona Enter para volver..."
}

# ===================================================================
# MODULO DE limpieza de caches del sistema
# ===================================================================

function Clear-SystemCaches {
    Write-Log -LogLevel INFO -Message "CACHES: Usuario entro al menu de caches del sistema."

    while ($true) {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Centro de Mantenimiento de Caches           " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Limpiar Cache DNS (Resolucion de Nombres)"
        Write-Host "       (Soluciona 'No se puede acceder al sitio web')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Limpiar Cache ARP (Tablas de Ruta Local)"
        Write-Host "       (Soluciona conflictos de IP y problemas de LAN)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Reconstruir Cache de Iconos y Miniaturas"
        Write-Host "       (Repara iconos blancos o corruptos. Reinicia Explorer)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Limpiar Cache de la Tienda (Microsoft Store)"
        Write-Host "       (Soluciona errores de descarga/actualizacion de apps)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Limpiar Cache de Fuentes (Font Cache)"
        Write-Host "       (Soluciona texto corrupto o fuentes que no cargan)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [6] Limpiar Cache de Certificados SSL (Cryptnet)"
        Write-Host "       (Soluciona errores de seguridad en navegadores)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "   [A] EJECUTAR TODO (Limpieza Completa)" -ForegroundColor Yellow
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "   Selecciona una opcion"
        
        if ($choice.ToUpper() -eq 'V') { return }

        # --- LOGICA DE SELECCION ---
        $tasks = @()
        switch ($choice.ToUpper()) {
            '1' { $tasks += "DNS" }
            '2' { $tasks += "ARP" }
            '3' { $tasks += "ICONS" }
            '4' { $tasks += "STORE" }
            '5' { $tasks += "FONTS" }
            '6' { $tasks += "SSL" }
            'A' { $tasks = @("DNS", "ARP", "SSL", "FONTS", "ICONS", "STORE") }
            default { continue }
        }

        # --- EJECUCION DE TAREAS CON COMPROBACIONES ---
        if ($tasks.Count -gt 0) {
            Write-Host "`n[+] Iniciando operaciones..." -ForegroundColor Yellow
            
            foreach ($task in $tasks) {
                Write-Host "   Processing: $task..." -ForegroundColor DarkGray
                try {
                    switch ($task) {
                        "DNS" {
                            Write-Host "   - Limpiando Cache DNS..." -NoNewline
                            $dnsSuccess = $false
                            
                            # Intento 1: Cmdlet Moderno
                            try {
                                Clear-DnsClientCache -ErrorAction Stop
                                $dnsSuccess = $true
                            } catch {
                                # Intento 2: Legacy
                                $dnsResult = Invoke-AegisNativeProcess -FilePath 'ipconfig.exe' -ArgumentList @('/flushdns') -TimeoutSeconds 30 -NoThrow
                                if ($dnsResult.Succeeded) { $dnsSuccess = $true }
                            }

                            if ($dnsSuccess) {
                                Write-Host " [OK]" -ForegroundColor Green
                                Write-Log -LogLevel ACTION -Message "CACHES: DNS limpiado exitosamente."
                            } else {
                                Write-Host " [FALLO]" -ForegroundColor Red
                                Write-Log -LogLevel ERROR -Message "CACHES: Fallo al limpiar DNS."
                            }
                        }

                        "ARP" {
                            Write-Host "   - Limpiando Tabla ARP..." -NoNewline
                            # Ejecucion y captura de error
                            $proc = Invoke-AegisNativeProcess -FilePath 'netsh.exe' -ArgumentList @('interface','ip','delete','arpcache') -TimeoutSeconds 30 -NoThrow
                            
                            if ($proc.ExitCode -eq 0) {
                                Write-Host " [OK]" -ForegroundColor Green
                            } elseif ($proc.ExitCode -eq 1) {
                                Write-Host " [REQUIERE ELEVACION]" -ForegroundColor Red
                            } else {
                                Write-Host " [ERROR CODE: $($proc.ExitCode)]" -ForegroundColor Red
                            }
                        }

                        "SSL" {
                            Write-Host "   - Limpiando Cache SSL (Cryptnet)..." -NoNewline
                            $proc = Invoke-AegisNativeProcess -FilePath 'certutil.exe' -ArgumentList @('-urlcache','*','delete') -TimeoutSeconds 120 -NoThrow
                            
                            if ($proc.ExitCode -eq 0) {
                                Write-Host " [OK]" -ForegroundColor Green
                            } else {
                                Write-Host " [ADVERTENCIA]" -ForegroundColor Yellow
                                Write-Host "     (Es posible que la cache ya estuviera vacia)" -ForegroundColor Gray
                            }
                        }

                        "FONTS" {
                            Write-Host "`n   - Limpiando Cache de Fuentes..." -ForegroundColor Cyan
                            
                            $svcName = "FontCache"
                            $svc = Get-Service $svcName -ErrorAction SilentlyContinue
                            $wasRunning = ($svc.Status -eq 'Running')

                            # 1. Detener Servicio
                            if ($wasRunning) {
                                Write-Host "     * Deteniendo servicio de cache..." -ForegroundColor Gray
                                Stop-Service $svcName -Force -ErrorAction SilentlyContinue
                                Start-Sleep -Milliseconds 500
                            }
                            
                            # 2. Eliminar Archivos
                            $fontCachePath = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
                            if (Test-Path $fontCachePath) {
                                $files = Get-ChildItem "$fontCachePath\*.dat" -ErrorAction SilentlyContinue
                                if ($files) {
                                    Remove-Item "$fontCachePath\*.dat" -Force -ErrorAction SilentlyContinue
                                    if (!(Test-Path "$fontCachePath\*.dat")) {
                                        Write-Host "     * Archivos .dat eliminados." -ForegroundColor Green
                                    } else {
                                        Write-Host "     * Algunos archivos estaban bloqueados." -ForegroundColor Yellow
                                    }
                                } else {
                                    Write-Host "     * No se encontraron archivos de cache." -ForegroundColor Gray
                                }
                            }
                            
                            # 3. Reiniciar Servicio (solo si estaba corriendo)
                            if ($wasRunning) {
                                Start-Service $svcName -ErrorAction SilentlyContinue
                                Write-Host "     [OK] Servicio reiniciado." -ForegroundColor Green
                            }
                        }

                        "ICONS" {
                            Write-Host "`n   - Reconstruyendo Cache de Iconos..." -ForegroundColor Cyan
                            Write-Host "     * Reiniciando Explorador de Windows..." -ForegroundColor Yellow
                            
                            # Comprobación de seguridad antes de matar Explorer
                            try {
                                Stop-Process -Name "explorer" -Force -ErrorAction Stop
                                Start-Sleep -Milliseconds 500
                                
                                $iconPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                                $deletedCount = 0
                                
                                # Borrado selectivo
                                $items = Get-ChildItem -Path $iconPath -Filter "iconcache_*.db" -ErrorAction SilentlyContinue
                                $items += Get-ChildItem -Path $iconPath -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
                                
                                foreach ($item in $items) {
                                    try {
                                        Remove-Item $item.FullName -Force -ErrorAction Stop
                                        $deletedCount++
                                    } catch {
                                        Write-Log -LogLevel WARN -Message "CACHES: No se pudo eliminar '$($item.FullName)': $($_.Exception.Message)"
                                    }
                                }
                                Write-Host "     * Bases de datos purgadas: $deletedCount" -ForegroundColor Gray
                            } catch {
                                Write-Warning "     No se pudo detener el Explorador o acceder a los archivos."
                            } finally {
                                # Garantizar que Explorer vuelva
                                if (-not (Get-Process "explorer" -ErrorAction SilentlyContinue)) {
                                    Start-Process "explorer.exe"
                                    Write-Host "     [OK] Explorador reiniciado." -ForegroundColor Green
                                }
                            }
                        }

                        "STORE" {
                            Write-Host "`n   - Reseteando Microsoft Store (WSReset)..." -ForegroundColor Cyan
                            Write-Host "     (Se abrira una ventana externa, no la cierres...)" -ForegroundColor Gray
                            
                            try {
                                # Usamos Start-Process para monitorear
                                $p = Start-Process "wsreset.exe" -PassThru
                                
                                # Esperamos maximo 10 segundos para no congelar el script si wsreset se cuelga
                                $timeout = 0
                                while (-not $p.HasExited -and $timeout -lt 10) {
                                    Start-Sleep -Seconds 1
                                    $timeout++
                                }
                                
                                if ($p.HasExited) {
                                    Write-Host "     [OK] Comando finalizado." -ForegroundColor Green
                                } else {
                                    Write-Host "     [INFO] WSReset sigue ejecutandose en segundo plano." -ForegroundColor Yellow
                                }
                            } catch {
                                Write-Error "     Fallo al iniciar WSReset."
                            }
                        }
                    }
                } catch {
                    Write-Error "     [ERROR FATAL] Fallo en modulo $task : $($_.Exception.Message)"
                }
            }

            Write-Host "`n[FIN] Operaciones completadas." -ForegroundColor Green
            Read-Host "Presiona Enter para continuar..."
        }
    }
}

# ===================================================================
# MODULO DE Optimizacion de unidades
# ===================================================================

function Optimize-Drives {
    Write-Log -LogLevel INFO -Message "DISCOS: Usuario entro al menu de optimizacion avanzada."
    
    # --- CONFIGURACION DE LOGGING ---
    $parentDir = Split-Path -Parent $PSScriptRoot
    $logDir = Join-Path -Path $parentDir -ChildPath "Logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    
    $logFileName = "Optimizacion_Detallada_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
    $logFile = Join-Path -Path $logDir -ChildPath $logFileName

    # --- HELPER 1: Escribir en Log (Limpieza Null Bytes) ---
    function Write-LogFile {
        param([string]$Text, [bool]$IsHeader = $false)
        $cleanText = $Text -replace '\0', '' # Elimina bytes nulos que rompen logs
        if ($IsHeader) {
            $separator = "=" * 60
            "$separator`r`n$cleanText`r`n$separator" | Out-File -FilePath $logFile -Append -Encoding UTF8
        } else {
            $cleanText | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }

    # --- HELPER 2: Salida Dual ---
    function Write-Dual {
        param(
            [Parameter(Mandatory=$true)][string]$Message,
            [string]$Color = "White",
            [switch]$NoNewLine
        )
        if ($NoNewLine) { Write-Host $Message -NoNewline -ForegroundColor $Color }
        else { Write-Host $Message -ForegroundColor $Color }

        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-LogFile "[$timestamp] $Message"
    }

    # Header del Log
    $headerInfo = "REPORTE DE OPTIMIZACION DE ALMACENAMIENTO`r`n" +
                  "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n" +
                  "Equipo: $env:COMPUTERNAME | Usuario: $env:USERNAME`r`n" +
                  "Sistema: $((Get-CimInstance Win32_OperatingSystem).Caption)"
    Write-LogFile $headerInfo -IsHeader $true

    # --- FUNCIONES INTERNAS ---
    function Test-VolumeDirtyInternal {
        param($Letter)
        try {
            $v = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($Letter):'" -ErrorAction Stop
            return $v.VolumeDirty
        } catch { return $false }
    }

    function Get-MediaTypeInternal {
        param($Letter)
        try {
            $part = Get-Partition -DriveLetter $Letter -ErrorAction Stop
            $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop
            if ($disk.Model -match "Virtual|Storage Space" -or $disk.BusType -eq "FileBackedVirtual") { return "Virtual" }
            $pDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $disk.Number } | Select-Object -First 1
            if ($pDisk) { return $pDisk.MediaType }
        } catch {
            Write-Log -LogLevel WARN -Message "UNIDADES: No se pudo detectar el tipo de '$Letter`:': $($_.Exception.Message)"
        }
        return "Unknown"
    }

	# Estado Global TRIM. El nombre de la propiedad y el valor numerico son
    # estables aunque el texto descriptivo de fsutil este localizado.
    $trimResult = Invoke-AegisNativeProcess -FilePath 'fsutil.exe' -ArgumentList @('behavior','query','DisableDeleteNotify') -TimeoutSeconds 30 -NoThrow
    $trimKnown = $trimResult.Succeeded -and $trimResult.StdOut -match 'DisableDeleteNotify\s*=\s*[01]'
    $isTrimEnabledGlobal = $trimKnown -and $trimResult.StdOut -match 'DisableDeleteNotify\s*=\s*0'
    $trimLabelGlobal = if (-not $trimKnown) { "DESCONOCIDO" } elseif ($isTrimEnabledGlobal) { "ON (Habilitado)" } else { "OFF (Deshabilitado)" }
    $trimColorGlobal = if (-not $trimKnown) { "Yellow" } elseif ($isTrimEnabledGlobal) { "Green" } else { "Red" }

    # --- BUCLE PRINCIPAL ---
    while ($true) {
        $volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | Sort-Object DriveLetter

        if ($volumes.Count -eq 0) {
            Write-Warning "No se detectaron unidades fijas."
            return
        }

        # CONSTRUCCION DE INVENTARIO
        $driveList = @()
        foreach ($vol in $volumes) {
            $letter = $vol.DriveLetter
            $type = Get-MediaTypeInternal -Letter $letter
            $isDirty = Test-VolumeDirtyInternal -Letter $letter
            $integrityStr = if ($isDirty) { "CORRUPTO" } else { "Sano" }
            
            $totalGB = [math]::Round($vol.Size / 1GB, 2)
            $freeGB  = [math]::Round($vol.SizeRemaining / 1GB, 2)

            $trimStatus = "N/A"
            if ($type -eq 'SSD' -or $type -eq 'Virtual' -or $type -eq 'Tiered') {
                if ($isTrimEnabledGlobal) { $trimStatus = "Activo" } else { $trimStatus = "Inactivo" }
            } else { $trimStatus = "-" }

            $blStatus = "Desbloqueado"
            $bl = $null
            try {
                $bl = Get-BitLockerVolume -MountPoint "$($letter):" -ErrorAction SilentlyContinue
                if ($bl) {
                    if ($bl.ProtectionStatus -eq 'On' -and $bl.LockStatus -eq 'Locked') { $blStatus = "BLOQUEADO" }
                    elseif ($bl.ProtectionStatus -eq 'On') { $blStatus = "Cifrado" }
                }
            } catch {
                Write-Log -LogLevel WARN -Message "UNIDADES: BitLocker no disponible para '$letter`:': $($_.Exception.Message)"
            }

            $driveList += [PSCustomObject]@{
                Letter    = $letter
                Label     = if ($vol.FileSystemLabel) { $vol.FileSystemLabel } else { "Sin Etiqueta" }
                Total     = $totalGB
                Free      = $freeGB
                Type      = $type
                Integrity = $integrityStr
                BLStatus  = $blStatus
                IsDirty   = $isDirty
                IsLocked  = ($blStatus -eq "BLOQUEADO")
                Trim      = $trimStatus
            }
        }

        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Optimizacion de Almacenamiento              " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "   Estado Global TRIM (OS): $trimLabelGlobal" -ForegroundColor $trimColorGlobal
        Write-Host "   Archivo de Log: $logFileName" -ForegroundColor Gray
        Write-Host ""
        
        $fmt = "{0,-4} | {1,-3} | {2,-12} | {3,-8} | {4,-10} | {5,-10} | {6,-10} | {7,-8} | {8}"
        Write-Host ($fmt -f "Num", "Ltr", "Etiqueta", "Tipo", "Total (GB)", "Libre (GB)", "Integridad", "TRIM", "BitLocker") -ForegroundColor DarkGray
        Write-Host ("-" * 115) -ForegroundColor DarkGray

        for ($i = 0; $i -lt $driveList.Count; $i++) {
            $d = $driveList[$i]
            $rowColor = "White"
            if ($d.IsDirty) { $rowColor = "Red" }
            elseif ($d.IsLocked) { $rowColor = "Magenta" }
            elseif ($d.Type -eq 'SSD') { $rowColor = "Cyan" }
            elseif ($d.Type -eq 'Virtual') { $rowColor = "Green" }
            elseif ($d.Type -eq 'Tiered') { $rowColor = "Yellow" }

            Write-Host ($fmt -f "[$($i+1)]", $d.Letter, $d.Label.Substring(0, [math]::Min($d.Label.Length, 12)), $d.Type, $d.Total, $d.Free, $d.Integrity, $d.Trim, $d.BLStatus) -ForegroundColor $rowColor
        }
        
        Write-Host ""
        Write-Host "   [T] Optimizar TODAS (Lote Completo)" -ForegroundColor Green
        Write-Host "   [A] Analizar TODAS (Solo Diagnostico)" -ForegroundColor Yellow
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "   Selecciona una opcion (Numero de Unidad, T, A, V)"
        
        $targets = @()
        $analyzeOnly = $false
        
        if ($choice.ToUpper() -eq 'V') { return }
        elseif ($choice.ToUpper() -eq 'T') { $targets = $driveList }
        elseif ($choice.ToUpper() -eq 'A') { $analyzeOnly = $true; $targets = $driveList }
        elseif ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $driveList.Count) {
                $found = $driveList[$index]
                $targets = @($found)
                Write-Host ""
                Write-Host "   Has seleccionado la Unidad ($($found.Letter)):" -ForegroundColor Cyan
                Write-Host "   [1] OPTIMIZAR (Ejecutar ReTrim/Defrag)" -ForegroundColor Green
                Write-Host "   [2] ANALIZAR (Ver estado de fragmentacion)" -ForegroundColor Yellow
                $subChoice = Read-Host "   Que deseas hacer?"
                if ($subChoice -eq '2') { $analyzeOnly = $true }
                elseif ($subChoice -ne '1') { continue }
            } else { continue }
        } else { continue }

        # --- EJECUCION ---
        foreach ($item in $targets) {
            Write-Dual "`n[+] Procesando Unidad $($item.Letter): ($($item.Type))..." -Color Yellow
            Write-LogFile "`r`n--- INICIO OPERACION: Unidad $($item.Letter) ($($item.Type)) ---"
            
            if ($item.IsLocked) { Write-Dual "   [OMITIDO] Unidad bloqueada por BitLocker." -Color Magenta; continue }
            if ($item.IsDirty) { Write-Dual "   [PELIGRO] Unidad corrupta. Ejecuta CHKDSK primero." -Color Red; continue }

            try {
                $params = @{ DriveLetter = $item.Letter; ErrorAction = "Stop"; Verbose = $true }
                $cmdOutputRaw = $null

                if ($analyzeOnly) {
                    Write-Dual "   - Iniciando Analisis..." -Color Cyan
                    $params.Add("Analyze", $true)
                    
                    # Captura Salida
                    $cmdOutputRaw = Optimize-Volume @params 4>&1 | Out-String
                    Write-Dual "   ------------------------------------------------" -Color DarkGray
                    Write-Dual "   [RESULTADO] Analisis completado por Optimize-Volume." -Color Green
                    Write-Dual "   [DETALLE] Consulta la salida tecnica del log; no se interpreta texto localizado." -Color Gray
                    Write-Dual "   ------------------------------------------------" -Color DarkGray
                    Write-Dual "   [OK] Analisis finalizado." -Color Green

                } else {
                    # Logica de Optimizacion
                    if ($item.Type -eq 'SSD') {
                        if (-not $isTrimEnabledGlobal) {
                            Write-Dual "   [AVISO] TRIM global aparece deshabilitado. Aegis no cambiara esta politica automaticamente." -Color Yellow
                        }
                        Write-Dual "   - Ejecutando Retrim (Flash)..." -Color Cyan
                        $params.Add("ReTrim", $true)
                    } elseif ($item.Type -eq 'HDD') {
                        Write-Dual "   - Ejecutando Desfragmentacion..." -Color Cyan
                        $params.Add("Defrag", $true)
                    } elseif ($item.Type -eq 'Virtual') {
                        Write-Dual "   - Ejecutando Slab Consolidation..." -Color Cyan
                        $params.Add("SlabConsolidate", $true)
                    } elseif ($item.Type -eq 'Tiered') {
                        Write-Dual "   - Ejecutando Tier Optimization..." -Color Cyan
                        $params.Add("TierOptimize", $true)
                    } else {
                        Write-Dual "   - Ejecutando optimizacion estandar..." -Color Gray
                        $params.Add("Normal", $true)
                    }
                    
                    # EJECUCION Y CAPTURA
                    $cmdOutputRaw = Optimize-Volume @params 4>&1 | Out-String
                    
                    if ($item.Type -eq 'SSD') {
                        # SSDs no suelen dar reporte de fragmentacion tras retrim
                        Write-Dual "   [REPORTE] Operacion TRIM completada exitosamente." -Color Green
                    } else {
                        Write-Dual "   [REPORTE] Optimizacion completada." -Color Green
                    }

                    Write-Dual "   [OK] Finalizado." -Color Green
                }

                if (-not [string]::IsNullOrWhiteSpace($cmdOutputRaw)) {
                    Write-LogFile "DETALLES TECNICOS DE WINDOWS:"
                    Write-LogFile "-----------------------------"
                    Write-LogFile $cmdOutputRaw
                    Write-LogFile "-----------------------------"
                }

            } catch {
                $errMsg = $_.Exception.Message
                if ($errMsg -match "not supported") {
                    Write-Dual "   [AVISO] Operacion no soportada por el hardware." -Color Yellow
                } else {
                    Write-Dual "   [ERROR] $errMsg" -Color Red
                }
            }
        }
        
        Write-Host ""
        Read-Host "Presiona Enter para continuar..."
    }
}

# ===================================================================
# MODULO DE DIAGNOSTICO DE ENERGIA
# ===================================================================

function Generate-SystemReport {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Activar estilos visuales
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Centro de Diagnostico de Energia"
    $form.Size = New-Object System.Drawing.Size(800, 550)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. ENCABEZADO ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Diagnosticos de Energia y Hardware"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.AutoSize = $true
    $lblTitle.ForeColor = [System.Drawing.Color]::Cyan
    $form.Controls.Add($lblTitle)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "Genera reportes detallados sobre la salud de la bateria, eficiencia y suspension."
    $lblSub.Location = New-Object System.Drawing.Point(25, 55)
    $lblSub.AutoSize = $true
    $lblSub.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($lblSub)

    # --- 3. CONTENEDOR DE OPCIONES ---
    $grpOptions = New-Object System.Windows.Forms.GroupBox
    $grpOptions.Text = "Selecciona un Reporte"
    $grpOptions.Location = New-Object System.Drawing.Point(20, 90)
    $grpOptions.Size = New-Object System.Drawing.Size(740, 280)
    $grpOptions.ForeColor = [System.Drawing.Color]::LightGray
    $form.Controls.Add($grpOptions)

    # -- OPCION A: ENERGY REPORT --
    $btnEnergy = New-Object System.Windows.Forms.Button
    $btnEnergy.Text = "Reporte de Eficiencia (Energy)"
    $btnEnergy.Location = New-Object System.Drawing.Point(30, 40)
    $btnEnergy.Size = New-Object System.Drawing.Size(250, 50)
    $btnEnergy.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnEnergy.ForeColor = [System.Drawing.Color]::White
    $btnEnergy.FlatStyle = "Flat"
    $btnEnergy.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $grpOptions.Controls.Add($btnEnergy)

    $lblEnergy = New-Object System.Windows.Forms.Label
    $lblEnergy.Text = "Analiza el comportamiento del sistema, busca errores de hardware USB y consumo excesivo."
    $lblEnergy.Location = New-Object System.Drawing.Point(300, 45)
    $lblEnergy.Size = New-Object System.Drawing.Size(400, 40)
    $grpOptions.Controls.Add($lblEnergy)

    # Selector de Duracion
    $lblDur = New-Object System.Windows.Forms.Label
    $lblDur.Text = "Duracion (seg):"
    $lblDur.Location = New-Object System.Drawing.Point(30, 100)
    $lblDur.AutoSize = $true
    $grpOptions.Controls.Add($lblDur)

    $numDuration = New-Object System.Windows.Forms.NumericUpDown
    $numDuration.Location = New-Object System.Drawing.Point(120, 98)
    $numDuration.Width = 60
    $numDuration.Minimum = 5
    $numDuration.Maximum = 300
    $numDuration.Value = 60
    $numDuration.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $numDuration.ForeColor = [System.Drawing.Color]::White
    $grpOptions.Controls.Add($numDuration)

    # -- OPCION B: BATTERY REPORT --
    $btnBattery = New-Object System.Windows.Forms.Button
    $btnBattery.Text = "Reporte de Bateria (Health)"
    $btnBattery.Location = New-Object System.Drawing.Point(30, 150)
    $btnBattery.Size = New-Object System.Drawing.Size(250, 50)
    $btnBattery.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnBattery.ForeColor = [System.Drawing.Color]::LightGreen
    $btnBattery.FlatStyle = "Flat"
    $btnBattery.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $grpOptions.Controls.Add($btnBattery)

    $lblBattery = New-Object System.Windows.Forms.Label
    $lblBattery.Text = "Historial de uso, capacidad real vs diseño y ciclos de carga."
    $lblBattery.Location = New-Object System.Drawing.Point(300, 155)
    $lblBattery.Size = New-Object System.Drawing.Size(400, 40)
    $grpOptions.Controls.Add($lblBattery)

    # -- OPCION C: SLEEP STUDY --
    $btnSleep = New-Object System.Windows.Forms.Button
    $btnSleep.Text = "Sleep Study (Suspension)"
    $btnSleep.Location = New-Object System.Drawing.Point(30, 210)
    $btnSleep.Size = New-Object System.Drawing.Size(250, 50)
    $btnSleep.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSleep.ForeColor = [System.Drawing.Color]::White
    $btnSleep.FlatStyle = "Flat"
    $btnSleep.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $grpOptions.Controls.Add($btnSleep)

    $lblSleep = New-Object System.Windows.Forms.Label
    $lblSleep.Text = "Diagnostica drenaje de bateria durante la suspension (Modern Standby)."
    $lblSleep.Location = New-Object System.Drawing.Point(300, 215)
    $lblSleep.Size = New-Object System.Drawing.Size(400, 40)
    $grpOptions.Controls.Add($lblSleep)

    # --- 4. BARRA DE ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 390)
    $progressBar.Size = New-Object System.Drawing.Size(740, 20)
    $progressBar.Style = "Blocks" # Estilo sólido para llenado real
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo para analizar."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 420)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    $btnOpenFolder = New-Object System.Windows.Forms.Button
    $btnOpenFolder.Text = "Abrir Carpeta"
    $btnOpenFolder.Location = New-Object System.Drawing.Point(560, 450)
    $btnOpenFolder.Size = New-Object System.Drawing.Size(200, 40)
    $btnOpenFolder.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $btnOpenFolder.ForeColor = [System.Drawing.Color]::White
    $btnOpenFolder.FlatStyle = "Flat"
    $form.Controls.Add($btnOpenFolder)

    $btnCancelAnalysis = New-Object System.Windows.Forms.Button
    $btnCancelAnalysis.Text = 'Cancelar analisis'
    $btnCancelAnalysis.Location = New-Object System.Drawing.Point(340, 450)
    $btnCancelAnalysis.Size = New-Object System.Drawing.Size(200, 40)
    $btnCancelAnalysis.BackColor = [System.Drawing.Color]::Maroon
    $btnCancelAnalysis.ForeColor = [System.Drawing.Color]::White
    $btnCancelAnalysis.FlatStyle = 'Flat'
    $btnCancelAnalysis.Enabled = $false
    $form.Controls.Add($btnCancelAnalysis)

    # --- VARIABLES DE ESTADO Y SINCRONIZACION ---
    $powerState = [PSCustomObject]@{
        ActiveProcess = $null
        ActiveReportPath = ""
        StartTime = $null
        TargetDuration = 0
    }

    # --- 5. EL MONITOR ASINCRONO (TIMER DE CUENTA REGRESIVA) ---
    $monitorTimer = New-Object System.Windows.Forms.Timer
    $monitorTimer.Interval = 1000 # Actualizar cada segundo

    $monitorTimer.Add_Tick({
        # Calcular tiempo
        if ($powerState.StartTime) {
            $elapsed = (Get-Date) - $powerState.StartTime
            $secondsElapsed = [int]$elapsed.TotalSeconds
            
            # Calculo inverso: Cuantos segundos faltan
            $secondsRemaining = $powerState.TargetDuration - $secondsElapsed
            if ($secondsRemaining -lt 0) { $secondsRemaining = 0 }

            # Actualizar Barra (Se llena hacia arriba)
            if ($secondsElapsed -le $progressBar.Maximum) {
                $progressBar.Value = $secondsElapsed
            }

            # Actualizar Texto (Cuenta Regresiva)
            $lblStatus.Text = "Analizando... Quedan $secondsRemaining segundos."
        }

        # Verificar si el proceso sigue vivo
        if ($null -ne $powerState.ActiveProcess -and -not $powerState.ActiveProcess.HasExited) {
            return
        }

        # --- EL PROCESO TERMINO ---
        $monitorTimer.Stop()
        $progressBar.Value = $progressBar.Maximum # Llenar barra al 100%
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        
        # Reactivar botones
        $btnEnergy.Enabled = $true; $btnBattery.Enabled = $true; $btnSleep.Enabled = $true
        $btnCancelAnalysis.Enabled = $false

        # Analizar resultados
        if ($powerState.ActiveProcess.ExitCode -eq 0 -and (Test-Path -LiteralPath $powerState.ActiveReportPath)) {
            $lblStatus.Text = "Reporte generado con exito."
            $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
            
            if ([System.Windows.Forms.MessageBox]::Show("Reporte generado exitosamente.`n`nDeseas abrirlo ahora?", "Completado", 'YesNo', 'Information') -eq 'Yes') {
                Start-Process $powerState.ActiveReportPath
            }
        } else {
            $lblStatus.Text = "Fallo al generar el reporte."
            $lblStatus.ForeColor = [System.Drawing.Color]::Salmon
            [System.Windows.Forms.MessageBox]::Show("El comando fallo.`nAsegurate de ejecutar como Administrador.`nCodigo: $($powerState.ActiveProcess.ExitCode)", "Error", 0, 16)
        }
    })

    # --- LOGICA DE INICIO ---
    $StartAnalysis = {
        param($Type)
        
        # Preparar Directorios
        $parentDir = Split-Path -Parent $PSScriptRoot
        $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
        if (-not (Test-Path $diagDir)) { New-Item -Path $diagDir -ItemType Directory | Out-Null }
        
        $date = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $cmdArgs = ""
        $duration = 0
        
        switch ($Type) {
            'Energy' {
                $duration = [int]$numDuration.Value
                $lblStatus.Text = "Iniciando analisis de ENERGIA ($duration seg)..."
                $powerState.ActiveReportPath = Join-Path $diagDir "Energy_Report_$date.html"
                $cmdArgs = "/energy /output `"$($powerState.ActiveReportPath)`" /duration $duration"
            }
            'Battery' {
                $duration = 5 # Estimado visual
                $lblStatus.Text = "Generando reporte de BATERIA..."
                $powerState.ActiveReportPath = Join-Path $diagDir "Battery_Report_$date.html"
                $cmdArgs = "/batteryreport /output `"$($powerState.ActiveReportPath)`""
            }
            'Sleep' {
                $duration = 5 # Estimado visual
                $lblStatus.Text = "Analizando SUSPENSION..."
                $powerState.ActiveReportPath = Join-Path $diagDir "Sleep_Study_$date.html"
                $cmdArgs = "/sleepstudy /output `"$($powerState.ActiveReportPath)`""
            }
        }

        # Configurar UI
        $btnEnergy.Enabled = $false; $btnBattery.Enabled = $false; $btnSleep.Enabled = $false
        $btnCancelAnalysis.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
        
        # Configurar Barra
        $progressBar.Style = "Blocks"
        $progressBar.Minimum = 0
        $progressBar.Maximum = $duration
        $progressBar.Value = 0
        
        # Guardar duración objetivo para la cuenta regresiva
        $powerState.TargetDuration = $duration
        
        # Iniciar
        try {
            $powerState.StartTime = Get-Date
            $powerState.ActiveProcess = Start-Process "powercfg.exe" -ArgumentList $cmdArgs -WindowStyle Hidden -PassThru
            $monitorTimer.Start()
        } catch {
            $lblStatus.Text = "Error al iniciar proceso: $_"
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $btnEnergy.Enabled = $true; $btnBattery.Enabled = $true; $btnSleep.Enabled = $true
            $btnCancelAnalysis.Enabled = $false
        }
    }

    # --- EVENTOS ---
    $btnEnergy.Add_Click({ & $StartAnalysis -Type 'Energy' })
    $btnBattery.Add_Click({ & $StartAnalysis -Type 'Battery' })
    $btnSleep.Add_Click({ & $StartAnalysis -Type 'Sleep' })
    $btnCancelAnalysis.Add_Click({
        if ($powerState.ActiveProcess -and -not $powerState.ActiveProcess.HasExited) {
            try {
                Stop-Process -Id $powerState.ActiveProcess.Id -Force -ErrorAction Stop
                $monitorTimer.Stop()
                $lblStatus.Text = 'Analisis cancelado por el usuario.'
                $lblStatus.ForeColor = [System.Drawing.Color]::Orange
            } catch {
                $lblStatus.Text = "No se pudo cancelar: $($_.Exception.Message)"
            } finally {
                $btnEnergy.Enabled = $true; $btnBattery.Enabled = $true; $btnSleep.Enabled = $true
                $btnCancelAnalysis.Enabled = $false
            }
        }
    })
    
    $btnOpenFolder.Add_Click({
        $parentDir = Split-Path -Parent $PSScriptRoot
        $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
        if (Test-Path $diagDir) { Start-Process $diagDir }
    })

    # Limpieza al cerrar
    $form.Add_FormClosing({
        $monitorTimer.Stop()
        if ($null -ne $powerState.ActiveProcess -and -not $powerState.ActiveProcess.HasExited) {
            try { Stop-Process -Id $powerState.ActiveProcess.Id -Force -ErrorAction Stop }
            catch { Write-Log -LogLevel WARN -Message "POWERCFG: No se pudo detener el proceso al cerrar: $($_.Exception.Message)" }
        }
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# ===================================================================
# MODULO DE RECONSTRUCCION DEL INDICE DE BUSQUEDA
# ===================================================================

function Rebuild-SearchIndex {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Log -LogLevel INFO -Message "MANTENIMIENTO: Usuario inicio la reconstruccion del indice de busqueda."
    Write-Host "`n[+] Reconstruyendo el Indice de Busqueda de Windows..." -ForegroundColor Cyan
    Write-Warning "Esta operacion eliminara la base de datos de busqueda actual (.edb)."
    Write-Warning "El sistema tardara un tiempo en volver a indexar tus archivos (puede haber consumo de CPU)."

    if (-not ($PSCmdlet.ShouldProcess("Base de Datos de Busqueda", "Eliminar y Regenerar desde Cero"))) { 
        return 
    }

    $service = $null
    $originalStartType = $null
    $originalWasRunning = $false
    $setupFlagOriginal = $null
    $completed = $false
    $searchDbPath = $null
    $indexBackupPath = $null
    $journal = $null

    try {
        # 1. Detener el servicio Windows Search
        Write-Host "   - Deteniendo servicio Windows Search (WSearch)..." -ForegroundColor Gray
        $service = Get-Service -Name "WSearch" -ErrorAction Stop
        $originalStartType = [string]$service.StartType
        $originalWasRunning = ($service.Status -eq 'Running')
        
        if ($originalWasRunning) {
            Stop-Service -Name "WSearch" -Force -ErrorAction Stop
        }

        # 2. Localizar la ruta real de la base de datos (No asumir ProgramData)
        Write-Host "   - Localizando ubicacion del indice..." -ForegroundColor Gray
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Search"
        $regValues = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $dataDir = $regValues.DataDirectory
        $setupFlagOriginal = $regValues.SetupCompletedSuccessfully

        if ([string]::IsNullOrWhiteSpace($dataDir)) {
            # Fallback seguro si el registro falla
            $dataDir = "$env:ProgramData\Microsoft\Search\Data"
        }

        $dataDir = [Environment]::ExpandEnvironmentVariables([string]$dataDir)
        $dataDirFull = [System.IO.Path]::GetFullPath($dataDir).TrimEnd('\')
        $dataRoot = [System.IO.Path]::GetPathRoot($dataDirFull).TrimEnd('\')
        if ([string]::IsNullOrWhiteSpace($dataDirFull) -or $dataDirFull.Equals($dataRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "La ruta DataDirectory no es segura: '$dataDirFull'."
        }

        $searchDbPath = [System.IO.Path]::GetFullPath((Join-Path $dataDirFull "Applications\Windows")).TrimEnd('\')
        if (-not $searchDbPath.StartsWith($dataDirFull + '\', [StringComparison]::OrdinalIgnoreCase) -or
            -not $searchDbPath.EndsWith('\Applications\Windows', [StringComparison]::OrdinalIgnoreCase)) {
            throw "La ruta calculada de la base de busqueda no supero la validacion: '$searchDbPath'."
        }
        if (-not $PSCmdlet.ShouldProcess($searchDbPath, "Eliminar exclusivamente la base del indice y regenerarla")) { return }
        $indexBackupRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Backup\SearchIndex'
        if (-not (Test-Path -LiteralPath $indexBackupRoot)) { New-Item -Path $indexBackupRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        $indexBackupPath = Join-Path $indexBackupRoot ("Windows_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
        $journal = New-AegisOperationJournal -Module 'Sistema' -Action 'RebuildSearchIndex' -Targets @($searchDbPath) -Metadata @{ BackupPath=$indexBackupPath }

        # 3. Mover la base anterior a un respaldo recuperable.
        if (Test-Path -LiteralPath $searchDbPath -PathType Container) {
            Write-Host "   - Respaldando base de datos anterior en: $indexBackupPath" -ForegroundColor Yellow
            try {
                Move-Item -LiteralPath $searchDbPath -Destination $indexBackupPath -Force -ErrorAction Stop
            } catch {
                Write-Host "     (Archivo bloqueado, reintentando en 2s...)" -ForegroundColor DarkGray
                Start-Sleep -Seconds 2
                Move-Item -LiteralPath $searchDbPath -Destination $indexBackupPath -Force -ErrorAction Stop
            }
            Write-Log -LogLevel ACTION -Message "MANTENIMIENTO: Base de busqueda respaldada antes de reconstruir."
        } else {
            Write-Host "   - No se encontro base de datos previa (o ya estaba limpia)." -ForegroundColor Gray
        }

        # 4. Truco Pro: Resetear bandera de configuracion
        # Esto obliga a Windows a verificar las ubicaciones de indexado al arrancar
        Set-ItemProperty -Path $regPath -Name "SetupCompletedSuccessfully" -Value 0 -Type DWord -Force -ErrorAction Stop

        # 5. Reiniciar el servicio (CON VALIDACION DE ESTADO)
        Write-Host "   - Reiniciando servicio Windows Search..." -ForegroundColor Gray
        
        # Refrescamos el objeto del servicio para ver su estado actual
        if ($originalStartType -eq 'Disabled') {
            Write-Warning "El servicio WSearch estaba deshabilitado. Reactivandolo temporalmente para reconstruir el indice..."
            Set-Service -Name "WSearch" -StartupType Automatic -ErrorAction Stop
            Write-Log -LogLevel WARN -Message "MANTENIMIENTO: Se reactivo WSearch (estaba Disabled) para reconstruccion."
        }
        
        Start-Service -Name "WSearch" -ErrorAction Stop
        $completed = $true
        Complete-AegisOperationJournal -Journal $journal -Status Completed -Results @("Backup anterior: $indexBackupPath") | Out-Null

        Write-Host "`n[OK] Indice restablecido correctamente." -ForegroundColor Green
        Write-Host "      Windows comenzara a re-indexar en segundo plano inmediatamente." -ForegroundColor Cyan

    } catch {
        if ($journal) { Complete-AegisOperationJournal -Journal $journal -Status Failed -Results @($_.Exception.Message) | Out-Null }
        Write-Error "Fallo critico al reconstruir el indice: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "MANTENIMIENTO: Fallo reconstruccion de indice. Error: $($_.Exception.Message)"
        
    } finally {
        if ($service) {
            try {
                if (-not $originalWasRunning) {
                    $currentService = Get-Service -Name "WSearch" -ErrorAction Stop
                    if ($currentService.Status -eq 'Running') { Stop-Service -Name "WSearch" -Force -ErrorAction Stop }
                }
                $restoreType = switch ($originalStartType) {
                    'Automatic' { 'Automatic' }
                    'Manual' { 'Manual' }
                    'Disabled' { 'Disabled' }
                    default { 'Manual' }
                }
                Set-Service -Name "WSearch" -StartupType $restoreType -ErrorAction Stop
                if ($originalWasRunning) { Start-Service -Name "WSearch" -ErrorAction Stop }
            } catch {
                Write-Warning "No se pudo restaurar completamente el estado original de WSearch: $($_.Exception.Message)"
                Write-Log -LogLevel ERROR -Message "WSEARCH: Fallo restaurando estado original: $($_.Exception.Message)"
            }
        }
        if (-not $completed -and $null -ne $setupFlagOriginal) {
            Set-ItemProperty -Path $regPath -Name "SetupCompletedSuccessfully" -Value $setupFlagOriginal -Type DWord -Force -ErrorAction SilentlyContinue
        }
        if (-not $completed -and $indexBackupPath -and (Test-Path -LiteralPath $indexBackupPath)) {
            try {
                if ($searchDbPath -and (Test-Path -LiteralPath $searchDbPath)) {
                    Remove-Item -LiteralPath $searchDbPath -Recurse -Force -ErrorAction Stop
                }
                Move-Item -LiteralPath $indexBackupPath -Destination $searchDbPath -Force -ErrorAction Stop
                Write-Log -LogLevel ACTION -Message 'WSEARCH: La base anterior fue restaurada tras el fallo.'
            } catch {
                Write-Log -LogLevel ERROR -Message "WSEARCH: No se pudo restaurar la base anterior: $($_.Exception.Message)"
            }
        }
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}