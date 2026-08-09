<#
.SYNOPSIS
    Suite de optimizacion, gestion, seguridad y diagnostico para Windows 11 y 10.
.DESCRIPTION
    Aegis Phoenix Suite v5 by SOFTMAXTER es la herramienta PowerShell. Con una estructura de submenus y una
    logica de verificacion inteligente, permite maximizar el rendimiento, reforzar la seguridad, gestionar
    software y drivers, y personalizar la experiencia de usuario.
    Requiere ejecucion como Administrador.
.AUTHOR
    SOFTMAXTER
.VERSION
    4.9.6

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

#>

$script:Version = "4.9.6"
$script:SoftwareEngine = 'Winget'
$script:AegisScriptRoot = $PSScriptRoot

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('INFO', 'ACTION', 'WARN', 'ERROR')]
        [string]$LogLevel,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    try {
        $parentDir = Split-Path -Parent $PSScriptRoot
        $logDir = Join-Path -Path $parentDir -ChildPath "Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        $logFile = Join-Path -Path $logDir -ChildPath "Registro.log"
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] [$LogLevel] - $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
    catch {
        Write-Warning "No se pudo escribir en el archivo de log: $_"
    }
}

function Write-AegisJsonAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$InputObject,
        [Parameter(Mandatory=$true)][string]$Path,
        [ValidateRange(2, 100)][int]$Depth = 12
    )

    $directory = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($directory)) { throw "La ruta JSON no contiene un directorio valido." }
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $tempPath = Join-Path $directory ((Split-Path -Leaf $Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $InputObject | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
        if (Test-Path -LiteralPath $Path) {
            $backupPath = "$Path.previous"
            [System.IO.File]::Replace($tempPath, $Path, $backupPath, $true)
        } else {
            [System.IO.File]::Move($tempPath, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function ConvertTo-AegisNativeArgument {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Argument)

    if ($null -eq $Argument -or $Argument.Length -eq 0) { return '""' }
    if ($Argument -notmatch '[\s"]') { return $Argument }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq '\') {
            $slashes++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($slashes * 2) + 1)))
            [void]$builder.Append('"')
            $slashes = 0
            continue
        }
        if ($slashes -gt 0) {
            [void]$builder.Append(('\' * $slashes))
            $slashes = 0
        }
        [void]$builder.Append($character)
    }
    if ($slashes -gt 0) { [void]$builder.Append(('\' * ($slashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-AegisNativeProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [ValidateRange(0, 86400)][int]$TimeoutSeconds = 0,
        [int[]]$ValidExitCodes = @(0),
        [string]$WorkingDirectory,
        [switch]$StreamOutput,
        [switch]$NoThrow
    )

    $resolvedCommand = Get-Command $FilePath -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolvedCommand -and -not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "No se encontro el ejecutable requerido: $FilePath"
    }
    $resolvedPath = if ($resolvedCommand) { $resolvedCommand.Source } else { $FilePath }
    if ([string]::IsNullOrWhiteSpace($resolvedPath)) { $resolvedPath = $FilePath }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $resolvedPath
    $startInfo.Arguments = (($ArgumentList | ForEach-Object { ConvertTo-AegisNativeArgument -Argument ([string]$_) }) -join ' ')
    $startInfo.UseShellExecute = $false
    # Para transmisión directa, el proceso debe permanecer unido a la consola
    # de Aegis; en modo capturado se mantiene completamente oculto.
    $startInfo.CreateNoWindow = -not $StreamOutput
    # Con StreamOutput el proceso hereda la consola actual. Esto conserva en
    # tiempo real barras de progreso y mensajes interactivos de herramientas
    # como DISM y SFC. Sin el modificador, la salida se captura como antes.
    $startInfo.RedirectStandardOutput = -not $StreamOutput
    $startInfo.RedirectStandardError = -not $StreamOutput
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) { $startInfo.WorkingDirectory = $WorkingDirectory }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $startedAt = Get-Date
    $timedOut = $false
    $stdout = ''
    $stderr = ''
    try {
        if (-not $process.Start()) { throw "No fue posible iniciar '$FilePath'." }
        if (-not $StreamOutput) {
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
        }
        if ($TimeoutSeconds -gt 0) {
            if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
                $timedOut = $true
                try { $process.Kill() } catch {}
                $process.WaitForExit()
            }
        } else {
            $process.WaitForExit()
        }
        if (-not $StreamOutput) {
            $stdout = $stdoutTask.Result
            $stderr = $stderrTask.Result
        }
        $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    } finally {
        $process.Dispose()
    }

    $result = [PSCustomObject]@{
        FilePath   = $resolvedPath
        Arguments  = @($ArgumentList)
        ExitCode   = $exitCode
        TimedOut   = $timedOut
        Succeeded  = (-not $timedOut -and $exitCode -in $ValidExitCodes)
        StdOut     = [string]$stdout
        StdErr     = [string]$stderr
        OutputWasStreamed = [bool]$StreamOutput
        DurationMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds)
    }
    if (-not $result.Succeeded -and -not $NoThrow) {
        $reason = if ($timedOut) { "Tiempo de espera agotado ($TimeoutSeconds s)." } else { "Codigo de salida $exitCode." }
        $detail = @($stderr, $stdout) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
        throw "$FilePath fallo. $reason $detail"
    }
    return $result
}

function Test-AegisCapability {
    [CmdletBinding()]
    param(
        [string]$Command,
        [int]$MinimumBuild = 0
    )
    if ($Command -and -not (Get-Command $Command -ErrorAction SilentlyContinue)) { return $false }
    if ($MinimumBuild -gt 0) {
        try {
            $build = [int](Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).BuildNumber
            if ($build -lt $MinimumBuild) { return $false }
        } catch { return $false }
    }
    return $true
}

