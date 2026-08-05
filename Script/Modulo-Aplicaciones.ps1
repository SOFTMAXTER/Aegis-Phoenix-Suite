# =================================================================
#  Modulo-Aplicaciones
#
#  CONTENIDO   : Show-BloatwareMenu, Manage-StartupApps
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Write-AegisJsonAtomic          : escritura atomica de archivos JSON (snapshots/config)
#    - Invoke-AegisNativeProcess      : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - Test-AegisCapability           : verifica disponibilidad de un comando/capacidad del sistema
#    - Read-AegisSafeXml              : carga y valida contenido XML de forma segura
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-Aplicaciones.ps1"
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

function Get-RemovableApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft', 'ThirdParty_AllUsers', 'ThirdParty_CurrentUser')]
        [string]$Type
    )

    $apps = @()
    # Filtro base: Ignorar librerias de sistema (.NET, VCLibs) que rompen apps si se borran
    $baseFilter = { $_.IsFramework -eq $false -and $_.IsResourcePackage -eq $false -and $_.Name -notmatch "NET.Native|VCLibs|UI.Xaml" }

    # Cargar patrones desde variables globales o usar defaults seguros si fallan
    $recPattern = if ($script:RecommendedBloatwareList) { ($script:RecommendedBloatwareList | ForEach-Object { [System.Text.RegularExpressions.Regex]::Escape($_) }) -join '|' } else { "Solitaire|Bing|Cortana|Zune|Xbox" }
    $hardProtectedApps = @(
        'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.DesktopAppInstaller',
        'Microsoft.SecHealthUI', 'Microsoft.Windows.ShellExperienceHost', 'Microsoft.Windows.StartMenuExperienceHost',
        'Microsoft.Windows.Search', 'Microsoft.AAD.BrokerPlugin', 'Microsoft.AccountsControl',
        'Microsoft.LockApp', 'MicrosoftWindows.Client.CBS'
    )
    $protectedPatterns = @($hardProtectedApps) + @($script:ProtectedAppList)
    $protPattern = ($protectedPatterns | Where-Object { $_ } | ForEach-Object { [System.Text.RegularExpressions.Regex]::Escape($_) }) -join '|'

    try {
        if ($Type -eq 'Microsoft') {
            # Apps firmadas por Microsoft
            $rawApps = Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { $_.Publisher -like "*Microsoft*" -and $_.NonRemovable -eq $false -and (& $baseFilter) }
        }
        elseif ($Type -eq 'ThirdParty_AllUsers') {
            # Apps de terceros (Provisionadas en el sistema)
            $rawApps = Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { $_.Publisher -notlike "*Microsoft*" -and $_.SignatureKind -eq 'System' -and (& $baseFilter) }
        }
        elseif ($Type -eq 'ThirdParty_CurrentUser') {
            # Apps de usuario actual (Store / Descargas)
            $rawApps = Get-AppxPackage -ErrorAction Stop | Where-Object { $_.Publisher -notlike "*Microsoft*" -and (& $baseFilter) }
        }

        foreach ($app in $rawApps) {
            $status = "Normal"
            if ($app.Name -match $recPattern) { $status = "Recommended" }
            if ($app.Name -match $protPattern -or $app.NonRemovable -eq $true -or $app.IsFramework -eq $true -or $app.IsResourcePackage -eq $true) { $status = "Protected" }

            # Convertir tamaño si existe (algunas versiones de PS no lo traen)
            $sizeMB = "N/A"
            
            $apps += [PSCustomObject]@{
                Name              = $app.Name
                DisplayName       = if ($app.Name.Length -gt 50) { $app.Name.Substring(0,47) + "..." } else { $app.Name }
                PackageFullName   = $app.PackageFullName
                PackageFamilyName = $app.PackageFamilyName
                Publisher         = $app.Publisher
                Version           = $app.Version
                Status            = $status
                Obj               = $app
            }
        }
    } catch {
        Write-Warning "Error al listar apps: $_"
    }
    
    return $apps | Sort-Object @{Expression={$_.Status -eq 'Recommended'}; Descending=$true}, Name
}

