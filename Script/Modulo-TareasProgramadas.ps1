# =================================================================
#  Modulo-TareasProgramadas
#
#  CONTENIDO   : Show-ScheduledTasks
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Write-AegisJsonAtomic          : escritura atomica de archivos JSON (snapshots/config)
#    - Read-AegisSafeXml              : carga y valida contenido XML de forma segura
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-TareasProgramadas.ps1"
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

function Get-AegisScheduledTaskActionInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Task)

    $action = @($Task.Actions | Where-Object { $_.Execute } | Select-Object -First 1)
    if ($action.Count -eq 0) {
        return [PSCustomObject]@{ Execute=''; Arguments=''; Path=''; Publisher='Sin ejecutable'; SignatureStatus='Unknown' }
    }
    $execute = [Environment]::ExpandEnvironmentVariables([string]$action[0].Execute).Trim('"')
    $resolvedPath = $execute
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        $command = Get-Command $execute -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source) { $resolvedPath = $command.Source }
    }
    $publisher = 'No verificable'
    $signatureStatus = 'Unknown'
    if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
        try {
            $signature = Get-AuthenticodeSignature -LiteralPath $resolvedPath -ErrorAction Stop
            $signatureStatus = [string]$signature.Status
            if ($signature.SignerCertificate.Subject -match '(?:^|,\s*)O=([^,]+)') { $publisher = $matches[1] }
            elseif ($signature.SignerCertificate.Subject) { $publisher = [string]$signature.SignerCertificate.Subject }
            elseif ($signature.Status -eq 'NotSigned') { $publisher = 'Sin firma' }
        } catch { $publisher = 'No verificable' }
    }
    return [PSCustomObject]@{
        Execute = [string]$action[0].Execute
        Arguments = [string]$action[0].Arguments
        Path = $resolvedPath
        Publisher = $publisher
        SignatureStatus = $signatureStatus
    }
}

