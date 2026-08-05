# =================================================================
#  Modulo-Limpieza
#
#  CONTENIDO   : Show-CleaningMenu, Clean-BrowserCaches
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Invoke-AegisNativeProcess      : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - Test-AegisCapability           : verifica disponibilidad de un comando/capacidad del sistema
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-Limpieza.ps1"
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

function Get-CleanableSize {
    param([string[]]$Paths)
    [long]$totalSize = 0
    foreach ($path in $Paths) {
        try {
            if (Test-Path -LiteralPath $path) {
                Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction Stop | ForEach-Object {
                    $totalSize += [long]$_.Length
                }
            }
        }
        catch {
            Write-Warning "No se pudo calcular el tamaño de '$path': $($_.Exception.Message)"
        }
    }
    return $totalSize
}

# --- FUNCIoN AUXILIAR NUEVA: Elimina archivos de forma robusta ---

function Remove-FilesSafely {
    param(
        [string]$Path,
        [switch]$ForceSystemFiles = $false
    )
    
    Write-Host "   - Limpiando: $Path" -ForegroundColor Gray
    
    $result = [ordered]@{ Path=$Path; Scanned=0; Deleted=0; Failed=0; FreedBytes=[long]0; Errors=[System.Collections.Generic.List[string]]::new() }
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "     [INFO] La ruta '$Path' no existe." -ForegroundColor Gray
        return [PSCustomObject]$result
    }

    try {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction Stop | ForEach-Object {
            $file = $_
            $result.Scanned++
            $length = [long]$file.Length
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $result.Deleted++
                $result.FreedBytes += $length
            } catch {
                if ($ForceSystemFiles) {
                    try {
                        $item = Get-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                        $item.IsReadOnly = $false
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                        $result.Deleted++
                        $result.FreedBytes += $length
                    } catch {
                        $result.Failed++
                        $result.Errors.Add("$($file.FullName): $($_.Exception.Message)")
                    }
                } else {
                    $result.Failed++
                    $result.Errors.Add("$($file.FullName): $($_.Exception.Message)")
                }
            }
        }
    } catch {
        $result.Failed++
        $result.Errors.Add("Enumeracion: $($_.Exception.Message)")
    }

    try {
        @(Get-ChildItem -LiteralPath $Path -Directory -Force -Recurse -ErrorAction Stop |
            Sort-Object { $_.FullName.Length } -Descending) | ForEach-Object {
                if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                }
            }
    } catch {
        $result.Errors.Add("Directorios: $($_.Exception.Message)")
    }

    foreach ($errorDetail in $result.Errors) { Write-Log -LogLevel WARN -Message "LIMPIEZA: $errorDetail" }
    $percent = if ($result.Scanned -gt 0) { [math]::Round(($result.Deleted / $result.Scanned) * 100, 1) } else { 100 }
    Write-Host "     [RESULTADO] Eliminados $($result.Deleted) de $($result.Scanned) archivos ($percent%). Fallos: $($result.Failed)" -ForegroundColor $(if ($result.Failed -eq 0) { 'Green' } else { 'Yellow' })
    return [PSCustomObject]$result
}

# --- FUNCIoN MEJORADA Y BLINDADA: Menu Principal de Limpieza ---