function ConvertTo-AegisHtmlSafe {
    [CmdletBinding()]
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Read-AegisSafeXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [ValidateRange(1024, 104857600)][long]$MaxCharacters = 5242880
    )
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -gt $MaxCharacters) { throw "El XML excede el limite permitido de $MaxCharacters bytes." }
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.MaxCharactersInDocument = $MaxCharacters
    $reader = [System.Xml.XmlReader]::Create($item.FullName, $settings)
    try {
        $document = New-Object System.Xml.XmlDocument
        $document.XmlResolver = $null
        $document.Load($reader)
        return $document
    } finally {
        $reader.Dispose()
    }
}

function New-AegisOperationJournal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Module,
        [Parameter(Mandatory=$true)][string]$Action,
        [object[]]$Targets = @(),
        [hashtable]$Metadata = @{}
    )
    $root = Join-Path (Split-Path -Parent $PSScriptRoot) 'Backup\Operations'
    if (-not (Test-Path -LiteralPath $root)) { New-Item -Path $root -ItemType Directory -Force -ErrorAction Stop | Out-Null }
    $id = '{0}_{1}_{2}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), ($Module -replace '[^a-zA-Z0-9_-]', '_'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $path = Join-Path $root "$id.json"
    $data = [ordered]@{
        SchemaVersion = 1
        Id = $id
        Module = $Module
        Action = $Action
        StartedAt = (Get-Date).ToString('o')
        CompletedAt = $null
        Status = 'Started'
        Targets = @($Targets)
        Metadata = $Metadata
        Results = @()
    }
    Write-AegisJsonAtomic -InputObject $data -Path $path
    return [PSCustomObject]@{ Path = $path; Data = $data }
}

function Complete-AegisOperationJournal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Journal,
        [ValidateSet('Completed','Partial','Failed','Cancelled')][string]$Status,
        [object[]]$Results = @()
    )
    $Journal.Data.Status = $Status
    $Journal.Data.CompletedAt = (Get-Date).ToString('o')
    $Journal.Data.Results = @($Results)
    Write-AegisJsonAtomic -InputObject $Journal.Data -Path $Journal.Path
    return $Journal.Path
}

