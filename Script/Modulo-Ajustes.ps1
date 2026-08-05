# =================================================================
#  Modulo-Ajustes
#
#  CONTENIDO   : Show-TweakManagerMenu
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Write-AegisJsonAtomic          : escritura atomica de archivos JSON (snapshots/config)
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-Ajustes.ps1"
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

function Get-AegisTweakStableId {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][PSCustomObject]$Tweak)

    $text = "$($Tweak.Category)|$($Tweak.Name)"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) -replace '-', '').Substring(0, 16))
    } finally { $sha.Dispose() }
}

function Get-AegisRegistryValuesSnapshot {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object[]]$Values)

    return @($Values | ForEach-Object {
        $registryPath = [string]$_.Path
        $registryName = [string]$_.Name
        $pathExisted = Test-Path -LiteralPath $registryPath
        $valueExisted = $false
        $value = $null
        $valueKind = $null
        if ($pathExisted) {
            $registryKey = Get-Item -LiteralPath $registryPath -ErrorAction Stop
            $valueExisted = $registryKey.GetValueNames() -contains $registryName
            if ($valueExisted) {
                $value = $registryKey.GetValue($registryName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $valueKind = [string]$registryKey.GetValueKind($registryName)
            }
        }
        [ordered]@{ Path=$registryPath; Name=$registryName; PathExisted=$pathExisted; ValueExisted=$valueExisted; Value=$value; ValueKind=$valueKind }
    })
}

function Restore-AegisRegistryValuesSnapshot {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object[]]$Values)

    foreach ($snapshot in @($Values)) {
        $path = [string]$snapshot.Path
        $name = [string]$snapshot.Name
        if ([bool]$snapshot.ValueExisted) {
            if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force -ErrorAction Stop | Out-Null }
            $value = $snapshot.Value
            switch ([string]$snapshot.ValueKind) {
                'DWord'       { $value = [int]$value }
                'QWord'       { $value = [long]$value }
                'Binary'      { $value = [byte[]]@($value) }
                'MultiString' { $value = [string[]]@($value) }
                default       { $value = [string]$value }
            }
            Set-ItemProperty -LiteralPath $path -Name $name -Value $value -Type ([string]$snapshot.ValueKind) -Force -ErrorAction Stop
        } elseif (Test-Path -LiteralPath $path) {
            Remove-ItemProperty -LiteralPath $path -Name $name -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-AegisTweakBaseline {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][PSCustomObject]$Tweak)

    $backupDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Backup\Tweaks'
    if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction Stop | Out-Null }
    $stableId = Get-AegisTweakStableId -Tweak $Tweak
    $path = Join-Path $backupDir ("${stableId}_" + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.json')
    $snapshot = [ordered]@{
        SchemaVersion = 1
        StableId = $stableId
        Name = [string]$Tweak.Name
        Category = [string]$Tweak.Category
        Method = [string]$Tweak.Method
        CreatedAt = (Get-Date).ToString('o')
        Status = 'Available'
        State = Get-TweakState -Tweak $Tweak
        Registry = $null
        CommandData = $null
    }
    if ($Tweak.Method -eq 'Registry') {
        $pathExisted = Test-Path -LiteralPath $Tweak.RegistryPath
        $valueExisted = $false
        $value = $null
        $valueKind = $null
        if ($pathExisted) {
            $registryKey = Get-Item -LiteralPath $Tweak.RegistryPath -ErrorAction Stop
            $valueExisted = $registryKey.GetValueNames() -contains [string]$Tweak.RegistryKey
            if ($valueExisted) {
                $value = $registryKey.GetValue([string]$Tweak.RegistryKey, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $valueKind = [string]$registryKey.GetValueKind([string]$Tweak.RegistryKey)
            }
        }
        $snapshot.Registry = [ordered]@{
            Path = [string]$Tweak.RegistryPath
            Key = [string]$Tweak.RegistryKey
            PathExisted = $pathExisted
            ValueExisted = $valueExisted
            Value = $value
            ValueKind = $valueKind
        }
    } elseif ($Tweak.Method -eq 'Command' -and $Tweak.PSObject.Properties['SnapshotCommand'] -and $Tweak.SnapshotCommand -is [scriptblock]) {
        $snapshotCommand = $Tweak.SnapshotCommand
        $snapshot.CommandData = & $snapshotCommand
    }
    Write-AegisJsonAtomic -InputObject $snapshot -Path $path
    return [PSCustomObject]@{ Path=$path; Data=$snapshot }
}

function Get-AegisTweakBaseline {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][PSCustomObject]$Tweak)

    $backupDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Backup\Tweaks'
    if (-not (Test-Path -LiteralPath $backupDir)) { return $null }
    $stableId = Get-AegisTweakStableId -Tweak $Tweak
    foreach ($file in @(Get-ChildItem -LiteralPath $backupDir -Filter "${stableId}_*.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)) {
        try {
            $data = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ([int]$data.SchemaVersion -eq 1 -and $data.StableId -eq $stableId -and $data.Status -in @('Available','Failed')) {
                return [PSCustomObject]@{ Path=$file.FullName; Data=$data }
            }
        } catch { Write-Log -LogLevel WARN -Message "AJUSTES: Respaldo ilegible '$($file.FullName)': $($_.Exception.Message)" }
    }
    return $null
}