function Show-BloatwareMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Aplicaciones (Bloatware)"
    $form.Size = New-Object System.Drawing.Size(1050, 780)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR (FILTROS) ---
    
    # FILA 1: Origen y Escaneo
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Fuente:"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 23)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    $cmbType = New-Object System.Windows.Forms.ComboBox
    $cmbType.Location = New-Object System.Drawing.Point(90, 20)
    $cmbType.Width = 300
    $cmbType.FlatStyle = "Flat"
    $cmbType.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $cmbType.ForeColor = [System.Drawing.Color]::White
    $cmbType.Items.Add("Bloatware Microsoft (Sistema)") | Out-Null
    $cmbType.Items.Add("Bloatware Terceros (Preinstalado)") | Out-Null
    $cmbType.Items.Add("Mis Apps (Usuario Actual)") | Out-Null
    $cmbType.SelectedIndex = 0
    $form.Controls.Add($cmbType)

    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "ESCANEAR"
    $btnScan.Location = New-Object System.Drawing.Point(410, 18)
    $btnScan.Size = New-Object System.Drawing.Size(120, 28)
    $btnScan.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnScan.ForeColor = [System.Drawing.Color]::White
    $btnScan.FlatStyle = "Flat"
    $btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnScan)

    # FILA 2: Filtros de Visualizacion (NUEVO)
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(20, 63)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(90, 60)
    $txtSearch.Width = 300
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    # Checkbox para mostrar/ocultar protegidos
    $chkShowProtected = New-Object System.Windows.Forms.CheckBox
    $chkShowProtected.Text = "Mostrar Apps Protegidas (Sistema)"
    $chkShowProtected.Location = New-Object System.Drawing.Point(410, 60)
    $chkShowProtected.Width = 250
    $chkShowProtected.AutoSize = $true
    $chkShowProtected.ForeColor = [System.Drawing.Color]::Silver
    $chkShowProtected.Checked = $false # Ocultos por defecto para seguridad
    $form.Controls.Add($chkShowProtected)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 100)
    $grid.Size = New-Object System.Drawing.Size(990, 450)
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

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Nombre de la Aplicacion"
    $colName.Name = "DisplayName"
    $colName.ReadOnly = $true
    $colName.Width = 350
    $grid.Columns.Add($colName) | Out-Null
    
    $colVer = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colVer.HeaderText = "Version"
    $colVer.Name = "Version"
    $colVer.ReadOnly = $true
    $colVer.Width = 100
    $grid.Columns.Add($colVer) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Clasificacion"
    $colStatus.Width = 150
    $colStatus.Name = "StatusDesc"
    $colStatus.ReadOnly = $true
    $grid.Columns.Add($colStatus) | Out-Null

    # Columna Oculta
    $colObj = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colObj.Name = "RealObject"
    $colObj.Visible = $false
    $grid.Columns.Add($colObj) | Out-Null

    $form.Controls.Add($grid)

    # --- MENU CONTEXTUAL ---
    $ctxMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $itemGoogle = $ctxMenu.Items.Add("Buscar en Google (Que es esto?)")
    $itemGoogle.Add_Click({
        if ($grid.SelectedRows.Count -gt 0) {
            $appName = $grid.SelectedRows[0].Cells["DisplayName"].Value
            Start-Process "https://www.google.com/search?q=$appName app windows bloatware"
        }
    })
    $grid.ContextMenuStrip = $ctxMenu

    # --- 4. AREA DE ESTADO ---
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo. Selecciona 'Escanear' para comenzar."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 560)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    $chkDeepClean = New-Object System.Windows.Forms.CheckBox
    $chkDeepClean.Text = "Eliminar tambien datos del usuario actual (no recuperables)"
    $chkDeepClean.Location = New-Object System.Drawing.Point(20, 590)
    $chkDeepClean.AutoSize = $true
    $chkDeepClean.ForeColor = [System.Drawing.Color]::Silver
    $chkDeepClean.Checked = $false
    $form.Controls.Add($chkDeepClean)

    # --- 5. BOTONES DE ACCION ---
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 630)
    $btnSelectAll.Size = New-Object System.Drawing.Size(60, 40)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $btnSelectRec = New-Object System.Windows.Forms.Button
    $btnSelectRec.Text = "Marcar Recomendados"
    $btnSelectRec.Location = New-Object System.Drawing.Point(90, 630)
    $btnSelectRec.Size = New-Object System.Drawing.Size(160, 40)
    $btnSelectRec.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectRec.ForeColor = [System.Drawing.Color]::Orange
    $btnSelectRec.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectRec)

    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "Exportar Lista"
    $btnExport.Location = New-Object System.Drawing.Point(260, 630)
    $btnExport.Size = New-Object System.Drawing.Size(120, 40)
    $btnExport.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $btnExport.ForeColor = [System.Drawing.Color]::White
    $btnExport.FlatStyle = "Flat"
    $form.Controls.Add($btnExport)

    $btnRestoreApp = New-Object System.Windows.Forms.Button
    $btnRestoreApp.Text = "Restaurar AppX"
    $btnRestoreApp.Location = New-Object System.Drawing.Point(390, 630)
    $btnRestoreApp.Size = New-Object System.Drawing.Size(120, 40)
    $btnRestoreApp.BackColor = [System.Drawing.Color]::SteelBlue
    $btnRestoreApp.ForeColor = [System.Drawing.Color]::White
    $btnRestoreApp.FlatStyle = "Flat"
    $form.Controls.Add($btnRestoreApp)

    $btnRestoreStore = New-Object System.Windows.Forms.Button
    $btnRestoreStore.Text = "REPARAR TIENDA"
    $btnRestoreStore.Location = New-Object System.Drawing.Point(520, 630)
    $btnRestoreStore.Size = New-Object System.Drawing.Size(180, 40)
    $btnRestoreStore.BackColor = [System.Drawing.Color]::Teal
    $btnRestoreStore.ForeColor = [System.Drawing.Color]::White
    $btnRestoreStore.FlatStyle = "Flat"
    $btnRestoreStore.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestoreStore)

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = "ELIMINAR SELECCIONADOS"
    $btnRemove.Location = New-Object System.Drawing.Point(710, 630)
    $btnRemove.Size = New-Object System.Drawing.Size(300, 40)
    $btnRemove.BackColor = [System.Drawing.Color]::Crimson
    $btnRemove.ForeColor = [System.Drawing.Color]::White
    $btnRemove.FlatStyle = "Flat"
    $btnRemove.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnRemove.Enabled = $false
    $form.Controls.Add($btnRemove)

    $appState = [PSCustomObject]@{ Cache = @(); ScanType = 'Microsoft' }

    # --- LOGICA: RENDERIZADO GRID ---
    $RenderGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        
        $term = $txtSearch.Text.Trim()
        $filtered = $appState.Cache

        # 1. Filtro de Texto
        if (-not [string]::IsNullOrWhiteSpace($term)) {
            $filtered = $filtered | Where-Object {
                $_.Name.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
        }

        # 2. Filtro de Protegidos (NUEVO)
        if (-not $chkShowProtected.Checked) {
            $filtered = $filtered | Where-Object { $_.Status -ne 'Protected' }
        }

        foreach ($app in $filtered) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["DisplayName"].Value = $app.Name
            $row.Cells["Version"].Value = $app.Version
            $row.Cells["RealObject"].Value = $app 
            
            if ($app.Status -eq 'Protected') {
                $row.Cells["StatusDesc"].Value = "SISTEMA (Protegido)"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::LightGreen
                $row.Cells["Check"].ReadOnly = $true 
            }
            elseif ($app.Status -eq 'Recommended') {
                $row.Cells["StatusDesc"].Value = "BLOATWARE"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Orange
            }
            else {
                $row.Cells["StatusDesc"].Value = "Usuario / Opcional"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
            }
        }
        $grid.ResumeLayout()
        $grid.ClearSelection()
        
        $count = $filtered.Count
        $lblStatus.Text = "Aplicaciones listadas: $count"
        if ($count -gt 0) { $btnRemove.Enabled = $true }
    }

    $PerformScan = {
        $lblStatus.Text = "Escaneando aplicaciones... Por favor espera."
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnRemove.Enabled = $false
        [System.Windows.Forms.Application]::DoEvents()

        $type = switch($cmbType.SelectedIndex) {
            0 { 'Microsoft' }
            1 { 'ThirdParty_AllUsers' }
            2 { 'ThirdParty_CurrentUser' }
        }

        $appState.ScanType = $type
        $appState.Cache = @(Get-RemovableApps -Type $type)
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        
        & $RenderGrid
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $PerformScan })
    $btnScan.Add_Click({ & $PerformScan })
    $txtSearch.Add_KeyUp({ & $RenderGrid })
    # Nuevo evento para el checkbox
    $chkShowProtected.Add_CheckedChanged({ & $RenderGrid })

    $grid.Add_CellClick({ param($s,$e) if($e.RowIndex -ge 0 -and $e.ColumnIndex -ne 0 -and -not $grid.Rows[$e.RowIndex].Cells["Check"].ReadOnly){ $r=$grid.Rows[$e.RowIndex]; $r.Cells[0].Value = -not $r.Cells[0].Value } })
    $grid.Add_KeyDown({ param($s,$e) if($e.KeyCode -eq 'Space'){ $e.SuppressKeyPress=$true; foreach($r in $s.SelectedRows){ if(-not $r.Cells[0].ReadOnly){ $r.Cells[0].Value = -not $r.Cells[0].Value } } } })

    $btnSelectAll.Add_Click({ foreach($r in $grid.Rows){ if(-not $r.Cells[0].ReadOnly){ $r.Cells[0].Value = $true } } })
    $btnSelectRec.Add_Click({ foreach($r in $grid.Rows){ if($r.DefaultCellStyle.ForeColor -eq [System.Drawing.Color]::Orange){ $r.Cells[0].Value = $true } } })

    $btnExport.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = "Texto (*.txt)|*.txt"
        $sfd.FileName = "Lista_Apps_$(Get-Date -Format 'yyyyMMdd').txt"
        if ($sfd.ShowDialog() -eq 'OK') {
            $lines = $appState.Cache | Select-Object Name, Version, Publisher, Status
            $lines | Out-File $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Lista exportada.", "Exito", 0, 64)
        }
    })

    $btnRestoreStore.Add_Click({
        if ([System.Windows.Forms.MessageBox]::Show("Primero se intentara volver a registrar Microsoft Store si sus archivos siguen instalados. Si el paquete ya no existe, se intentara instalar desde la fuente msstore mediante Winget.\n\nContinuar?", "Reparar Tienda", 'YesNo', 'Warning') -eq 'Yes') {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            $lblStatus.Text = "Restaurando Microsoft Store..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                $storePackages = @(Get-AppxPackage -AllUsers *WindowsStore* -ErrorAction Stop)
                if ($storePackages.Count -gt 0) {
                    foreach ($storePackage in $storePackages) {
                        $manifestPath = Join-Path $storePackage.InstallLocation 'AppXManifest.xml'
                        if (Test-Path -LiteralPath $manifestPath) {
                            Add-AppxPackage -DisableDevelopmentMode -Register $manifestPath -ErrorAction Stop
                        }
                    }
                } elseif (Test-AegisCapability -Command 'winget.exe') {
                    Invoke-AegisNativeProcess -FilePath 'winget.exe' -ArgumentList @('install','--id','9WZDNCRFJBMP','--source','msstore','--accept-source-agreements','--accept-package-agreements') -TimeoutSeconds 1800 | Out-Null
                } else {
                    throw "Microsoft Store ya no esta instalada y Winget no esta disponible para intentar recuperarla."
                }
                [System.Windows.Forms.MessageBox]::Show("Reparacion completada. Reinicia el PC y verifica Microsoft Store.", "Info", 0, 64)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error al restaurar: $_", "Error", 0, 16)
            } finally {
                $form.Cursor = [System.Windows.Forms.Cursors]::Default
                $lblStatus.Text = "Listo."
            }
        }
    })

    $btnRestoreApp.Add_Click({
        $manifestPaths = Select-PathDialog -DialogType 'File' -Title 'Selecciona un manifiesto AppX respaldado' -Filter 'Manifiestos JSON (*.json)|*.json'
        if (-not $manifestPaths) { return }
        $manifestPath = [string]$manifestPaths[0]
        $journal = $null
        try {
            if ((Get-Item -LiteralPath $manifestPath -ErrorAction Stop).Length -gt 1MB) { throw 'El manifiesto excede 1 MB.' }
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ([int]$manifest.SchemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace([string]$manifest.Name)) {
                throw 'Manifiesto AppX incompleto o incompatible.'
            }
            $journal = New-AegisOperationJournal -Module 'Aplicaciones' -Action 'Restore-Appx' -Targets @([string]$manifest.Name) -Metadata @{ Manifest=$manifestPath }
            $restoredCurrentUser = $false
            $restoredProvisioning = $false

            if (-not [string]::IsNullOrWhiteSpace([string]$manifest.InstallLocation)) {
                $installLocation = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$manifest.InstallLocation)).TrimEnd('\')
                $allowedRoots = @(
                    [IO.Path]::GetFullPath((Join-Path $env:ProgramFiles 'WindowsApps')).TrimEnd('\'),
                    [IO.Path]::GetFullPath((Join-Path $env:SystemRoot 'SystemApps')).TrimEnd('\')
                )
                $isAllowed = @($allowedRoots | Where-Object {
                    $installLocation.Equals($_, [StringComparison]::OrdinalIgnoreCase) -or
                    $installLocation.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase)
                }).Count -gt 0
                if (-not $isAllowed) { throw 'La ubicacion AppX respaldada no pertenece a un directorio de paquetes de Windows.' }
                $appxManifestPath = Join-Path $installLocation 'AppXManifest.xml'
                if (Test-Path -LiteralPath $appxManifestPath -PathType Leaf) {
                    $appxXml = Read-AegisSafeXml -Path $appxManifestPath -MaxCharacters 5242880
                    if ($appxXml.DocumentElement.LocalName -ne 'Package' -or
                        $appxXml.DocumentElement.NamespaceURI -notmatch '^http://schemas\.microsoft\.com/appx/manifest/') {
                        throw 'El AppXManifest.xml no tiene el esquema esperado.'
                    }
                    Add-AppxPackage -DisableDevelopmentMode -Register $appxManifestPath -ErrorAction Stop
                    $restoredCurrentUser = $true
                }
            }

            foreach ($provisioned in @($manifest.Provisioned)) {
                $packagePath = [string]$provisioned.PackagePath
                if (-not [string]::IsNullOrWhiteSpace($packagePath) -and (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
                    $packageFullPath = [IO.Path]::GetFullPath($packagePath)
                    $packageRoots = @(
                        [IO.Path]::GetFullPath((Join-Path $env:ProgramFiles 'WindowsApps')).TrimEnd('\'),
                        [IO.Path]::GetFullPath((Join-Path $env:ProgramData 'Microsoft\Windows\AppRepository')).TrimEnd('\')
                    )
                    $packageAllowed = @($packageRoots | Where-Object {
                        $packageFullPath.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase)
                    }).Count -gt 0
                    if (-not $packageAllowed) { throw 'La ruta del paquete aprovisionado no pertenece a un almacen de Windows permitido.' }
                    Add-AppxProvisionedPackage -Online -PackagePath $packageFullPath -SkipLicense -ErrorAction Stop | Out-Null
                    $restoredProvisioning = $true
                }
            }
            if (-not $restoredCurrentUser -and -not $restoredProvisioning) {
                throw 'Los archivos originales del paquete ya no estan presentes. Reinstala la app desde Microsoft Store o Winget.'
            }
            [void](Complete-AegisOperationJournal -Journal $journal -Status 'Completed' -Results @(
                [ordered]@{ CurrentUser=$restoredCurrentUser; Provisioned=$restoredProvisioning }
            ))
            $dataWarning = if ([bool]$manifest.CurrentUserDataDeleted) { "`n`nLos datos de usuario eliminados no se pueden recuperar." } else { '' }
            [System.Windows.Forms.MessageBox]::Show("Restauracion completada. Usuario actual: $restoredCurrentUser; aprovisionamiento: $restoredProvisioning.$dataWarning", 'Restaurar AppX', 0, 64) | Out-Null
            & $PerformScan
        } catch {
            if ($journal) { [void](Complete-AegisOperationJournal -Journal $journal -Status 'Failed' -Results @([ordered]@{ Error=$_.Exception.Message })) }
            [System.Windows.Forms.MessageBox]::Show("No fue posible restaurar la aplicacion: $($_.Exception.Message)", 'Error', 0, 16) | Out-Null
        }
    })

    $btnRemove.Add_Click({
        $appsToRemove = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $appsToRemove += $row.Cells["RealObject"].Value
            }
        }

        if ($appsToRemove.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No hay apps seleccionadas.", "Aviso", 0, 48); return }

        if ($chkDeepClean.Checked) {
            $deepWarning = "Tambien se borraran los datos de estas aplicaciones para el usuario actual. Esos datos no forman parte de la restauracion y no se pueden recuperar.`n`nContinuar?"
            if ([System.Windows.Forms.MessageBox]::Show($deepWarning, "Datos no recuperables", 4, 48) -ne 'Yes') { return }
        }

        if ([System.Windows.Forms.MessageBox]::Show("Eliminar $($appsToRemove.Count) aplicaciones?\n\nEsta accion no se puede deshacer facilmente.", "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnRemove.Enabled = $false
        $count = 0
        $successCount = 0
        $errorCount = 0
        $manifestRoot = Join-Path (Split-Path -Parent $PSScriptRoot) ("Backup\Appx\" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
        New-Item -Path $manifestRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        $journal = New-AegisOperationJournal -Module 'Aplicaciones' -Action 'Remove-Appx' -Targets @($appsToRemove.Name) -Metadata @{
            ManifestPath=$manifestRoot; ScanType=$appState.ScanType; DeleteCurrentUserData=[bool]$chkDeepClean.Checked
        }
        $operationResults = [System.Collections.Generic.List[object]]::new()
        
        try {
            foreach ($appEntry in $appsToRemove) {
                $app = $appEntry.Obj
                $count++
                $lblStatus.Text = "Eliminando ($count/$($appsToRemove.Count)): $($app.Name)"
                $lblStatus.ForeColor = [System.Drawing.Color]::Cyan
                [System.Windows.Forms.Application]::DoEvents()

                try {
                    if ($appEntry.Status -eq 'Protected') { throw "La aplicacion esta marcada como protegida." }
                    $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -eq $app.Name })
                    $appManifest = [ordered]@{
                        SchemaVersion=1; Name=$app.Name; PackageFullName=$app.PackageFullName
                        PackageFamilyName=$app.PackageFamilyName; Publisher=$app.Publisher; Version=[string]$app.Version
                        InstallLocation=$app.InstallLocation; ScanType=$appState.ScanType
                        Provisioned=@($provisioned | Select-Object DisplayName,PackageName,PackagePath,Version,PublisherId)
                        RemovedAt=(Get-Date).ToString('o'); CurrentUserDataDeleted=[bool]$chkDeepClean.Checked
                    }
                    $safeManifestName = ($app.Name -replace '[^a-zA-Z0-9._-]', '_') + '.json'
                    Write-AegisJsonAtomic -InputObject $appManifest -Path (Join-Path $manifestRoot $safeManifestName)
                    Write-Log -LogLevel ACTION -Message "BLOATWARE: Eliminando $($app.Name) ($($app.PackageFullName))"
                    if ($appState.ScanType -eq 'ThirdParty_CurrentUser') {
                        Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
                    } else {
                        Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop
                        foreach ($prov in $provisioned) {
                            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
                        }
                    }

                    if ($chkDeepClean.Checked) {
                        $pkgPath = "$env:LOCALAPPDATA\Packages\$($app.PackageFamilyName)"
                        if (Test-Path -LiteralPath $pkgPath) { Remove-Item -LiteralPath $pkgPath -Recurse -Force -ErrorAction Stop }
                    }

                    foreach ($row in $grid.Rows) {
                        if ($row.Cells["DisplayName"].Value -eq $app.Name) {
                            $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
                            $row.Cells["StatusDesc"].Value = "ELIMINADO"
                            $row.Cells["Check"].Value = $false
                        }
                    }
                    $successCount++
                    $operationResults.Add([PSCustomObject]@{ Name=$app.Name; Success=$true; Manifest=$safeManifestName })
                } catch {
                    $errorCount++
                    $operationResults.Add([PSCustomObject]@{ Name=$app.Name; Success=$false; Error=$_.Exception.Message })
                    Write-Log -LogLevel ERROR -Message "Fallo al eliminar $($app.Name): $($_.Exception.Message)"
                }
            }
            Complete-AegisOperationJournal -Journal $journal -Status $(if ($errorCount -eq 0) { 'Completed' } else { 'Partial' }) -Results @($operationResults) | Out-Null
        } catch {
            Complete-AegisOperationJournal -Journal $journal -Status Failed -Results @($_.Exception.Message) | Out-Null
            $errorCount++
            Write-Log -LogLevel ERROR -Message "BLOATWARE: Fallo general: $($_.Exception.Message)"
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $btnRemove.Enabled = $true
        }

        $lblStatus.Text = "Proceso finalizado."
        $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
        [System.Windows.Forms.MessageBox]::Show("Resultado: $successCount eliminadas, $errorCount errores.", "Aplicaciones", 0, $(if ($errorCount -eq 0) { 64 } else { 48 }))
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# ===================================================================
# MODULO DE Gestor de Inicio
# ===================================================================

function Manage-StartupApps {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Inicio"
    $form.Size = New-Object System.Drawing.Size(1000, 750)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. FUNCIONES HELPER (BACKEND) ---
    
    # Obtiene el estado real basado en el byte de control de Windows
    $GetStartupStateSmart = {
        param($Hive, $Type, $Name)
        
        $approvedPath = "$($Hive):\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$Type"
        
        if (-not (Test-Path $approvedPath)) { return 'Enabled' }
        
        try {
            $bytes = (Get-ItemProperty -Path $approvedPath -Name $Name -ErrorAction SilentlyContinue).$Name
            if ($null -eq $bytes -or $bytes.Length -eq 0) { return 'Enabled' }
            
            switch ([byte]$bytes[0]) {
                0x02 { return 'Enabled' }
                0x03 { return 'Disabled' }
                default { return 'Unknown' }
            }
        } catch {
            Write-Log -LogLevel WARN -Message "INICIO: No se pudo leer StartupApproved para '$Name': $($_.Exception.Message)"
            return 'Unknown'
        }
    }

    # Establece el estado preservando metadatos
    $SetStartupStateSmart = {
        param($Item, $Enable)
        
        $hiveStr = if ($Item.RegBase -eq 'HKLM') { "HKLM:" } else { "HKCU:" }
        $subKey = if ($Item.InternalType -eq 'Folder') { "StartupFolder" } elseif ($Item.ApprovedType) { $Item.ApprovedType } else { "Run" }
        $approvedKeyPath = "$hiveStr\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$subKey"
        
        if (-not (Test-Path $approvedKeyPath)) { New-Item -Path $approvedKeyPath -Force | Out-Null }

        try {
            $currentBytes = (Get-ItemProperty -Path $approvedKeyPath -Name $Item.Name -ErrorAction SilentlyContinue).($Item.Name)
            
            if ($null -eq $currentBytes -or $currentBytes.Length -lt 1) {
                $currentBytes = New-Object byte[] 12
            }

            # 0x02 = Habilitado, 0x03 = Deshabilitado
            if ($Enable) { $currentBytes[0] = 0x02 } else { $currentBytes[0] = 0x03 }

            Set-ItemProperty -Path $approvedKeyPath -Name $Item.Name -Value $currentBytes -Type Binary -Force -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }

    # Elimina la entrada permanentemente
    $DeleteStartupItem = {
        param($Item)
        try {
            $backupRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "Backup\StartupItems"
            New-Item -Path $backupRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
            $backupId = (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8)
            $manifestPath = Join-Path $backupRoot "Startup_${backupId}.json"
            $manifest = [ordered]@{
                SchemaVersion=1; Type=$Item.InternalType; Name=$Item.Name; Command=$Item.Command
                Origin=$Item.Origin; RegBase=$Item.RegBase; RegPath=$Item.RegPath; ApprovedType=$Item.ApprovedType
                BackupPayload=$null; ApprovedBytesBase64=$null; DeletedAt=(Get-Date).ToString('o')
            }

            if ($Item.InternalType -eq 'Task') {
                $payloadPath = Join-Path $backupRoot "Task_${backupId}.xml"
                Export-ScheduledTask -TaskName $Item.Name -TaskPath $Item.RegPath -ErrorAction Stop |
                    Set-Content -LiteralPath $payloadPath -Encoding Unicode -ErrorAction Stop
                $manifest.BackupPayload = $payloadPath
                Write-AegisJsonAtomic -InputObject $manifest -Path $manifestPath
                Unregister-ScheduledTask -TaskName $Item.Name -TaskPath $Item.RegPath -Confirm:$false -ErrorAction Stop
            }
            elseif ($Item.InternalType -eq 'Folder') {
                if (Test-Path -LiteralPath $Item.Command) {
                    $payloadPath = Join-Path $backupRoot ("Folder_${backupId}_" + (Split-Path $Item.Command -Leaf))
                    Copy-Item -LiteralPath $Item.Command -Destination $payloadPath -Force -ErrorAction Stop
                    $manifest.BackupPayload = $payloadPath
                    Write-AegisJsonAtomic -InputObject $manifest -Path $manifestPath
                    Remove-Item -LiteralPath $Item.Command -Force -ErrorAction Stop
                }
            }
            elseif ($Item.InternalType -eq 'Registry') {
                $hiveStr = if ($Item.RegBase -eq 'HKLM') { "HKLM:" } else { "HKCU:" }
                $approvedType = if ($Item.ApprovedType) { $Item.ApprovedType } else { 'Run' }
                $approvedKeyPath = "$hiveStr\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$approvedType"
                $approvedBytes = try { (Get-ItemProperty -Path $approvedKeyPath -Name $Item.Name -ErrorAction Stop).($Item.Name) } catch { $null }
                if ($approvedBytes -is [byte[]]) { $manifest.ApprovedBytesBase64 = [Convert]::ToBase64String($approvedBytes) }
                Write-AegisJsonAtomic -InputObject $manifest -Path $manifestPath
                # 1. Borrar la clave Run original
                Remove-ItemProperty -Path $Item.RegPath -Name $Item.Name -Force -ErrorAction Stop
                
                # 2. Limpiar entrada huerfana en StartupApproved (Limpieza)
                if (Test-Path $approvedKeyPath) {
                    Remove-ItemProperty -Path $approvedKeyPath -Name $Item.Name -ErrorAction SilentlyContinue
                }
            }
            return $true
        } catch {
            Write-Warning "Error eliminando: $_"
            return $false
        }
    }

    # --- 3. UI SUPERIOR (BUSQUEDA AÑADIDA) ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Programas de Inicio"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    # Label Busqueda
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(350, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    # TextBox Busqueda
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(410, 20)
    $txtSearch.Width = 250
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(830, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(130, 28)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 4. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(940, 430)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas (Sin acentos)
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Nombre"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 250
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 100
    $grid.Columns.Add($colStatus) | Out-Null

    $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colType.HeaderText = "Ubicacion / Origen"
    $colType.Name = "Type"
    $colType.ReadOnly = $true
    $colType.Width = 150
    $grid.Columns.Add($colType) | Out-Null

    $colCmd = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCmd.HeaderText = "Comando"
    $colCmd.Name = "Command"
    $colCmd.ReadOnly = $true
    $grid.Columns.Add($colCmd) | Out-Null

    $form.Controls.Add($grid)

    # --- 5. PANEL DE DETALLES ---
    $grpDet = New-Object System.Windows.Forms.GroupBox
    $grpDet.Text = "Detalle del Comando Completo"
    $grpDet.ForeColor = [System.Drawing.Color]::Silver
    $grpDet.Location = New-Object System.Drawing.Point(20, 500)
    $grpDet.Size = New-Object System.Drawing.Size(940, 70)
    $form.Controls.Add($grpDet)

    $txtCommand = New-Object System.Windows.Forms.TextBox
    $txtCommand.Location = New-Object System.Drawing.Point(15, 25)
    $txtCommand.Size = New-Object System.Drawing.Size(910, 30)
    $txtCommand.ReadOnly = $true
    $txtCommand.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtCommand.ForeColor = [System.Drawing.Color]::Yellow
    $txtCommand.BorderStyle = "FixedSingle"
    $grpDet.Controls.Add($txtCommand)

    # --- 6. BOTONES DE ACCION (AGREGADO ELIMINAR) ---
    
    # Boton Habilitar
    $btnEnable = New-Object System.Windows.Forms.Button
    $btnEnable.Text = "HABILITAR"
    $btnEnable.Location = New-Object System.Drawing.Point(280, 590)
    $btnEnable.Size = New-Object System.Drawing.Size(200, 40)
    $btnEnable.BackColor = [System.Drawing.Color]::SeaGreen
    $btnEnable.ForeColor = [System.Drawing.Color]::White
    $btnEnable.FlatStyle = "Flat"
    $btnEnable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnEnable)

    # Boton Deshabilitar
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR"
    $btnDisable.Location = New-Object System.Drawing.Point(500, 590)
    $btnDisable.Size = New-Object System.Drawing.Size(200, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::Orange # Naranja para precaucion
    $btnDisable.ForeColor = [System.Drawing.Color]::Black
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    # Boton Eliminar (Nuevo)
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR"
    $btnDelete.Location = New-Object System.Drawing.Point(720, 590)
    $btnDelete.Size = New-Object System.Drawing.Size(240, 40)
    $btnDelete.BackColor = [System.Drawing.Color]::Maroon # Rojo oscuro peligro
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 595)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $btnRestoreDeleted = New-Object System.Windows.Forms.Button
    $btnRestoreDeleted.Text = "Restaurar eliminado"
    $btnRestoreDeleted.Location = New-Object System.Drawing.Point(20, 635)
    $btnRestoreDeleted.Size = New-Object System.Drawing.Size(180, 30)
    $btnRestoreDeleted.BackColor = [System.Drawing.Color]::Teal
    $btnRestoreDeleted.ForeColor = [System.Drawing.Color]::White
    $btnRestoreDeleted.FlatStyle = 'Flat'
    $form.Controls.Add($btnRestoreDeleted)

    # Cache global
    $startupState = [PSCustomObject]@{ RawList = @() }

    # --- LOGICA DE CARGA DE DATOS ---
    $LoadData = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        # 1. Obtener datos crudos (solo si la lista esta vacia o se pide refrescar)
        # Esto permite que la barra de busqueda use datos en memoria rapido
        if ($startupState.RawList.Count -eq 0) {
            $items = @()

            # A. Registro
            $regPaths = @(
                @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Base="HKCU"; Type="Run" },
                @{ P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Base="HKLM"; Type="Run" },
                @{ P="HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"; Base="HKLM"; Type="Run32" }
            )
            foreach ($loc in $regPaths) {
                if (Test-Path $loc.P) {
                    Get-ItemProperty $loc.P -ErrorAction SilentlyContinue | ForEach-Object {
                        $_.PSObject.Properties | Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider','(Default)') } | ForEach-Object {
                            $statusCheck = & $GetStartupStateSmart -Hive $loc.Base -Type $loc.Type -Name $_.Name
                            $items += [PSCustomObject]@{
                                Name = $_.Name; Command = $_.Value; Origin = "Registro ($($loc.Base))"
                                InternalType = "Registry"; RegBase = $loc.Base; RegPath = $loc.P; ApprovedType = $loc.Type; Status = $statusCheck
                            }
                        }
                    }
                }
            }

            # B. Carpetas
            $folders = @(
                @{ P="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Base="HKCU" },
                @{ P="$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"; Base="HKLM" }
            )
            foreach ($loc in $folders) {
                if (Test-Path $loc.P) {
                    Get-ChildItem $loc.P -File -ErrorAction SilentlyContinue | ForEach-Object {
                        $statusCheck = & $GetStartupStateSmart -Hive $loc.Base -Type "StartupFolder" -Name $_.Name
                        $items += [PSCustomObject]@{
                            Name = $_.Name; Command = $_.FullName; Origin = "Carpeta ($($loc.Base))"
                            InternalType = "Folder"; RegBase = $loc.Base; RegPath = $loc.P; ApprovedType = "StartupFolder"; Status = $statusCheck
                        }
                    }
                }
            }

            # C. Tareas
            Get-ScheduledTask | Where-Object {
                $startupTriggers = @($_.Triggers | Where-Object {
                    $_.CimClass.CimClassName -in @('MSFT_TaskLogonTrigger','MSFT_TaskBootTrigger')
                })
                $startupTriggers.Count -gt 0 -and $_.TaskPath -notlike "\Microsoft\*"
            } | ForEach-Object {
                $act = ($_.Actions | Select-Object -First 1)
                $cmd = "$($act.Execute) $($act.Arguments)"
                $items += [PSCustomObject]@{
                    Name = $_.TaskName; Command = $cmd; Origin = "Tarea Programada"
                    InternalType = "Task"; RegBase = ""; RegPath = $_.TaskPath
                    Status = if ($_.State -eq 'Disabled') { 'Disabled' } else { 'Enabled' }
                }
            }
            
            $startupState.RawList = @($items)
        }

        # 2. Filtrar y Poblar
        $searchTerm = $txtSearch.Text.Trim()
        $filteredItems = $startupState.RawList
        
        if (-not [string]::IsNullOrWhiteSpace($searchTerm)) {
            $filteredItems = $startupState.RawList | Where-Object {
                ([string]$_.Name).IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                ([string]$_.Command).IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
        }

        foreach ($item in $filteredItems) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            $row.Tag = $item 

            $row.Cells["Name"].Value = $item.Name
            $row.Cells["Type"].Value = $item.Origin
            $row.Cells["Command"].Value = $item.Command
            
            if ($item.Status -eq 'Enabled') {
                $row.Cells["Status"].Value = "Habilitado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
            } elseif ($item.Status -eq 'Disabled') {
                $row.Cells["Status"].Value = "Deshabilitado"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
            } else {
                $row.Cells["Status"].Value = "Desconocido"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Gold
            }
        }
        
        $grid.ResumeLayout()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $grid.ClearSelection()
        $txtCommand.Text = ""
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $LoadData })
    $btnRefresh.Add_Click({ $startupState.RawList = @(); & $LoadData })
    
    # Evento de Busqueda (Key Up)
    $txtSearch.Add_KeyUp({ & $LoadData })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $item = $grid.SelectedRows[0].Tag
            if ($item) { $txtCommand.Text = $item.Command }
        }
    })

    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            $e.SuppressKeyPress = $true 
            foreach ($row in $sender.SelectedRows) {
                if (-not $row.Cells["Check"].ReadOnly) {
                    $row.Cells["Check"].Value = -not ($row.Cells["Check"].Value)
                }
            }
        }
    })
    
    $grid.Add_CellClick({
        param($sender, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -eq 0) { 
             # Checkbox click handling
        }
    })

    $btnSelectAll.Add_Click({
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
    })

    $btnRestoreDeleted.Add_Click({
        $backupRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Backup\StartupItems'
        if (-not (Test-Path -LiteralPath $backupRoot)) {
            [System.Windows.Forms.MessageBox]::Show('No existen respaldos de elementos eliminados.', 'Restaurar', 0, 48) | Out-Null
            return
        }
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.InitialDirectory = $backupRoot
        $dialog.Filter = 'Manifiestos de inicio (Startup_*.json)|Startup_*.json'
        if ($dialog.ShowDialog() -ne 'OK') { return }
        try {
            $manifest = Get-Content -LiteralPath $dialog.FileName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($manifest.SchemaVersion -ne 1 -or -not $manifest.Type -or -not $manifest.Name) { throw 'Manifiesto invalido o incompatible.' }
            switch ($manifest.Type) {
                'Task' {
                    $xml = Get-Content -LiteralPath $manifest.BackupPayload -Raw -ErrorAction Stop
                    Register-ScheduledTask -TaskName $manifest.Name -TaskPath $manifest.RegPath -Xml $xml -Force -ErrorAction Stop | Out-Null
                }
                'Folder' {
                    $targetDirectory = Split-Path -Parent $manifest.Command
                    if (-not (Test-Path -LiteralPath $targetDirectory)) { New-Item -Path $targetDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null }
                    Copy-Item -LiteralPath $manifest.BackupPayload -Destination $manifest.Command -Force -ErrorAction Stop
                }
                'Registry' {
                    if (-not (Test-Path -LiteralPath $manifest.RegPath)) { New-Item -Path $manifest.RegPath -Force -ErrorAction Stop | Out-Null }
                    Set-ItemProperty -Path $manifest.RegPath -Name $manifest.Name -Value $manifest.Command -Type String -Force -ErrorAction Stop
                    if ($manifest.ApprovedBytesBase64) {
                        $hiveStr = if ($manifest.RegBase -eq 'HKLM') { 'HKLM:' } else { 'HKCU:' }
                        $approvedType = if ($manifest.ApprovedType) { $manifest.ApprovedType } else { 'Run' }
                        $approvedPath = "$hiveStr\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$approvedType"
                        if (-not (Test-Path -LiteralPath $approvedPath)) { New-Item -Path $approvedPath -Force -ErrorAction Stop | Out-Null }
                        Set-ItemProperty -Path $approvedPath -Name $manifest.Name -Value ([Convert]::FromBase64String([string]$manifest.ApprovedBytesBase64)) -Type Binary -Force -ErrorAction Stop
                    }
                }
                default { throw "Tipo de respaldo no compatible: $($manifest.Type)" }
            }
            $startupState.RawList = @()
            & $LoadData
            [System.Windows.Forms.MessageBox]::Show("'$($manifest.Name)' fue restaurado.", 'Restaurar', 0, 64) | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("No se pudo restaurar: $($_.Exception.Message)", 'Error', 0, 16) | Out-Null
        }
    })

    # Logica de Accion (Enable / Disable / Delete)
    $ApplyChange = {
        param($Action) # 'Enable', 'Disable', 'Delete'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $row.Tag
            }
        }

        if ($targets.Count -eq 0) { return }

        # Advertencia especial para Eliminar
        if ($Action -eq 'Delete') {
            $msg = "Estas seguro de eliminar $($targets.Count) elementos?`n`nSe guardara una copia en la carpeta Backup antes de cada eliminacion."
            if ([System.Windows.Forms.MessageBox]::Show($msg, "Confirmacion de Eliminacion", 4, 48) -ne 'Yes') { return }
        }

        $successCount = 0
        $errorCount = 0
        foreach ($item in $targets) {
            $res = $false
            try {
                if ($Action -eq 'Delete') {
                    $res = & $DeleteStartupItem -Item $item
                }
                elseif ($item.InternalType -eq 'Task') {
                    if ($Action -eq 'Enable') { 
                        Enable-ScheduledTask -TaskName $item.Name -TaskPath $item.RegPath -ErrorAction Stop 
                    } else { 
                        Disable-ScheduledTask -TaskName $item.Name -TaskPath $item.RegPath -ErrorAction Stop 
                    }
                    $res = $true
                }
                else {
                    # Registro o Carpeta (StartupApproved)
                    $boolState = ($Action -eq 'Enable')
                    $res = & $SetStartupStateSmart -Item $item -Enable $boolState
                }
                if ($res) { $successCount++ } else { $errorCount++ }
            } catch {
                $errorCount++
                Write-Log -LogLevel ERROR -Message "INICIO: Fallo '$Action' en '$($item.Name)': $($_.Exception.Message)"
            }
        }
        $startupState.RawList = @()
        & $LoadData
        [System.Windows.Forms.MessageBox]::Show("Resultado: $successCount correctos, $errorCount errores.", "Inicio", 0, $(if ($errorCount -eq 0) { 64 } else { 48 })) | Out-Null
    }

    $btnEnable.Add_Click({ & $ApplyChange -Action 'Enable' })
    $btnDisable.Add_Click({ & $ApplyChange -Action 'Disable' })
    $btnDelete.Add_Click({ & $ApplyChange -Action 'Delete' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}