# --- INICIO DEL MODULO DE AUTO-ACTUALIZACION ---
function Invoke-FullRepoUpdater {
    $repoUser = "SOFTMAXTER"
    $repoName = "Aegis-Phoenix-Suite"
    $repoBranch = "main"
    $versionUrl = "https://raw.githubusercontent.com/$repoUser/$repoName/$repoBranch/version.txt"
    $zipUrl = "https://github.com/$repoUser/$repoName/archive/refs/heads/$repoBranch.zip"

    $updateAvailable = $false
    $remoteVersionStr = ""
    $changelog = @()

    try {
        $response = Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 5 -ErrorAction Stop

        # Separar el contenido del archivo por saltos de linea
        $lines = $response.Content -split "`r?`n" | ForEach-Object { $_.Trim() }

        if ($lines.Count -gt 0) {
            # La primera linea es la version; se elimina una 'v' inicial si existe.
            $remoteVersionStr = $lines[0] -replace '(?i)^v', ''

            # Extraer las novedades entre separadores.
            $inChangelog = $false
            for ($i = 1; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "^====+") {
                    if (-not $inChangelog) {
                        $inChangelog = $true
                        continue
                    } else {
                        break
                    }
                }

                if ($inChangelog -and -not [string]::IsNullOrWhiteSpace($lines[$i])) {
                    $changelog += $lines[$i]
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($remoteVersionStr)) {
            throw "El servidor devolvio un archivo de version vacio o no valido."
        }

        try {
            if ([System.Version]$remoteVersionStr -gt [System.Version]$script:Version) {
                $updateAvailable = $true
            }
        }
        catch {
            Write-Log -LogLevel WARN -Message "UPDATER: No fue posible comparar las versiones como System.Version. Se usara comparacion de texto. Detalle: $($_.Exception.Message)"
            if ($remoteVersionStr -ne $script:Version) {
                $updateAvailable = $true
            }
        }
    }
    catch {
        $line = $_.InvocationInfo.ScriptLineNumber
        Write-Log -LogLevel ERROR -Message "UPDATER: Fallo la comprobacion de actualizaciones. Error: $($_.Exception.Message). Linea: $line."
        return
    }

    if (-not $updateAvailable) {
        return
    }

    Write-Log -LogLevel INFO -Message "UPDATER: Version remota detectada: v$remoteVersionStr. Version local: v$($script:Version)."
    Write-Log -LogLevel INFO -Message "UPDATER: Nueva version disponible: v$remoteVersionStr."

    Write-Host ""
    Write-Host "  =======================================================" -ForegroundColor Cyan
    Write-Host "           NUEVA VERSION DISPONIBLE DETECTADA!          " -ForegroundColor Green
    Write-Host "  =======================================================" -ForegroundColor Cyan
    Write-Host "     Version Local  : v$($script:Version)" -ForegroundColor Gray
    Write-Host "     Version Remota : v$remoteVersionStr" -ForegroundColor Yellow

    if ($changelog.Count -gt 0) {
        Write-Host "  -------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "     NOVEDADES Y CAMBIOS: " -ForegroundColor Magenta
        foreach ($line in $changelog) {
            Write-Host "      $line" -ForegroundColor White
        }
    }
    Write-Host "  =======================================================" -ForegroundColor Cyan

    $updateChoice = (Read-Host "`n  [?] Deseas descargar e instalar la actualizacion ahora? (S/N)").ToUpper()
    if ($updateChoice -ne 'S') {
        Write-Host "`n  [i] Actualizacion pospuesta por el usuario." -ForegroundColor Gray
        Write-Log -LogLevel INFO -Message "UPDATER: Actualizacion a v$remoteVersionStr pospuesta por el usuario. Respuesta: '$updateChoice'."
        Start-Sleep -Seconds 1
        return
    }

    Write-Log -LogLevel ACTION -Message "UPDATER: El usuario acepto instalar la version v$remoteVersionStr."
    Write-Host "`n  [!] Preparando la actualizacion de forma segura..." -ForegroundColor Magenta

    $installPath = $null
    $tempZip = $null
    $tempExtract = $null
    $batPath = $null

    try {
        # Determinar de forma segura la carpeta raiz de instalacion.
        # AegisPhoenixSuite.ps1 vive en \Script, por eso usamos su carpeta padre.
        $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            $PSScriptRoot
        } elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
            Split-Path -Path $PSCommandPath -Parent
        } else {
            $PWD.Path
        }

        $installPath = Split-Path -Path $scriptRoot -Parent
        if ([string]::IsNullOrWhiteSpace($installPath) -or -not (Test-Path -LiteralPath $installPath -PathType Container)) {
            throw "No se pudo determinar una ruta de instalacion valida. ScriptRoot: '$scriptRoot'"
        }

        Write-Log -LogLevel INFO -Message "UPDATER: Ruta de instalacion resuelta: '$installPath'."

        $tempZip = Join-Path -Path $installPath -ChildPath "update.zip"
        $tempExtract = Join-Path -Path $installPath -ChildPath "update_extracted"
        $batPath = Join-Path -Path $installPath -ChildPath "ApplyUpdate.cmd"
        $exePath = Join-Path -Path $installPath -ChildPath "AegisPhoenixSuite.exe"

        if (Test-Path -LiteralPath $tempExtract) {
            Write-Log -LogLevel ACTION -Message "UPDATER: Eliminando carpeta temporal anterior '$tempExtract'."
            Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction Stop
        }

        if (Test-Path -LiteralPath $tempZip) {
            Write-Log -LogLevel ACTION -Message "UPDATER: Eliminando paquete temporal anterior '$tempZip'."
            Remove-Item -LiteralPath $tempZip -Force -ErrorAction Stop
        }

        if (Test-Path -LiteralPath $batPath) {
            Write-Log -LogLevel ACTION -Message "UPDATER: Eliminando instalador temporal anterior '$batPath'."
            Remove-Item -LiteralPath $batPath -Force -ErrorAction Stop
        }

        Write-Host "   > Descargando paquete (v$remoteVersionStr)..." -ForegroundColor Cyan
        Write-Log -LogLevel ACTION -Message "UPDATER: Descargando paquete v$remoteVersionStr desde '$zipUrl'."
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop

        if (-not (Test-Path -LiteralPath $tempZip -PathType Leaf)) {
            throw "La descarga finalizo sin crear el archivo '$tempZip'."
        }

        $downloadSize = (Get-Item -LiteralPath $tempZip -ErrorAction Stop).Length
        if ($downloadSize -le 0) {
            throw "El paquete descargado esta vacio."
        }
        Write-Log -LogLevel INFO -Message "UPDATER: Descarga completada. Archivo: '$tempZip'. Tamano: $downloadSize bytes."

        Write-Host "   > Extrayendo archivos..." -ForegroundColor Cyan
        Write-Log -LogLevel ACTION -Message "UPDATER: Extrayendo paquete en '$tempExtract'."
        Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop

        $repoExtractedPath = Join-Path -Path $tempExtract -ChildPath "Aegis-Phoenix-Suite-main"
        if (-not (Test-Path -LiteralPath $repoExtractedPath -PathType Container)) {
            throw "La estructura esperada del paquete no existe: '$repoExtractedPath'."
        }
        Write-Log -LogLevel INFO -Message "UPDATER: Extraccion completada correctamente."

        Write-Host "   > Generando motor de inyeccion..." -ForegroundColor Cyan
        Write-Log -LogLevel ACTION -Message "UPDATER: Generando instalador diferido '$batPath'."

        # El proceso CMD continua despues de que PowerShell termina; por eso
        # escribe directamente en Logs\Registro.log.
        # Guardamos el PID actual para que ApplyUpdate.cmd espere de forma
        # dinamica a que este proceso libere los archivos, sin depender de
        # un timeout fijo.
        $updaterParentPid = $PID

        $batContent = @"
@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Instalando Actualizacion...
color 0B

set "LOGDIR=%~dp0Logs"
set "LOGFILE=%LOGDIR%\Registro.log"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >NUL 2>&1

echo [%date% %time:~0,8%] [ACTION] - UPDATER CMD: Proceso de instalacion iniciado. Version destino: v$remoteVersionStr.>>"%LOGFILE%"
echo [%date% %time:~0,8%] [INFO] - UPDATER CMD: Ruta de instalacion: %~dp0>>"%LOGFILE%"

echo.
echo =========================================================
echo    APLICANDO ACTUALIZACION A LA VERSION $remoteVersionStr
echo =========================================================
echo.
echo Esperando a que el sistema libere los archivos...
echo [%date% %time:~0,8%] [ACTION] - UPDATER CMD: Esperando cierre del proceso origen PID $updaterParentPid.>>"%LOGFILE%"

set /a "WAIT_COUNT=0"
:WAIT_PARENT_PROCESS
tasklist /FI "PID eq $updaterParentPid" /NH 2^>NUL | findstr /R /C:"[ ]$updaterParentPid[ ]" >NUL
if errorlevel 1 goto PARENT_RELEASED

set /a "WAIT_COUNT+=1"
if !WAIT_COUNT! GEQ 30 (
    echo [%date% %time:~0,8%] [WARN] - UPDATER CMD: El proceso PID $updaterParentPid sigue activo tras 30 segundos. Se continuara con la actualizacion.>>"%LOGFILE%"
    goto PARENT_RELEASED
)

rem Pausa aproximada de 1 segundo sin depender de un timeout fijo global.
ping 127.0.0.1 -n 2 >NUL
goto WAIT_PARENT_PROCESS

:PARENT_RELEASED
echo [%date% %time:~0,8%] [INFO] - UPDATER CMD: Archivos liberados tras !WAIT_COUNT! segundo(s) de espera.>>"%LOGFILE%"

echo Instalando nuevos archivos...
echo [%date% %time:~0,8%] [ACTION] - UPDATER CMD: Copiando archivos nuevos sobre la instalacion.>>"%LOGFILE%"
xcopy /Y /E /H /C /I "%~dp0update_extracted\Aegis-Phoenix-Suite-main\*" "%~dp0" >NUL 2>&1
set "XCOPY_EXIT=!ERRORLEVEL!"

if not "!XCOPY_EXIT!"=="0" (
    echo [%date% %time:~0,8%] [ERROR] - UPDATER CMD: XCOPY fallo. Codigo de salida: !XCOPY_EXIT!. Los temporales se conservaran para diagnostico.>>"%LOGFILE%"
    echo.
    echo [ERROR] No se pudo aplicar la actualizacion. Codigo XCOPY: !XCOPY_EXIT!
    echo Revisa Logs\Registro.log para mas detalles.
    timeout /t 8 /nobreak >NUL
    exit /b !XCOPY_EXIT!
)

echo [%date% %time:~0,8%] [INFO] - UPDATER CMD: Archivos de la nueva version copiados correctamente.>>"%LOGFILE%"

echo Limpiando temporales...
echo [%date% %time:~0,8%] [ACTION] - UPDATER CMD: Eliminando archivos temporales de actualizacion.>>"%LOGFILE%"
rmdir /S /Q "%~dp0update_extracted" 2>NUL
if errorlevel 1 echo [%date% %time:~0,8%] [WARN] - UPDATER CMD: No se pudo eliminar completamente update_extracted.>>"%LOGFILE%"

del /F /Q "%~dp0update.zip" 2>NUL
if errorlevel 1 echo [%date% %time:~0,8%] [WARN] - UPDATER CMD: No se pudo eliminar update.zip.>>"%LOGFILE%"

echo Reiniciando aplicacion...
if not exist "$exePath" (
    echo [%date% %time:~0,8%] [ERROR] - UPDATER CMD: No se encontro el ejecutable '$exePath' despues de aplicar la actualizacion.>>"%LOGFILE%"
    echo [ERROR] No se encontro AegisPhoenixSuite.exe.
    timeout /t 8 /nobreak >NUL
    exit /b 10
)

echo [%date% %time:~0,8%] [ACTION] - UPDATER CMD: Reiniciando AegisPhoenixSuite.exe.>>"%LOGFILE%"
start "" "$exePath"
set "START_EXIT=!ERRORLEVEL!"
if not "!START_EXIT!"=="0" (
    echo [%date% %time:~0,8%] [ERROR] - UPDATER CMD: No se pudo reiniciar la aplicacion. Codigo: !START_EXIT!.>>"%LOGFILE%"
    exit /b !START_EXIT!
)

echo [%date% %time:~0,8%] [INFO] - UPDATER CMD: Actualizacion a v$remoteVersionStr aplicada correctamente.>>"%LOGFILE%"
del "%~f0"
"@

        [System.IO.File]::WriteAllText($batPath, $batContent, [System.Text.Encoding]::ASCII)
        if (-not (Test-Path -LiteralPath $batPath -PathType Leaf)) {
            throw "No se pudo generar '$batPath'."
        }
        Write-Log -LogLevel INFO -Message "UPDATER: Instalador diferido generado correctamente."

        Write-Host "`n  [!] El sistema se cerrara para aplicar los cambios." -ForegroundColor Red
        Write-Log -LogLevel ACTION -Message "UPDATER: Lanzando ApplyUpdate.cmd y cerrando la sesion actual para liberar archivos."
        Start-Sleep -Seconds 2

        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -ErrorAction Stop | Out-Null
        Write-Log -LogLevel INFO -Message "UPDATER: ApplyUpdate.cmd iniciado correctamente. El registro continuara desde el proceso CMD."
        exit
    }
    catch {
        $errorMessage = $_.Exception.Message
        $errorType = $_.Exception.GetType().FullName
        $errorLine = $_.InvocationInfo.ScriptLineNumber

        Write-Host "`n  [ERROR] Fallo la actualizacion: $errorMessage" -ForegroundColor Red
        Write-Log -LogLevel ERROR -Message "UPDATER: Fallo durante la preparacion de la actualizacion. Error: $errorMessage. Tipo: $errorType. Linea: $errorLine."

        if ($tempZip -and (Test-Path -LiteralPath $tempZip)) {
            try {
                Remove-Item -LiteralPath $tempZip -Force -ErrorAction Stop
                Write-Log -LogLevel ACTION -Message "UPDATER: Paquete temporal eliminado tras el error: '$tempZip'."
            }
            catch {
                Write-Log -LogLevel WARN -Message "UPDATER: No se pudo eliminar '$tempZip' despues del error. Motivo: $($_.Exception.Message)"
            }
        }

        if ($tempExtract -and (Test-Path -LiteralPath $tempExtract)) {
            try {
                Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction Stop
                Write-Log -LogLevel ACTION -Message "UPDATER: Carpeta temporal eliminada tras el error: '$tempExtract'."
            }
            catch {
                Write-Log -LogLevel WARN -Message "UPDATER: No se pudo eliminar '$tempExtract' despues del error. Motivo: $($_.Exception.Message)"
            }
        }

        Start-Sleep -Seconds 3
    }
}

