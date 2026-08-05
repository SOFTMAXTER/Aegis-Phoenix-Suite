# =================================================================
#  Modulo-Servicios
#
#  CONTENIDO   : Manage-SystemServices
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-Servicios.ps1"
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

function ConvertTo-AegisServiceStartupType {
    param([Parameter(Mandatory=$true)][string]$StartMode)
    switch ($StartMode.Trim()) {
        { $_ -in 'Auto', 'Automatic' } { return 'Automatic' }
        { $_ -in 'Demand', 'Manual' } { return 'Manual' }
        'Disabled' { return 'Disabled' }
        default { throw "Tipo de inicio de servicio no compatible: '$StartMode'." }
    }
}


function Get-AegisServiceSnapshot {
    param([Parameter(Mandatory=$true)][string]$Name)
    $escapedName = $Name.Replace("'", "''")
    $service = Get-CimInstance Win32_Service -Filter "Name='$escapedName'" -ErrorAction Stop
    $serviceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    $delayed = try { [int](Get-ItemProperty -LiteralPath $serviceRegPath -Name DelayedAutoStart -ErrorAction Stop).DelayedAutoStart } catch { 0 }
    $serviceController = Get-Service -Name $Name -ErrorAction Stop
    return [PSCustomObject]@{
        Name=$Name; StartupType=(ConvertTo-AegisServiceStartupType $service.StartMode)
        DelayedAutoStart=$delayed; WasRunning=($service.State -eq 'Running')
        StartName=$service.StartName; PathName=$service.PathName
        Dependencies=@($serviceController.ServicesDependedOn.Name)
        Dependents=@($serviceController.DependentServices.Name)
        CapturedAt=(Get-Date).ToString('o')
    }
}


function Restore-AegisServiceSnapshot {
    param([Parameter(Mandatory=$true)]$Snapshot)
    Set-Service -Name $Snapshot.Name -StartupType (ConvertTo-AegisServiceStartupType $Snapshot.StartupType) -ErrorAction Stop
    $serviceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Snapshot.Name)"
    if ($Snapshot.StartupType -eq 'Automatic') {
        Set-ItemProperty -LiteralPath $serviceRegPath -Name DelayedAutoStart -Value ([int]$Snapshot.DelayedAutoStart) -Type DWord -Force -ErrorAction Stop
    }
    if ([bool]$Snapshot.WasRunning) {
        Start-Service -Name $Snapshot.Name -ErrorAction Stop
    } else {
        $current = Get-Service -Name $Snapshot.Name -ErrorAction Stop
        if ($current.Status -eq 'Running') { Stop-Service -Name $Snapshot.Name -Force -ErrorAction Stop }
    }
}


function Get-AegisServiceDisableImpact {
    param([Parameter(Mandatory=$true)][string]$Name)
    $criticalNames = @('RpcSs','DcomLaunch','EventLog','PlugPlay','Power','SamSs','Winmgmt','BFE','MpsSvc','LSM','ProfSvc','Schedule')
    $controller = Get-Service -Name $Name -ErrorAction Stop
    $activeDependents = @($controller.DependentServices | Where-Object { $_.Status -eq 'Running' -or $_.StartType -eq 'Automatic' })
    return [PSCustomObject]@{
        IsCritical=($Name -in $criticalNames)
        ActiveDependents=@($activeDependents.Name)
        Risk=$(if ($Name -in $criticalNames) { 'Blocked' } elseif ($activeDependents.Count -gt 0) { 'High' } else { 'Normal' })
    }
}


