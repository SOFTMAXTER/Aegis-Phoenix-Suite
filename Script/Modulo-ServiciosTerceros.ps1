# =================================================================
#  Modulo-ServiciosTerceros
#
#  CONTENIDO   : Manage-ThirdPartyServices
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Write-AegisJsonAtomic          : escritura atomica de archivos JSON (snapshots/config)
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-ServiciosTerceros.ps1"
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

function Get-AegisServiceExecutablePath {
    param([AllowNull()][string]$PathName)
    if ([string]::IsNullOrWhiteSpace($PathName)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($PathName.Trim())
    if ($expanded.StartsWith('"')) {
        $closingQuote = $expanded.IndexOf('"', 1)
        if ($closingQuote -gt 1) { return $expanded.Substring(1, $closingQuote - 1) }
    }
    $match = [regex]::Match($expanded, '^(.*?\.exe)(?:\s|$)', 'IgnoreCase')
    if ($match.Success) { return $match.Groups[1].Value.Trim('"') }
    return $expanded.Split(' ')[0].Trim('"')
}


# =========================================================================================
# MODULO DE GESTION DE SERVICIOS DE TERCEROS
# =========================================================================================

function Manage-ThirdPartyServices {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- RUTAS Y VARIABLES GLOBALES DEL MODULO ---
    $parentDir = Split-Path -Parent $PSScriptRoot
    $backupDir = Join-Path -Path $parentDir -ChildPath "Backup"
    if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
    $backupFile = Join-Path -Path $backupDir -ChildPath "ThirdPartyServicesBackup.json"
    
    $backupCache = @{}
    $liveServiceCache = @{}
    $cachedServiceList = [System.Collections.Generic.List[object]]::new()
    $signatureCache = @{}

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Servicios de Terceros (Apps)"
    $form.Size = New-Object System.Drawing.Size(980, 700) # Un poco mas ancho para la busqueda
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR ---
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "Gestion Inteligente de Servicios"
    $lblInfo.Location = New-Object System.Drawing.Point(20, 15)
    $lblInfo.AutoSize = $true
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblInfo)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "Detecta servicios no-Windows y permite optimizarlos."
    $lblSub.Location = New-Object System.Drawing.Point(22, 40)
    $lblSub.AutoSize = $true
    $lblSub.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($lblSub)

    # -- BUSCADOR (NUEVO) --
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(400, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(460, 20)
    $txtSearch.Width = 220
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar Datos"
    $btnRefresh.Location = New-Object System.Drawing.Point(700, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(150, 28)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 70)
    $grid.Size = New-Object System.Drawing.Size(920, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion DoubleBuffered (Evita parpadeo al escribir)
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

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Nombre del Servicio"
    $colName.Name = "DisplayName"
    $colName.ReadOnly = $true
    $colName.Width = 300
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 100
    $grid.Columns.Add($colStatus) | Out-Null

    $colMode = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colMode.HeaderText = "Inicio"
    $colMode.Name = "StartMode"
    $colMode.ReadOnly = $true
    $colMode.Width = 100
    $grid.Columns.Add($colMode) | Out-Null

    $colBackup = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colBackup.HeaderText = "Backup"
    $colBackup.Name = "BackupState"
    $colBackup.ReadOnly = $true
    $colBackup.Width = 120
    $grid.Columns.Add($colBackup) | Out-Null
    
    # Columna oculta para el nombre real del servicio
    $colRealName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colRealName.Name = "ServiceName"
    $colRealName.Visible = $false
    $grid.Columns.Add($colRealName) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DESCRIPCION ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Detalles"
    $grpDesc.ForeColor = [System.Drawing.Color]::Silver
    $grpDesc.Location = New-Object System.Drawing.Point(20, 500)
    $grpDesc.Size = New-Object System.Drawing.Size(920, 60)
    $form.Controls.Add($grpDesc)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "Selecciona un servicio..."
    $lblDesc.Location = New-Object System.Drawing.Point(10, 20)
    $lblDesc.Size = New-Object System.Drawing.Size(900, 30)
    $lblDesc.ForeColor = [System.Drawing.Color]::White
    $grpDesc.Controls.Add($lblDesc)

    # --- 5. BOTONES DE ACCION ---
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR (Optimizar)"
    $btnDisable.Location = New-Object System.Drawing.Point(670, 580)
    $btnDisable.Size = New-Object System.Drawing.Size(270, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::Crimson
    $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "RESTAURAR A ESTADO ORIGINAL"
    $btnRestore.Location = New-Object System.Drawing.Point(380, 580)
    $btnRestore.Size = New-Object System.Drawing.Size(270, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::SeaGreen
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestore)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 585)
    $btnSelectAll.Size = New-Object System.Drawing.Size(100, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # --- LOGICA 1: RENDERIZADO (Filtrado Rapido) ---
    $RenderGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        
        $searchTerm = $txtSearch.Text.Trim()
        
        # Filtramos la lista en memoria (Rapido)
        $itemsToShow = if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            $cachedServiceList
        } else {
            $cachedServiceList | Where-Object {
                $_.DisplayName.IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                $_.Name.IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
        }

        foreach ($svc in $itemsToShow) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["DisplayName"].Value = $svc.DisplayName
            $row.Cells["ServiceName"].Value = $svc.Name
            
            # Estado Visual (Logica de Colores)
            if ($svc.StartMode -eq 'Disabled') {
                $row.Cells["StartMode"].Value = "Deshabilitado"
                $row.Cells["Status"].Value = "Inactivo"
                
                # Rojo solo para el texto de estado
                $row.Cells["StartMode"].Style.ForeColor = [System.Drawing.Color]::Salmon
            } else {
                $row.Cells["StartMode"].Value = $svc.StartMode
                # Asegurar blanco si no es disabled
                $row.Cells["StartMode"].Style.ForeColor = [System.Drawing.Color]::White

                if ($svc.State -eq 'Running') {
                    $row.Cells["Status"].Value = "Ejecutando"
                    $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                } else {
                    $row.Cells["Status"].Value = "Detenido"
                    $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::White
                }
            }

            # Estado Backup
            $bkp = $backupCache[$svc.Name]
            if ($bkp) {
                $row.Cells["BackupState"].Value = $bkp.StartupType
                if ($bkp.StartupType -ne 'Disabled' -and $svc.StartMode -eq 'Disabled') {
                    $row.Cells["BackupState"].Style.ForeColor = [System.Drawing.Color]::Cyan
                }
            }
        }
        $grid.ResumeLayout()
        $grid.ClearSelection()
    }

    # --- LOGICA 2: CARGA DE DATOS (Lento - Solo al inicio/refrescar) ---
    $RefreshData = {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $liveServiceCache.Clear()
        $cachedServiceList.Clear()
        $backupCache.Clear()
        
        # 1. Cargar Backup existente
        if (Test-Path $backupFile) {
            try {
                $json = Get-Content -Path $backupFile -Raw | ConvertFrom-Json
                foreach ($prop in $json.PSObject.Properties) {
                    $backupCache[$prop.Name] = $prop.Value
                }
            } catch {
                $form.Cursor = [System.Windows.Forms.Cursors]::Default
                [System.Windows.Forms.MessageBox]::Show(
                    "El respaldo de servicios esta dañado o no es JSON valido.`nNo se modificara ni sobrescribira:`n$backupFile`n`n$($_.Exception.Message)",
                    "Respaldo invalido", 0, 16) | Out-Null
                Write-Log -LogLevel ERROR -Message "SERVICIOS: Backup JSON invalido: $($_.Exception.Message)"
                return
            }
        }

        # 2. Consultar servicios y clasificar por firma del ejecutable.
        try {
            $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | Where-Object PathName | ForEach-Object {
                $service = $_
                $exePath = Get-AegisServiceExecutablePath -PathName $service.PathName
                $signature = $null
                if ($exePath -and (Test-Path -LiteralPath $exePath -PathType Leaf)) {
                    if (-not $signatureCache.ContainsKey($exePath)) {
                        $signatureCache[$exePath] = Get-AuthenticodeSignature -LiteralPath $exePath -ErrorAction SilentlyContinue
                    }
                    $signature = $signatureCache[$exePath]
                }
                $publisher = if ($signature -and $signature.SignerCertificate) { [string]$signature.SignerCertificate.Subject } else { 'No verificado' }
                $microsoftSigned = $signature -and $signature.Status -eq 'Valid' -and $publisher -match 'Microsoft (Corporation|Windows|Code Signing)'
                if (-not $microsoftSigned -and $exePath -notmatch '(?i)\\Windows\\System32\\svchost\.exe$') {
                    $service | Select-Object *, @{N='ExecutablePath';E={$exePath}}, @{N='Publisher';E={$publisher}}, @{N='SignatureStatus';E={if($signature){$signature.Status}else{'NotFound'}}}
                }
            } | Sort-Object DisplayName)
        } catch {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            [System.Windows.Forms.MessageBox]::Show("No se pudieron consultar los servicios: $($_.Exception.Message)", "Error", 0, 16) | Out-Null
            return
        }

        $backupUpdated = $false

        foreach ($svc in $services) {
            $liveServiceCache[$svc.Name] = $svc
            $cachedServiceList.Add($svc)
            
            # Actualizar Backup si es nuevo
            if (-not $backupCache.ContainsKey($svc.Name)) {
                $backupCache[$svc.Name] = @{
                    StartupType = (ConvertTo-AegisServiceStartupType -StartMode $svc.StartMode)
                    DelayedAutoStart = (Get-AegisServiceSnapshot -Name $svc.Name).DelayedAutoStart
                    WasRunning = ($svc.State -eq 'Running')
                    DisplayName = $svc.DisplayName
                    Description = $svc.Description
                    PathName = $svc.PathName
                    Publisher = $svc.Publisher
                    SignatureStatus = [string]$svc.SignatureStatus
                }
                $backupUpdated = $true
            }
        }

        if ($backupUpdated) {
            try {
                Write-AegisJsonAtomic -InputObject $backupCache -Path $backupFile
            } catch {
                $form.Cursor = [System.Windows.Forms.Cursors]::Default
                [System.Windows.Forms.MessageBox]::Show("No se pudo guardar el respaldo: $($_.Exception.Message)", "Error", 0, 16) | Out-Null
                Write-Log -LogLevel ERROR -Message "SERVICIOS: Error guardando backup: $($_.Exception.Message)"
                return
            }
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        
        # Una vez cargados los datos, llamamos al renderizado
        & $RenderGrid
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $RefreshData })
    $btnRefresh.Add_Click({ & $RefreshData })
    
    # Evento de busqueda en tiempo real
    $txtSearch.Add_KeyUp({ & $RenderGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $val = $grid.SelectedRows[0].Cells["ServiceName"].Value
            $name = if ($val) { $val.ToString() } else { "" }
            
            if (-not [string]::IsNullOrEmpty($name) -and $liveServiceCache.ContainsKey($name)) {
                $desc = $liveServiceCache[$name].Description
                if ([string]::IsNullOrWhiteSpace($desc)) { $desc = "Sin descripcion disponible." }
                $lblDesc.Text = "$desc | Editor: $($liveServiceCache[$name].Publisher) | Firma: $($liveServiceCache[$name].SignatureStatus)"
            }
        }
    })

    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Logica de Acciones
    $ApplyAction = {
        param($ActionType)

        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $row.Cells["ServiceName"].Value
            }
        }

        if ($targets.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No has marcado ningun servicio.", "Aviso", 0, 48)
            return
        }

        $impacts = @($targets | ForEach-Object { Get-AegisServiceDisableImpact -Name $_ })
        if ($ActionType -eq 'Disable' -and @($impacts | Where-Object IsCritical).Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show('La seleccion contiene un servicio esencial protegido.', 'Operacion cancelada', 0, 16) | Out-Null
            return
        }
        $dependentNames = @($impacts | ForEach-Object ActiveDependents | Sort-Object -Unique)
        if ($ActionType -eq 'Disable' -and $dependentNames.Count -gt 0) {
            if ([System.Windows.Forms.MessageBox]::Show("Dependientes activos: $($dependentNames -join ', ')`n`nContinuar?", 'Impacto de dependencias', 4, 48) -ne 'Yes') { return }
        }

        $msg = if ($ActionType -eq 'Disable') { "Deshabilitar" } else { "Restaurar" }
        if ([System.Windows.Forms.MessageBox]::Show("Seguro de $msg $($targets.Count) servicios?", "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $successCount = 0
        $errorCount = 0
        $snapshots = @{}
        foreach ($svcName in $targets) { $snapshots[$svcName] = Get-AegisServiceSnapshot -Name $svcName }
        $journal = New-AegisOperationJournal -Module 'ServiciosTerceros' -Action $ActionType -Targets $targets -Metadata @{ Snapshots=@($snapshots.Values) }
        $changed = [System.Collections.Generic.List[string]]::new()

        try {
            foreach ($svcName in $targets) {
                try {
                    if ($ActionType -eq 'Disable') {
                        $s = Get-Service -Name $svcName -ErrorAction Stop
                        if ($s.Status -eq 'Running') { Stop-Service -Name $svcName -Force -ErrorAction Stop }
                        Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
                    } else {
                        if (-not $backupCache.ContainsKey($svcName)) { throw "No existe respaldo para este servicio." }
                        $backupEntry = $backupCache[$svcName]
                        $originalMode = ConvertTo-AegisServiceStartupType $backupCache[$svcName].StartupType
                        Set-Service -Name $svcName -StartupType $originalMode -ErrorAction Stop
                        if ($originalMode -eq 'Automatic' -and $null -ne $backupEntry.DelayedAutoStart) {
                            Set-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName" -Name DelayedAutoStart -Value ([int]$backupEntry.DelayedAutoStart) -Type DWord -Force -ErrorAction Stop
                        }
                        $hasRuntimeState = if ($backupEntry -is [System.Collections.IDictionary]) {
                            $backupEntry.Contains('WasRunning')
                        } else { $null -ne $backupEntry.PSObject.Properties['WasRunning'] }
                        if ($hasRuntimeState) {
                            if ([bool]$backupEntry.WasRunning) {
                                Start-Service -Name $svcName -ErrorAction Stop
                            } else {
                                $current = Get-Service -Name $svcName -ErrorAction Stop
                                if ($current.Status -eq 'Running') { Stop-Service -Name $svcName -Force -ErrorAction Stop }
                            }
                        }
                    }
                    $successCount++
                    $changed.Add($svcName)
                } catch {
                    $errorCount++
                    Write-Log -LogLevel ERROR -Message "SERVICIOS: Fallo con '$svcName': $($_.Exception.Message)"
                    foreach ($changedName in @($changed)) {
                        try { Restore-AegisServiceSnapshot -Snapshot $snapshots[$changedName] } catch {
                            Write-Log -LogLevel ERROR -Message "SERVICIOS: Rollback fallo en '$changedName': $($_.Exception.Message)"
                        }
                    }
                    break
                }
            }
            Complete-AegisOperationJournal -Journal $journal -Status $(if ($errorCount -eq 0) { 'Completed' } else { 'Failed' }) -Results @(
                [PSCustomObject]@{ Changed=@($changed); RolledBack=($errorCount -gt 0) }
            ) | Out-Null
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        # Refrescamos datos completos para ver cambios reales
        & $RefreshData
        [System.Windows.Forms.MessageBox]::Show("Resultado: $successCount correctos, $errorCount errores.", "Servicios", 0, $(if ($errorCount -eq 0) { 64 } else { 48 }))
    }

    $btnDisable.Add_Click({ & $ApplyAction -ActionType 'Disable' })
    $btnRestore.Add_Click({ & $ApplyAction -ActionType 'Restore' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}