function Show-ScheduledTasks {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Tareas fuera del arbol Microsoft"
    $form.Size = New-Object System.Drawing.Size(980, 700)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Tareas Programadas (fuera de \Microsoft)"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(380, 23)
    $lblSearch.AutoSize = $true
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

    # --- 3. DATAGRIDVIEW ---
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
    
    # Optimizacion de buffer
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
    $colName.HeaderText = "Nombre de Tarea"
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

    $colAuth = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAuth.HeaderText = "Autor"
    $colAuth.Name = "Author"
    $colAuth.ReadOnly = $true
    $colAuth.Width = 150
    $grid.Columns.Add($colAuth) | Out-Null

    $colPublisher = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPublisher.HeaderText = "Firmante"
    $colPublisher.Name = "Publisher"
    $colPublisher.ReadOnly = $true
    $colPublisher.Width = 150
    $grid.Columns.Add($colPublisher) | Out-Null

    $colPath = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPath.HeaderText = "Ruta Interna (TaskPath)"
    $colPath.Name = "Path"
    $colPath.ReadOnly = $true
    $colPath.Width = 200
    $grid.Columns.Add($colPath) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DETALLES ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Detalles de Ejecucion"
    $grpDesc.ForeColor = [System.Drawing.Color]::LightGray
    $grpDesc.Location = New-Object System.Drawing.Point(20, 490)
    $grpDesc.Size = New-Object System.Drawing.Size(920, 80)
    $form.Controls.Add($grpDesc)

    $txtDetails = New-Object System.Windows.Forms.TextBox
    $txtDetails.Location = New-Object System.Drawing.Point(15, 30)
    $txtDetails.Size = New-Object System.Drawing.Size(890, 40)
    $txtDetails.ReadOnly = $true
    $txtDetails.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtDetails.ForeColor = [System.Drawing.Color]::Yellow
    $txtDetails.BorderStyle = "FixedSingle"
    $grpDesc.Controls.Add($txtDetails)

    # --- 5. BOTONES DE ACCION (Reorganizados para caber 3) ---
    
    # Boton Marcar Todo
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 595)
    $btnSelectAll.Size = New-Object System.Drawing.Size(100, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "Restaurar respaldo"
    $btnRestore.Location = New-Object System.Drawing.Point(130, 595)
    $btnRestore.Size = New-Object System.Drawing.Size(135, 30)
    $btnRestore.BackColor = [System.Drawing.Color]::SteelBlue
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $form.Controls.Add($btnRestore)

    # Boton HABILITAR
    $btnEnable = New-Object System.Windows.Forms.Button
    $btnEnable.Text = "HABILITAR"
    $btnEnable.Location = New-Object System.Drawing.Point(280, 590)
    $btnEnable.Size = New-Object System.Drawing.Size(200, 40)
    $btnEnable.BackColor = [System.Drawing.Color]::SeaGreen
    $btnEnable.ForeColor = [System.Drawing.Color]::White
    $btnEnable.FlatStyle = "Flat"
    $btnEnable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnEnable)

    # Boton DESHABILITAR
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR"
    $btnDisable.Location = New-Object System.Drawing.Point(500, 590)
    $btnDisable.Size = New-Object System.Drawing.Size(200, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::OrangeRed
    $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    # Boton ELIMINAR (Nuevo)
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR TAREA"
    $btnDelete.Location = New-Object System.Drawing.Point(720, 590)
    $btnDelete.Size = New-Object System.Drawing.Size(220, 40)
    $btnDelete.BackColor = [System.Drawing.Color]::Maroon # Rojo oscuro para peligro
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    # --- VARIABLES Y CACHE ---
    $taskCache = @{}
    $taskActionCache = @{}

    # --- LOGICA DE CARGA ---
    $LoadGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $taskCache.Clear()
        $taskActionCache.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        # Filtro Inteligente
        # Nunca incluir tareas bajo el arbol reservado de Microsoft, aunque el
        # campo Author este vacio o haya sido localizado/modificado.
        try {
            $allTasks = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike '\Microsoft\*' }
        } catch {
            $grid.ResumeLayout()
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            [System.Windows.Forms.MessageBox]::Show("No se pudieron consultar las tareas: $($_.Exception.Message)", "Error", 0, 16) | Out-Null
            return
        }

        # Filtro de Busqueda
        $searchText = $txtSearch.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            $allTasks = $allTasks | Where-Object {
                $_.TaskName.IndexOf($searchText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
        }

        foreach ($task in $allTasks) {
            $taskId = "$($task.TaskPath)|$($task.TaskName)"
            $actionInfo = Get-AegisScheduledTaskActionInfo -Task $task
            $taskCache[$taskId] = $task
            $taskActionCache[$taskId] = $actionInfo

            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["Name"].Value = $task.TaskName
            $row.Cells["Name"].Tag = $taskId 
            
            $row.Cells["Author"].Value = $task.Author
            $row.Cells["Publisher"].Value = "$($actionInfo.Publisher) [$($actionInfo.SignatureStatus)]"
            $row.Cells["Path"].Value = $task.TaskPath

            if ($task.State -eq 'Disabled') {
                $row.Cells["Status"].Value = "Deshabilitado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
            } else {
                $row.Cells["Status"].Value = "Habilitado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                if ($task.State -eq 'Running') {
                    $row.Cells["Status"].Value = "Ejecutando"
                }
            }
        }
        
        $grid.ResumeLayout()
        $grid.ClearSelection()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $txtDetails.Text = ""
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $LoadGrid })
    $btnRefresh.Add_Click({ & $LoadGrid })
    $txtSearch.Add_KeyUp({ & $LoadGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $taskId = $grid.SelectedRows[0].Cells["Name"].Tag
            
            if ($null -ne $taskId -and $taskCache.ContainsKey($taskId)) {
                $t = $taskCache[$taskId]
                $actionInfo = $taskActionCache[$taskId]
                if ($actionInfo -and $actionInfo.Execute) {
                    $txtDetails.Text = "Ejecuta: $($actionInfo.Execute) $($actionInfo.Arguments) | Firmante: $($actionInfo.Publisher) [$($actionInfo.SignatureStatus)]"
                } else {
                    $txtDetails.Text = "No hay acciones definidas."
                }
            }
        }
    })

    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Logica General (Habilitar/Deshabilitar/Eliminar)
    $Apply = {
        param($Mode) # 'Enable', 'Disable', 'Delete'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $taskCache[$row.Cells["Name"].Tag]
            }
        }

        if ($targets.Count -eq 0) { return }

        # Configurar mensajes y advertencias segun accion
        $verb = ""
        $icon = [System.Windows.Forms.MessageBoxIcon]::Question
        
        switch ($Mode) {
            'Enable'  { $verb = "HABILITAR" }
            'Disable' { $verb = "DESHABILITAR" }
            'Delete'  { 
                $verb = "ELIMINAR PERMANENTEMENTE" 
                $icon = [System.Windows.Forms.MessageBoxIcon]::Warning
            }
        }

        $msg = "Estas seguro de $verb $($targets.Count) tareas seleccionadas?"
        if ($Mode -eq 'Delete') {
            $msg += "`n`nSe exportara una copia XML antes de eliminar cada tarea."
        }

        if ([System.Windows.Forms.MessageBox]::Show($msg, "Confirmar Accion", 4, $icon) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $successCount = 0
        $errorCount = 0
        $taskBackupDir = $null
        $journalResults = [System.Collections.Generic.List[object]]::new()
        $journal = New-AegisOperationJournal -Module 'Software' -Action "ScheduledTask.$Mode" -Targets @($targets | ForEach-Object {
            [ordered]@{ TaskName=$_.TaskName; TaskPath=$_.TaskPath; OriginalState=[string]$_.State }
        })

        try {
            if ($Mode -eq 'Delete') {
                $taskBackupDir = Join-Path (Split-Path -Parent $PSScriptRoot) ("Backup\ScheduledTasks\" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
                New-Item -Path $taskBackupDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            foreach ($t in $targets) {
                try {
                    if ($Mode -eq 'Enable') {
                        Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop
                    } elseif ($Mode -eq 'Disable') {
                        Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop
                    } elseif ($Mode -eq 'Delete') {
                        $taskId = "$($t.TaskPath)|$($t.TaskName)"
                        $safeName = ($t.TaskName -replace '[^a-zA-Z0-9._-]', '_')
                        $sha = [System.Security.Cryptography.SHA256]::Create()
                        try { $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($taskId))) -replace '-', '').Substring(0, 12) }
                        finally { $sha.Dispose() }
                        $xmlPath = Join-Path $taskBackupDir ("${safeName}_${hash}.xml")
                        $xmlText = Export-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop
                        $xmlText | Set-Content -LiteralPath $xmlPath -Encoding Unicode -ErrorAction Stop
                        $xmlDocument = Read-AegisSafeXml -Path $xmlPath
                        if ($xmlDocument.DocumentElement.LocalName -ne 'Task' -or
                            $xmlDocument.DocumentElement.NamespaceURI -ne 'http://schemas.microsoft.com/windows/2004/02/mit/task') {
                            throw "El respaldo XML de '$($t.TaskName)' no tiene el esquema esperado."
                        }
                        $xmlHash = (Get-FileHash -LiteralPath $xmlPath -Algorithm SHA256 -ErrorAction Stop).Hash
                        $manifestPath = [IO.Path]::ChangeExtension($xmlPath, '.json')
                        $manifest = [ordered]@{
                            SchemaVersion = 1
                            CreatedAt = (Get-Date).ToString('o')
                            TaskName = [string]$t.TaskName
                            TaskPath = [string]$t.TaskPath
                            OriginalState = [string]$t.State
                            XmlFile = Split-Path -Leaf $xmlPath
                            XmlSha256 = $xmlHash
                        }
                        Write-AegisJsonAtomic -InputObject $manifest -Path $manifestPath
                        Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false -ErrorAction Stop
                    }
                    $successCount++
                    $journalResults.Add([ordered]@{ TaskName=$t.TaskName; TaskPath=$t.TaskPath; Status='Completed'; BackupDirectory=$taskBackupDir })
                    Write-Log -LogLevel ACTION -Message "TASKS GUI: $verb $($t.TaskName)"
                } catch {
                    $errorCount++
                    $journalResults.Add([ordered]@{ TaskName=$t.TaskName; TaskPath=$t.TaskPath; Status='Failed'; Error=$_.Exception.Message })
                    Write-Log -LogLevel ERROR -Message "Error con tarea $($t.TaskName): $($_.Exception.Message)"
                }
            }
        } catch {
            $errorCount++
            Write-Log -LogLevel ERROR -Message "TASKS GUI: Fallo preparando la operacion: $($_.Exception.Message)"
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        $journalStatus = if ($errorCount -eq 0) { 'Completed' } elseif ($successCount -gt 0) { 'Partial' } else { 'Failed' }
        [void](Complete-AegisOperationJournal -Journal $journal -Status $journalStatus -Results @($journalResults))

        & $LoadGrid
        $backupText = if ($taskBackupDir) { "`nRespaldos: $taskBackupDir" } else { "" }
        [System.Windows.Forms.MessageBox]::Show("Resultado: $successCount correctas, $errorCount errores.$backupText", "Tareas", 0, $(if ($errorCount -eq 0) { 64 } else { 48 }))
    }

    $btnRestore.Add_Click({
        $journal = $null
        $manifestPaths = Select-PathDialog -DialogType 'File' -Title 'Selecciona un manifiesto de tarea respaldada' -Filter 'Manifiestos JSON (*.json)|*.json'
        if (-not $manifestPaths) { return }
        $manifestPath = [string]$manifestPaths[0]
        try {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ([int]$manifest.SchemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace([string]$manifest.TaskName) -or
                [string]::IsNullOrWhiteSpace([string]$manifest.TaskPath)) { throw 'Manifiesto de tarea incompleto o incompatible.' }
            if ([string]$manifest.TaskName -match '[\\/:*?"<>|]' -or [string]$manifest.TaskPath -notmatch '^\\') {
                throw 'Nombre o ruta de tarea no validos en el manifiesto.'
            }
            $xmlLeaf = [IO.Path]::GetFileName([string]$manifest.XmlFile)
            if ($xmlLeaf -ne [string]$manifest.XmlFile -or [IO.Path]::GetExtension($xmlLeaf) -ne '.xml') {
                throw 'La referencia al XML no es valida.'
            }
            $xmlPath = Join-Path (Split-Path -Parent $manifestPath) $xmlLeaf
            $actualHash = (Get-FileHash -LiteralPath $xmlPath -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($actualHash -ne [string]$manifest.XmlSha256) { throw 'La integridad SHA-256 del XML no coincide.' }
            $xmlDocument = Read-AegisSafeXml -Path $xmlPath
            if ($xmlDocument.DocumentElement.LocalName -ne 'Task' -or
                $xmlDocument.DocumentElement.NamespaceURI -ne 'http://schemas.microsoft.com/windows/2004/02/mit/task') {
                throw 'El XML no corresponde al esquema de una tarea programada.'
            }

            $existing = Get-ScheduledTask -TaskName ([string]$manifest.TaskName) -TaskPath ([string]$manifest.TaskPath) -ErrorAction SilentlyContinue
            if ($existing -and [System.Windows.Forms.MessageBox]::Show('La tarea ya existe. Deseas reemplazarla?', 'Restaurar tarea', 4, 48) -ne 'Yes') { return }
            $journal = New-AegisOperationJournal -Module 'Software' -Action 'ScheduledTask.Restore' -Targets @(
                [ordered]@{ TaskName=$manifest.TaskName; TaskPath=$manifest.TaskPath; Manifest=$manifestPath }
            )
            $xmlText = Get-Content -LiteralPath $xmlPath -Raw -ErrorAction Stop
            Register-ScheduledTask -TaskName ([string]$manifest.TaskName) -TaskPath ([string]$manifest.TaskPath) -Xml $xmlText -Force -ErrorAction Stop | Out-Null
            if ([string]$manifest.OriginalState -eq 'Disabled') {
                Disable-ScheduledTask -TaskName ([string]$manifest.TaskName) -TaskPath ([string]$manifest.TaskPath) -ErrorAction Stop | Out-Null
            }
            [void](Complete-AegisOperationJournal -Journal $journal -Status 'Completed' -Results @([ordered]@{ Status='Restored' }))
            Write-Log -LogLevel ACTION -Message "TASKS GUI: Restaurada '$($manifest.TaskPath)$($manifest.TaskName)'."
            [System.Windows.Forms.MessageBox]::Show('Tarea restaurada correctamente.', 'Restaurar tarea', 0, 64) | Out-Null
            & $LoadGrid
        } catch {
            if ($journal) { [void](Complete-AegisOperationJournal -Journal $journal -Status 'Failed' -Results @([ordered]@{ Error=$_.Exception.Message })) }
            [System.Windows.Forms.MessageBox]::Show("No fue posible restaurar la tarea: $($_.Exception.Message)", 'Error', 0, 16) | Out-Null
        }
    })

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

    # Asignar eventos a botones
    $btnEnable.Add_Click({ & $Apply -Mode 'Enable' })
    $btnDisable.Add_Click({ & $Apply -Mode 'Disable' })
    $btnDelete.Add_Click({ & $Apply -Mode 'Delete' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}