function Restore-AegisRegistryBaseline {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Baseline)

    $snapshot = $Baseline.Data.Registry
    if (-not $snapshot) { throw 'El respaldo no contiene estado de registro.' }
    if ([bool]$snapshot.ValueExisted) {
        if (-not (Test-Path -LiteralPath ([string]$snapshot.Path))) {
            New-Item -Path ([string]$snapshot.Path) -Force -ErrorAction Stop | Out-Null
        }
        $value = $snapshot.Value
        switch ([string]$snapshot.ValueKind) {
            'DWord'       { $value = [int]$value }
            'QWord'       { $value = [long]$value }
            'Binary'      { $value = [byte[]]@($value) }
            'MultiString' { $value = [string[]]@($value) }
            default       { $value = [string]$value }
        }
        Set-ItemProperty -LiteralPath ([string]$snapshot.Path) -Name ([string]$snapshot.Key) -Value $value -Type ([string]$snapshot.ValueKind) -Force -ErrorAction Stop
    } elseif (Test-Path -LiteralPath ([string]$snapshot.Path)) {
        Remove-ItemProperty -LiteralPath ([string]$snapshot.Path) -Name ([string]$snapshot.Key) -Force -ErrorAction SilentlyContinue
    }
}

function Complete-AegisTweakBaseline {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Baseline, [ValidateSet('Restored','Failed')][string]$Status)

    $Baseline.Data.Status = $Status
    $Baseline.Data.CompletedAt = (Get-Date).ToString('o')
    Write-AegisJsonAtomic -InputObject $Baseline.Data -Path $Baseline.Path
}

function Get-TweakState {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak
    )

    try {
        if ($Tweak.PSObject.Properties['MinimumBuild']) {
            $currentBuild = [Environment]::OSVersion.Version.Build
            if ($currentBuild -lt [int]$Tweak.MinimumBuild) { return 'NotApplicable' }
        }
        # --- Logica para ajustes basados en el Registro de Windows ---
        if ($Tweak.Method -eq 'Registry') {
            # Si la ruta base del registro no existe, el ajuste no puede estar habilitado.
            if (-not (Test-Path $Tweak.RegistryPath)) {
                return 'Disabled'
            }
            $currentValue = (Get-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -ErrorAction SilentlyContinue).($Tweak.RegistryKey)
            
            # Compara el valor actual con el valor que define el estado "Habilitado".
            # Se convierte a [string] para asegurar una comparacion consistente.
            if ([string]$currentValue -eq [string]$Tweak.EnabledValue) {
                return 'Enabled'
            } else {
                return 'Disabled'
            }
        }
        # --- Logica para ajustes basados en Comandos ---
        elseif ($Tweak.Method -eq 'Command') {
            # Si un ajuste de comando no tiene un CheckCommand, no podemos saber su estado.
            if (-not $Tweak.CheckCommand) {
                Write-Warning "El ajuste '$($Tweak.Name)' es de tipo Comando pero no tiene un 'CheckCommand'."
                return 'Unknown'
            }

            # Ejecuta el bloque de script de verificacion.
            $checkResult = & $Tweak.CheckCommand

            # Maneja el caso especial donde la verificacion no es aplicable en el sistema actual.
            if ($checkResult -is [string] -and $checkResult -eq 'NotApplicable') {
                return 'NotApplicable'
            }

            # La sintaxis anterior era el punto de fallo.
            if ($checkResult) {
                return 'Enabled'
            } else {
                return 'Disabled'
            }
        }
    } catch {
        # Captura cualquier error inesperado durante la verificacion.
        Write-Warning "Error al verificar el estado de '$($Tweak.Name)': $_"
        return 'Unknown'
    }

    return 'Unknown'
}