Write-Log -LogLevel INFO -Message "================================================="
Write-Log -LogLevel INFO -Message "Aegis Phoenix Suite v$($script:Version) iniciado en modo Administrador."

# --- CARGA DE CATALOGOS EXTERNOS ---
Write-Host "Cargando catalogos..."
try {
    . "$PSScriptRoot\Catalogos\Ajustes.ps1"
    . "$PSScriptRoot\Catalogos\Servicios.ps1"
	. "$PSScriptRoot\Catalogos\Bloatware.ps1"
    . "$PSScriptRoot\Catalogos\EventSolutions.ps1"
}
catch {
    Write-Error "Error critico: No se pudieron cargar los archivos de catalogo."
    Write-Error "Asegurate de que 'Ajustes.ps1', 'Servicios.ps1', 'Bloatware.ps1' y 'EventSolutions.ps1' existen en la subcarpeta 'Catalogos'."
    Read-Host "Presiona Enter para salir."
    exit
}

# --- CARGA DE MODULOS FUNCIONALES (MISMO DIRECTORIO) ---
$script:ModulosFallidos = New-Object System.Collections.Generic.List[string]
$modulosDisponibles = @(Get-ChildItem -Path $PSScriptRoot -Filter "Modulo-*.ps1" -File -ErrorAction SilentlyContinue | Sort-Object Name)

