# =================================================================
#  Modulo-ReubicacionPerfil
#
#  CONTENIDO   : Show-UserProfileRelocationDialog
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Invoke-AegisNativeProcess      : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-ReubicacionPerfil.ps1"
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

function Remove-AegisVerifiedRelocationSources {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [ValidateSet('Fast','Deep')][string]$VerificationType = 'Fast'
    )

    $sourceRoot = (Get-Item -LiteralPath $SourcePath -ErrorAction Stop).FullName.TrimEnd('\')
    $destinationRoot = (Get-Item -LiteralPath $DestinationPath -ErrorAction Stop).FullName.TrimEnd('\')
    $validated = [System.Collections.Generic.List[object]]::new()
    foreach ($sourceFile in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force -File -ErrorAction Stop)) {
        $relativePath = $sourceFile.FullName.Substring($sourceRoot.Length).TrimStart('\')
        $targetPath = Join-Path $destinationRoot $relativePath
        $targetFile = Get-Item -LiteralPath $targetPath -ErrorAction Stop
        if ($targetFile.Length -ne $sourceFile.Length) { throw "Tamano distinto en '$relativePath'." }
        if ($VerificationType -eq 'Deep') {
            $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
            $targetHash = (Get-FileHash -LiteralPath $targetFile.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($sourceHash -ne $targetHash) { throw "Hash distinto en '$relativePath'." }
        } elseif ($sourceFile.LastWriteTimeUtc -ne $targetFile.LastWriteTimeUtc) {
            throw "Fecha de modificacion distinta en '$relativePath'."
        }
        $validated.Add([PSCustomObject]@{ Source=$sourceFile.FullName; Destination=$targetFile.FullName })
    }

    foreach ($entry in $validated) {
        if ($PSCmdlet.ShouldProcess($entry.Source, 'Eliminar archivo de origen verificado')) {
            Remove-Item -LiteralPath $entry.Source -Force -ErrorAction Stop
        }
    }
    foreach ($directory in @(Get-ChildItem -LiteralPath $sourceRoot -Directory -Force -Recurse -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending)) {
        if (-not (Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            Remove-Item -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    return $validated.ToArray()
}

# ===================================================================
# --- MoDULO DE REUBICACIoN DE CARPETAS DE USUARIO ---
# ===================================================================

function Get-AegisUserFolderRelocationInfo {
    [CmdletBinding()]
    param()

    $registryPath = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $definitions = @(
        [PSCustomObject]@{ Name='Escritorio'; RegValue='Desktop'; DefaultName='Desktop' }
        [PSCustomObject]@{ Name='Documentos'; RegValue='Personal'; DefaultName='Documents' }
        [PSCustomObject]@{ Name='Descargas'; RegValue='{374DE290-123F-4565-9164-39C4925E467B}'; DefaultName='Downloads' }
        [PSCustomObject]@{ Name='Imagenes'; RegValue='My Pictures'; DefaultName='Pictures' }
        [PSCustomObject]@{ Name='Musica'; RegValue='My Music'; DefaultName='Music' }
        [PSCustomObject]@{ Name='Videos'; RegValue='My Video'; DefaultName='Videos' }
    )

    foreach ($definition in $definitions) {
        $currentPath = $null
        try {
            $property = Get-ItemProperty -Path $registryPath -Name $definition.RegValue -ErrorAction Stop
            $rawPath = [string]$property.($definition.RegValue)
            if (-not [string]::IsNullOrWhiteSpace($rawPath)) {
                $currentPath = [Environment]::ExpandEnvironmentVariables($rawPath)
            }
        } catch {
            Write-Verbose "No se pudo leer la carpeta conocida '$($definition.Name)': $($_.Exception.Message)"
        }

        [PSCustomObject]@{
            Name = $definition.Name
            RegValue = $definition.RegValue
            DefaultName = $definition.DefaultName
            CurrentPath = $currentPath
            Exists = -not [string]::IsNullOrWhiteSpace($currentPath) -and (Test-Path -LiteralPath $currentPath -PathType Container)
            IsLocked = -not [string]::IsNullOrWhiteSpace($currentPath) -and $currentPath -match '\\OneDrive(?:\s*-\s*[^\\]+)?(?:\\|$)'
        }
    }
}

function Show-UserProfileRelocationDialog {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $colorWindow = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $colorPanel = [System.Drawing.Color]::FromArgb(42, 42, 45)
    $colorControl = [System.Drawing.Color]::FromArgb(55, 55, 58)
    $colorText = [System.Drawing.Color]::White

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Aegis Phoenix - Reubicar carpetas de usuario'
    $form.Size = New-Object System.Drawing.Size(1000, 720)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.BackColor = $colorWindow
    $form.ForeColor = $colorText
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'REUBICAR CARPETAS CONOCIDAS DE WINDOWS'
    $lblTitle.Location = New-Object System.Drawing.Point(20, 14)
    $lblTitle.AutoSize = $true
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::Cyan
    $form.Controls.Add($lblTitle)

    $lblWarning = New-Object System.Windows.Forms.Label
    $lblWarning.Text = 'Esta operacion puede mover los datos y actualizar las rutas del Registro. Las carpetas administradas por OneDrive se bloquean por seguridad.'
    $lblWarning.Location = New-Object System.Drawing.Point(23, 49)
    $lblWarning.Size = New-Object System.Drawing.Size(940, 38)
    $lblWarning.ForeColor = [System.Drawing.Color]::Khaki
    $form.Controls.Add($lblWarning)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 92)
    $grid.Size = New-Object System.Drawing.Size(940, 250)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(35, 35, 38)
    $grid.BorderStyle = 'None'
    $grid.GridColor = [System.Drawing.Color]::FromArgb(70, 70, 72)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.EditMode = 'EditOnEnter'
    $grid.AutoSizeColumnsMode = 'Fill'

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
    $colName.HeaderText = 'Carpeta'
    $colName.Width = 110
    $colName.ReadOnly = $true
    $grid.Columns.Add($colName) | Out-Null

    $colCurrent = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCurrent.Name = 'CurrentPath'
    $colCurrent.HeaderText = 'Ruta actual'
    $colCurrent.Width = 330
    $colCurrent.ReadOnly = $true
    $grid.Columns.Add($colCurrent) | Out-Null

    $colTarget = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colTarget.Name = 'TargetPath'
    $colTarget.HeaderText = 'Nueva ruta'
    $colTarget.Width = 330
    $colTarget.ReadOnly = $true
    $grid.Columns.Add($colTarget) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.Name = 'Status'
    $colStatus.HeaderText = 'Estado'
    $colStatus.Width = 130
    $colStatus.ReadOnly = $true
    $grid.Columns.Add($colStatus) | Out-Null
    $form.Controls.Add($grid)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = 'Seleccionar libres'
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 352)
    $btnSelectAll.Size = New-Object System.Drawing.Size(145, 32)
    $btnSelectAll.BackColor = $colorControl
    $btnSelectAll.ForeColor = $colorText
    $btnSelectAll.FlatStyle = 'Flat'
    $form.Controls.Add($btnSelectAll)

    $btnSelectNone = New-Object System.Windows.Forms.Button
    $btnSelectNone.Text = 'Desmarcar todas'
    $btnSelectNone.Location = New-Object System.Drawing.Point(175, 352)
    $btnSelectNone.Size = New-Object System.Drawing.Size(140, 32)
    $btnSelectNone.BackColor = $colorControl
    $btnSelectNone.ForeColor = $colorText
    $btnSelectNone.FlatStyle = 'Flat'
    $form.Controls.Add($btnSelectNone)

    $grpAction = New-Object System.Windows.Forms.GroupBox
    $grpAction.Text = 'Accion'
    $grpAction.Location = New-Object System.Drawing.Point(330, 348)
    $grpAction.Size = New-Object System.Drawing.Size(300, 105)
    $grpAction.ForeColor = [System.Drawing.Color]::LightGray
    $grpAction.BackColor = $colorPanel
    $form.Controls.Add($grpAction)

    $rbMoveAndRegister = New-Object System.Windows.Forms.RadioButton
    $rbMoveAndRegister.Text = 'Mover datos y actualizar Registro'
    $rbMoveAndRegister.Location = New-Object System.Drawing.Point(15, 27)
    $rbMoveAndRegister.AutoSize = $true
    $rbMoveAndRegister.Checked = $true
    $rbMoveAndRegister.ForeColor = [System.Drawing.Color]::LightGreen
    $grpAction.Controls.Add($rbMoveAndRegister)

    $rbRegisterOnly = New-Object System.Windows.Forms.RadioButton
    $rbRegisterOnly.Text = 'Solo actualizar Registro (datos ya movidos)'
    $rbRegisterOnly.Location = New-Object System.Drawing.Point(15, 61)
    $rbRegisterOnly.AutoSize = $true
    $rbRegisterOnly.ForeColor = [System.Drawing.Color]::Khaki
    $grpAction.Controls.Add($rbRegisterOnly)

    $grpVerify = New-Object System.Windows.Forms.GroupBox
    $grpVerify.Text = 'Verificacion del movimiento'
    $grpVerify.Location = New-Object System.Drawing.Point(645, 348)
    $grpVerify.Size = New-Object System.Drawing.Size(335, 105)
    $grpVerify.ForeColor = [System.Drawing.Color]::LightGray
    $grpVerify.BackColor = $colorPanel
    $form.Controls.Add($grpVerify)

    $rbSimulation = New-Object System.Windows.Forms.RadioButton
    $rbSimulation.Text = 'Simular primero'
    $rbSimulation.Location = New-Object System.Drawing.Point(15, 27)
    $rbSimulation.AutoSize = $true
    $grpVerify.Controls.Add($rbSimulation)

    $rbFast = New-Object System.Windows.Forms.RadioButton
    $rbFast.Text = 'Rapida'
    $rbFast.Location = New-Object System.Drawing.Point(130, 27)
    $rbFast.AutoSize = $true
    $rbFast.Checked = $true
    $grpVerify.Controls.Add($rbFast)

    $rbDeep = New-Object System.Windows.Forms.RadioButton
    $rbDeep.Text = 'SHA-256 profunda'
    $rbDeep.Location = New-Object System.Drawing.Point(200, 27)
    $rbDeep.AutoSize = $true
    $rbDeep.ForeColor = [System.Drawing.Color]::Khaki
    $grpVerify.Controls.Add($rbDeep)

    $lblVerify = New-Object System.Windows.Forms.Label
    $lblVerify.Text = 'El origen se elimina solamente despues de verificar cada archivo.'
    $lblVerify.Location = New-Object System.Drawing.Point(15, 61)
    $lblVerify.Size = New-Object System.Drawing.Size(305, 34)
    $lblVerify.ForeColor = [System.Drawing.Color]::Silver
    $grpVerify.Controls.Add($lblVerify)

    $grpDestination = New-Object System.Windows.Forms.GroupBox
    $grpDestination.Text = 'Nueva ubicacion base'
    $grpDestination.Location = New-Object System.Drawing.Point(20, 466)
    $grpDestination.Size = New-Object System.Drawing.Size(940, 82)
    $grpDestination.ForeColor = [System.Drawing.Color]::LightGray
    $grpDestination.BackColor = $colorPanel
    $form.Controls.Add($grpDestination)

    $txtDestination = New-Object System.Windows.Forms.TextBox
    $txtDestination.Location = New-Object System.Drawing.Point(15, 31)
    $txtDestination.Size = New-Object System.Drawing.Size(760, 25)
    $txtDestination.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 38)
    $txtDestination.ForeColor = $colorText
    $txtDestination.BorderStyle = 'FixedSingle'
    $grpDestination.Controls.Add($txtDestination)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = 'Examinar...'
    $btnBrowse.Location = New-Object System.Drawing.Point(790, 27)
    $btnBrowse.Size = New-Object System.Drawing.Size(130, 32)
    $btnBrowse.BackColor = $colorControl
    $btnBrowse.ForeColor = $colorText
    $btnBrowse.FlatStyle = 'Flat'
    $grpDestination.Controls.Add($btnBrowse)

    $lblSummary = New-Object System.Windows.Forms.Label
    $lblSummary.Location = New-Object System.Drawing.Point(20, 562)
    $lblSummary.Size = New-Object System.Drawing.Size(670, 72)
    $lblSummary.ForeColor = [System.Drawing.Color]::DarkGray 
    $form.Controls.Add($lblSummary)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'CANCELAR'
    $btnCancel.Location = New-Object System.Drawing.Point(700, 596)
    $btnCancel.Size = New-Object System.Drawing.Size(120, 38)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(75, 55, 55)
    $btnCancel.ForeColor = $colorText
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel)

    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Text = 'INICIAR REUBICACION'
    $btnStart.Location = New-Object System.Drawing.Point(830, 596)
    $btnStart.Size = New-Object System.Drawing.Size(130, 38)
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 125, 90)
    $btnStart.ForeColor = $colorText
    $btnStart.FlatStyle = 'Flat'
    $btnStart.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnStart)
    $form.AcceptButton = $btnStart
    $form.CancelButton = $btnCancel

    $folderInfo = @(Get-AegisUserFolderRelocationInfo)
    foreach ($folder in $folderInfo) {
        $status = if ($folder.IsLocked) { 'OneDrive' } elseif ($folder.Exists) { 'Disponible' } else { 'Origen ausente' }
        $rowIndex = $grid.Rows.Add($false, $folder.Name, $folder.CurrentPath, '', $status)
        $row = $grid.Rows[$rowIndex]
        $row.Tag = $folder
        if ($folder.IsLocked) {
            $row.Cells['Selected'].ReadOnly = $true
            $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Salmon
        } elseif (-not $folder.Exists) {
            $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Khaki
        }
    }

    $getSelectedRows = {
        $selected = [System.Collections.Generic.List[object]]::new()
        foreach ($row in $grid.Rows) {
            $isSelected = $false
            try { $isSelected = [Convert]::ToBoolean($row.Cells['Selected'].Value) } catch { }
            if ($isSelected) { $selected.Add($row) }
        }
        return $selected.ToArray()
    }

    $updateTargets = {
        $basePath = $txtDestination.Text.Trim()
        foreach ($row in $grid.Rows) {
            $folder = $row.Tag
            $row.Cells['TargetPath'].Value = if ([string]::IsNullOrWhiteSpace($basePath)) { '' } else { Join-Path $basePath $folder.DefaultName }
            $row.Cells['Selected'].ReadOnly = $folder.IsLocked -or (-not $folder.Exists -and $rbMoveAndRegister.Checked)
            if ($row.Cells['Selected'].ReadOnly -and -not $rbRegisterOnly.Checked) {
                $row.Cells['Selected'].Value = $false
            }
        }

        $verificationEnabled = $rbMoveAndRegister.Checked
        foreach ($control in @($rbFast, $rbSimulation, $rbDeep)) { $control.Enabled = $verificationEnabled }
        $lblVerify.ForeColor = if ($verificationEnabled) { [System.Drawing.Color]::Silver } else { [System.Drawing.Color]::Gray }

        $selectedCount = @(& $getSelectedRows).Count
        $actionText = if ($rbRegisterOnly.Checked) { 'Solo Registro' } else { 'Mover y registrar' }
        $verificationText = if (-not $verificationEnabled) { 'No aplica' } elseif ($rbDeep.Checked) { 'SHA-256' } elseif ($rbSimulation.Checked) { 'Simulacion + rapida' } else { 'Rapida' }
        
        $lblSummary.Text = "Seleccionadas: $selectedCount carpeta(s)`r`nAccion: $actionText | Verificacion: $verificationText`r`nLa salida detallada de Robocopy se mostrara en la consola."
    }

    $btnSelectAll.Add_Click({
        foreach ($row in $grid.Rows) {
            if (-not $row.Cells['Selected'].ReadOnly) { $row.Cells['Selected'].Value = $true }
        }
        & $updateTargets
    })
    $btnSelectNone.Add_Click({
        foreach ($row in $grid.Rows) { $row.Cells['Selected'].Value = $false }
        & $updateTargets
    })
    $btnBrowse.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Selecciona la carpeta base para las nuevas rutas de usuario'
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) { $txtDestination.Text = $dialog.SelectedPath }
    })
    $txtDestination.Add_TextChanged({ & $updateTargets })
    $rbMoveAndRegister.Add_CheckedChanged({ & $updateTargets })
    $rbRegisterOnly.Add_CheckedChanged({ & $updateTargets })
    foreach ($radio in @($rbFast, $rbSimulation, $rbDeep)) { $radio.Add_CheckedChanged({ & $updateTargets }) }
    $grid.Add_CurrentCellDirtyStateChanged({
        if ($grid.IsCurrentCellDirty) { $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
    })
    $grid.Add_CellValueChanged({ & $updateTargets })

    $btnStart.Add_Click({
        $grid.EndEdit()
        $selectedRows = @(& $getSelectedRows)
        if ($selectedRows.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Selecciona al menos una carpeta.', 'Seleccion requerida', 0, 48) | Out-Null
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtDestination.Text) -or -not (Test-Path -LiteralPath $txtDestination.Text -PathType Container)) {
            [System.Windows.Forms.MessageBox]::Show('Selecciona una carpeta base de destino existente.', 'Destino requerido', 0, 48) | Out-Null
            return
        }

        $destinationFull = (Get-Item -LiteralPath $txtDestination.Text -ErrorAction Stop).FullName.TrimEnd('\')
        $profileFull = (Get-Item -LiteralPath $env:USERPROFILE -ErrorAction Stop).FullName.TrimEnd('\')
        if ($destinationFull.Equals($profileFull, [StringComparison]::OrdinalIgnoreCase) -or $destinationFull.StartsWith($profileFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
            [System.Windows.Forms.MessageBox]::Show('La nueva ubicacion base no puede estar dentro del perfil actual.', 'Destino no valido', 0, 16) | Out-Null
            return
        }

        $actionType = if ($rbRegisterOnly.Checked) { 'RegisterOnly' } else { 'MoveAndRegister' }
        $verificationMode = if ($rbDeep.Checked) { 'Deep' } elseif ($rbSimulation.Checked) { 'Simulation' } else { 'Fast' }
        $selectedNames = @($selectedRows | ForEach-Object { $_.Tag.Name })

        foreach ($row in $selectedRows) {
            $folder = $row.Tag
            $targetPath = Join-Path $destinationFull $folder.DefaultName
            if ($actionType -eq 'MoveAndRegister' -and -not $folder.Exists) {
                [System.Windows.Forms.MessageBox]::Show("La carpeta de origen '$($folder.Name)' no existe. Usa Solo Registro únicamente si sus datos ya están en el destino.", 'Origen no disponible', 0, 16) | Out-Null
                return
            }
            if ($actionType -eq 'RegisterOnly' -and -not (Test-Path -LiteralPath $targetPath -PathType Container)) {
                [System.Windows.Forms.MessageBox]::Show("Para Solo Registro debe existir previamente:`n$targetPath", 'Destino incompleto', 0, 16) | Out-Null
                return
            }
            if ($actionType -eq 'MoveAndRegister' -and (Test-Path -LiteralPath $targetPath -PathType Container)) {
                $existingItem = Get-ChildItem -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($existingItem) {
                    [System.Windows.Forms.MessageBox]::Show("El destino de '$($folder.Name)' ya contiene datos:`n$targetPath`n`nUsa una ubicacion vacia para conservar un rollback seguro.", 'Destino no vacio', 0, 16) | Out-Null
                    return
                }
            }
        }

        $confirmationText = if ($actionType -eq 'RegisterOnly') {
            "Se actualizaran las rutas del Registro para $($selectedNames.Count) carpeta(s). No se copiaran archivos.`n`n¿Continuar?"
        } else {
            "Se copiaran y verificaran los datos de $($selectedNames.Count) carpeta(s), se retirara el origen verificado y se actualizaran las rutas del Registro.`n`nEl Explorador de Windows se reiniciara. ¿Continuar?"
        }
        $confirmation = [System.Windows.Forms.MessageBox]::Show($confirmationText, 'Confirmar reubicacion', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        $form.Tag = [PSCustomObject]@{
            Destination = $destinationFull
            SelectedNames = $selectedNames
            ActionType = $actionType
            VerificationMode = $verificationMode
        }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    & $updateTargets
    $dialogResult = $form.ShowDialog()
    $configuration = $form.Tag
    $form.Dispose()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $configuration) { return }

    Clear-Host
    Write-Host 'La configuracion grafica fue validada. La salida de reubicacion se mostrara en esta consola.' -ForegroundColor Cyan
    try {
        $result = Move-UserProfileFolders -NewBasePath $configuration.Destination -SelectedFolderNames $configuration.SelectedNames `
            -ActionType $configuration.ActionType -VerificationMode $configuration.VerificationMode `
            -SkipConfirmation -NoPause -Confirm:$false
        if (-not $result) { return }

        $message = "$($result.Message)`n`nDestino base: $($result.Destination)`nCompletadas: $($result.CompletedCount) de $($result.SelectedCount)"
        switch ($result.Status) {
            'Completed' { [System.Windows.Forms.MessageBox]::Show($message, 'Reubicacion completada', 0, 64) | Out-Null }
            'Simulated' { [System.Windows.Forms.MessageBox]::Show($result.Message, 'Simulacion completada', 0, 64) | Out-Null }
            'Partial' { [System.Windows.Forms.MessageBox]::Show($message, 'Reubicacion parcial', 0, 48) | Out-Null }
            default { [System.Windows.Forms.MessageBox]::Show($message, 'Error de reubicacion', 0, 16) | Out-Null }
        }
    } catch {
        Write-Log -LogLevel ERROR -Message "REUBICACION GUI: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("No se pudo completar la reubicacion:`n`n$($_.Exception.Message)", 'Error de reubicacion', 0, 16) | Out-Null
    }
}

function Move-UserProfileFolders {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [string]$NewBasePath,

        [string[]]$SelectedFolderNames,

        [ValidateSet('Prompt', 'MoveAndRegister', 'RegisterOnly')]
        [string]$ActionType = 'Prompt',

        [ValidateSet('Prompt', 'Fast', 'Simulation', 'Deep')]
        [string]$VerificationMode = 'Prompt',

        [switch]$SkipConfirmation,

        [switch]$NoPause
    )

    Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Reubicacion de Carpetas de Usuario."

    # --- UTILIDAD PARA MANTENER LA CONSOLA VISIBLE ---
    if (-not ([System.Management.Automation.PSTypeName]'Win32ConsoleUtils').Type) {
        try {
            Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32ConsoleUtils {
                [DllImport("kernel32.dll")]
                public static extern IntPtr GetConsoleWindow();
                
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                
                [DllImport("user32.dll")]
                public static extern bool SetForegroundWindow(IntPtr hWnd);

                [DllImport("user32.dll", SetLastError = true)]
                public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

                public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
                public const uint SWP_NOSIZE = 0x0001;
                public const uint SWP_NOMOVE = 0x0002;
                public const uint SWP_SHOWWINDOW = 0x0040;
                public const int SW_RESTORE = 9;
            }
"@ -ErrorAction Stop
        } catch {
            Write-Log -LogLevel WARN -Message "REUBICACION: No se pudo compilar Win32ConsoleUtils: $($_.Exception.Message)"
        }
    }

    $folderMappings = @{
        'Escritorio' = @{ RegValue = 'Desktop'; DefaultName = 'Desktop' }
        'Documentos' = @{ RegValue = 'Personal'; DefaultName = 'Documents' }
        'Descargas'  = @{ RegValue = '{374DE290-123F-4565-9164-39C4925E467B}'; DefaultName = 'Downloads' }
        'Musica'     = @{ RegValue = 'My Music'; DefaultName = 'Music' }
        'Imagenes'   = @{ RegValue = 'My Pictures'; DefaultName = 'Pictures' }
        'Videos'     = @{ RegValue = 'My Video'; DefaultName = 'Videos' }
    }
    $registryPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

    if ([string]::IsNullOrWhiteSpace($NewBasePath)) {
        Write-Host "`n[+] Paso 1: Selecciona la carpeta RAIZ donde se crearan las nuevas carpetas de usuario." -ForegroundColor Yellow
        Write-Host "    (Ejemplo: Si seleccionas 'D:\MisDatos', se crearan 'D:\MisDatos\Escritorio', etc.)" -ForegroundColor Gray
        $NewBasePath = Select-PathDialog -DialogType Folder -Title "Selecciona la NUEVA UBICACION BASE para tus carpetas"
    }
    
    if ([string]::IsNullOrWhiteSpace($NewBasePath)) {
        Write-Warning "Operacion cancelada. No se selecciono una ruta de destino."
        if (-not $NoPause) { Start-Sleep -Seconds 2 }
        return $null
    }

    $newBasePath = (Get-Item -LiteralPath $NewBasePath -ErrorAction Stop).FullName
    
    $currentUserProfilePath = (Get-Item -LiteralPath $env:USERPROFILE -ErrorAction Stop).FullName.TrimEnd('\')
    $newBaseFullPath = (Get-Item -LiteralPath $newBasePath -ErrorAction Stop).FullName.TrimEnd('\')
    if ($newBaseFullPath.Equals($currentUserProfilePath, [System.StringComparison]::OrdinalIgnoreCase) -or
        $newBaseFullPath.StartsWith($currentUserProfilePath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
         throw "La nueva ubicacion base no puede estar dentro de tu perfil de usuario actual ('$currentUserProfilePath')."
    }

    # --- NUEVO: ANALISIS INTELIGENTE DE RUTAS Y ONEDRIVE ---
    $selectableFolders = $folderMappings.Keys | Sort-Object
    $folderItems = @()
    $hasOneDriveLocks = $false

    foreach ($folderName in $selectableFolders) {
        $regName = $folderMappings[$folderName].RegValue
        $currentPathRaw = (Get-ItemProperty -Path $registryPath -Name $regName -ErrorAction SilentlyContinue).($regName)
        $currentPathExpanded = try { [Environment]::ExpandEnvironmentVariables($currentPathRaw) } catch { $currentPathRaw }
        
        # Deteccion de seguridad: Comprobar si OneDrive controla la carpeta
        $isOneDriveLocked = [bool]($currentPathExpanded -match "\\OneDrive")
        if ($isOneDriveLocked) { $hasOneDriveLocks = $true }

        $folderItems += [PSCustomObject]@{
            Name     = $folderName
            Selected = [bool]($SelectedFolderNames -and $folderName -in $SelectedFolderNames)
            Path     = $currentPathExpanded
            IsLocked = $isOneDriveLocked
        }
    }

    # --- MENU DE SELECCION (respaldo para invocaciones sin GUI) ---
    if (-not $SelectedFolderNames) {
        $choice = ''
        while ($choice.ToUpper() -ne 'C' -and $choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "      Selecciona las Carpetas de Usuario a Reubicar    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Nueva Ubicacion Base: $newBasePath" -ForegroundColor Yellow
        Write-Host ""
        
        for ($i = 0; $i -lt $folderItems.Count; $i++) {
            $item = $folderItems[$i]
            
            if ($item.IsLocked) {
                # Diseño de advertencia visual para elementos bloqueados
                Write-Host ("   [{0}] [!] {1,-12} -> BLOQUEADO POR ONEDRIVE" -f ($i + 1), $item.Name) -ForegroundColor Red
            } else {
                $status = if ($item.Selected) { "[X]" } else { "[ ]" }
                Write-Host ("   [{0}] {1} {2,-12} -> Actual: {3}" -f ($i + 1), $status, $item.Name, $item.Path) -ForegroundColor White
            }
        }
        
        $selectedCount = $folderItems.Where({$_.Selected}).Count
        if ($selectedCount -gt 0) {
            Write-Host "`n   ($selectedCount carpeta(s) seleccionada(s))" -ForegroundColor Cyan
        }

        if ($hasOneDriveLocks) {
            Write-Host "`n[ADVERTENCIA DE SEGURIDAD]" -ForegroundColor DarkYellow
            Write-Host "No puedes reubicar carpetas controladas por Microsoft OneDrive." -ForegroundColor Gray
            Write-Host "Pasos para desbloquearlas:" -ForegroundColor Gray
            Write-Host " 1. Clic derecho en el icono de la nube de OneDrive (barra de tareas)." -ForegroundColor Gray
            Write-Host " 2. Ve a 'Configuracion' -> 'Sincronizacion y copia de seguridad'." -ForegroundColor Gray
            Write-Host " 3. Clic en 'Administrar copias de seguridad' y desactiva las carpetas deseadas." -ForegroundColor Gray
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] Marcar/Desmarcar        [T] Marcar Todas (Libres)"
        Write-Host "   [C] Continuar con la Reubicacion [N] Desmarcar Todas"
        Write-Host ""
        Write-Host "   [V] Cancelar y Volver" -ForegroundColor Red
        Write-Host ""
        $choice = Read-Host "Selecciona una opcion"

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $folderItems.Count) {
            $index = [int]$choice - 1
            if ($folderItems[$index].IsLocked) {
                [System.Console]::Beep(400, 200)
                Write-Warning "Carpeta protegida por OneDrive. Sigue las instrucciones para desbloquearla."
                Start-Sleep -Seconds 3
            } else {
                $folderItems[$index].Selected = -not $folderItems[$index].Selected
            }
        } 
        elseif ($choice.ToUpper() -eq 'T') { 
            # Marcar todas, excepto las bloqueadas
            $folderItems | Where-Object { -not $_.IsLocked } | ForEach-Object { $_.Selected = $true } 
        }
        elseif ($choice.ToUpper() -eq 'N') { $folderItems.ForEach({$_.Selected = $false}) }
        elseif ($choice.ToUpper() -notin @('C', 'V')) {
             Write-Warning "Opcion no valida." ; Start-Sleep -Seconds 1
        }
        }

        if ($choice.ToUpper() -eq 'V') {
            Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
            if (-not $NoPause) { Start-Sleep -Seconds 2 }
            return $null
        }
    } else {
        $unknownFolders = @($SelectedFolderNames | Where-Object { $_ -notin $folderMappings.Keys })
        if ($unknownFolders.Count -gt 0) {
            throw "Carpetas conocidas no validas: $($unknownFolders -join ', ')."
        }
        $lockedSelections = @($folderItems | Where-Object { $_.Selected -and $_.IsLocked })
        if ($lockedSelections.Count -gt 0) {
            throw "No se pueden reubicar carpetas controladas por OneDrive: $($lockedSelections.Name -join ', ')."
        }
    }

    $foldersToProcess = @($folderItems | Where-Object { $_.Selected })
    if ($foldersToProcess.Count -eq 0) {
        throw 'No se selecciono ninguna carpeta para reubicar.'
    }

    # Resolver la accion antes de validar rutas: Solo Registro no requiere que el origen siga presente.
    $actionType = $ActionType
    if ($actionType -eq 'Prompt') {
        Write-Host "`n--- TIPO DE ACCION ---" -ForegroundColor Cyan
        Write-Host "   [1] Mover Archivos Y Actualizar Registro (Recomendado)"
        Write-Host "   [2] Solo Actualizar Registro (Si ya moviste archivos manualmente)"
        $actionInput = Read-Host "`nElige opcion (1/2)"
        if ($actionInput -ne '1' -and $actionInput -ne '2') { return $null }
        $actionType = if ($actionInput -eq '1') { 'MoveAndRegister' } else { 'RegisterOnly' }
    }

    foreach ($folder in $foldersToProcess) {
        if ([string]::IsNullOrWhiteSpace([string]$folder.Path)) {
            if ($actionType -eq 'MoveAndRegister') { throw "No se pudo resolver la ruta de origen de '$($folder.Name)'." }
            continue
        }
        $sourceFull = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$folder.Path)).TrimEnd('\')
        $targetFull = [System.IO.Path]::GetFullPath((Join-Path $newBaseFullPath $folderMappings[$folder.Name].DefaultName)).TrimEnd('\')
        $pathsOverlap = $sourceFull.Equals($targetFull, [StringComparison]::OrdinalIgnoreCase) -or
            $sourceFull.StartsWith($targetFull + '\', [StringComparison]::OrdinalIgnoreCase) -or
            $targetFull.StartsWith($sourceFull + '\', [StringComparison]::OrdinalIgnoreCase)
        if ($pathsOverlap) {
            throw "La ruta destino de '$($folder.Name)' se superpone con su origen."
        }
    }

    # Preflight global antes de cerrar Explorer o modificar alguna ruta.
    foreach ($folder in $foldersToProcess) {
        $targetPath = Join-Path $newBaseFullPath $folderMappings[$folder.Name].DefaultName
        if ($actionType -eq 'MoveAndRegister') {
            if (-not (Test-Path -LiteralPath $folder.Path -PathType Container)) {
                throw "La carpeta de origen '$($folder.Name)' no existe: $($folder.Path)"
            }
            if (Test-Path -LiteralPath $targetPath -PathType Container) {
                $existingTargetItem = Get-ChildItem -LiteralPath $targetPath -Force -ErrorAction Stop | Select-Object -First 1
                if ($existingTargetItem) { throw "El destino de '$($folder.Name)' ya contiene datos: $targetPath" }
            }
        } elseif (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
            throw "En modo Solo Registro debe existir previamente el destino de '$($folder.Name)': $targetPath"
        }
    }

    # --- CALCULO DE ESPACIO AUTOMATICO ---
    if ($actionType -eq 'MoveAndRegister') {
        Clear-Host
        Write-Host "`n[+] Calculando espacio necesario..." -ForegroundColor Yellow
        $totalRequiredBytes = 0
        foreach ($folder in $foldersToProcess) {
            try {
                $size = (Get-ChildItem -Path $folder.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                $totalRequiredBytes += $size
            } catch {
                Write-Warning "No se pudo calcular completamente '$($folder.Path)': $($_.Exception.Message)"
            }
        }

        try {
            $destDrive = Split-Path $newBasePath -Qualifier
            $volumeInfo = Get-Volume | Where-Object { ($_.DriveLetter + ":") -eq $destDrive }
            if (-not $volumeInfo -or $null -eq $volumeInfo.SizeRemaining) { throw 'No se obtuvo espacio disponible.' }
            $freeSpaceBytes = [long]$volumeInfo.SizeRemaining
        } catch {
            throw "No fue posible verificar el espacio libre del destino: $($_.Exception.Message)"
        }

        $reqGB = [math]::Round($totalRequiredBytes / 1GB, 2)
        $freeGB = [math]::Round($freeSpaceBytes / 1GB, 2)

        if ($totalRequiredBytes -gt $freeSpaceBytes) {
            throw "Espacio insuficiente: se requieren aproximadamente $reqGB GB y hay $freeGB GB disponibles."
        } else {
            Write-Host "`n[OK] Espacio suficiente verificado." -ForegroundColor Green
            Write-Host "Requerido: $reqGB GB | Disponible: $freeGB GB" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n[+] Modo Solo Registro: no se requiere calcular espacio para transferencia." -ForegroundColor Cyan
    }

    $verificationMode = $VerificationMode
    if ($actionType -eq 'MoveAndRegister' -and $verificationMode -eq 'Prompt') {
        Write-Host "`n--- NIVEL DE VERIFICACION ---" -ForegroundColor Yellow
        Write-Host "   [R] Rapida (tamano y fecha; recomendada)"
        Write-Host "   [S] Simulacion (/L), seguida de verificacion rapida"
        Write-Host "   [H] Profunda SHA-256 (lenta)"
        
        $verifyInput = Read-Host "`nElige opcion"
        switch ($verifyInput.ToUpper()) {
            'S' { $verificationMode = 'Simulation' }
            'H' { $verificationMode = 'Deep' }
            default { $verificationMode = 'Fast' }
        }
    } elseif ($actionType -eq 'RegisterOnly') {
        $verificationMode = 'Fast'
    } elseif ($verificationMode -eq 'Prompt') {
        $verificationMode = 'Fast'
    }

    if ($verificationMode -eq 'Simulation') {
        Write-Host "`n[SIMULACION] Ejecutando Robocopy /L para previsualizar..." -ForegroundColor Cyan
        foreach ($folder in $foldersToProcess) {
            $dest = Join-Path $newBasePath $folderMappings[$folder.Name].DefaultName
            $previewResult = Invoke-AegisNativeProcess -FilePath 'robocopy.exe' `
                -ArgumentList @($folder.Path, $dest, '/L', '/E', '/NP', '/NJH', '/NJS') `
                -TimeoutSeconds 43200 -ValidExitCodes @(0,1,2,3,4,5,6,7) -StreamOutput -NoThrow
            if (-not $previewResult.Succeeded) {
                throw "La simulacion de '$($folder.Name)' fallo con codigo $($previewResult.ExitCode)."
            }
        }
        Write-Host "`nSimulacion completada. Revisa la salida arriba." -ForegroundColor Yellow
        if ($NoPause) {
            $simulationChoice = [System.Windows.Forms.MessageBox]::Show("La simulacion termino. Revisa la salida de Robocopy en la consola.`n`n¿Deseas ejecutar ahora la reubicacion real?", 'Simulacion completada', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($simulationChoice -ne [System.Windows.Forms.DialogResult]::Yes) {
                return [PSCustomObject]@{ Status='Simulated'; Message='La simulacion finalizo sin ejecutar cambios.'; Destination=$newBasePath; SelectedCount=$foldersToProcess.Count }
            }
        } elseif ((Read-Host "¿Deseas proceder con el movimiento REAL? (S/N)").ToUpper() -ne 'S') {
            return $null
        }
        $verificationMode = 'Fast'
    }

    if (-not $SkipConfirmation) {
        Write-Host ""
        Write-Warning "Cerrando aplicaciones y explorador..."
        $confirmation = Read-Host "¿Confirmar inicio? (SI/NO)"
        if ($confirmation.ToUpper() -notin @('SI', 'S')) { return $null }
    }

    if (-not $PSCmdlet.ShouldProcess(($foldersToProcess.Name -join ', '), "Reubicar carpetas de usuario en '$newBasePath'")) {
        return
    }

    $relocationJournal = New-AegisOperationJournal -Module 'Respaldos' -Action 'RelocateKnownFolders' -Targets @($foldersToProcess | ForEach-Object {
        [ordered]@{ Name=$_.Name; Source=$_.Path; Destination=(Join-Path $newBasePath $folderMappings[$_.Name].DefaultName) }
    }) -Metadata @{ ActionType=$actionType; Verification=$verificationMode }
    $relocationResults = [System.Collections.Generic.List[object]]::new()

    # --- [SEGURIDAD] CERRAR EXPLORER Y FORZAR VISIBILIDAD ---
    Write-Host "Cerrando el Explorador de Windows..." -ForegroundColor Yellow
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    try {
        $hWnd = [Win32ConsoleUtils]::GetConsoleWindow()
        if ($hWnd -ne [IntPtr]::Zero) {
            [void][Win32ConsoleUtils]::ShowWindow($hWnd, [Win32ConsoleUtils]::SW_RESTORE)
            [Win32ConsoleUtils]::SetWindowPos($hWnd, [Win32ConsoleUtils]::HWND_TOPMOST, 0, 0, 0, 0, ([Win32ConsoleUtils]::SWP_NOMOVE -bor [Win32ConsoleUtils]::SWP_NOSIZE -bor [Win32ConsoleUtils]::SWP_SHOWWINDOW)) | Out-Null
            [Win32ConsoleUtils]::SetForegroundWindow($hWnd) | Out-Null
        }
    } catch {
        Write-Log -LogLevel WARN -Message "REUBICACION: No se pudo traer la consola al frente: $($_.Exception.Message)"
    }

    $globalSuccess = $true

    try {
    foreach ($op in $foldersToProcess) {
        $regName = $folderMappings[$op.Name].RegValue
        $srcPath = $op.Path
        
        if ($actionType -eq 'MoveAndRegister' -and -not (Test-Path -LiteralPath $srcPath -PathType Container)) {
            Write-Warning "   [OMITIDO] La carpeta de origen no existe en disco: $srcPath"
            $globalSuccess = $false
            $relocationResults.Add([ordered]@{ Name=$op.Name; Status='SourceMissing'; Source=$srcPath })
            continue
        }

        $destPath = Join-Path $newBasePath $folderMappings[$op.Name].DefaultName

        Write-Host "`nProcesando: $($op.Name)..." -ForegroundColor Cyan

        if ($actionType -eq 'RegisterOnly' -and -not (Test-Path -LiteralPath $destPath -PathType Container)) {
            Write-Error "   El destino '$destPath' no existe. En modo Solo Registro debe contener los archivos movidos previamente."
            $globalSuccess = $false
            continue
        }
        if ($actionType -eq 'MoveAndRegister' -and (Test-Path -LiteralPath $destPath -PathType Container)) {
            $existingDestinationItems = @(Get-ChildItem -LiteralPath $destPath -Force -ErrorAction Stop | Select-Object -First 1)
            if ($existingDestinationItems.Count -gt 0) {
                Write-Error "   El destino '$destPath' ya contiene datos. Usa un destino vacio para permitir un rollback seguro."
                $globalSuccess = $false
                continue
            }
        }
        if (-not (Test-Path -LiteralPath $destPath)) { New-Item -Path $destPath -ItemType Directory -Force | Out-Null }

        $filesMoved = $true
        if ($actionType -eq 'MoveAndRegister') {
            $logDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs"
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
            $logFile = Join-Path $logDir "Move_$($op.Name).log"

            Write-Host "   [MOVE SEGURO] Copiando antes de verificar..." -ForegroundColor Gray
            $args = @($srcPath, $destPath, '/E', '/COPY:DAT', '/DCOPY:T', '/MT:8', '/R:2', '/W:2', '/NP', "/LOG:$logFile")
            $copyResult = Invoke-AegisNativeProcess -FilePath 'robocopy.exe' -ArgumentList $args -TimeoutSeconds 43200 -ValidExitCodes @(0,1,2,3,4,5,6,7) -NoThrow
            if (-not $copyResult.Succeeded) {
                Write-Error "   Robocopy fallo durante la copia (codigo $($copyResult.ExitCode))."
                $filesMoved = $false
                $globalSuccess = $false
                $relocationResults.Add([ordered]@{ Name=$op.Name; Status='CopyFailed'; ExitCode=$copyResult.ExitCode })
                continue
            }

            try {
                $verificationType = if ($verificationMode -eq 'Deep') { 'Deep' } else { 'Fast' }
                Write-Host "   [VERIFICACION $($verificationType.ToUpper())] Validando todos los archivos..." -ForegroundColor Yellow
                $removed = Remove-AegisVerifiedRelocationSources -SourcePath $srcPath -DestinationPath $destPath -VerificationType $verificationType -Confirm:$false
                Write-Host "   [OK] $($removed.Count) archivo(s) verificados y retirados del origen." -ForegroundColor Green
            } catch {
                Write-Warning "La verificacion o retirada segura fallo: $($_.Exception.Message)"
                $filesMoved = $false
                $globalSuccess = $false
                $relocationResults.Add([ordered]@{ Name=$op.Name; Status='VerificationFailed'; Error=$_.Exception.Message })
            }
        } else {
            if (-not [string]::IsNullOrWhiteSpace([string]$srcPath)) {
                $ini = Join-Path $srcPath "desktop.ini"
                if (Test-Path $ini) { Copy-Item $ini (Join-Path $destPath "desktop.ini") -Force -ErrorAction SilentlyContinue }
            }
        }

        # 3. Actualizar Registro
        if ($filesMoved) {
            $originalRegistryValue = $null
            $hadOriginalRegistryValue = $false
            try {
                $registryItem = Get-ItemProperty -Path $registryPath -ErrorAction Stop
                $originalProperty = $registryItem.PSObject.Properties[$regName]
                if ($originalProperty) {
                    $hadOriginalRegistryValue = $true
                    $originalRegistryValue = $originalProperty.Value
                }
                Set-ItemProperty -Path $registryPath -Name $regName -Value $destPath -Type ExpandString -Force -ErrorAction Stop
                Write-Host "   Registro actualizado." -ForegroundColor Green
                
                $srcIni = if ([string]::IsNullOrWhiteSpace([string]$srcPath)) { $null } else { Join-Path $srcPath "desktop.ini" }
                $destIni = Join-Path $destPath "desktop.ini"
                if ($srcIni -and (Test-Path $srcIni) -and (-not (Test-Path $destIni))) {
                    Copy-Item $srcIni $destIni -Force -ErrorAction SilentlyContinue
                }
                
                if (Test-Path $destIni) { (Get-Item $destIni -Force).Attributes = 'Hidden', 'System' }
                (Get-Item $destPath -Force).Attributes = 'ReadOnly'
                
                Write-Log -LogLevel ACTION -Message "Registro actualizado para $($op.Name) -> $destPath"
                $relocationResults.Add([ordered]@{ Name=$op.Name; Status='Completed'; Destination=$destPath })
            } catch {
                Write-Error "   Error actualizando registro: $_"
                $globalSuccess = $false
                if ($actionType -eq 'MoveAndRegister' -and (Test-Path -LiteralPath $destPath)) {
                    Write-Warning "   Intentando devolver los archivos al origen porque el Registro no pudo actualizarse..."
                    if (-not (Test-Path -LiteralPath $srcPath)) { New-Item -Path $srcPath -ItemType Directory -Force | Out-Null }
                    $rollbackArgs = @($destPath, $srcPath, '/MOVE', '/E', '/COPY:DAT', '/DCOPY:T', '/R:2', '/W:2', '/NP')
                    $rollbackProc = Invoke-AegisNativeProcess -FilePath 'robocopy.exe' -ArgumentList $rollbackArgs -TimeoutSeconds 43200 -ValidExitCodes @(0,1,2,3,4,5,6,7) -NoThrow
                    if (-not $rollbackProc.Succeeded) {
                        Write-Error "   El rollback de archivos tambien fallo (codigo $($rollbackProc.ExitCode))."
                    }
                }
                if ($hadOriginalRegistryValue) {
                    Set-ItemProperty -Path $registryPath -Name $regName -Value $originalRegistryValue -Type ExpandString -Force -ErrorAction SilentlyContinue
                } else {
                    Remove-ItemProperty -Path $registryPath -Name $regName -Force -ErrorAction SilentlyContinue
                }
                $relocationResults.Add([ordered]@{ Name=$op.Name; Status='RegistryFailed'; Error=$_.Exception.Message })
            }
        }
    }
    } catch {
        $globalSuccess = $false
        $relocationResults.Add([ordered]@{ Status='UnhandledFailure'; Error=$_.Exception.Message })
        Write-Log -LogLevel ERROR -Message "REUBICACION: Fallo no controlado: $($_.Exception.Message)"
    } finally {
        Write-Host "`nRestaurando escritorio..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        Invoke-ExplorerRestart -Confirm:$false
    }

    $completedRelocations = @($relocationResults | Where-Object { $_.Status -eq 'Completed' }).Count
    $relocationStatus = if ($globalSuccess) { 'Completed' } elseif ($completedRelocations -gt 0) { 'Partial' } else { 'Failed' }
    [void](Complete-AegisOperationJournal -Journal $relocationJournal -Status $relocationStatus -Results @($relocationResults))

    if (-not $globalSuccess) {
        Write-Warning "La reubicacion termino con errores. Revisa los mensajes y Logs antes de continuar."
    } else {
        Write-Host "`n[OK] Reubicacion finalizada correctamente." -ForegroundColor Green
    }

    if (-not $NoPause) { Read-Host "`nPresiona Enter para volver..." | Out-Null }
    return [PSCustomObject]@{
        Status = $relocationStatus
        Message = if ($globalSuccess) { 'Reubicacion finalizada correctamente.' } else { 'La reubicacion termino con errores o resultados parciales.' }
        Destination = $newBasePath
        SelectedCount = $foldersToProcess.Count
        CompletedCount = $completedRelocations
        Results = @($relocationResults)
    }
}