function Show-CleaningMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Limpieza de Sistema"
    $form.Size = New-Object System.Drawing.Size(900, 650)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. VARIABLES Y RUTAS ---
    $tempPaths = @(
        "$env:TEMP", "$env:windir\Temp", "$env:windir\Minidump", "$env:LOCALAPPDATA\CrashDumps",
        "$env:windir\Prefetch", "$env:windir\SoftwareDistribution\Download", "$env:windir\LiveKernelReports"
    )
    $cachePaths = @(
        "$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:windir\SoftwareDistribution\DeliveryOptimization"
    )

    # --- 3. UI SUPERIOR ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Limpieza Profunda de Disco"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "Analizar Espacio (Scan)"
    $btnScan.Location = New-Object System.Drawing.Point(700, 20)
    $btnScan.Size = New-Object System.Drawing.Size(160, 30)
    $btnScan.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnScan.ForeColor = [System.Drawing.Color]::White
    $btnScan.FlatStyle = "Flat"
    $form.Controls.Add($btnScan)

    # --- 4. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 70)
    $grid.Size = New-Object System.Drawing.Size(840, 350)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colCat = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCat.HeaderText = "Categoria"
    $colCat.Name = "Category"
    $colCat.ReadOnly = $true
    $colCat.Width = 150
    $grid.Columns.Add($colCat) | Out-Null

    $colDesc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDesc.HeaderText = "Descripcion"
    $colDesc.Name = "Desc"
    $colDesc.ReadOnly = $true
    $colDesc.Width = 350
    $grid.Columns.Add($colDesc) | Out-Null

    $colSize = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colSize.HeaderText = "Tamano Detectado"
    $colSize.Name = "Size"
    $colSize.ReadOnly = $true
    $colSize.Width = 120
    $grid.Columns.Add($colSize) | Out-Null

    $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colType.Name = "InternalType"
    $colType.Visible = $false
    $grid.Columns.Add($colType) | Out-Null

    $form.Controls.Add($grid)

    # --- 5. AGREGAR FILAS BASE ---
    $row1 = $grid.Rows.Add($false, "Archivos Temporales", "Temporales de Windows, Logs, Dumps de error, Prefetch.", "Pendiente...", "TEMP")
    $row2 = $grid.Rows.Add($false, "Caches del Sistema", "Cache de DirectX, NVIDIA, Miniaturas (Requiere reinicio de Explorer).", "Pendiente...", "CACHE")
    $row3 = $grid.Rows.Add($false, "Papelera de Reciclaje", "Archivos borrados por el usuario.", "Pendiente...", "BIN")
    $row4 = $grid.Rows.Add($false, "Limpieza Profunda (Admin)", "Componentes y actualizaciones antiguas mediante DISM/CleanMgr.", "N/A", "DEEP")
    
    # Colorear la fila DEEP para advertencia
    $grid.Rows[$row4].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Orange

    # --- 6. BARRA DE PROGRESO Y ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 440)
    $progressBar.Size = New-Object System.Drawing.Size(840, 20)
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Pulsa 'Analizar Espacio' para comenzar."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 470)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    # --- 7. BOTONES INFERIORES ---
    $btnClean = New-Object System.Windows.Forms.Button
    $btnClean.Text = "EJECUTAR LIMPIEZA SELECCIONADA"
    $btnClean.Location = New-Object System.Drawing.Point(560, 520)
    $btnClean.Size = New-Object System.Drawing.Size(300, 50)
    $btnClean.BackColor = [System.Drawing.Color]::Crimson
    $btnClean.ForeColor = [System.Drawing.Color]::White
    $btnClean.FlatStyle = "Flat"
    $btnClean.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnClean)

    $chkForce = New-Object System.Windows.Forms.CheckBox
    $chkForce.Text = "Cerrar navegadores de forma controlada"
    $chkForce.Location = New-Object System.Drawing.Point(20, 520)
    $chkForce.AutoSize = $true
    $chkForce.Checked = $false
    $form.Controls.Add($chkForce)

    # --- LOGICA: SCAN ---
    $btnScan.Add_Click({
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = "Calculando tamanos... esto puede tardar un momento."
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $sizeTemp = Get-CleanableSize -Paths $tempPaths
            $grid.Rows[0].Cells["Size"].Value = "$([math]::Round($sizeTemp / 1MB, 2)) MB"

            $sizeCache = Get-CleanableSize -Paths $cachePaths
            $grid.Rows[1].Cells["Size"].Value = "$([math]::Round($sizeCache / 1MB, 2)) MB"

            $sizeBin = 0
            $shell = New-Object -ComObject Shell.Application
            $binItems = $shell.NameSpace(0x0a).Items()
            foreach ($item in $binItems) { $sizeBin += [long]$item.Size }
            $grid.Rows[2].Cells["Size"].Value = "$([math]::Round($sizeBin / 1MB, 2)) MB"
            $lblStatus.Text = "Analisis completado."
        } catch {
            $lblStatus.Text = "Analisis parcial: $($_.Exception.Message)"
            Write-Log -LogLevel WARN -Message "LIMPIEZA: Analisis parcial: $($_.Exception.Message)"
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

    # --- LOGICA: CLEAN ---
    $btnClean.Add_Click({
        # Identificar qué se va a limpiar
        $tasks = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $tasks += $row.Cells["InternalType"].Value
            }
        }

        if ($tasks.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Selecciona al menos una categoria.", "Aviso", 0, 48)
            return
        }

        # Advertencia especial para DEEP CLEAN
        if ($tasks -contains "DEEP") {
            $warn = "Has seleccionado 'Limpieza Profunda'.\n\n- Se ejecutaran DISM y CleanMgr, que pueden retirar instalaciones anteriores.\n- No se forzaran permisos ni se borrara Windows.old manualmente.\n- El proceso puede tardar mucho.\n\nDeseas continuar?"
            if ([System.Windows.Forms.MessageBox]::Show($warn, "Advertencia Critica", 4, 48) -ne 'Yes') { return }
        }

        # Confirmacion general
        if ([System.Windows.Forms.MessageBox]::Show("Iniciar proceso de limpieza?", "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnClean.Enabled = $false
        $progressBar.Value = 0
        $totalSteps = $tasks.Count + 1 # +1 por el cierre final
        $currentStep = 0
        $totalFreed = 0
        $cleanErrors = 0
        $journal = New-AegisOperationJournal -Module 'Limpieza' -Action 'Clean' -Targets $tasks -Metadata @{ CloseBrowsers=[bool]$chkForce.Checked }
        $operationResults = [System.Collections.Generic.List[object]]::new()

        try {
        # Cerrar procesos si es necesario
        if ($tasks -contains "TEMP" -or $tasks -contains "CACHE") {
            if ($chkForce.Checked) {
                $lblStatus.Text = "Solicitando el cierre de navegadores..."
                $browserProcesses = @(Get-Process -Name @('chrome','firefox','msedge') -ErrorAction SilentlyContinue)
                foreach ($browserProcess in $browserProcesses) { try { [void]$browserProcess.CloseMainWindow() } catch {} }
                if ($browserProcesses.Count -gt 0) { Start-Sleep -Seconds 3 }
                foreach ($browserProcess in $browserProcesses) {
                    try {
                        if (-not $browserProcess.HasExited) { Stop-Process -Id $browserProcess.Id -Force -ErrorAction Stop }
                    } catch {
                        $cleanErrors++
                        Write-Log -LogLevel WARN -Message "LIMPIEZA: No se pudo cerrar '$($browserProcess.ProcessName)': $($_.Exception.Message)"
                    }
                }
            }
        }

        # Bucle de tareas
        foreach ($type in $tasks) {
            $currentStep++
            $progressVal = [int](($currentStep / $totalSteps) * 100)
            $progressBar.Value = $progressVal
            
            switch ($type) {
                "TEMP" {
                    $lblStatus.Text = "Limpiando archivos temporales..."
                    [System.Windows.Forms.Application]::DoEvents()
                    foreach ($path in $tempPaths) {
                        if (Test-Path $path) { 
                            $cleanResult = Remove-FilesSafely -Path $path
                            $totalFreed += [long]$cleanResult.FreedBytes
                            $cleanErrors += [int]$cleanResult.Failed
                            $operationResults.Add($cleanResult)
                        }
                    }
                }
                "CACHE" {
                    $lblStatus.Text = "Limpiando caches y reiniciando Explorer..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # Matar Explorer para limpiar miniaturas
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Sleep -Milliseconds 500
                    
                    foreach ($path in $cachePaths) {
                        if (Test-Path $path) { 
                            $cleanResult = Remove-FilesSafely -Path $path
                            $totalFreed += [long]$cleanResult.FreedBytes
                            $cleanErrors += [int]$cleanResult.Failed
                            $operationResults.Add($cleanResult)
                        }
                    }
                    
                    # Miniaturas
                    try {
                        $thumb = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                        if (Test-Path "$thumb\thumbcache_*.db") {
                            Remove-Item "$thumb\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                        }
                    } catch {
                        $cleanErrors++
                        Write-Log -LogLevel WARN -Message "LIMPIEZA: No se pudo limpiar completamente la cache de miniaturas: $($_.Exception.Message)"
                    }
                    
                    # Reiniciar Explorer inmediatamente
                    Start-Process "explorer.exe"
                }
                "BIN" {
                    $lblStatus.Text = "Vaciando Papelera de Reciclaje..."
                    [System.Windows.Forms.Application]::DoEvents()
                    try {
                        # Calculamos tamaño antes de borrar para sumar al total
                        $shell = New-Object -ComObject Shell.Application
                        $items = $shell.NameSpace(0x0a).Items()
                        foreach ($i in $items) { try { $totalFreed += [long]$i.Size } catch {} }
                        
                        Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop
                    } catch {
                        $cleanErrors++
                        Write-Log -LogLevel WARN -Message "LIMPIEZA: No se pudo vaciar completamente la papelera: $($_.Exception.Message)"
                    }
                }
                "DEEP" {
                    $lblStatus.Text = "Ejecutando Limpieza Profunda (DISM/CleanMgr)..."
                    $lblStatus.ForeColor = [System.Drawing.Color]::Cyan
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    $stateFlagsBackup = [System.Collections.Generic.List[object]]::new()
                    try {
                        # 1. DISM (Oculto, espera simple)
                        $dismResult = Invoke-AegisNativeProcess -FilePath 'dism.exe' -ArgumentList @('/Online','/Cleanup-Image','/StartComponentCleanup','/NoRestart') -TimeoutSeconds 7200
                        $operationResults.Add([PSCustomObject]@{ Step='DISM StartComponentCleanup'; Success=$true; ExitCode=$dismResult.ExitCode })
                        
                        # 2. Configurar Registro (Sageset dinamico)
                        $handlers = @("Temporary Files", "Recycle Bin", "Update Cleanup", "Windows Upgrade Log Files", "Previous Installations")
                        foreach ($h in $handlers) {
                            $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$h"
                            if (Test-Path $reg) {
                                $existing = Get-ItemProperty -Path $reg -Name 'StateFlags0099' -ErrorAction SilentlyContinue
                                $hadValue = $null -ne $existing -and $null -ne $existing.PSObject.Properties['StateFlags0099']
                                $oldValue = if ($hadValue) { $existing.StateFlags0099 } else { $null }
                                $stateFlagsBackup.Add([PSCustomObject]@{ Path=$reg; HadValue=$hadValue; Value=$oldValue })
                                Set-ItemProperty -Path $reg -Name "StateFlags0099" -Value 2 -Type DWord -Force -ErrorAction Stop
                            }
                        }
                        
                        # 3. Ejecutar CleanMgr solo cuando exista en esta compilacion.
                        if (Test-AegisCapability -Command 'cleanmgr.exe') {
                            $cleanMgrResult = Invoke-AegisNativeProcess -FilePath 'cleanmgr.exe' -ArgumentList @('/sagerun:99') -TimeoutSeconds 7200
                            $operationResults.Add([PSCustomObject]@{ Step='CleanMgr'; Success=$true; ExitCode=$cleanMgrResult.ExitCode })
                        } else {
                            Write-Log -LogLevel WARN -Message 'LIMPIEZA: CleanMgr no esta disponible; se completo solamente DISM.'
                        }
                        
                        # Windows.old solo se elimina por mecanismos soportados.
                        $winOldPath = "$env:SystemDrive\Windows.old"
                        if (Test-Path -LiteralPath $winOldPath) {
                            Write-Log -LogLevel WARN -Message "LIMPIEZA: Windows.old permanece tras DISM/CleanMgr; no se forzo su eliminacion."
                            $lblStatus.Text = "Windows.old permanece; usa Configuracion > Almacenamiento."
                        }
                    } catch {
                        $cleanErrors++
                        $operationResults.Add([PSCustomObject]@{ Step='DeepClean'; Success=$false; Error=$_.Exception.Message })
                        Write-Log -LogLevel ERROR -Message "Error en Deep Clean GUI: $($_.Exception.Message)"
                    } finally {
                        foreach ($backupEntry in $stateFlagsBackup) {
                            try {
                                if ($backupEntry.HadValue) {
                                    Set-ItemProperty -Path $backupEntry.Path -Name 'StateFlags0099' -Value $backupEntry.Value -Type DWord -Force -ErrorAction Stop
                                } else {
                                    Remove-ItemProperty -Path $backupEntry.Path -Name 'StateFlags0099' -Force -ErrorAction SilentlyContinue
                                }
                            } catch {
                                $cleanErrors++
                                Write-Log -LogLevel ERROR -Message "LIMPIEZA: No se pudo restaurar StateFlags0099 en '$($backupEntry.Path)': $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
        }
        Complete-AegisOperationJournal -Journal $journal -Status $(if ($cleanErrors -eq 0) { 'Completed' } else { 'Partial' }) -Results @($operationResults) | Out-Null
        } catch {
            $cleanErrors++
            Write-Log -LogLevel ERROR -Message "LIMPIEZA: Fallo no controlado: $($_.Exception.Message)"
            Complete-AegisOperationJournal -Journal $journal -Status Failed -Results @($_.Exception.Message) | Out-Null
        } finally {
            if ((Get-Process -Name explorer -ErrorAction SilentlyContinue) -eq $null) {
                Start-Process "explorer.exe" -ErrorAction SilentlyContinue
            }
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $btnClean.Enabled = $true
        }

        $progressBar.Value = 100
        $freedMB = [math]::Round($totalFreed / 1MB, 2)
        $lblStatus.Text = "Limpieza finalizada."
        $msg = "Proceso terminado. Errores: $cleanErrors."
        if ($totalFreed -gt 0) { $msg += "`n`nEspacio recuperado aprox: $freedMB MB" }
        [System.Windows.Forms.MessageBox]::Show($msg, "Resultado", 0, $(if ($cleanErrors -eq 0) { 64 } else { 48 }))
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

function Clean-BrowserCaches {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Log -LogLevel INFO -Message "MANTENIMIENTO: Inicio de limpieza robusta de navegadores."
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "            Limpieza Profunda de Navegadores           " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [!] ADVERTENCIA: Se solicitara cerrar los navegadores y solo se forzara si no responden." -ForegroundColor Yellow
    Write-Host "   [i] Se verificara que los archivos no esten bloqueados." -ForegroundColor Gray
    Write-Host ""
    
    if ((Read-Host "Deseas continuar? (S/N)").ToUpper() -ne 'S') { return }

    # Definición expandida de objetivos
    $browsers = @(
        @{ Name="Google Chrome"; Process="chrome"; Path="$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache*" },
        @{ Name="Google Chrome (GPU)"; Process="chrome"; Path="$env:LOCALAPPDATA\Google\Chrome\User Data\*\GPUCache*" },
        @{ Name="Microsoft Edge"; Process="msedge"; Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache*" },
        @{ Name="Microsoft Edge (GPU)"; Process="msedge"; Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\GPUCache*" },
        @{ Name="Brave Browser"; Process="brave"; Path="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Cache*" },
        @{ Name="Opera Stable"; Process="opera"; Path="$env:LOCALAPPDATA\Opera Software\Opera Stable\Cache*" },
        @{ Name="Opera GX"; Process="opera_gx"; Path="$env:LOCALAPPDATA\Opera Software\Opera GX Stable\Cache*" },
        @{ Name="Mozilla Firefox"; Process="firefox"; Path="$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2*" }
    )

    $globalFreed = 0

    foreach ($browserGroup in ($browsers | Group-Object Process)) {
        $processName = $browserGroup.Name
        $displayNames = ($browserGroup.Group.Name -join ', ')
        Write-Host "`n[+] Analizando: $displayNames..." -ForegroundColor Cyan
        if (-not $PSCmdlet.ShouldProcess($displayNames, "Cerrar el navegador una vez y eliminar sus carpetas de cache")) { continue }

        $processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
        foreach ($browserProcess in $processes) { try { [void]$browserProcess.CloseMainWindow() } catch {} }
        if ($processes.Count -gt 0) { Start-Sleep -Seconds 3 }
        foreach ($browserProcess in $processes) {
            try {
                if (-not $browserProcess.HasExited) { Stop-Process -Id $browserProcess.Id -Force -ErrorAction Stop }
            } catch {
                Write-Log -LogLevel ERROR -Message "BROWSER CLEAN: No se pudo cerrar ${processName}: $($_.Exception.Message)"
            }
        }

        foreach ($target in $browserGroup.Group) {
            foreach ($folder in @(Get-Item -Path $target.Path -ErrorAction SilentlyContinue)) {
                $cleanResult = Remove-FilesSafely -Path $folder.FullName
                $globalFreed += [long]$cleanResult.FreedBytes
            }
        }
    }

    $totalFreedMB = [math]::Round($globalFreed / 1MB, 2)
    Write-Host "`n-------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "   RESUMEN FINAL DE LIMPIEZA" -ForegroundColor Cyan
    if ($totalFreedMB -gt 0) {
        Write-Host "   Espacio Real Recuperado: $totalFreedMB MB" -ForegroundColor Green
        Write-Log -LogLevel ACTION -Message "BROWSER CLEAN: Limpieza masiva completada. Recuperados $totalFreedMB MB."
    } else {
        Write-Host "   No se requeria limpieza." -ForegroundColor White
    }
    Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
    
    Read-Host "Presiona Enter para volver..."
}