function Manage-SystemServices {
    # Verificar que el catalogo este cargado
    if ($null -eq $script:ServiceCatalog) {
        try { . "$PSScriptRoot\Catalogos\Servicios.ps1" } catch { 
            [System.Windows.Forms.MessageBox]::Show("No se pudo cargar el catalogo de servicios.", "Error", 0, 16); return 
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO (ESTILO OSCURO) ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Servicios"
    $form.Size = New-Object System.Drawing.Size(950, 700) # Ligeramente mas ancho para acomodar la busqueda
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR (FILTROS Y BuSQUEDA) ---
    $lblCat = New-Object System.Windows.Forms.Label
    $lblCat.Text = "Categoria:"
    $lblCat.Location = New-Object System.Drawing.Point(20, 23)
    $lblCat.AutoSize = $true
    $lblCat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblCat)

    $cmbCategory = New-Object System.Windows.Forms.ComboBox
    $cmbCategory.Location = New-Object System.Drawing.Point(100, 20)
    $cmbCategory.Width = 250
    $cmbCategory.DropDownStyle = "DropDownList"
    $cmbCategory.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $cmbCategory.ForeColor = [System.Drawing.Color]::White
    $cmbCategory.FlatStyle = "Flat"
    
    # Poblar categorias dinamicamente + "Todas"
    $cmbCategory.Items.Add("--- TODAS LAS CATEGORIAS ---") | Out-Null
    $categories = $script:ServiceCatalog | Select-Object -ExpandProperty Category -Unique | Sort-Object
    foreach ($cat in $categories) { $cmbCategory.Items.Add($cat) | Out-Null }
    $cmbCategory.SelectedIndex = 0
    $form.Controls.Add($cmbCategory)

    # -- NUEVO: CAJA DE BuSQUEDA --
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(370, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(430, 20)
    $txtSearch.Width = 250
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(700, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(100, 26)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW (TABLA CENTRAL) ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(890, 400)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion de Doble Bufer (Evita parpadeo)
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
    $colName.HeaderText = "Servicio"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 200
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado Actual"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 120
    $grid.Columns.Add($colStatus) | Out-Null
    
    $colStartup = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStartup.HeaderText = "Inicio"
    $colStartup.Name = "Startup"
    $colStartup.ReadOnly = $true
    $colStartup.Width = 100
    $grid.Columns.Add($colStartup) | Out-Null

    $colDefault = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDefault.HeaderText = "Recomendado"
    $colDefault.Name = "Default"
    $colDefault.ReadOnly = $true
    $colDefault.Width = 120
    $grid.Columns.Add($colDefault) | Out-Null
    
    # Columna oculta para guardar el objeto completo
    $colCat = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCat.Name = "Category"
    $colCat.Visible = $false
    $grid.Columns.Add($colCat) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DESCRIPCION ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Descripcion del Servicio"
    $grpDesc.ForeColor = [System.Drawing.Color]::Silver
    $grpDesc.Location = New-Object System.Drawing.Point(20, 470)
    $grpDesc.Size = New-Object System.Drawing.Size(890, 80)
    $form.Controls.Add($grpDesc)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "Selecciona un servicio para ver su descripcion..."
    $lblDesc.Location = New-Object System.Drawing.Point(10, 20)
    $lblDesc.Size = New-Object System.Drawing.Size(870, 50)
    $lblDesc.ForeColor = [System.Drawing.Color]::White
    $grpDesc.Controls.Add($lblDesc)

    # --- 5. BOTONES DE ACCION ---
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR SELECCIONADOS"
    $btnDisable.Location = New-Object System.Drawing.Point(650, 560)
    $btnDisable.Size = New-Object System.Drawing.Size(260, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::Crimson
    $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "Restaurar / Habilitar (Default)"
    $btnRestore.Location = New-Object System.Drawing.Point(380, 560)
    $btnRestore.Size = New-Object System.Drawing.Size(260, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRestore.ForeColor = [System.Drawing.Color]::LightGreen
    $btnRestore.FlatStyle = "Flat"
    $form.Controls.Add($btnRestore)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 565)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # --- VARIABLES GLOBALES PARA LA GUI ---
    $serviceCache = @{}

    # --- FUNCION DE CARGA ---
    $LoadGrid = {
        # Optimizacion: SuspendLayout evita parpadeo y mejora rendimiento
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $serviceCache.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        # 1. Obtener estado real de servicios (WMI)
        $liveServices = @{}
        try {
            Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | ForEach-Object { $liveServices[$_.Name] = $_ }
        } catch { Write-Warning "Error leyendo servicios WMI" }

        # 2. Filtrar por categoria
        $filterCat = $cmbCategory.SelectedItem
        $itemsToShow = if ($filterCat -eq "--- TODAS LAS CATEGORIAS ---") { 
            $script:ServiceCatalog 
        } else { 
            $script:ServiceCatalog | Where-Object { $_.Category -eq $filterCat } 
        }

        # 3. Filtrar por Texto de Busqueda (Nuevo)
        $searchText = $txtSearch.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            $itemsToShow = $itemsToShow | Where-Object {
                $_.Name.IndexOf($searchText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
        }

        # 4. Poblar Grid
        foreach ($item in $itemsToShow) {
            $svc = $liveServices[$item.Name]
            
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["Name"].Value = $item.Name
            $row.Cells["Category"].Value = $item.Category
            $row.Cells["Default"].Value = $item.DefaultStartupType

            # Guardar en cache para la descripcion y acciones
            $serviceCache[$item.Name] = $item

            # Estado Visual
            if ($svc) {
                if ($svc.StartMode -eq 'Disabled') {
                    $row.Cells["Startup"].Value = "Deshabilitado"
                    $row.Cells["Status"].Value = "Desactivado"
                    
                    # Estilo: Solo la palabra "Desactivado" en Rojo, el resto Blanco
                    $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
                    $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White 
                } else {
                    $row.Cells["Startup"].Value = $svc.StartMode
                    if ($svc.State -eq 'Running') {
                        $row.Cells["Status"].Value = "Ejecutando"
                        $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                        $row.Cells["Name"].Style.Font = New-Object System.Drawing.Font($grid.Font, [System.Drawing.FontStyle]::Bold)
                    } else {
                        $row.Cells["Status"].Value = "Detenido"
                        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
                    }
                }
            } else {
                $row.Cells["Status"].Value = "No Instalado"
                $row.Cells["Startup"].Value = "-"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::DarkGray
            }
        }
        
        # Restaurar layout
        $grid.ResumeLayout()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $grid.ClearSelection()
    }

    # --- EVENTOS ---
    
    # Carga inicial y cambio de filtro
    $form.Add_Shown({ & $LoadGrid })
    $btnRefresh.Add_Click({ & $LoadGrid })
    $cmbCategory.Add_SelectedIndexChanged({ & $LoadGrid })
    
    # Evento de busqueda en tiempo real
    $txtSearch.Add_KeyUp({ & $LoadGrid })

    # Mostrar descripcion al seleccionar fila
    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            # Obtenemos el valor de la celda de forma segura
            $val = $grid.SelectedRows[0].Cells["Name"].Value
            $name = if ($val) { $val.ToString() } else { "" }

            # Verificamos que tenga texto y exista en cache
            if (-not [string]::IsNullOrEmpty($name) -and $serviceCache.ContainsKey($name)) {
                $lblDesc.Text = $serviceCache[$name].Description
            } else {
                $lblDesc.Text = "" 
            }
        }
    })

    # Boton Seleccionar Todo
    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Funcion helper para aplicar cambios
    $ApplyAction = {
        param($Mode) # 'Disable' o 'Restore'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $row.Cells["Name"].Value
            }
        }

        if ($targets.Count -eq 0) { 
            [System.Windows.Forms.MessageBox]::Show("No has seleccionado ningun servicio.", "Aviso", 0, 48)
            return 
        }

        $impacts = @($targets | ForEach-Object { Get-AegisServiceDisableImpact -Name $_ })
        if ($Mode -eq 'Disable' -and @($impacts | Where-Object IsCritical).Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show('La seleccion contiene un servicio esencial protegido. La operacion fue cancelada.', 'Servicios protegidos', 0, 16) | Out-Null
            return
        }
        $dependentNames = @($impacts | ForEach-Object ActiveDependents | Sort-Object -Unique)
        if ($Mode -eq 'Disable' -and $dependentNames.Count -gt 0) {
            $dependencyWarning = "Los siguientes servicios dependen de la seleccion y pueden dejar de funcionar:`n`n$($dependentNames -join ', ')`n`nContinuar?"
            if ([System.Windows.Forms.MessageBox]::Show($dependencyWarning, 'Impacto de dependencias', 4, 48) -ne 'Yes') { return }
        }

        $confirmMsg = if ($Mode -eq 'Disable') { 
            "Deshabilitar $($targets.Count) servicios? Esto detendra su ejecucion." 
        } else { 
            "Restaurar $($targets.Count) servicios a su estado recomendado?" 
        }

        if ([System.Windows.Forms.MessageBox]::Show($confirmMsg, "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $successCount = 0
        $errorCount = 0
        $snapshots = @{}
        foreach ($svcName in $targets) { $snapshots[$svcName] = Get-AegisServiceSnapshot -Name $svcName }
        $journal = New-AegisOperationJournal -Module 'ServiciosSistema' -Action $Mode -Targets $targets -Metadata @{ Snapshots=@($snapshots.Values) }
        $changed = [System.Collections.Generic.List[string]]::new()
        
        try {
            foreach ($svcName in $targets) {
                try {
                    $config = $serviceCache[$svcName]
                    if ($Mode -eq 'Disable') {
                        Write-Log -LogLevel ACTION -Message "SERVICIOS GUI: Deshabilitando $svcName"
                        $s = Get-Service -Name $svcName -ErrorAction Stop
                        if ($s.Status -eq 'Running') { Stop-Service -Name $svcName -Force -ErrorAction Stop }
                        Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
                    } else {
                        $targetType = ConvertTo-AegisServiceStartupType $config.DefaultStartupType
                        Write-Log -LogLevel ACTION -Message "SERVICIOS GUI: Restaurando $svcName a $targetType"
                        Set-Service -Name $svcName -StartupType $targetType -ErrorAction Stop
                        if ($targetType -eq 'Automatic') { Start-Service -Name $svcName -ErrorAction Stop }
                    }
                    $successCount++
                    $changed.Add($svcName)
                } catch {
                    $errorCount++
                    Write-Log -LogLevel ERROR -Message "Fallo con servicio $svcName : $($_.Exception.Message)"
                    foreach ($changedName in @($changed)) {
                        try { Restore-AegisServiceSnapshot -Snapshot $snapshots[$changedName] } catch {
                            Write-Log -LogLevel ERROR -Message "SERVICIOS GUI: Rollback fallo en '$changedName': $($_.Exception.Message)"
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
        
        # Recargar para ver cambios
        & $LoadGrid
        [System.Windows.Forms.MessageBox]::Show("Resultado: $successCount correctos, $errorCount errores.", "Servicios", 0, $(if ($errorCount -eq 0) { 64 } else { 48 }))
    }

    # --- EVENTO: BARRA ESPACIADORA PARA MARCAR/DESMARCAR ---
    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            # Evita que la barra espaciadora haga scroll hacia abajo
            $e.SuppressKeyPress = $true 
            
            # Recorre todas las filas seleccionadas (permite seleccion multiple con Shift/Ctrl)
            foreach ($row in $sender.SelectedRows) {
                # Invierte el valor actual (True -> False / False -> True)
                # Nota: Verificamos si la celda es de solo lectura (como en Bloatware protegido)
                if (-not $row.Cells["Check"].ReadOnly) {
                    $row.Cells["Check"].Value = -not ($row.Cells["Check"].Value)
                }
            }
        }
    })

    $btnDisable.Add_Click({ & $ApplyAction -Mode 'Disable' })
    $btnRestore.Add_Click({ & $ApplyAction -Mode 'Restore' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}