if ($modulosDisponibles.Count -eq 0) {
    Write-Log -LogLevel WARN -Message "No se encontraron archivos Modulo-*.ps1 en '$PSScriptRoot'."
}

# --- Deteccion de posibles duplicados ---
$nombresBase = @($modulosDisponibles | ForEach-Object { $_.BaseName })
$modulosOmitidos = New-Object System.Collections.Generic.List[string]
$modulosACargar = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($modulo in $modulosDisponibles) {
    $esDuplicadoConParentesis = $modulo.BaseName -match '^(?<base>Modulo-.+?)\s*\(\d+\)$'
    $esDuplicadoConSufijo = $false
    if (-not $esDuplicadoConParentesis -and $modulo.BaseName -match '^(?<base>Modulo-.+?)[_\-\s]*(?<num>\d+)$') {
        $baseSinSufijo = $matches['base']
        if ($baseSinSufijo -in $nombresBase) { $esDuplicadoConSufijo = $true }
    }

    if ($esDuplicadoConParentesis -or $esDuplicadoConSufijo) {
        Write-Log -LogLevel WARN -Message "Posible duplicado omitido: '$($modulo.Name)' (coincide con otro modulo base)."
        [void]$modulosOmitidos.Add($modulo.Name)
        continue
    }
    [void]$modulosACargar.Add($modulo)
}

$modulosCargados = 0

foreach ($modulo in $modulosACargar) {
    try {
        . $modulo.FullName
        $modulosCargados++
    }
    catch {
        Write-Log -LogLevel ERROR -Message "Fallo al cargar '$($modulo.Name)': $($_.Exception.Message) (Linea $($_.InvocationInfo.ScriptLineNumber))"
        [void]$script:ModulosFallidos.Add($modulo.Name)
    }
}

Write-Log -LogLevel INFO -Message "Modulos funcionales: $modulosCargados cargados | $($script:ModulosFallidos.Count) fallidos | $($modulosOmitidos.Count) omitidos."

if ($modulosOmitidos.Count -gt 0) {
    Write-Host "`n[ADVERTENCIA] Se omitieron $($modulosOmitidos.Count) archivo(s) por parecer copias duplicadas:" -ForegroundColor Yellow
    foreach ($nombreOmitido in $modulosOmitidos) { Write-Host "  - $nombreOmitido" -ForegroundColor Yellow }
    Write-Host "Revisa cual es la version correcta y elimina las demas manualmente.`n" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

if ($script:ModulosFallidos.Count -gt 0) {
    Write-Host "`n[ADVERTENCIA] $($script:ModulosFallidos.Count) modulo(s) no se cargaron correctamente:" -ForegroundColor Yellow
    foreach ($nombreModulo in $script:ModulosFallidos) { Write-Host "  - $nombreModulo" -ForegroundColor Yellow }
    Write-Host "Revisa Registro.log para mas detalles. Las opciones de esos modulos no estaran disponibles.`n" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

try {
    foreach ($moduleName in $requiredModules) {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath $moduleName
        if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
            throw "No se encontro el modulo requerido: $moduleName"
        }
        . $modulePath
    }
}
catch {
    Write-Error "Error critico al cargar los modulos funcionales: $($_.Exception.Message)"
    Read-Host "Presiona Enter para salir."
    exit
}

# --- Verificacion de Privilegios de Administrador ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script necesita ser ejecutado como Administrador."
    Write-Host "Por favor, cierra esta ventana, haz clic derecho en el archivo del script y selecciona 'Ejecutar como Administrador'."
    Read-Host "Presiona Enter para salir."
    exit
}

# Consultar actualizaciones solo despues de validar archivos locales y
# privilegios. La instalacion siempre requiere confirmacion explicita.
Invoke-FullRepoUpdater

# --- NUEVA FUNCIoN AUXILIAR PARA AJUSTAR TEXTO (WORD WRAP) ---
function Format-WrappedText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,

        [Parameter(Mandatory=$true)]
        [int]$Indent,

        [Parameter(Mandatory=$true)]
        [int]$MaxWidth
    )

    # Calculamos el ancho real disponible para el texto, restando la sangria.
    $wrapWidth = $MaxWidth - $Indent
    if ($wrapWidth -le 0) { $wrapWidth = 1 } # Evitar un ancho negativo o cero

    $words = $Text -split '\s+'
    $lines = [System.Collections.Generic.List[string]]::new()
    $currentLine = ""

    foreach ($word in $words) {
        # Si la linea actual esta vacia, simplemente añadimos la palabra.
        if ($currentLine.Length -eq 0) {
            $currentLine = $word
        }
        # Si añadir la siguiente palabra (con un espacio) excede el limite...
        elseif (($currentLine.Length + $word.Length + 1) -gt $wrapWidth) {
            # ...guardamos la linea actual y empezamos una nueva con la palabra actual.
            $lines.Add($currentLine)
            $currentLine = $word
        }
        # Si no excede el limite, añadimos la palabra a la linea actual.
        else {
            $currentLine += " " + $word
        }
    }
    # Añadimos la ultima linea que se estaba construyendo.
    if ($currentLine) {
        $lines.Add($currentLine)
    }

    # Creamos el bloque de texto final con la sangria aplicada a cada linea.
    $indentation = " " * $Indent
    return $lines | ForEach-Object { "$indentation$_" }
}