# --- FUNCIoN 2: El Ejecutor ---

function Set-TweakState {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Action
    )

    Write-Host " -> Aplicando '$Action' al ajuste '$($Tweak.Name)'..." -ForegroundColor Yellow
    Write-Log -LogLevel INFO -Message "Intentando aplicar '$Action' al ajuste '$($Tweak.Name)' en la categoria '$($Tweak.Category)'."
    $baseline = $null
    try {
        if ($Action -eq 'Enable') {
            $currentState = Get-TweakState -Tweak $Tweak
            if ($currentState -eq 'NotApplicable') { throw 'El ajuste no es aplicable en este equipo.' }
            if ($currentState -eq 'Unknown') { throw 'No se pudo determinar el estado inicial; no se aplicaran cambios a ciegas.' }
            if ($currentState -eq 'Enabled') {
                Write-Host '    [INFO] El ajuste ya estaba activado.' -ForegroundColor Gray
                return $true
            }
            $baseline = New-AegisTweakBaseline -Tweak $Tweak
            if ($Tweak.Method -eq 'Registry') {
                if (-not (Test-Path $Tweak.RegistryPath)) { New-Item -Path $Tweak.RegistryPath -Force | Out-Null }
                $registryType = if ($Tweak.PSObject.Properties['RegistryType']) { $Tweak.RegistryType } else { 'DWord' }
                Set-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Value $Tweak.EnabledValue -Type $registryType -Force -ErrorAction Stop
            }
            elseif ($Tweak.Method -eq 'Command') {
                if ($Tweak.EnableCommand -isnot [scriptblock]) { throw "No hay EnableCommand valido." }
                $global:LASTEXITCODE = 0
                & $Tweak.EnableCommand
                if ($LASTEXITCODE -ne 0) { throw "El comando nativo termino con codigo $LASTEXITCODE." }
            } else {
                throw "Metodo de ajuste no compatible: '$($Tweak.Method)'."
            }
        }
        else { # $Action -eq 'Disable'
            $baseline = Get-AegisTweakBaseline -Tweak $Tweak
            if ($Tweak.Method -eq 'Registry') {
                if ($baseline -and $baseline.Data.Registry) {
                    Restore-AegisRegistryBaseline -Baseline $baseline
                    Write-Host "    - Restaurado al valor real respaldado." -ForegroundColor Gray
                }
                elseif (Test-Path $Tweak.RegistryPath) {
                    Write-Warning "No existe respaldo previo; se usara el valor de compatibilidad del catalogo."
                    if ($null -ne $Tweak.PSObject.Properties['DefaultValue']) {
                        $registryType = if ($Tweak.PSObject.Properties['RegistryType']) { $Tweak.RegistryType } else { 'DWord' }
                        Set-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Value $Tweak.DefaultValue -Type $registryType -Force -ErrorAction Stop
                        Write-Host "    - Restaurado al valor por defecto." -ForegroundColor Gray
                    }
                    else {
                        Remove-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Force -ErrorAction SilentlyContinue
                        Write-Host "    - Propiedad de registro eliminada para restaurar el comportamiento por defecto." -ForegroundColor Gray
                    }
                }
            }
            elseif ($Tweak.Method -eq 'Command') {
                $global:LASTEXITCODE = 0
                if ($baseline -and $null -ne $baseline.Data.CommandData -and
                    $Tweak.PSObject.Properties['RestoreCommand'] -and $Tweak.RestoreCommand -is [scriptblock]) {
                    $restoreCommand = $Tweak.RestoreCommand
                    & $restoreCommand $baseline.Data.CommandData
                } else {
                    if ($Tweak.DisableCommand -isnot [scriptblock]) { throw "No hay DisableCommand valido." }
                    & $Tweak.DisableCommand
                }
                if ($LASTEXITCODE -ne 0) { throw "El comando nativo termino con codigo $LASTEXITCODE." }
            } else {
                throw "Metodo de ajuste no compatible: '$($Tweak.Method)'."
            }
        }

        $verifiedState = Get-TweakState -Tweak $Tweak
        if ($Action -eq 'Enable' -and $verifiedState -ne 'Enabled') {
            throw "La verificacion posterior devolvio '$verifiedState'."
        }
        $baselineExpectedEnabled = $baseline -and [string]$baseline.Data.State -eq 'Enabled'
        if ($Action -eq 'Disable' -and $Tweak.Method -eq 'Command' -and $verifiedState -eq 'Enabled' -and -not $baselineExpectedEnabled) {
            throw 'La verificacion posterior indica que el ajuste continua activado.'
        }
        if ($Action -eq 'Disable' -and $baseline) { Complete-AegisTweakBaseline -Baseline $baseline -Status 'Restored' }
        Write-Host "    [OK] Accion completada." -ForegroundColor Green
		Write-Log -LogLevel ACTION -Message "El ajuste '$($Tweak.Name)' se establecio a '$Action' exitosamente."
        return $true
    } catch {
        if ($Action -eq 'Disable' -and $baseline) {
            try { Complete-AegisTweakBaseline -Baseline $baseline -Status 'Failed' } catch {}
        }
        Write-Error "No se pudo modificar el ajuste '$($Tweak.Name)'. Error: $($_.Exception.Message)"
		Write-Log -LogLevel ERROR -Message "Fallo al modificar '$($Tweak.Name)'. Motivo: $($_.Exception.Message)"
        return $false
    }
}

