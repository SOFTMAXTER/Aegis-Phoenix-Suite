# =================================================================
#  Modulo-Respaldos
#
#  CONTENIDO   : Show-UserDataBackupMenu
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-Respaldos.ps1"
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

function Select-PathDialog {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Folder', 'File')]
        [string]$DialogType,

        [string]$Title,

        [string]$Filter = "Todos los archivos (*.*)|*.*"
    )
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        if ($DialogType -eq 'Folder') {
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = $Title
            if ($dialog.ShowDialog() -eq 'OK') {
                return $dialog.SelectedPath
            }
        } elseif ($DialogType -eq 'File') {
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Title = $Title
            $dialog.Filter = $Filter
            $dialog.CheckFileExists = $true
            $dialog.CheckPathExists = $true
            $dialog.Multiselect = $true 
            if ($dialog.ShowDialog() -eq 'OK') {
                return $dialog.FileNames 
            }
        }
    } catch {
        Write-Error "No se pudo mostrar el dialogo. Error: $($_.Exception.Message)"
    }
    
    return $null 
}


function Test-AegisRobocopyVerificationExitCode {
    param(
        [Parameter(Mandatory=$true)][int]$ExitCode,
        [Parameter(Mandatory=$true)][ValidateSet('Copy','Mirror','Move')][string]$Mode
    )
    # Robocopy usa un bitmask: 1=copias pendientes, 2=extras, 4=diferencias,
    # 8=errores de copia y 16=error fatal. En copia incremental los extras del
    # destino son validos; en espejo cualquier diferencia invalida la revision.
    if (($ExitCode -band 24) -ne 0) { return $false }
    if (($ExitCode -band 5) -ne 0) { return $false }
    if ($Mode -eq 'Mirror' -and ($ExitCode -band 2) -ne 0) { return $false }
    return $true
}