# --- FUNCIONES DE ACCION (Las herramientas que hacen el trabajo) ---
function Show-AdminMenu {
    $adminChoice = ''
    do {
		Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Administracion de Sistema."
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "            Modulo de Administracion de Sistema        " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Limpiar Registros de Eventos de Windows"
        Write-Host "       (Elimina eventos de Aplicacion, Seguridad, Sistema, etc.)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Gestionar Tareas Programadas de Terceros"
        Write-Host "       (Activa o desactiva tareas que no son de Microsoft)" -ForegroundColor Gray
        Write-Host ""
		Write-Host "   [3] Reubicar Carpetas de Usuario (GUI)" -ForegroundColor Yellow
        Write-Host "       (Mueve tus carpetas personales a otra unidad o ubicacion)" -ForegroundColor Gray
        Write-Host ""
		Write-Host "   [4] Gestor de Claves Wi-Fi (Ver/Backup/Restore)" -ForegroundColor Cyan
		Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $adminChoice = Read-Host "Selecciona una opcion"
        
        switch ($adminChoice.ToUpper()) {
            '1' {
                if ((Read-Host "`nADVERTENCIA: Esto eliminara permanentemente los registros de eventos. Estas seguro? (S/N)").ToUpper() -eq 'S') {
                    
                    $targetLogs = @("Application", "Security", "System", "Setup")
                    $eventBackupRoot = Join-Path (Split-Path -Parent $PSScriptRoot) ("Backup\EventLogs\{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
                    New-Item -Path $eventBackupRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    $journal = New-AegisOperationJournal -Module 'Administracion' -Action 'Limpiar registros de eventos' -Targets $targetLogs -Metadata @{ BackupPath = $eventBackupRoot }
                    $operationResults = New-Object System.Collections.Generic.List[object]
                    Write-Host ""

                    foreach ($logName in $targetLogs) {
                        $logExists = Get-WinEvent -ListLog $logName -ErrorAction SilentlyContinue

                        if ($logExists) {
                            Write-Host "[+] Intentando limpiar el registro '$logName'..." -ForegroundColor Gray
                            try {
                                $backupPath = Join-Path $eventBackupRoot "$logName.evtx"
                                Invoke-AegisNativeProcess -FilePath 'wevtutil.exe' -ArgumentList @('export-log',$logName,$backupPath,'/ow:true') -TimeoutSeconds 300 -ValidExitCodes @(0) | Out-Null
                                Invoke-AegisNativeProcess -FilePath 'wevtutil.exe' -ArgumentList @('clear-log',$logName) -TimeoutSeconds 300 -ValidExitCodes @(0) | Out-Null
                                Write-Host "[OK] Registro '$logName' respaldado y limpiado exitosamente." -ForegroundColor Green
                                Write-Log -LogLevel ACTION -Message "Registro de eventos '$logName' respaldado en '$backupPath' y limpiado por el usuario."
                                $operationResults.Add([PSCustomObject]@{ Log=$logName; Status='Completed'; Backup=$backupPath })
                            }
                            catch {
                                Write-Warning "No se pudo limpiar el registro '$logName'. Error: $($_.Exception.Message)"
                                Write-Log -LogLevel WARN -Message "Fallo al limpiar el registro '$logName'. Motivo: $($_.Exception.Message)"
                                $operationResults.Add([PSCustomObject]@{ Log=$logName; Status='Failed'; Error=$_.Exception.Message })
                            }
                        }
                        else {
                            Write-Host "[INFO] Registro '$logName' no encontrado en este sistema. Omitido." -ForegroundColor Yellow
                            $operationResults.Add([PSCustomObject]@{ Log=$logName; Status='NotFound' })
                        }
                    }
                    $failedCount = @($operationResults | Where-Object { $_.Status -eq 'Failed' }).Count
                    $journalStatus = if ($failedCount -eq 0) { 'Completed' } elseif ($failedCount -lt $targetLogs.Count) { 'Partial' } else { 'Failed' }
                    Complete-AegisOperationJournal -Journal $journal -Status $journalStatus -Results $operationResults.ToArray() | Out-Null
                }
            }
            '2' { Show-ScheduledTasks }
			'3' { Show-UserProfileRelocationDialog }
			'4' { Show-WifiManager }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
            }
        }
    } while ($adminChoice.ToUpper() -ne 'V')
}

function Show-OptimizationMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Optimizacion y Limpieza."
    $optimChoice = ''
	do { 
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "            Modulo de Optimizacion y Limpieza          " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Gestor de Servicios No Esenciales de Windows"
        Write-Host "       (Activa, desactiva o restaura servicios de forma segura)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Optimizar Servicios de Programas Instalados"
        Write-Host "       (Activa o desactiva servicios de tus aplicaciones)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Modulo de Limpieza Profunda"
        Write-Host "       (Libera espacio en disco eliminando archivos basura)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Eliminar Apps Preinstaladas"
        Write-Host "       (Detecta y te permite elegir que bloatware quitar)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Gestionar Programas de Inicio"
        Write-Host "       (Controla que aplicaciones arrancan con Windows)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------"
        Write-Host ""
        Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
        Write-Host ""
        
        $optimChoice = Read-Host "Selecciona una opcion"
        
        switch ($optimChoice.ToUpper()) {
            '1' { Manage-SystemServices }
            '2' { Manage-ThirdPartyServices }
            '3' { Show-CleaningMenu }
            '4' { Show-BloatwareMenu }
            '5' { Manage-StartupApps }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
                Read-Host 
            }
		} 
	} while ($optimChoice.ToUpper() -ne 'V')
}

