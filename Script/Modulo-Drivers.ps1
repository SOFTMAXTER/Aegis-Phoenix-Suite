# =================================================================
#  Modulo-Drivers
#
#  CONTENIDO   : Show-DriverMenu
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Invoke-AegisNativeProcess      : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-Drivers.ps1"
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

function Show-DriverMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Administrador de Controladores (Drivers)"
    $form.Size = New-Object System.Drawing.Size(1050, 750)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR (FILTROS) ---
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "Repositorio de Drivers (Driver Store)"
    $lblInfo.Location = New-Object System.Drawing.Point(20, 15)
    $lblInfo.AutoSize = $true
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblInfo)

    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Filtrar:"
    $lblSearch.Location = New-Object System.Drawing.Point(350, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(410, 20)
    $txtSearch.Width = 300
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $chkShowMS = New-Object System.Windows.Forms.CheckBox
    $chkShowMS.Text = "Mostrar Microsoft"
    $chkShowMS.Location = New-Object System.Drawing.Point(730, 20)
    $chkShowMS.AutoSize = $true
    $chkShowMS.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($chkShowMS)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(880, 15)
    $btnRefresh.Size = New-Object System.Drawing.Size(130, 30)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(990, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $true
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion grafica
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

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

    $colInf = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colInf.HeaderText = "Archivo INF"
    $colInf.Name = "InfName"
    $colInf.Width = 100
    $colInf.ReadOnly = $true
    $grid.Columns.Add($colInf) | Out-Null

    $colProv = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colProv.HeaderText = "Fabricante (Provider)"
    $colProv.Name = "Provider"
    $colProv.Width = 200
    $colProv.ReadOnly = $true
    $grid.Columns.Add($colProv) | Out-Null

    $colClass = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colClass.HeaderText = "Clase de Dispositivo"
    $colClass.Name = "Class"
    $colClass.Width = 150
    $colClass.ReadOnly = $true
    $grid.Columns.Add($colClass) | Out-Null

    $colVer = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colVer.HeaderText = "Version"
    $colVer.Name = "Version"
    $colVer.Width = 100
    $colVer.ReadOnly = $true
    $grid.Columns.Add($colVer) | Out-Null

    $colDate = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDate.HeaderText = "Fecha"
    $colDate.Name = "Date"
    $colDate.Width = 100
    $colDate.ReadOnly = $true
    $grid.Columns.Add($colDate) | Out-Null

    # Columna oculta para ID objeto
    $colObj = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colObj.Name = "ObjID"
    $colObj.Visible = $false
    $grid.Columns.Add($colObj) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DETALLES ---
    $grpDet = New-Object System.Windows.Forms.GroupBox
    $grpDet.Text = "Informacion Detallada"
    $grpDet.ForeColor = [System.Drawing.Color]::Silver
    $grpDet.Location = New-Object System.Drawing.Point(20, 490)
    $grpDet.Size = New-Object System.Drawing.Size(990, 70)
    $form.Controls.Add($grpDet)

    $lblDetailPath = New-Object System.Windows.Forms.Label
    $lblDetailPath.Text = "Selecciona un driver para ver detalles..."
    $lblDetailPath.Location = New-Object System.Drawing.Point(15, 25)
    $lblDetailPath.AutoSize = $true
    $lblDetailPath.ForeColor = [System.Drawing.Color]::Cyan
    $grpDet.Controls.Add($lblDetailPath)

    # --- 5. BARRA DE ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 570)
    $progressBar.Size = New-Object System.Drawing.Size(990, 10)
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 590)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    # --- 6. BOTONES DE ACCION ---
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 620)
    $btnSelectAll.Size = New-Object System.Drawing.Size(60, 40)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $btnBackup = New-Object System.Windows.Forms.Button
    $btnBackup.Text = "EXPORTAR (Backup)"
    $btnBackup.Location = New-Object System.Drawing.Point(90, 620)
    $btnBackup.Size = New-Object System.Drawing.Size(250, 40)
    $btnBackup.BackColor = [System.Drawing.Color]::SeaGreen
    $btnBackup.ForeColor = [System.Drawing.Color]::White
    $btnBackup.FlatStyle = "Flat"
    $btnBackup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnBackup)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "INSTALAR (Restaurar)"
    $btnRestore.Location = New-Object System.Drawing.Point(350, 620)
    $btnRestore.Size = New-Object System.Drawing.Size(250, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestore)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR (Limpiar)"
    $btnDelete.Location = New-Object System.Drawing.Point(610, 620)
    $btnDelete.Size = New-Object System.Drawing.Size(200, 40)
    $btnDelete.BackColor = [System.Drawing.Color]::Maroon
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    # Checkbox para Forzar Instalacion
    $chkForce = New-Object System.Windows.Forms.CheckBox
    $chkForce.Text = "Forzar eliminacion (/force)"
    $chkForce.Location = New-Object System.Drawing.Point(830, 620)
    $chkForce.Width = 150
    $chkForce.ForeColor = [System.Drawing.Color]::Salmon
    $form.Controls.Add($chkForce)

    # --- VARIABLES Y CACHE ---
    $driverState = [PSCustomObject]@{ Cache = @() }

    # --- LOGICA: RENDERIZAR GRID (Rapido) ---
    $RenderGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        
        $searchTerm = $txtSearch.Text.Trim()
        
        $filtered = $driverState.Cache
        
        # Filtro de Busqueda
        if (-not [string]::IsNullOrWhiteSpace($searchTerm)) {
            $filtered = $filtered | Where-Object {
                ([string]$_.ProviderName).IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                ([string]$_.ClassName).IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                ([string]$_.Driver).IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
        }

        # Filtro de Microsoft
        if (-not $chkShowMS.Checked) {
            $filtered = $filtered | Where-Object { $_.ProviderName -notmatch "^Microsoft" }
        }

        foreach ($d in $filtered) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["InfName"].Value = $d.Driver
            $row.Cells["Provider"].Value = $d.ProviderName
            $row.Cells["Class"].Value = $d.ClassName
            $row.Cells["Version"].Value = $d.Version
            $row.Cells["Date"].Value = try { $d.Date.ToString("yyyy-MM-dd") } catch { $d.Date }
            
            # Guardamos el objeto real en una columna oculta o en el Tag para uso posterior
            $row.Tag = $d 

            # Colorear Microsoft en gris si se muestran
            if ($d.ProviderName -match "^Microsoft") {
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
            }
        }
        $grid.ResumeLayout()
        $grid.ClearSelection()
    }

    # --- LOGICA: ESCANEAR SISTEMA (Lento) ---
    $ScanDrivers = {
        $lblStatus.Text = "Escaneando Driver Store... (Esto puede tardar)"
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $driverState.Cache = @(Get-WindowsDriver -Online -ErrorAction Stop)
            $lblStatus.Text = "Drivers cargados: $($driverState.Cache.Count)"
            $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
        } catch {
            $lblStatus.Text = "Error al leer drivers: $_"
            $lblStatus.ForeColor = [System.Drawing.Color]::Salmon
            $driverState.Cache = @()
        }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        & $RenderGrid
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $ScanDrivers })
    $btnRefresh.Add_Click({ & $ScanDrivers })
    $txtSearch.Add_KeyUp({ & $RenderGrid })
    $chkShowMS.Add_CheckedChanged({ & $RenderGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $d = $grid.SelectedRows[0].Tag
            $lblDetailPath.Text = "Origen: $($d.OriginalFileName) | Firmado por: $($d.SignerName)"
        }
    })

    # Evento de checkbox en celda y Barra Espaciadora
    $grid.Add_CellClick({ param($s,$e) if($e.RowIndex -ge 0 -and $e.ColumnIndex -ne 0){ $r=$grid.Rows[$e.RowIndex]; $r.Cells[0].Value = -not $r.Cells[0].Value } })
    $grid.Add_KeyDown({ param($s,$e) if($e.KeyCode -eq 'Space'){ $e.SuppressKeyPress=$true; foreach($r in $s.SelectedRows){ $r.Cells[0].Value = -not $r.Cells[0].Value } } })
    $btnSelectAll.Add_Click({ foreach($r in $grid.Rows){ $r.Cells[0].Value = $true } })

    # --- ACCION: BACKUP ---
    $btnBackup.Add_Click({
        $targets = @($grid.Rows | Where-Object { $_.Cells[0].Value } | ForEach-Object { $_.Cells["InfName"].Value })
        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona drivers.", "Aviso", 0, 48); return }

        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog; $dlg.Description = "Carpeta de destino"
        if ($dlg.ShowDialog() -ne 'OK') { return }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0; $progressBar.Maximum = $targets.Count; $cnt = 0; $errs = 0

        try {
            foreach ($inf in $targets) {
                $cnt++; $progressBar.Value = $cnt
                $lblStatus.Text = "Exportando $inf..."
                [System.Windows.Forms.Application]::DoEvents()
                try {
                    $nativeResult = Invoke-AegisNativeProcess -FilePath 'pnputil.exe' -ArgumentList @('/export-driver', $inf, $dlg.SelectedPath) -TimeoutSeconds 300
                    Write-Log -LogLevel INFO -Message "DRIVERS: pnputil export '$inf': $($nativeResult.StdOut.Trim())"
                } catch {
                    $errs++
                    Write-Log -LogLevel ERROR -Message "DRIVERS: Error exportando '$inf': $($_.Exception.Message)"
                }
            }
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
        
        $lblStatus.Text = "Backup finalizado."
        [System.Windows.Forms.MessageBox]::Show("Exportados: $($targets.Count - $errs). Errores: $errs", "Resultado", 0, $(if ($errs -eq 0) { 64 } else { 48 }))
    })

    # --- ACCION: DELETE (NUEVO) ---
    $btnDelete.Add_Click({
        $targets = @($grid.Rows | Where-Object { $_.Cells[0].Value } | ForEach-Object { $_.Tag })
        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona drivers para eliminar.", "Aviso", 0, 48); return }

        $activeInfNames = @{}
        try {
            Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object InfName | ForEach-Object {
                $activeInfNames[([string]$_.InfName).ToLowerInvariant()] = $true
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("No fue posible identificar los drivers vinculados a dispositivos activos. Por seguridad se cancela la eliminacion.`n`n$($_.Exception.Message)", "Comprobacion incompleta", 0, 16) | Out-Null
            return
        }

        $criticalClasses = @('System','HDC','SCSIAdapter','Storage','DiskDrive','Volume','Computer','Processor','Firmware')
        $blocked = @($targets | Where-Object {
            $_.BootCritical -eq $true -or $_.Inbox -eq $true -or $_.ClassName -in $criticalClasses
        })
        if ($blocked.Count -gt 0) {
            $blockedNames = ($blocked | ForEach-Object { "$($_.Driver) [$($_.ClassName)]" }) -join "`n"
            [System.Windows.Forms.MessageBox]::Show("La seleccion contiene drivers de sistema, integrados o criticos y no se eliminaran:`n`n$blockedNames", "Drivers protegidos", 0, 16) | Out-Null
            return
        }

        $activeTargets = @($targets | Where-Object { $activeInfNames.ContainsKey(([string]$_.Driver).ToLowerInvariant()) })
        if ($activeTargets.Count -gt 0 -and -not $chkForce.Checked) {
            [System.Windows.Forms.MessageBox]::Show("Hay $($activeTargets.Count) drivers asociados a dispositivos presentes. Desmarca esos drivers o activa Forzar tras revisar el riesgo.", "Drivers en uso", 0, 48) | Out-Null
            return
        }

        if ([System.Windows.Forms.MessageBox]::Show("PELIGRO: Vas a eliminar $($targets.Count) drivers del almacén del sistema.`n`nSi eliminas un driver en uso, el dispositivo dejará de funcionar.`nEstás seguro?", "Confirmar Eliminación", 4, 48) -ne 'Yes') { return }

        if ($chkForce.Checked) {
             if ([System.Windows.Forms.MessageBox]::Show("HAS MARCADO 'FORZAR'.`nEsto eliminará el driver incluso si está en uso.`nConfirmación final?", "PELIGRO EXTREMO", 4, 16) -ne 'Yes') { return }
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0; $progressBar.Maximum = $targets.Count; $cnt = 0; $errs = 0
        $backupRoot = Join-Path (Split-Path -Parent $PSScriptRoot) ("Backup\Drivers\BeforeDelete_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
        New-Item -Path $backupRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        $journal = New-AegisOperationJournal -Module 'Drivers' -Action 'Delete' -Targets @($targets.Driver) -Metadata @{
            BackupPath=$backupRoot; Force=[bool]$chkForce.Checked
        }
        $results = [System.Collections.Generic.List[object]]::new()

        try {
            # Respaldo obligatorio y aislado por paquete antes de tocar Driver Store.
            foreach ($driver in $targets) {
                $inf = [string]$driver.Driver
                $driverBackup = Join-Path $backupRoot ($inf -replace '[^a-zA-Z0-9._-]', '_')
                New-Item -Path $driverBackup -ItemType Directory -Force -ErrorAction Stop | Out-Null
                $exportResult = Invoke-AegisNativeProcess -FilePath 'pnputil.exe' -ArgumentList @('/export-driver', $inf, $driverBackup) -TimeoutSeconds 300
                if (-not (Get-ChildItem -LiteralPath $driverBackup -Filter '*.inf' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1)) {
                    throw "PnPUtil no dejo un archivo INF verificable para '$inf'. Se cancela toda la eliminacion."
                }
                $results.Add([PSCustomObject]@{ Driver=$inf; Step='Backup'; Success=$true; Output=$exportResult.StdOut.Trim() })
            }

            foreach ($driver in $targets) {
                $inf = [string]$driver.Driver
                $cnt++; $progressBar.Value = $cnt
                $lblStatus.Text = "Eliminando $inf..."
                [System.Windows.Forms.Application]::DoEvents()
                try {
                    $deleteArgs = @('/delete-driver', $inf)
                    if ($chkForce.Checked) { $deleteArgs += '/force' }
                    $nativeResult = Invoke-AegisNativeProcess -FilePath 'pnputil.exe' -ArgumentList $deleteArgs -TimeoutSeconds 300
                    $results.Add([PSCustomObject]@{ Driver=$inf; Step='Delete'; Success=$true; Output=$nativeResult.StdOut.Trim() })
                } catch {
                    $errs++
                    $results.Add([PSCustomObject]@{ Driver=$inf; Step='Delete'; Success=$false; Error=$_.Exception.Message })
                    Write-Log -LogLevel ERROR -Message "DRIVERS: Error eliminando '$inf': $($_.Exception.Message)"
                }
            }
            Complete-AegisOperationJournal -Journal $journal -Status $(if ($errs -eq 0) { 'Completed' } else { 'Partial' }) -Results @($results) | Out-Null
        } catch {
            $errs = $targets.Count
            $results.Add([PSCustomObject]@{ Step='PreflightBackup'; Success=$false; Error=$_.Exception.Message })
            Complete-AegisOperationJournal -Journal $journal -Status Failed -Results @($results) | Out-Null
            Write-Log -LogLevel ERROR -Message "DRIVERS: Eliminacion cancelada durante respaldo previo: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("No se elimino ningun driver porque el respaldo previo no pudo completarse:`n`n$($_.Exception.Message)", "Operacion cancelada", 0, 16) | Out-Null
            return
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
        
        [System.Windows.Forms.MessageBox]::Show("Eliminados: $($targets.Count - $errs). Errores: $errs", "Resultado", 0, $(if ($errs -eq 0) { 64 } else { 48 }))
        & $ScanDrivers # Recargar lista
    })

    # --- ACCION: RESTORE ---
    $btnRestore.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = "Selecciona archivos .INF"; $dlg.Filter = "Drivers (*.inf)|*.inf"; $dlg.Multiselect = $true
        if ($dlg.ShowDialog() -ne 'OK') { return }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0; $progressBar.Maximum = $dlg.FileNames.Count; $cnt = 0; $errs = 0
        
        # /force solo es valido con /delete-driver; no debe enviarse al restaurar.
        $argsBase = "/add-driver /install"

        try {
            foreach ($file in $dlg.FileNames) {
                $cnt++; $progressBar.Value = $cnt
                $fname = [System.IO.Path]::GetFileName($file)
                $lblStatus.Text = "Instalando $fname..."
                [System.Windows.Forms.Application]::DoEvents()
                try {
                    $nativeResult = Invoke-AegisNativeProcess -FilePath 'pnputil.exe' -ArgumentList @('/add-driver', $file, '/install') -TimeoutSeconds 300
                    Write-Log -LogLevel INFO -Message "DRIVERS: pnputil add '$fname': $($nativeResult.StdOut.Trim())"
                } catch {
                    $errs++
                    Write-Log -LogLevel ERROR -Message "DRIVERS: Error instalando '$fname': $($_.Exception.Message)"
                }
            }
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
        
        [System.Windows.Forms.MessageBox]::Show("Instalados: $($dlg.FileNames.Count - $errs). Errores: $errs", "Resultado", 0, $(if ($errs -eq 0) { 64 } else { 48 }))
        & $ScanDrivers
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}