function Get-AegisBackupDestinationFile {
    param($SourceFile, [string[]]$SourcePaths, [string]$DestinationPath, [string]$BackupType)
    if ($BackupType -eq 'Files') { return (Join-Path $DestinationPath $SourceFile.Name) }

    $baseSourceFolder = $SourcePaths | Where-Object {
        $candidate = (Get-Item -LiteralPath $_ -ErrorAction Stop).FullName.TrimEnd('\')
        $SourceFile.FullName.Equals($candidate, [StringComparison]::OrdinalIgnoreCase) -or
        $SourceFile.FullName.StartsWith($candidate + '\', [StringComparison]::OrdinalIgnoreCase)
    } | Sort-Object Length -Descending | Select-Object -First 1
    if (-not $baseSourceFolder) { throw "No se pudo resolver el origen de '$($SourceFile.FullName)'." }
    $baseSourceFolder = (Get-Item -LiteralPath $baseSourceFolder -ErrorAction Stop).FullName.TrimEnd('\')
    $relativePath = $SourceFile.FullName.Substring($baseSourceFolder.Length).TrimStart('\')
    return (Join-Path (Join-Path $DestinationPath (Split-Path $baseSourceFolder -Leaf)) $relativePath)
}


function Remove-AegisVerifiedMoveSources {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true)][string[]]$SourcePaths,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [Parameter(Mandatory=$true)][ValidateSet('Files','Folders')][string]$BackupType,
        [Parameter(Mandatory=$true)][ValidateSet('Fast','Deep')][string]$VerificationType
    )

    $sourceFiles = if ($BackupType -eq 'Files') {
        @(Get-Item -LiteralPath $SourcePaths -ErrorAction Stop)
    } else {
        @($SourcePaths | ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -Force -File -ErrorAction Stop })
    }
    $validated = [System.Collections.Generic.List[object]]::new()
    foreach ($sourceFile in $sourceFiles) {
        $destinationFile = Get-AegisBackupDestinationFile -SourceFile $sourceFile -SourcePaths $SourcePaths -DestinationPath $DestinationPath -BackupType $BackupType
        $destinationItem = Get-Item -LiteralPath $destinationFile -ErrorAction Stop
        if ($destinationItem.Length -ne $sourceFile.Length) {
            throw "El tamaño no coincide para '$($sourceFile.FullName)'. El origen no se eliminara."
        }
        if ($VerificationType -eq 'Deep') {
            $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
            $destinationHash = (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($sourceHash -ne $destinationHash) { throw "El hash no coincide para '$($sourceFile.FullName)'." }
        } elseif ($sourceFile.LastWriteTimeUtc -ne $destinationItem.LastWriteTimeUtc) {
            throw "La fecha de modificacion no coincide para '$($sourceFile.FullName)'. Usa verificacion hash si el archivo cambia activamente."
        }
        $validated.Add([PSCustomObject]@{ Source=$sourceFile.FullName; Destination=$destinationFile })
    }

    foreach ($entry in $validated) {
        if ($PSCmdlet.ShouldProcess($entry.Source, 'Eliminar archivo de origen ya verificado')) {
            Remove-Item -LiteralPath $entry.Source -Force -ErrorAction Stop
        }
    }
    if ($BackupType -eq 'Folders') {
        foreach ($sourceFolder in $SourcePaths) {
            $directories = @(Get-ChildItem -LiteralPath $sourceFolder -Directory -Force -Recurse -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending)
            foreach ($directory in $directories) {
                if (-not (Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
                    Remove-Item -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue
                }
            }
            if (-not (Get-ChildItem -LiteralPath $sourceFolder -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
                Remove-Item -LiteralPath $sourceFolder -Force -ErrorAction Stop
            }
        }
    }
    return @($validated)
}


function Invoke-BackupRobocopyVerification {
    [CmdletBinding()]
    param($logFile, $baseRoboCopyArgs, $backupType, $sourcePaths, $destinationPath, $Mode)

    Write-Host "`n[+] Iniciando comprobacion de integridad (RAPIDA /L)..." -ForegroundColor Yellow
    $verifyBaseArgs = $baseRoboCopyArgs + "/L"
    $logArg = "/LOG+:`"$logFile`""

    $verificationFailed = $false
    if ($backupType -eq 'Files') {
        $filesByDirectory = $sourcePaths | Get-Item | Group-Object -Property DirectoryName
        foreach ($group in $filesByDirectory) {
            $sourceDir = $group.Name
            $fileNames = $group.Group | ForEach-Object { "`"$($_.Name)`"" }
            Write-Host " - Verificando lote desde '$sourceDir'..." -ForegroundColor Gray
            $currentArgs = @("`"$sourceDir`"", "`"$destinationPath`"") + $fileNames + $verifyBaseArgs + $logArg
            $proc = Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow -PassThru
            if (-not (Test-AegisRobocopyVerificationExitCode -ExitCode $proc.ExitCode -Mode $Mode)) {
                $verificationFailed = $true
                Write-Warning "La comprobacion detecto diferencias en '$sourceDir' (codigo $($proc.ExitCode))."
            }
        }
    } else {
        $folderArgs = $verifyBaseArgs + "/E"
        if ($Mode -eq 'Mirror') { $folderArgs = $verifyBaseArgs + "/MIR" }
        foreach ($sourceFolder in $sourcePaths) {
            $folderName = Split-Path $sourceFolder -Leaf
            $destinationFolder = Join-Path $destinationPath $folderName
            Write-Host "`n[+] Verificando '$folderName'..." -ForegroundColor Gray
            $currentArgs = @("`"$sourceFolder`"", "`"$destinationFolder`"") + $folderArgs + $logArg
            $proc = Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow -PassThru
            if (-not (Test-AegisRobocopyVerificationExitCode -ExitCode $proc.ExitCode -Mode $Mode)) {
                $verificationFailed = $true
                Write-Warning "La comprobacion detecto diferencias en '$folderName' (codigo $($proc.ExitCode))."
            }
        }
    }
    if ($verificationFailed) {
        throw "ROBOCOPY_VERIFICATION_FAILURE"
    }
    Write-Host "[OK] Verificacion rapida correcta: no se detectaron diferencias." -ForegroundColor Green
    return $true
}


function Invoke-BackupHashVerification {
    [CmdletBinding()]
    param($sourcePaths, $destinationPath, $backupType, $logFile)
    
    Write-Host "`n[+] Iniciando comprobacion profunda por Hash (SHA256)..." -ForegroundColor Yellow
    
    $sourceFiles = @()
    if ($backupType -eq 'Files') {
        $sourceFiles = $sourcePaths | Get-Item
    } else {
        $sourcePaths | ForEach-Object { $sourceFiles += Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue }
    }

    if ($sourceFiles.Count -eq 0) { Write-Warning "Sin archivos para verificar."; return }

    $totalFiles = $sourceFiles.Count
    $checkedFiles = 0; $mismatchedFiles = 0; $missingFiles = 0; $readErrors = 0
    $details = [System.Collections.Generic.List[string]]::new()

    foreach ($sourceFile in $sourceFiles) {
        $checkedFiles++
        # Progreso en la misma linea para no saturar
        if ($checkedFiles % 5 -eq 0) { 
            Write-Progress -Activity "Calculando Hash (SHA256)" -Status "Archivo $checkedFiles de $totalFiles" -PercentComplete (($checkedFiles / $totalFiles) * 100)
        }
        
        $destinationFile = Get-AegisBackupDestinationFile -SourceFile $sourceFile -SourcePaths $sourcePaths -DestinationPath $destinationPath -BackupType $backupType
        
        if (Test-Path $destinationFile) {
            try {
                $h1 = (Get-FileHash $sourceFile.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                $h2 = (Get-FileHash $destinationFile -Algorithm SHA256 -ErrorAction Stop).Hash
                
                if ($h1 -ne $h2) { 
                    $mismatchedFiles++
                    Write-Host "`n[!] DISCREPANCIA: $($sourceFile.Name)" -ForegroundColor Red
                    $details.Add("DIFF: $($sourceFile.FullName)") 
                }
            } catch { 
                # Ignorar desktop.ini bloqueados, es normal
                if ($sourceFile.Name -ne "desktop.ini") {
                    $readErrors++
                    $details.Add("ERROR LEER: $($sourceFile.Name)") 
                }
            }
        } else { 
            $missingFiles++
            Write-Host "`n[!] FALTANTE: $($sourceFile.Name)" -ForegroundColor Red
            $details.Add("FALTANTE: $destinationFile") 
        }
    }
    Write-Progress -Activity "Calculando Hash (SHA256)" -Completed
    
    $logTxt = "`r`n--- RESUMEN HASH ---`r`nTotal: $totalFiles | Diferentes: $mismatchedFiles | Faltan: $missingFiles | Errores de lectura: $readErrors`r`n"
    if ($details.Count -gt 0) { $logTxt += ($details | Out-String) }
    $logTxt | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    if ($mismatchedFiles -eq 0 -and $missingFiles -eq 0 -and $readErrors -eq 0) { 
        Write-Host "[OK] Integridad Hash Correcta." -ForegroundColor Green 
        return $true
    } else { 
        # Lanzamos una excepcion controlada para que el modulo principal sepa que fallo
        throw "HASH_FAILURE" 
    }
}


function Get-AegisKnownUserBackupFolders {
    [CmdletBinding()]
    param()

    $registryPath = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'

    function Resolve-KnownFolderPath {
        param(
            [Parameter(Mandatory=$true)][string]$RegistryName,
            [Parameter(Mandatory=$true)][string]$SpecialFolder,
            [string]$FallbackName
        )

        try {
            $property = Get-ItemProperty -Path $registryPath -Name $RegistryName -ErrorAction Stop
            $rawPath = [string]$property.$RegistryName
            if (-not [string]::IsNullOrWhiteSpace($rawPath)) {
                return [Environment]::ExpandEnvironmentVariables($rawPath)
            }
        } catch {
            Write-Verbose "No se pudo resolver '$RegistryName' desde el Registro: $($_.Exception.Message)"
        }

        $resolvedPath = [Environment]::GetFolderPath($SpecialFolder)
        if ([string]::IsNullOrWhiteSpace($resolvedPath) -and -not [string]::IsNullOrWhiteSpace($FallbackName)) {
            $resolvedPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) $FallbackName
        }
        return $resolvedPath
    }

    $downloadsPath = Resolve-KnownFolderPath -RegistryName '{374DE290-123F-4565-9164-39C4925E467B}' -SpecialFolder 'UserProfile' -FallbackName 'Downloads'
    if ($downloadsPath -eq [Environment]::GetFolderPath('UserProfile')) {
        $downloadsPath = Join-Path $downloadsPath 'Downloads'
    }

    $folders = @(
        [PSCustomObject]@{ Name='Escritorio'; Path=(Resolve-KnownFolderPath -RegistryName 'Desktop' -SpecialFolder 'Desktop'); Exists=$false }
        [PSCustomObject]@{ Name='Documentos'; Path=(Resolve-KnownFolderPath -RegistryName 'Personal' -SpecialFolder 'MyDocuments'); Exists=$false }
        [PSCustomObject]@{ Name='Imagenes'; Path=(Resolve-KnownFolderPath -RegistryName 'My Pictures' -SpecialFolder 'MyPictures'); Exists=$false }
        [PSCustomObject]@{ Name='Musica'; Path=(Resolve-KnownFolderPath -RegistryName 'My Music' -SpecialFolder 'MyMusic'); Exists=$false }
        [PSCustomObject]@{ Name='Videos'; Path=(Resolve-KnownFolderPath -RegistryName 'My Video' -SpecialFolder 'MyVideos'); Exists=$false }
        [PSCustomObject]@{ Name='Descargas'; Path=$downloadsPath; Exists=$false }
    )
    foreach ($folder in $folders) {
        $folder.Exists = -not [string]::IsNullOrWhiteSpace($folder.Path) -and (Test-Path -LiteralPath $folder.Path -PathType Container)
    }
    return $folders
}


function Invoke-UserDataBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Copy', 'Mirror', 'Move')]
        [string]$Mode,

        [string[]]$CustomSourcePath,

        [string]$DestinationPath,

        [ValidateSet('Prompt', 'None', 'Fast', 'Deep')]
        [string]$VerificationType = 'Prompt',

        [switch]$SkipSameVolumePrompt,

        [switch]$AllowUnknownDestinationSpace,

        [switch]$NoPause
    )

    # 1. Determinamos el origen
    $backupType = 'Folders'
    $sourcePaths = @()
    
    if ($CustomSourcePath) {
        $sourceItems = @($CustomSourcePath | ForEach-Object { Get-Item -LiteralPath $_ -ErrorAction Stop })
        $folderItems = @($sourceItems | Where-Object { $_.PSIsContainer })
        $fileItems = @($sourceItems | Where-Object { -not $_.PSIsContainer })
        if ($folderItems.Count -gt 0 -and $fileItems.Count -gt 0) {
            throw 'No se pueden mezclar carpetas y archivos en una misma operacion de respaldo.'
        }
        if ($folderItems.Count -eq $sourceItems.Count) {
            $backupType = 'Folders'
            $sourcePaths = @($folderItems | Select-Object -ExpandProperty FullName -Unique)
        } else {
            $backupType = 'Files'
            $sourcePaths = @($fileItems | Select-Object -ExpandProperty FullName -Unique)
        }
    } else {
        $backupType = 'Folders'
        $sourcePaths = @(Get-AegisKnownUserBackupFolders | Where-Object Exists | Select-Object -ExpandProperty Path -Unique)
    }

    if ($sourcePaths.Count -eq 0) {
        throw 'No hay carpetas o archivos validos seleccionados para respaldar.'
    }
    if ($backupType -eq 'Files' -and $Mode -eq 'Mirror') {
        throw 'El modo Espejo solo es valido para carpetas. Para archivos individuales usa Copia o Mover.'
    }
    
    # 2. Solicitamos destino
    if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
        Write-Host "`n[+] Por favor, selecciona la carpeta de destino para el respaldo..." -ForegroundColor Yellow
        $DestinationPath = Select-PathDialog -DialogType 'Folder' -Title "Paso 2: Elige la Carpeta de Destino"
    }
    
    if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
        Write-Warning 'No se selecciono destino. Operacion cancelada.'
        return $null
    }

    $destinationPath = (Get-Item -LiteralPath $DestinationPath -ErrorAction Stop).FullName

    # --- VALIDACIONES ---
    # A) Validar Bucle Infinito
    $destFull = (Get-Item -LiteralPath $destinationPath -ErrorAction Stop).FullName.TrimEnd('\')
    if ($backupType -eq 'Folders') {
        $duplicateFolderNames = @($sourcePaths | ForEach-Object {
            [PSCustomObject]@{ Path=$_; DestinationName=(Split-Path $_ -Leaf) }
        } | Group-Object DestinationName | Where-Object Count -gt 1)
        if ($duplicateFolderNames.Count -gt 0) {
            throw "Hay carpetas de origen con el mismo nombre de destino ($($duplicateFolderNames.Name -join ', ')). Selecciona una carpeta padre o usa destinos separados."
        }
    }
    foreach ($src in $sourcePaths) {
        if ($backupType -eq 'Folders') {
            $srcFull = (Get-Item -LiteralPath $src -ErrorAction Stop).FullName.TrimEnd('\')
            $destInsideSource = $destFull.Equals($srcFull, [System.StringComparison]::OrdinalIgnoreCase) -or
                $destFull.StartsWith($srcFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
            $sourceInsideDestination = $srcFull.Equals($destFull, [System.StringComparison]::OrdinalIgnoreCase) -or
                $srcFull.StartsWith($destFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
            if ($destInsideSource -or $sourceInsideDestination) {
                throw "El origen '$srcFull' y el destino no pueden contenerse entre si ni ser la misma ruta."
            }
        }
    }

    if ($backupType -eq 'Files') {
        $sourceFileItems = @($sourcePaths | Get-Item -ErrorAction Stop)
        $duplicateNames = $sourceFileItems | Group-Object Name | Where-Object Count -gt 1
        if ($duplicateNames) {
            throw "Hay archivos de carpetas distintas con el mismo nombre ($($duplicateNames.Name -join ', ')). Usa una carpeta como origen para evitar sobrescrituras."
        }
        foreach ($sourceFileItem in $sourceFileItems) {
            $targetFileFull = [System.IO.Path]::GetFullPath((Join-Path $destFull $sourceFileItem.Name))
            if ($targetFileFull.Equals($sourceFileItem.FullName, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "El destino resolveria al mismo archivo de origen: '$($sourceFileItem.FullName)'."
            }
        }
    }

    # B) Advertir si ambas rutas estan en el mismo volumen.
    try {
        $destDrive = Split-Path $destinationPath -Qualifier -ErrorAction SilentlyContinue
        $sourceDrives = @($sourcePaths | ForEach-Object { Split-Path $_ -Qualifier -ErrorAction SilentlyContinue } | Where-Object { $_ } | Select-Object -Unique)
        $sameVolumeDrives = @($sourceDrives | Where-Object { $destDrive -and $_ -eq $destDrive })

        if ($sameVolumeDrives.Count -gt 0) {
            Write-Warning "AVISO: Hay origenes y destino en el mismo volumen ($($sameVolumeDrives -join ', ')). Esto no protege contra una falla de esa unidad."
            if (-not $SkipSameVolumePrompt) {
                if ($NoPause) { throw 'La ejecucion no interactiva requiere confirmar explicitamente el uso del mismo volumen.' }
                if ((Read-Host "Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') { return $null }
            }
        }
    } catch {
        Write-Warning "No se pudo comparar el volumen de origen y destino: $($_.Exception.Message)"
    }
    
    # 3. Calculo de espacio
	Clear-Host
    Write-Host "`n[+] Calculando espacio requerido..." -ForegroundColor Yellow
    $sourceTotalSize = 0
    try {
        if ($backupType -eq 'Files') {
            $sourceTotalSize = ($sourcePaths | Get-Item | Measure-Object -Property Length -Sum).Sum
        } else {
            foreach ($folder in $sourcePaths) {
                $sourceTotalSize += (Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            }
        }
    } catch { Write-Warning "Calculo aproximado." }
    
    $destDriveLetter = Split-Path $destinationPath -Qualifier
    $driveInfo = Get-Volume | Where-Object { ($_.DriveLetter + ":") -eq $destDriveLetter }
    $destinationFreeSpace = if ($driveInfo) { $driveInfo.SizeRemaining } else { $null }

    if ($null -eq $destinationFreeSpace) {
        Write-Warning "No fue posible determinar el espacio libre del destino (por ejemplo, una ruta UNC)."
        if (-not $AllowUnknownDestinationSpace) {
            if ($NoPause) { throw 'No se pudo validar el espacio libre y no se autorizo continuar sin esa comprobacion.' }
            if ((Read-Host "Continuar sin validacion de espacio? (S/N)").ToUpper() -ne 'S') { return $null }
        }
    }

    if ($null -ne $destinationFreeSpace -and $sourceTotalSize -gt $destinationFreeSpace) {
        $neededGB = [math]::Round($sourceTotalSize / 1GB, 2)
        $freeGB = [math]::Round($destinationFreeSpace / 1GB, 2)
        throw "Espacio insuficiente: se requieren aproximadamente $neededGB GB y hay $freeGB GB libres."
    }

    # 4. Configurar Robocopy
	$logDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    $logFile = Join-Path $logDir "Respaldo_Robocopy_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

    # DATS conserva datos, atributos, marcas de tiempo y ACL. Se evita /J porque
    # perjudica respaldos compuestos por muchos archivos pequeños.
    $baseRoboCopyArgs = @("/COPY:DATS", "/DCOPY:DAT", "/R:2", "/W:3", "/XJ", "/NP", "/TEE", "/B", "/MT:8")
    $excludeDirs = @("/XD", "`"$destinationPath`"", "System Volume Info", "`$RECYCLE.BIN", "AppData\Local\Temp")

    # --- ACTUALIZACIoN DE DESCRIPCIoN DE MODO ---
    $modeDescription = switch ($Mode) {
        'Mirror' { "Sincronizacion (ESPEJO - Borra en destino)" }
        'Move'   { "Mover (CORTAR y PEGAR - Borra en origen)" }
        default  { "Respaldo Incremental (Copia)" }
    }
    
    Write-Host "--- RESUMEN DE RESPALDO ---" -ForegroundColor Cyan
    Write-Host "Modo: $modeDescription"
    Write-Host "Destino: $destinationPath"
    Write-Host "Origen(es):"
    $sourcePaths | ForEach-Object { Write-Host " - $_" }

	if ($Mode -eq 'Move') {
        Write-Host "`n[ADVERTENCIA EXTREMA] Se selecciono MOVER." -ForegroundColor Red
        Write-Host "Los archivos se borraran del origen una vez copiados al destino."
        Write-Host "Asegurate de que el destino sea correcto."
    }

    $verificationType = $VerificationType
    if ($verificationType -eq 'Prompt') {
        Write-Host ""
        Write-Host $(if ($Mode -eq 'Move') { "   [S] Iniciar + Verificacion Rapida OBLIGATORIA" } else { "   [S] Iniciar Operacion" })
        Write-Host "   [V] Iniciar + Verificacion Rapida (/L)"
        Write-Host "   [H] Iniciar + Verificacion Hash (LENTO)" -ForegroundColor Yellow
        Write-Host "   [N] Cancelar"
        $confirmChoice = Read-Host "`nElige una opcion"

        switch ($confirmChoice.ToUpper()) {
            'S' { $verificationType = if ($Mode -eq 'Move') { 'Fast' } else { 'None' } }
            'V' { $verificationType = 'Fast' }
            'H' { $verificationType = 'Deep' }
            'N' { return $null }
            default { return $null }
        }
    }
    if ($Mode -eq 'Move' -and $verificationType -eq 'None') {
        $verificationType = 'Fast'
    }

    # 6. Ejecucion
    $logArg = "/LOG+:`"$logFile`""
    Write-Log -LogLevel ACTION -Message "BACKUP: Iniciando ($Mode) en $destinationPath"

    $operationSucceeded = $true
    # En modo Move siempre se copia primero. El origen solo se elimina cuando
    # Robocopy termina correctamente y, si se pidio, la verificacion tambien.
    $safeMove = ($Mode -eq 'Move')
    $journal = New-AegisOperationJournal -Module 'Respaldos' -Action $Mode -Targets $sourcePaths -Metadata @{
        Destination = $destinationPath
        Verification = $verificationType
        BackupType = $backupType
    }

    if ($backupType -eq 'Files') {
        $filesByDirectory = $sourcePaths | Get-Item | Group-Object -Property DirectoryName
        $currentFileArgs = $baseRoboCopyArgs

        foreach ($group in $filesByDirectory) {
            $sourceDir = $group.Name
            $fileNames = $group.Group | ForEach-Object { "`"$($_.Name)`"" }
            $currentArgs = @("`"$sourceDir`"", "`"$destinationPath`"") + $fileNames + $currentFileArgs + $logArg
            Write-Host "Procesando archivos desde: $sourceDir" -ForegroundColor Gray
            $proc = Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -ge 8) {
                $operationSucceeded = $false
                Write-Error "Robocopy fallo con codigo $($proc.ExitCode) al procesar '$sourceDir'."
            }
        }
    } else {
        $folderArgs = $baseRoboCopyArgs
        if ($Mode -eq 'Mirror') { 
            $folderArgs += "/MIR" 
        } 
        else { 
            $folderArgs += "/E" 
        }
        # En Move no se excluye ningun elemento: excluir durante la copia y
        # borrar despues el origen completo podria causar perdida de datos.
        if ($Mode -ne 'Move') { $folderArgs += $excludeDirs }

        foreach ($sourceFolder in $sourcePaths) {
            $folderName = Split-Path $sourceFolder -Leaf
            $destinationFolder = Join-Path $destinationPath $folderName
            
            Write-Host "`n[ROBOCOPY] Procesando: $folderName" -ForegroundColor Cyan
            $currentArgs = @("`"$sourceFolder`"", "`"$destinationFolder`"") + $folderArgs + $logArg
            
            $proc = Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow -PassThru
            
            if ($proc.ExitCode -ge 8) {
                $operationSucceeded = $false
                Write-Host "   [!] Errores detectados (Cod: $($proc.ExitCode))." -ForegroundColor Red
            } else {
                Write-Host "   -> Completado." -ForegroundColor Green
            }
        }
    }

    if (-not $operationSucceeded) {
        Complete-AegisOperationJournal -Journal $journal -Status Failed -Results @('Robocopy reporto codigo >= 8') | Out-Null
        Write-Log -LogLevel ERROR -Message "BACKUP: Robocopy reporto errores; se cancela la verificacion y cualquier borrado de origen."
        Write-Error "La operacion termino con errores. No se eliminara ningun origen pendiente."
        Write-Host "Log: $logFile"
        if (-not $NoPause) { Read-Host "Presiona Enter para volver..." | Out-Null }
        return [PSCustomObject]@{ Status='Failed'; Message='Robocopy reporto errores. El origen se conservo.'; LogFile=$logFile; Destination=$destinationPath }
    }
    
    # 7. Verificaciones
    try {
        switch ($verificationType) {
            'Fast' {
                $verificationModeForCopy = if ($safeMove) { 'Copy' } else { $Mode }
                Invoke-BackupRobocopyVerification -logFile $logFile -baseRoboCopyArgs $baseRoboCopyArgs -backupType $backupType -sourcePaths $sourcePaths -destinationPath $destinationPath -Mode $verificationModeForCopy | Out-Null
            }
            'Deep' {
                Invoke-BackupHashVerification -sourcePaths $sourcePaths -destinationPath $destinationPath -backupType $backupType -logFile $logFile | Out-Null
            }
        }
    } catch {
        Complete-AegisOperationJournal -Journal $journal -Status Failed -Results @($_.Exception.Message) | Out-Null
        Write-Log -LogLevel ERROR -Message "BACKUP: Verificacion fallida. $($_.Exception.Message)"
        Write-Error "La verificacion fallo. El origen se conserva sin cambios."
        Write-Host "Log: $logFile"
        if (-not $NoPause) { Read-Host "Presiona Enter para volver..." | Out-Null }
        return [PSCustomObject]@{ Status='Failed'; Message="La verificacion fallo: $($_.Exception.Message)"; LogFile=$logFile; Destination=$destinationPath }
    }

    if ($safeMove) {
        Write-Host "`n[+] Verificacion correcta. Eliminando origen de forma controlada..." -ForegroundColor Yellow
        try {
            $deletedEntries = Remove-AegisVerifiedMoveSources -SourcePaths $sourcePaths -DestinationPath $destinationPath -BackupType $backupType -VerificationType $verificationType -Confirm:$false
        } catch {
            Complete-AegisOperationJournal -Journal $journal -Status Partial -Results @($_.Exception.Message) | Out-Null
            Write-Log -LogLevel ERROR -Message "BACKUP: Copia verificada, pero no se pudo eliminar todo el origen: $($_.Exception.Message)"
            Write-Warning "La copia esta verificada, pero algunos elementos del origen no pudieron eliminarse."
            if (-not $NoPause) { Read-Host "Presiona Enter para volver..." | Out-Null }
            return [PSCustomObject]@{ Status='Partial'; Message="La copia esta verificada, pero no se pudo retirar todo el origen: $($_.Exception.Message)"; LogFile=$logFile; Destination=$destinationPath }
        }
    }

    Complete-AegisOperationJournal -Journal $journal -Status Completed -Results @(
        [PSCustomObject]@{ Destination=$destinationPath; Verification=$verificationType; Mode=$Mode }
    ) | Out-Null

    Write-Host "`n[FIN] Operacion y verificaciones finalizadas correctamente." -ForegroundColor Green
    Write-Host "Log: $logFile"
    if (-not $NoPause) { Read-Host "Presiona Enter para volver..." | Out-Null }
    return [PSCustomObject]@{
        Status = 'Completed'
        Message = 'Operacion y verificaciones finalizadas correctamente.'
        LogFile = $logFile
        Destination = $destinationPath
        Mode = $Mode
        Verification = $verificationType
        SourceCount = $sourcePaths.Count
    }
}

# --- FUNCION: INTERFAZ DE USUARIO DEL MODULO DE RESPALDO ---


function Show-UserDataBackupMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $colorWindow = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $colorPanel = [System.Drawing.Color]::FromArgb(42, 42, 45)
    $colorControl = [System.Drawing.Color]::FromArgb(55, 55, 58)
    $colorAccent = [System.Drawing.Color]::FromArgb(0, 122, 204)
    $colorText = [System.Drawing.Color]::White

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Aegis Phoenix - Respaldo de datos de usuario'
    $form.Size = New-Object System.Drawing.Size(1040, 760)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.BackColor = $colorWindow
    $form.ForeColor = $colorText
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'CENTRO DE RESPALDO DE DATOS'
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 17, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::Cyan
    $form.Controls.Add($lblTitle)

    $lblSubtitle = New-Object System.Windows.Forms.Label
    $lblSubtitle.Text = 'Selecciona origen, destino, modo y verificacion antes de iniciar Robocopy.'
    $lblSubtitle.Location = New-Object System.Drawing.Point(23, 50)
    $lblSubtitle.AutoSize = $true
    $lblSubtitle.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($lblSubtitle)

    $grpSources = New-Object System.Windows.Forms.GroupBox
    $grpSources.Text = '1. Origen del respaldo'
    $grpSources.Location = New-Object System.Drawing.Point(20, 82)
    $grpSources.Size = New-Object System.Drawing.Size(650, 360)
    $grpSources.ForeColor = [System.Drawing.Color]::LightGray
    $grpSources.BackColor = $colorPanel
    $form.Controls.Add($grpSources)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(15, 28)
    $grid.Size = New-Object System.Drawing.Size(620, 265)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(35, 35, 38)
    $grid.BorderStyle = 'None'
    $grid.GridColor = [System.Drawing.Color]::FromArgb(70, 70, 72)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $true
    $grid.EditMode = 'EditOnEnter'
    $grid.AutoSizeColumnsMode = 'None'

    $gridStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $gridStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $gridStyle.ForeColor = $colorText
    $gridStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(65, 85, 100)
    $gridStyle.SelectionForeColor = $colorText
    $grid.DefaultCellStyle = $gridStyle
    $grid.ColumnHeadersDefaultCellStyle = $gridStyle
    $grid.EnableHeadersVisualStyles = $false

    $colSelected = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colSelected.Name = 'Selected'
    $colSelected.HeaderText = 'X'
    $colSelected.Width = 35
    $grid.Columns.Add($colSelected) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.Name = 'Name'
    $colName.HeaderText = 'Nombre'
    $colName.Width = 130
    $colName.ReadOnly = $true
    $grid.Columns.Add($colName) | Out-Null

    $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colType.Name = 'Type'
    $colType.HeaderText = 'Tipo'
    $colType.Width = 105
    $colType.ReadOnly = $true
    $grid.Columns.Add($colType) | Out-Null

    $colPath = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPath.Name = 'Path'
    $colPath.HeaderText = 'Ruta'
    $colPath.Width = 325
    $colPath.ReadOnly = $true
    $grid.Columns.Add($colPath) | Out-Null
    $grpSources.Controls.Add($grid)

    try {
        $bindingFlags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
        $doubleBufferProperty = $grid.GetType().GetProperty('DoubleBuffered', $bindingFlags)
        if ($doubleBufferProperty) { $doubleBufferProperty.SetValue($grid, $true, $null) }
    } catch { }

    $styleButton = {
        param($Button, $BackColor)
        $Button.BackColor = $BackColor
        $Button.ForeColor = $colorText
        $Button.FlatStyle = 'Flat'
        $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(85, 85, 88)
    }

    $btnProfile = New-Object System.Windows.Forms.Button
    $btnProfile.Text = 'Perfil predeterminado'
    $btnProfile.Location = New-Object System.Drawing.Point(15, 307)
    $btnProfile.Size = New-Object System.Drawing.Size(145, 34)
    & $styleButton $btnProfile $colorAccent
    $grpSources.Controls.Add($btnProfile)

    $btnAddFolder = New-Object System.Windows.Forms.Button
    $btnAddFolder.Text = 'Agregar carpeta'
    $btnAddFolder.Location = New-Object System.Drawing.Point(170, 307)
    $btnAddFolder.Size = New-Object System.Drawing.Size(135, 34)
    & $styleButton $btnAddFolder $colorControl
    $grpSources.Controls.Add($btnAddFolder)

    $btnAddFiles = New-Object System.Windows.Forms.Button
    $btnAddFiles.Text = 'Agregar archivos'
    $btnAddFiles.Location = New-Object System.Drawing.Point(315, 307)
    $btnAddFiles.Size = New-Object System.Drawing.Size(135, 34)
    & $styleButton $btnAddFiles $colorControl
    $grpSources.Controls.Add($btnAddFiles)

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = 'Quitar seleccion'
    $btnRemove.Location = New-Object System.Drawing.Point(460, 307)
    $btnRemove.Size = New-Object System.Drawing.Size(160, 34)
    & $styleButton $btnRemove ([System.Drawing.Color]::FromArgb(90, 50, 50))
    $grpSources.Controls.Add($btnRemove)

    $grpMode = New-Object System.Windows.Forms.GroupBox
    $grpMode.Text = '2. Modo de operacion'
    $grpMode.Location = New-Object System.Drawing.Point(685, 82)
    $grpMode.Size = New-Object System.Drawing.Size(320, 205)
    $grpMode.ForeColor = [System.Drawing.Color]::LightGray
    $grpMode.BackColor = $colorPanel
    $form.Controls.Add($grpMode)

    $rbCopy = New-Object System.Windows.Forms.RadioButton
    $rbCopy.Text = 'Copia incremental (recomendado)'
    $rbCopy.Location = New-Object System.Drawing.Point(18, 30)
    $rbCopy.AutoSize = $true
    $rbCopy.Checked = $true
    $rbCopy.ForeColor = [System.Drawing.Color]::LightGreen
    $grpMode.Controls.Add($rbCopy)

    $rbMirror = New-Object System.Windows.Forms.RadioButton
    $rbMirror.Text = 'Espejo (elimina extras del destino)'
    $rbMirror.Location = New-Object System.Drawing.Point(18, 64)
    $rbMirror.AutoSize = $true
    $rbMirror.ForeColor = [System.Drawing.Color]::Orange
    $grpMode.Controls.Add($rbMirror)

    $rbMove = New-Object System.Windows.Forms.RadioButton
    $rbMove.Text = 'Mover (elimina el origen verificado)'
    $rbMove.Location = New-Object System.Drawing.Point(18, 98)
    $rbMove.AutoSize = $true
    $rbMove.ForeColor = [System.Drawing.Color]::Salmon
    $grpMode.Controls.Add($rbMove)

    $lblModeInfo = New-Object System.Windows.Forms.Label
    $lblModeInfo.Text = 'Copia archivos nuevos o modificados sin borrar datos del destino.'
    $lblModeInfo.Location = New-Object System.Drawing.Point(18, 136)
    $lblModeInfo.Size = New-Object System.Drawing.Size(285, 52)
    $lblModeInfo.ForeColor = [System.Drawing.Color]::Silver
    $grpMode.Controls.Add($lblModeInfo)

    $grpVerify = New-Object System.Windows.Forms.GroupBox
    $grpVerify.Text = '3. Verificacion'
    $grpVerify.Location = New-Object System.Drawing.Point(685, 299)
    $grpVerify.Size = New-Object System.Drawing.Size(320, 143)
    $grpVerify.ForeColor = [System.Drawing.Color]::LightGray
    $grpVerify.BackColor = $colorPanel
    $form.Controls.Add($grpVerify)

    $rbVerifyNone = New-Object System.Windows.Forms.RadioButton
    $rbVerifyNone.Text = 'Sin verificacion adicional'
    $rbVerifyNone.Location = New-Object System.Drawing.Point(18, 27)
    $rbVerifyNone.AutoSize = $true
    $grpVerify.Controls.Add($rbVerifyNone)

    $rbVerifyFast = New-Object System.Windows.Forms.RadioButton
    $rbVerifyFast.Text = 'Rapida con Robocopy /L'
    $rbVerifyFast.Location = New-Object System.Drawing.Point(18, 57)
    $rbVerifyFast.AutoSize = $true
    $rbVerifyFast.Checked = $true
    $rbVerifyFast.ForeColor = [System.Drawing.Color]::LightGreen
    $grpVerify.Controls.Add($rbVerifyFast)

    $rbVerifyDeep = New-Object System.Windows.Forms.RadioButton
    $rbVerifyDeep.Text = 'Profunda SHA-256 (lenta)'
    $rbVerifyDeep.Location = New-Object System.Drawing.Point(18, 87)
    $rbVerifyDeep.AutoSize = $true
    $rbVerifyDeep.ForeColor = [System.Drawing.Color]::Khaki
    $grpVerify.Controls.Add($rbVerifyDeep)

    $lblVerifyInfo = New-Object System.Windows.Forms.Label
    $lblVerifyInfo.Text = 'Mover siempre exige verificacion.'
    $lblVerifyInfo.Location = New-Object System.Drawing.Point(18, 113)
    $lblVerifyInfo.AutoSize = $true
    $lblVerifyInfo.ForeColor = [System.Drawing.Color]::Gray
    $grpVerify.Controls.Add($lblVerifyInfo)

    $grpDestination = New-Object System.Windows.Forms.GroupBox
    $grpDestination.Text = '4. Destino'
    $grpDestination.Location = New-Object System.Drawing.Point(20, 455)
    $grpDestination.Size = New-Object System.Drawing.Size(985, 82)
    $grpDestination.ForeColor = [System.Drawing.Color]::LightGray
    $grpDestination.BackColor = $colorPanel
    $form.Controls.Add($grpDestination)

    $txtDestination = New-Object System.Windows.Forms.TextBox
    $txtDestination.Location = New-Object System.Drawing.Point(15, 31)
    $txtDestination.Size = New-Object System.Drawing.Size(790, 25)
    $txtDestination.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 38)
    $txtDestination.ForeColor = $colorText
    $txtDestination.BorderStyle = 'FixedSingle'
    $grpDestination.Controls.Add($txtDestination)

    $btnDestination = New-Object System.Windows.Forms.Button
    $btnDestination.Text = 'Examinar...'
    $btnDestination.Location = New-Object System.Drawing.Point(820, 27)
    $btnDestination.Size = New-Object System.Drawing.Size(145, 32)
    & $styleButton $btnDestination $colorControl
    $grpDestination.Controls.Add($btnDestination)

    $txtSummary = New-Object System.Windows.Forms.TextBox
    $txtSummary.Location = New-Object System.Drawing.Point(20, 550)
    $txtSummary.Size = New-Object System.Drawing.Size(985, 82)
    $txtSummary.Multiline = $true
    $txtSummary.ReadOnly = $true
    $txtSummary.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 21)
    $txtSummary.ForeColor = [System.Drawing.Color]::LightGray
    $txtSummary.BorderStyle = 'FixedSingle'
    $form.Controls.Add($txtSummary)

    $btnLogs = New-Object System.Windows.Forms.Button
    $btnLogs.Text = 'ABRIR LOGS'
    $btnLogs.Location = New-Object System.Drawing.Point(20, 650)
    $btnLogs.Size = New-Object System.Drawing.Size(130, 38)
    & $styleButton $btnLogs $colorControl
    $form.Controls.Add($btnLogs)

    $btnRelocate = New-Object System.Windows.Forms.Button
    $btnRelocate.Text = 'REUBICAR CARPETAS'
    $btnRelocate.Location = New-Object System.Drawing.Point(165, 650)
    $btnRelocate.Size = New-Object System.Drawing.Size(175, 38)
    & $styleButton $btnRelocate ([System.Drawing.Color]::FromArgb(80, 65, 35))
    $form.Controls.Add($btnRelocate)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'CANCELAR'
    $btnCancel.Location = New-Object System.Drawing.Point(715, 650)
    $btnCancel.Size = New-Object System.Drawing.Size(130, 38)
    & $styleButton $btnCancel ([System.Drawing.Color]::FromArgb(75, 55, 55))
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel)

    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Text = 'INICIAR RESPALDO'
    $btnStart.Location = New-Object System.Drawing.Point(855, 650)
    $btnStart.Size = New-Object System.Drawing.Size(150, 38)
    & $styleButton $btnStart ([System.Drawing.Color]::FromArgb(0, 125, 90))
    $btnStart.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnStart)
    $form.AcceptButton = $btnStart
    $form.CancelButton = $btnCancel

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($rbMirror, 'Solo esta disponible para carpetas. Elimina del destino los elementos que ya no existan en el origen.')
    $toolTip.SetToolTip($rbMove, 'Primero copia, despues verifica y solo entonces elimina los archivos del origen.')
    $toolTip.SetToolTip($rbVerifyDeep, 'Compara el hash SHA-256 de cada archivo. Es la opcion mas lenta y rigurosa.')

    $getSelectedPaths = {
        $paths = [System.Collections.Generic.List[string]]::new()
        foreach ($row in $grid.Rows) {
            $isSelected = $false
            try { $isSelected = [Convert]::ToBoolean($row.Cells['Selected'].Value) } catch { }
            if ($isSelected) { $paths.Add([string]$row.Cells['Path'].Value) }
        }
        return $paths.ToArray()
    }

    $updateSummary = {
        $selectedCount = @(& $getSelectedPaths).Count
        $containsFiles = @($grid.Rows | Where-Object { $_.Tag -eq 'Files' }).Count -gt 0
        $rbMirror.Enabled = -not $containsFiles
        if ($containsFiles -and $rbMirror.Checked) { $rbCopy.Checked = $true }

        if ($rbMove.Checked) {
            $rbVerifyNone.Enabled = $false
            if ($rbVerifyNone.Checked) { $rbVerifyFast.Checked = $true }
            $lblModeInfo.Text = 'Copia, verifica y despues elimina cada archivo del origen de forma controlada.'
            $lblModeInfo.ForeColor = [System.Drawing.Color]::Salmon
        } elseif ($rbMirror.Checked) {
            $rbVerifyNone.Enabled = $true
            $lblModeInfo.Text = 'Iguala cada carpeta de destino al origen y elimina elementos extra del destino.'
            $lblModeInfo.ForeColor = [System.Drawing.Color]::Orange
        } else {
            $rbVerifyNone.Enabled = $true
            $lblModeInfo.Text = 'Copia archivos nuevos o modificados sin borrar datos del destino.'
            $lblModeInfo.ForeColor = [System.Drawing.Color]::Silver
        }

        $modeText = if ($rbMove.Checked) { 'Mover' } elseif ($rbMirror.Checked) { 'Espejo' } else { 'Copia incremental' }
        $verifyText = if ($rbVerifyDeep.Checked) { 'SHA-256 profunda' } elseif ($rbVerifyFast.Checked) { 'Rapida /L' } else { 'Sin verificacion adicional' }
        $destinationText = if ([string]::IsNullOrWhiteSpace($txtDestination.Text)) { '(sin seleccionar)' } else { $txtDestination.Text }
        $sourceKindText = if ($containsFiles) { 'archivos' } else { 'carpetas' }
        $txtSummary.Text = "Seleccionados: $selectedCount $sourceKindText`r`nModo: $modeText | Verificacion: $verifyText`r`nDestino: $destinationText"
    }

    $loadProfile = {
        $grid.Rows.Clear()
        foreach ($folder in @(Get-AegisKnownUserBackupFolders)) {
            $rowIndex = $grid.Rows.Add($folder.Exists, $folder.Name, 'Perfil', $folder.Path)
            $row = $grid.Rows[$rowIndex]
            $row.Tag = 'Folders'
            if (-not $folder.Exists) {
                $row.Cells['Selected'].ReadOnly = $true
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
                $row.Cells['Type'].Value = 'No disponible'
            }
        }
        & $updateSummary
    }

    $btnProfile.Add_Click({ & $loadProfile })

    $btnAddFolder.Add_Click({
        $containsFiles = @($grid.Rows | Where-Object { $_.Tag -eq 'Files' }).Count -gt 0
        if ($containsFiles) {
            $answer = [System.Windows.Forms.MessageBox]::Show('La seleccion actual contiene archivos. Para evitar mezclar tipos se reemplazara por carpetas. Continuar?', 'Cambiar tipo de origen', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $grid.Rows.Clear()
        }
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Selecciona una carpeta de origen'
        if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $fullPath = (Get-Item -LiteralPath $dialog.SelectedPath -ErrorAction Stop).FullName
        $duplicate = @($grid.Rows | Where-Object { ([string]$_.Cells['Path'].Value).Equals($fullPath, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        if (-not $duplicate) {
            $displayName = Split-Path $fullPath -Leaf
            if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = $fullPath }
            $rowIndex = $grid.Rows.Add($true, $displayName, 'Carpeta', $fullPath)
            $grid.Rows[$rowIndex].Tag = 'Folders'
        }
        & $updateSummary
    })

    $btnAddFiles.Add_Click({
        $containsFolders = @($grid.Rows | Where-Object { $_.Tag -eq 'Folders' }).Count -gt 0
        if ($containsFolders) {
            $answer = [System.Windows.Forms.MessageBox]::Show('La seleccion actual contiene carpetas. Para evitar mezclar tipos se reemplazara por archivos. Continuar?', 'Cambiar tipo de origen', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $grid.Rows.Clear()
        }
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Selecciona uno o varios archivos de origen'
        $dialog.Filter = 'Todos los archivos (*.*)|*.*'
        $dialog.Multiselect = $true
        $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) { return }
        foreach ($filePath in $dialog.FileNames) {
            $fullPath = (Get-Item -LiteralPath $filePath -ErrorAction Stop).FullName
            $duplicate = @($grid.Rows | Where-Object { ([string]$_.Cells['Path'].Value).Equals($fullPath, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
            if (-not $duplicate) {
                $rowIndex = $grid.Rows.Add($true, (Split-Path $fullPath -Leaf), 'Archivo', $fullPath)
                $grid.Rows[$rowIndex].Tag = 'Files'
            }
        }
        & $updateSummary
    })

    $btnRemove.Add_Click({
        foreach ($row in @($grid.SelectedRows | Sort-Object Index -Descending)) {
            if (-not $row.IsNewRow) { $grid.Rows.RemoveAt($row.Index) }
        }
        & $updateSummary
    })

    $btnDestination.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Selecciona la carpeta de destino del respaldo'
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtDestination.Text = $dialog.SelectedPath
            & $updateSummary
        }
    })

    $btnLogs.Add_Click({
        $logDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'Logs'
        if (-not (Test-Path -LiteralPath $logDirectory)) { New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null }
        Start-Process explorer.exe -ArgumentList @($logDirectory)
    })

    $btnRelocate.Add_Click({
        Show-UserProfileRelocationDialog
        & $loadProfile
    })

    $grid.Add_CurrentCellDirtyStateChanged({
        if ($grid.IsCurrentCellDirty) { $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
    })
    $grid.Add_CellValueChanged({ & $updateSummary })
    $txtDestination.Add_TextChanged({ & $updateSummary })
    foreach ($radio in @($rbCopy, $rbMirror, $rbMove, $rbVerifyNone, $rbVerifyFast, $rbVerifyDeep)) {
        $radio.Add_CheckedChanged({ & $updateSummary })
    }

    $btnStart.Add_Click({
        $grid.EndEdit()
        $selectedPaths = @(& $getSelectedPaths)
        if ($selectedPaths.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Selecciona al menos una carpeta o archivo valido.', 'Origen requerido', 0, 48) | Out-Null
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtDestination.Text) -or -not (Test-Path -LiteralPath $txtDestination.Text -PathType Container)) {
            [System.Windows.Forms.MessageBox]::Show('Selecciona una carpeta de destino existente.', 'Destino requerido', 0, 48) | Out-Null
            return
        }

        $mode = if ($rbMove.Checked) { 'Move' } elseif ($rbMirror.Checked) { 'Mirror' } else { 'Copy' }
        $verification = if ($rbVerifyDeep.Checked) { 'Deep' } elseif ($rbVerifyFast.Checked) { 'Fast' } else { 'None' }

        if ($mode -eq 'Mirror') {
            $answer = [System.Windows.Forms.MessageBox]::Show("El modo ESPEJO eliminara del destino los archivos que no existan en el origen.`n`nConfirma que el destino es correcto.", 'Confirmar espejo', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }
        if ($mode -eq 'Move') {
            $answer = [System.Windows.Forms.MessageBox]::Show("El modo MOVER eliminara del origen cada archivo despues de copiarlo y verificarlo.`n`n¿Deseas continuar?", 'Confirmar movimiento', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }

        $destinationFull = (Get-Item -LiteralPath $txtDestination.Text -ErrorAction Stop).FullName
        $destinationDrive = Split-Path $destinationFull -Qualifier -ErrorAction SilentlyContinue
        $sourceDrives = @($selectedPaths | ForEach-Object { Split-Path $_ -Qualifier -ErrorAction SilentlyContinue } | Where-Object { $_ } | Select-Object -Unique)
        if ($destinationDrive -and @($sourceDrives | Where-Object { $_ -eq $destinationDrive }).Count -gt 0) {
            $answer = [System.Windows.Forms.MessageBox]::Show("El origen y el destino comparten el volumen $destinationDrive. Este respaldo no protege contra una falla de esa unidad.`n`n¿Continuar de todos modos?", 'Mismo volumen', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }

        $allowUnknownSpace = $false
        try {
            $volume = Get-Volume -ErrorAction Stop | Where-Object { ($_.DriveLetter + ':') -eq $destinationDrive } | Select-Object -First 1
            if (-not $volume -or $null -eq $volume.SizeRemaining) { throw 'Espacio no disponible.' }
        } catch {
            $answer = [System.Windows.Forms.MessageBox]::Show("No se pudo determinar el espacio libre del destino (por ejemplo, una ruta de red).`n`n¿Continuar sin validar el espacio disponible?", 'Espacio desconocido', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $allowUnknownSpace = $true
        }

        $form.Tag = [PSCustomObject]@{
            SourcePaths = $selectedPaths
            Destination = $destinationFull
            Mode = $mode
            Verification = $verification
            AllowUnknownSpace = $allowUnknownSpace
        }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    & $loadProfile
    & $updateSummary

    $dialogResult = $form.ShowDialog()
    $configuration = $form.Tag
    $form.Dispose()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $configuration) { return }

    Write-Log -LogLevel INFO -Message "BACKUP GUI: $($configuration.SourcePaths.Count) origen(es), modo $($configuration.Mode), verificacion $($configuration.Verification)."
    Clear-Host
    Write-Host 'La configuracion grafica fue validada. La salida de Robocopy se mostrara en esta consola.' -ForegroundColor Cyan

    try {
        $result = Invoke-UserDataBackup -Mode $configuration.Mode -CustomSourcePath $configuration.SourcePaths `
            -DestinationPath $configuration.Destination -VerificationType $configuration.Verification `
            -SkipSameVolumePrompt -AllowUnknownDestinationSpace:$configuration.AllowUnknownSpace -NoPause

        if (-not $result) { return }
        $message = "$($result.Message)`n`nDestino: $($result.Destination)"
        if ($result.LogFile) { $message += "`nLog: $($result.LogFile)" }
        switch ($result.Status) {
            'Completed' { [System.Windows.Forms.MessageBox]::Show($message, 'Respaldo completado', 0, 64) | Out-Null }
            'Partial' { [System.Windows.Forms.MessageBox]::Show($message, 'Respaldo parcial', 0, 48) | Out-Null }
            default { [System.Windows.Forms.MessageBox]::Show($message, 'Error en el respaldo', 0, 16) | Out-Null }
        }
    } catch {
        Write-Log -LogLevel ERROR -Message "BACKUP GUI: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("No se pudo iniciar o completar el respaldo:`n`n$($_.Exception.Message)", 'Error en el respaldo', 0, 16) | Out-Null
    }
}