function Show-MaintenanceMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Mantenimiento y Reparacion."
    $maintChoice = ''
	do { 
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Modulo de Mantenimiento y Reparacion        " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Verificar y Reparar Archivos del Sistema (SFC/DISM)"
        Write-Host "       (Soluciona errores de sistema, cuelgues y pantallas azules)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Limpiar Caches de Sistema (DNS, Tienda, etc.)"
        Write-Host "       (Resuelve problemas de conexion a internet y de la Tienda Windows)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Optimizar Unidades (Desfragmentar/TRIM)"
        Write-Host "       (Mejora la velocidad de lectura y la vida util de tus discos)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Generar Reporte de Salud del Sistema (Energia)"
        Write-Host "       (Diagnostica problemas de bateria y consumo de energia)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Purgar Memoria RAM en Cache (Standby List)" -ForegroundColor Yellow
        Write-Host "       (Libera la memoria 'En espera'. Para usos muy especificos)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [6] Diagnostico y Reparacion de Red"
        Write-Host "       (Soluciona problemas de conectividad a internet)" -ForegroundColor Gray
        Write-Host ""
		Write-Host "   [7] Reconstruir Indice de Busqueda (Search Index)" -ForegroundColor Cyan
        Write-Host "       (Soluciona busquedas lentas, incompletas o que no encuentran archivos)" -ForegroundColor Gray
		Write-Host ""
		Write-Host "   [8] Limpieza Profunda de Cache de Navegadores" -ForegroundColor Yellow
        Write-Host "       (Chrome, Edge, Firefox, Brave, Opera)" -ForegroundColor Gray
        Write-Host "-------------------------------------------------------"
        Write-Host ""
        Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
        Write-Host ""
        
        $maintChoice = Read-Host "Selecciona una opcion"
        
        switch ($maintChoice.ToUpper()) {
            '1' { Repair-SystemFiles }
            '2' { Clear-SystemCaches }
            '3' { Optimize-Drives }
            '4' { Generate-SystemReport }
            '5' { Clear-RAMCache }
            '6' { Show-NetworkDiagnosticsMenu }
            '7' { Rebuild-SearchIndex }
			'8' { Clean-BrowserCaches }
			'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        } 
    } while ($maintChoice.ToUpper() -ne 'V')
}

function Show-AdvancedMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Herramientas Avanzadas."
    $advChoice = ''
    do { 
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "                 Herramientas Avanzadas                " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Gestor de Ajustes del Sistema (Tweaks, Seguridad, UI, Privacidad)"
        Write-Host "       (Activa y desactiva individualmente ajustes para optimizar tu sistema)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Inventario y Reportes del Sistema"
        Write-Host "       (Genera un informe detallado del hardware y software de tu PC)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Gestion de Drivers (Backup/Listar/Eliminar)"
        Write-Host "       (Crea una copia de seguridad de tus drivers, esencial para reinstalar Windows)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Gestion de Software (Multi-Motor)"
        Write-Host "       (Actualiza e instala todas tus aplicaciones con Winget o Chocolatey)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Administracion de Sistema"
        Write-Host "       (Limpia logs, gestiona tareas y reubica carpetas de usuario)" -ForegroundColor Gray
		Write-Host ""
        Write-Host "   [6] Analizador Rapido de Registros de Eventos"
        Write-Host "       (Encuentra errores criticos del sistema y aplicaciones)" -ForegroundColor Gray
		Write-Host ""
        Write-Host "   [7] Herramienta de Respaldo de Datos de Usuario (Robocopy)"
        Write-Host "       (Crea copias de seguridad de tus archivos personales)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------"
        Write-Host ""
        Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
		Write-Host ""
        
        $advChoice = Read-Host "Selecciona una opcion"
        
        switch ($advChoice.ToUpper()) {
            '1' { Show-TweakManagerMenu }
            '2' { Show-InventoryMenu }
            '3' { Show-DriverMenu }
            '4' { Show-SoftwareMenu }
            '5' { Show-AdminMenu }
			'6' { Show-EventLogAnalyzerMenu }
			'7' { Show-UserDataBackupMenu }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
                Read-Host
            }
        }
    } while ($advChoice.ToUpper() -ne 'V')
}