function Show-TweakManagerMenu {
    # Validar Catalogo
    if ($null -eq $script:SystemTweaks) {
        try { . "$PSScriptRoot\Catalogos\Ajustes.ps1" } catch { 
            [System.Windows.Forms.MessageBox]::Show("Error cargando catalogo.", "Error", 0, 16); return 
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Ajustes"
    $form.Size = New-Object System.Drawing.Size(980, 720)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL DE FILTROS ---
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
    $cmbCategory.Items.Add("--- TODAS LAS CATEGORIAS ---") | Out-Null
    
    # Las entradas ocultas se conservan para compatibilidad, pero no se ofrecen
    # porque no tienen un beneficio universal o una restauracion segura.
    $visibleTweaks = @($script:SystemTweaks | Where-Object { -not ($_.PSObject.Properties['Hidden'] -and $_.Hidden) })
    $visibleTweaks | Select-Object -ExpandProperty Category -Unique | Sort-Object | ForEach-Object {
        $cmbCategory.Items.Add($_) | Out-Null 
    }
    $cmbCategory.SelectedIndex = 0
    $form.Controls.Add($cmbCategory)

    # -- OPTIMIZACIoN: CAJA DE BuSQUEDA --
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

    # --- 3. DATAGRIDVIEW OPTIMIZADO ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(920, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    # -- OPTIMIZACIoN: DOBLE BuFER PARA EVITAR PARPADEO --
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
    $colName.HeaderText = "Ajuste"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 350
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 100
    $grid.Columns.Add($colStatus) | Out-Null

    $colReboot = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colReboot.HeaderText = "Requiere"
    $colReboot.Name = "Reboot"
    $colReboot.ReadOnly = $true
    $colReboot.Width = 120
    $grid.Columns.Add($colReboot) | Out-Null

    $colCat = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCat.HeaderText = "Categoria"
    $colCat.Name = "Category"
    $colCat.ReadOnly = $true
    $colCat.Width = 150
    $grid.Columns.Add($colCat) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DESCRIPCION ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Detalles"
    $grpDesc.ForeColor = [System.Drawing.Color]::LightGray
    $grpDesc.Location = New-Object System.Drawing.Point(20, 490)
    $grpDesc.Size = New-Object System.Drawing.Size(920, 80)
    $form.Controls.Add($grpDesc)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "Selecciona un ajuste..."
    $lblDesc.Location = New-Object System.Drawing.Point(10, 20)
    $lblDesc.Size = New-Object System.Drawing.Size(900, 50)
    $lblDesc.ForeColor = [System.Drawing.Color]::White
    $grpDesc.Controls.Add($lblDesc)

    # --- 5. BOTONES ---
    $btnEnable = New-Object System.Windows.Forms.Button
    $btnEnable.Text = "ACTIVAR / OPTIMIZAR"
    $btnEnable.Location = New-Object System.Drawing.Point(680, 590)
    $btnEnable.Size = New-Object System.Drawing.Size(260, 40)
    $btnEnable.BackColor = [System.Drawing.Color]::SeaGreen
    $btnEnable.ForeColor = [System.Drawing.Color]::White
    $btnEnable.FlatStyle = "Flat"
    $btnEnable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnEnable)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "RESTAURAR RESPALDO"
    $btnRestore.Location = New-Object System.Drawing.Point(400, 590)
    $btnRestore.Size = New-Object System.Drawing.Size(260, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $form.Controls.Add($btnRestore)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 595)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Location = New-Object System.Drawing.Point(20, 640)
    $lblInfo.AutoSize = $true
    $lblInfo.ForeColor = [System.Drawing.Color]::Orange
    $form.Controls.Add($lblInfo)

    # --- VARIABLES Y CACHE ---
    $tweakCache = @{}

    # --- LOGICA DE CARGA (OPTIMIZADA) ---
    $LoadGrid = {
        # 1. OPTIMIZACIoN DE RENDIMIENTO: SuspendLayout evita repintado por cada fila
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $tweakCache.Clear()
        
        # Filtro de Categoria
        $cat = $cmbCategory.SelectedItem
        $items = if ($cat -eq "--- TODAS LAS CATEGORIAS ---") { $visibleTweaks }
                 else { $visibleTweaks | Where-Object { $_.Category -eq $cat } }

        # Filtro de Busqueda (Texto)
        $searchText = $txtSearch.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            $items = $items | Where-Object {
                $_.Name.IndexOf($searchText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
        }

        foreach ($tweak in $items) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            # Guardamos referencia en Cache (acceso O(1))
            $tweakCache[$tweak.Name] = $tweak

            $row.Cells["Name"].Value = $tweak.Name
            $row.Cells["Category"].Value = $tweak.Category
            
            $rebootTxt = switch($tweak.RestartNeeded) {
                "Reboot"   { "Reiniciar PC" }
                "Explorer" { "Reiniciar Explorer" }
                "Session"  { "Cerrar Sesion" }
                default    { "-" }
            }
            $row.Cells["Reboot"].Value = $rebootTxt

            # Obtener Estado
            $state = Get-TweakState -Tweak $tweak
            
            if ($state -eq 'Enabled') {
                $row.Cells["Status"].Value = "Activado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                $row.Cells["Name"].Style.Font = New-Object System.Drawing.Font($grid.Font, [System.Drawing.FontStyle]::Bold)
            } 
            elseif ($state -eq 'Disabled') {
                $row.Cells["Status"].Value = "Desactivado"
                # Estilo solicitado: Rojo suave solo en el texto de estado
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
            }
            else {
                $row.Cells["Status"].Value = if ($state -eq 'NotApplicable') { "N/A" } else { "Desconocido" }
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Silver
            }
        }
        
        # 2. Restaurar pintado (Renderiza todo de golpe)
        $grid.ResumeLayout()
        $grid.ClearSelection()
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $LoadGrid })
    $btnRefresh.Add_Click({ & $LoadGrid })
    $cmbCategory.Add_SelectedIndexChanged({ & $LoadGrid })
    
    # Evento de busqueda en tiempo real (mientras escribes)
    $txtSearch.Add_KeyUp({ & $LoadGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            # 1. Obtener nombre del ajuste seleccionado
            $val = $grid.SelectedRows[0].Cells["Name"].Value
            $name = if ($val) { $val.ToString() } else { "" }
            
            # 2. Buscar en la caché y actualizar la etiqueta directamente
            if (-not [string]::IsNullOrEmpty($name) -and $tweakCache.ContainsKey($name)) {
                $selectedTweak = $tweakCache[$name]
                $desc = $selectedTweak.Description
                $risk = if ($selectedTweak.PSObject.Properties['RiskLevel']) { [string]$selectedTweak.RiskLevel } else { 'Normal' }
                
                # Asignacion directa en lugar de Invoke
                # Si la descripcion esta vacia, mostramos un mensaje por defecto
                if (-not [string]::IsNullOrWhiteSpace($desc)) {
                    $lblDesc.Text = "Riesgo: $risk | $desc"
                } else {
                    $lblDesc.Text = "Sin descripcion disponible para este ajuste."
                }
            }
        }
    })

    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Logica de Aplicacion
    $Apply = {
        param($Mode) # 'Enable' o 'Disable'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $tweakCache[$row.Cells["Name"].Value]
            }
        }

        if ($targets.Count -eq 0) { return }

        $actionTxt = if ($Mode -eq 'Enable') { "ACTIVAR" } else { "RESTAURAR" }
        if ([System.Windows.Forms.MessageBox]::Show("$actionTxt $($targets.Count) ajustes?", "Confirmar", 4, 32) -ne 'Yes') { return }

        $highRiskTargets = @($targets | Where-Object { $_.PSObject.Properties['RiskLevel'] -and $_.RiskLevel -eq 'High' })
        if ($highRiskTargets.Count -gt 0) {
            Add-Type -AssemblyName Microsoft.VisualBasic
            $names = ($highRiskTargets | Select-Object -ExpandProperty Name) -join "`n - "
            $typed = [Microsoft.VisualBasic.Interaction]::InputBox(
                "Los siguientes ajustes tienen riesgo alto:`n - $names`n`nEscribe APLICAR para continuar.",
                'Confirmacion reforzada', ''
            )
            if ($typed -cne 'APLICAR') { return }
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $needRestart = $false
        $needExplorer = $false
        $successCount = 0
        $errorCount = 0
        $journal = New-AegisOperationJournal -Module 'Ajustes' -Action $Mode -Targets @($targets | ForEach-Object {
            $risk = if ($_.PSObject.Properties['RiskLevel']) { $_.RiskLevel } else { 'Normal' }
            [ordered]@{ Name=$_.Name; Category=$_.Category; InitialState=(Get-TweakState -Tweak $_); Risk=$risk }
        })
        $journalResults = [System.Collections.Generic.List[object]]::new()

        try {
            foreach ($t in $targets) {
                if (Set-TweakState -Tweak $t -Action $Mode) {
                    $successCount++
                    $journalResults.Add([ordered]@{ Name=$t.Name; Status='Completed'; FinalState=(Get-TweakState -Tweak $t) })
                    if ($t.RestartNeeded -eq 'Reboot') { $needRestart = $true }
                    if ($t.RestartNeeded -eq 'Explorer') { $needExplorer = $true }
                } else {
                    $errorCount++
                    $journalResults.Add([ordered]@{ Name=$t.Name; Status='Failed'; FinalState=(Get-TweakState -Tweak $t) })
                }
            }
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        $journalStatus = if ($errorCount -eq 0) { 'Completed' } elseif ($successCount -gt 0) { 'Partial' } else { 'Failed' }
        [void](Complete-AegisOperationJournal -Journal $journal -Status $journalStatus -Results @($journalResults))

        & $LoadGrid
        [System.Windows.Forms.MessageBox]::Show("Resultado: $successCount correctos, $errorCount errores.", "Ajustes", 0, $(if ($errorCount -eq 0) { 64 } else { 48 })) | Out-Null

        if ($needExplorer -and -not $needRestart) {
            if ([System.Windows.Forms.MessageBox]::Show("Se requiere reiniciar el Explorador. Hacerlo ahora?", "Aviso", 4, 32) -eq 'Yes') {

                $grid.ShowCellToolTips = $false
                [System.Windows.Forms.Application]::DoEvents() 

                try {
                    Invoke-ExplorerRestart
            } finally {
                    $grid.ShowCellToolTips = $true
                }
            }
        }
        if ($needRestart) {
            [System.Windows.Forms.MessageBox]::Show("Algunos cambios requieren reiniciar el PC para surtir efecto.", "Reinicio Requerido", 0, 48)
        }
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
	
    $btnEnable.Add_Click({ & $Apply -Mode 'Enable' })
    $btnRestore.Add_Click({ & $Apply -Mode 'Disable' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}