# ===================================================================
# --- BUCLE PRINCIPAL (MOTOR DE INTERFAZ DE USUARIO) ---
# ===================================================================
function Invoke-MainMenuLoop {
    # Variable de estado para mensajes de retroalimentacion (Feedback Loop)
    $statusMessage = ""
    $statusColor = "Gray"
    
    # --- PRE-CALCULO DE INFORMACION ---
    $cachedSystemInfo = try {
        $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        
        # 1. Determinar Nombre Comercial (El registro miente en Win11 por compatibilidad)
        $build = [int]$reg.CurrentBuild
        $osName = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }
        
        # 2. Limpiar Edición
        $edition = $reg.EditionID `
            -replace "Professional", "Pro" `
            -replace "Core", "Home" `
            -replace "Enterprise", "Ent" `
            -replace "Education", "Edu" `
            -replace "Server", "Srv" `
            -replace "Workstation", "Wrk" `
            -replace "SingleLanguage", "SL" `
            -replace "CountrySpecific", "CS" `
            -replace "Essentials", "Ess" `
            -replace "Ultimate", "Ult" `
            -replace "Starter", "Strt" `
            -replace "Cloud", "SE" `
            -replace "IoT", "IoT"
        
        # 3. Versión de Visualización (23H2, 22H2, etc.)
        $displayVer = if ($reg.DisplayVersion) { $reg.DisplayVersion } else { $reg.ReleaseId }
        
        # 4. Arquitectura (Desde variable de entorno = 0ms)
        $arch = $env:PROCESSOR_ARCHITECTURE -replace "AMD64", "x64" -replace "x86", "x32"
        
        # String Final
        "$osName $edition $displayVer ($arch) - Build $build.$($reg.UBR)"
    } catch { 
        "Windows (Detectando...)" 
    }
    
    # Bucle infinito controlado
    while ($true) {
		Clear-Host

        # --- ENCABEZADO UNIFICADO ---
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        $line = "=" * $consoleWidth
        
        Write-Host $line -ForegroundColor Cyan
        
        # Titulo centrado
        $title = "Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER"
        $padding = [math]::Max(0, [int](($consoleWidth - $title.Length) / 2))
        Write-Host (" " * $padding + $title) -ForegroundColor Cyan
        
        # Metadata L1: Usuario y Equipo
        $metaInfo1 = "Usuario: $env:USERNAME | Equipo: $env:COMPUTERNAME | Privilegios: Admin"
        $paddingMeta1 = [math]::Max(0, [int](($consoleWidth - $metaInfo1.Length) / 2))
        Write-Host (" " * $paddingMeta1 + $metaInfo1) -ForegroundColor Gray

        # Metadata L2: Sistema Exacto (Cacheado)
        $paddingMeta2 = [math]::Max(0, [int](($consoleWidth - $cachedSystemInfo.Length) / 2))
        Write-Host (" " * $paddingMeta2 + $cachedSystemInfo) -ForegroundColor Gray
        
        Write-Host $line -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Crear Punto de Restauracion" -ForegroundColor White
        Write-Host "       (Snapshot de seguridad del sistema)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "--- MODULOS OPERATIVOS ---" -ForegroundColor Cyan
        Write-Host "   [2] Optimizacion y Limpieza" -ForegroundColor Green
        Write-Host "       (Servicios, Bloatware, Disco, Inicio)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Mantenimiento y Reparacion" -ForegroundColor Green
        Write-Host "       (SFC, DISM, Red, Caches, Drivers)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Herramientas Avanzadas" -ForegroundColor Yellow
        Write-Host "       (Ajustes/Tweaks, Inventario, Software)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "   [L] Ver Logs   [H] Ayuda/Info   [S] Salir" -ForegroundColor Gray
        Write-Host ""

        # --- AREA DE MENSAJES DE ESTADO (FEEDBACK) ---
        if (-not [string]::IsNullOrWhiteSpace($statusMessage)) {
            Write-Host "   ESTADO: $statusMessage" -ForegroundColor $statusColor
            $statusMessage = ""
            $statusColor = "Gray"
        } else {
            Write-Host ""
        }
        
        # --- CAPTURA DE ENTRADA ---
        $selection = Read-Host "   > Selecciona una opcion"
        
        # --- VALIDACIoN Y LOGICA ---
        switch ($selection.Trim().ToUpper()) {
            '1' { 
                Create-RestorePoint 
                $statusMessage = "Ultima accion: Punto de restauracion finalizado."; $statusColor = "Green"
            }
            '2' { 
                Show-OptimizationMenu 
                $statusMessage = "Regresando del menu de Optimizacion."; $statusColor = "Cyan"
            }
            '3' { 
                Show-MaintenanceMenu 
                $statusMessage = "Regresando del menu de Mantenimiento."; $statusColor = "Cyan"
            }
            '4' { 
                Show-AdvancedMenu 
                $statusMessage = "Regresando del menu Avanzado."; $statusColor = "Cyan"
            }
            'L' {
                $logFile = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs\Registro.log"
                if (Test-Path $logFile) {
                    Start-Process notepad.exe -ArgumentList $logFile
                    $statusMessage = "Abriendo logs..."; $statusColor = "Green"
                } else {
                    $statusMessage = "Error: El archivo de log aun no existe."; $statusColor = "Red"
                }
            }
            'H' {
               $msg = "Aegis Phoenix Suite v$($script:Version)`n" +
                      "Desarrollado por SOFTMAXTER`n`n" +
                      "Email: softmaxter@hotmail.com`n" +
                      "Blog: softmaxter.blogspot.com`n`n" +
                      "Una suite integral para el mantenimiento proactivo de sistemas Windows."
               
               [System.Windows.Forms.MessageBox]::Show($msg, "Acerca de", 0, 64)
            }
            'S' { 
                Write-Host "`n   Cerrando sesion y limpiando variables temporales..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                return # Rompe el bucle y la funcion
            }
            default {
                if ([string]::IsNullOrWhiteSpace($selection)) {
                    $statusMessage = "Por favor, escribe una opcion."; $statusColor = "Yellow"
                } else {
                    $statusMessage = "Opcion '$selection' no reconocida. Intenta de nuevo."; $statusColor = "Red"
                    [System.Console]::Beep(500, 200) 
                }
            }
        }
        
        # Registro de telemetria interna
        if (-not [string]::IsNullOrWhiteSpace($selection)) {
            Write-Log -LogLevel INFO -Message "MAIN_MENU: Input usuario: '$selection'"
        }
    }
}

# --- PUNTO DE ENTRADA (ENTRY POINT) ---
try {
    # Configurar titulo de consola
    $Host.UI.RawUI.WindowTitle = "Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER"
    
    # Iniciar el bucle principal
    Invoke-MainMenuLoop
    
    Write-Log -LogLevel INFO -Message "Sesion finalizada correctamente."
}
catch {
    Write-Log -LogLevel ERROR -Message "CRASH FATAL EN MENU PRINCIPAL: $_"
    Write-Error "Ocurrio un error inesperado en el nucleo del script."
    Write-Error $_
    Read-Host "Presiona Enter para salir..."
}