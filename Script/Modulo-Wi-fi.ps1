# =================================================================
#  Modulo-Wi-fi
#
#  CONTENIDO   : Show-WifiManager
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                 : registro de eventos en el log de la suite
#    - Invoke-AegisNativeProcess : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - Read-AegisSafeXml         : carga y valida contenido XML de forma segura
#
#  CARGA       : . "$PSScriptRoot\Modulo-Wi-fi.ps1"
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

function Show-WifiManager {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Claves Wi-Fi"
    $form.Size = New-Object System.Drawing.Size(980, 700)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Redes Wi-Fi Guardadas"
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

    $chkReveal = New-Object System.Windows.Forms.CheckBox
    $chkReveal.Text = "Mostrar claves"
    $chkReveal.Location = New-Object System.Drawing.Point(815, 20)
    $chkReveal.AutoSize = $true
    $chkReveal.ForeColor = [System.Drawing.Color]::Orange
    $form.Controls.Add($chkReveal)

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
    $colName.HeaderText = "SSID (Nombre de Red)"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 250
    $grid.Columns.Add($colName) | Out-Null

    $colAuth = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAuth.HeaderText = "Autenticacion"
    $colAuth.Name = "Auth"
    $colAuth.ReadOnly = $true
    $colAuth.Width = 150
    $grid.Columns.Add($colAuth) | Out-Null

    $colPass = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPass.HeaderText = "Contrasena (Clave)"
    $colPass.Name = "Password"
    $colPass.ReadOnly = $true
    $colPass.Width = 250
    $grid.Columns.Add($colPass) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. BARRA DE ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 490)
    $progressBar.Size = New-Object System.Drawing.Size(920, 20)
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 520)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    # --- 5. BOTONES DE ACCION ---
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 560)
    $btnSelectAll.Size = New-Object System.Drawing.Size(100, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # Boton EXPORTAR
    $btnBackup = New-Object System.Windows.Forms.Button
    $btnBackup.Text = "EXPORTAR CIFRADO"
    $btnBackup.Location = New-Object System.Drawing.Point(140, 550)
    $btnBackup.Size = New-Object System.Drawing.Size(260, 50)
    $btnBackup.BackColor = [System.Drawing.Color]::SeaGreen
    $btnBackup.ForeColor = [System.Drawing.Color]::White
    $btnBackup.FlatStyle = "Flat"
    $btnBackup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnBackup)

    # Boton RESTAURAR
    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "RESTAURAR CIFRADO"
    $btnRestore.Location = New-Object System.Drawing.Point(410, 550)
    $btnRestore.Size = New-Object System.Drawing.Size(260, 50)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestore)

    # Boton ELIMINAR (Nuevo)
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR SELECCIONADOS"
    $btnDelete.Location = New-Object System.Drawing.Point(680, 550)
    $btnDelete.Size = New-Object System.Drawing.Size(260, 50)
    $btnDelete.BackColor = [System.Drawing.Color]::Crimson
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    # --- VARIABLES Y CACHE ---
    $wifiCache = @{}
    $wifiState = @{ IsRendering = $false } # <--- NUEVA BANDERA DE SEGURIDAD

    $NewRestrictedTemp = {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("AegisWifi_" + [guid]::NewGuid().ToString('N'))
        New-Item -Path $tempDir -ItemType Directory -ErrorAction Stop | Out-Null
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $acl.SetOwner($identity.User)
        $acl.SetAccessRuleProtection($true, $false)
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $identity.User, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))
        [System.IO.Directory]::SetAccessControl($tempDir, $acl)
        return $tempDir
    }

    $ReadWifiProfile = {
        param([string]$Ssid, [bool]$IncludeClearKey)
        $tempDir = & $NewRestrictedTemp
        try {
            $args = @('wlan','export','profile',"name=$Ssid", "folder=$tempDir")
            if ($IncludeClearKey) { $args += 'key=clear' }
            Invoke-AegisNativeProcess -FilePath 'netsh.exe' -ArgumentList $args -TimeoutSeconds 60 | Out-Null
            $xmlFile = Get-ChildItem -LiteralPath $tempDir -Filter '*.xml' -File -ErrorAction Stop | Select-Object -First 1
            if (-not $xmlFile) { throw "Netsh no exporto el perfil '$Ssid'." }
            $xml = Read-AegisSafeXml -Path $xmlFile.FullName -MaxCharacters 2097152
            if ($xml.DocumentElement.LocalName -ne 'WLANProfile' -or $xml.DocumentElement.NamespaceURI -notmatch '^http://www\.microsoft\.com/networking/WLAN/profile/v\d+$') {
                throw "El perfil '$Ssid' no tiene el esquema WLAN esperado."
            }
            $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
            $ns.AddNamespace('w', $xml.DocumentElement.NamespaceURI)
            $nameNode = $xml.SelectSingleNode('/w:WLANProfile/w:name', $ns)
            $authNode = $xml.SelectSingleNode('/w:WLANProfile/w:MSM/w:security/w:authEncryption/w:authentication', $ns)
            $keyNode = $xml.SelectSingleNode('/w:WLANProfile/w:MSM/w:security/w:sharedKey/w:keyMaterial', $ns)
            return [PSCustomObject]@{
                Name=$(if ($nameNode) { $nameNode.InnerText } else { $Ssid })
                Auth=$(if ($authNode) { $authNode.InnerText } else { 'No disponible' })
                Password=$(if ($IncludeClearKey -and $keyNode) { $keyNode.InnerText } else { $null })
                XmlBytes=[System.IO.File]::ReadAllBytes($xmlFile.FullName)
            }
        } finally {
            if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    $CreateEncryptedWifiBackup = {
        param([string[]]$Targets, [string]$OutputPath)
        $profiles = [System.Collections.Generic.List[object]]::new()
        foreach ($ssid in $Targets) {
            $profile = & $ReadWifiProfile -Ssid $ssid -IncludeClearKey $true
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try { $hash = ([BitConverter]::ToString($sha.ComputeHash($profile.XmlBytes)) -replace '-', '') } finally { $sha.Dispose() }
            $profiles.Add([PSCustomObject]@{ Name=$profile.Name; Sha256=$hash; XmlBase64=[Convert]::ToBase64String($profile.XmlBytes) })
        }
        $bundle = [ordered]@{ SchemaVersion=1; Protection='DPAPI-CurrentUser'; CreatedAt=(Get-Date).ToString('o'); Profiles=@($profiles) }
        $plainBytes = [Text.Encoding]::UTF8.GetBytes(($bundle | ConvertTo-Json -Depth 6 -Compress))
        $entropy = [Text.Encoding]::UTF8.GetBytes('AegisPhoenixWiFiV1')
        $protectedBytes = [Security.Cryptography.ProtectedData]::Protect($plainBytes, $entropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [Convert]::ToBase64String($protectedBytes) | Set-Content -LiteralPath $OutputPath -Encoding ASCII -ErrorAction Stop
        return $OutputPath
    }

    $RenderWifi = {
        $wifiState.IsRendering = $true # <--- BLOQUEAMOS EVENTOS
        
        $grid.Rows.Clear()
        $searchText = $txtSearch.Text.Trim()
        foreach ($key in @($wifiCache.Keys | Sort-Object)) {
            $item = $wifiCache[$key]
            if (-not [string]::IsNullOrWhiteSpace($searchText) -and
                $item.Name.IndexOf($searchText, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }

            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            $row.Cells["Name"].Value = $item.Name
            $row.Cells["Auth"].Value = $item.Auth
            $row.Cells["Password"].Value = if ($chkReveal.Checked -and -not [string]::IsNullOrWhiteSpace($item.Password)) {
                $item.Password
            } elseif ($item.Auth -match 'open|abierta') { '(Sin clave)' } else { '********' }
            $row.Cells["Password"].Style.ForeColor = if ([string]::IsNullOrWhiteSpace($item.Password)) {
                [System.Drawing.Color]::Silver
            } else { [System.Drawing.Color]::LightGreen }
        }
        $lblStatus.Text = "Se encontraron $($grid.Rows.Count) redes Wi-Fi."
        $grid.ClearSelection()
        
        $wifiState.IsRendering = $false # <--- LIBERAMOS EVENTOS
    }

    # --- LOGICA: ESCANEAR SIN DESENCRIPTAR PASSWORDS ---
    $ScanWifi = {
        $wifiCache.Clear()
        $lblStatus.Text = "Recuperando perfiles Wi-Fi sin exponer claves..."
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        [System.Windows.Forms.Application]::DoEvents()

        $tempDir = & $NewRestrictedTemp

        try {
            Invoke-AegisNativeProcess -FilePath 'netsh.exe' -ArgumentList @('wlan','export','profile',"folder=$tempDir") -TimeoutSeconds 60 | Out-Null
            
            $xmlFiles = Get-ChildItem -LiteralPath $tempDir -Filter "*.xml" -ErrorAction Stop
            foreach ($file in $xmlFiles) {
                try {
                    $xmlContent = Read-AegisSafeXml -Path $file.FullName -MaxCharacters 2097152
                    $ns = New-Object System.Xml.XmlNamespaceManager($xmlContent.NameTable)
                    $ns.AddNamespace('w', $xmlContent.DocumentElement.NamespaceURI)
                    $ssid = $xmlContent.SelectSingleNode('/w:WLANProfile/w:name', $ns).InnerText
                    $authNode = $xmlContent.SelectSingleNode('/w:WLANProfile/w:MSM/w:security/w:authEncryption/w:authentication', $ns)
                    $auth = if ($authNode) { $authNode.InnerText } else { 'No disponible' }

                    $wifiCache[$ssid] = [PSCustomObject]@{
                        Name = $ssid
                        Auth = $auth
                        Password = $null
                    }
                } catch {
                    Write-Log -LogLevel WARN -Message "WIFI: No se pudo leer '$($file.Name)': $($_.Exception.Message)"
                }
            }
        } catch {
            $lblStatus.Text = "Error al leer perfiles Wi-Fi: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "WIFI: $($_.Exception.Message)"
        } finally {
            if (Test-Path -LiteralPath $tempDir) {
                Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
        & $RenderWifi
    }

    # --- EVENTOS ---
    
    $form.Add_Shown({ & $ScanWifi })
    $btnRefresh.Add_Click({ & $ScanWifi })
    $txtSearch.Add_KeyUp({ & $RenderWifi })
    
    $RevealSelected = {
        if (-not $chkReveal.Checked -or $grid.SelectedRows.Count -eq 0) { return }
        $ssid = [string]$grid.SelectedRows[0].Cells['Name'].Value
        try {
            $profile = & $ReadWifiProfile -Ssid $ssid -IncludeClearKey $true
            $wifiCache[$ssid].Password = if ([string]::IsNullOrWhiteSpace($profile.Password)) { '(Sin clave / Enterprise)' } else { $profile.Password }
        } catch {
            Write-Log -LogLevel ERROR -Message "WIFI: No se pudo revelar '$ssid': $($_.Exception.Message)"
        }
        & $RenderWifi
    }
    
    $chkReveal.Add_CheckedChanged({
        if ($wifiState.IsRendering) { return } # <--- PROTECCION
        
        if ($chkReveal.Checked) {
            if ([System.Windows.Forms.MessageBox]::Show('Se desencriptara solamente la clave del perfil seleccionado y se mantendra en memoria hasta cerrar esta ventana. Continuar?', 'Mostrar clave', 4, 48) -ne 'Yes') {
                $wifiState.IsRendering = $true # <--- PROTECCION
                $chkReveal.Checked = $false
                $wifiState.IsRendering = $false # <--- PROTECCION
                return
            }
            & $RevealSelected
        } else { & $RenderWifi }
    })
    
    $grid.Add_SelectionChanged({ 
        if ($wifiState.IsRendering) { return } # <--- PROTECCION CONTRA EL BUCLE INFINITO
        if ($chkReveal.Checked) { & $RevealSelected } 
    })
    
    $form.Add_FormClosed({ foreach ($item in $wifiCache.Values) { $item.Password = $null }; $wifiCache.Clear() })

    # Evento: Clic en celda
    $grid.Add_CellClick({
        param($sender, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -ne 0) {
            $row = $grid.Rows[$e.RowIndex]
            $val = $row.Cells["Check"].Value
            if ($val -eq $null) { $val = $false }
            $row.Cells["Check"].Value = -not $val
        }
    })

    # Evento: Barra Espaciadora
    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            $e.SuppressKeyPress = $true 
            foreach ($row in $sender.SelectedRows) {
                $curr = $row.Cells["Check"].Value
                if ($curr -eq $null) { $curr = $false }
                $row.Cells["Check"].Value = -not $curr
            }
        }
    })

    $btnSelectAll.Add_Click({
        foreach ($row in $grid.Rows) { 
            $row.Cells["Check"].Value = $true
        }
    })

    # 3. BACKUP (EXPORTAR)
    $btnBackup.Add_Click({
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) { $targets += $row.Cells["Name"].Value }
        }

        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona al menos una red.", "Aviso", 0, 48); return }

        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Title = 'Guardar respaldo Wi-Fi cifrado'
        $dialog.Filter = 'Respaldo Wi-Fi Aegis (*.aegiswifi)|*.aegiswifi'
        $dialog.FileName = 'WiFi_Backup_' + (Get-Date -Format 'yyyyMMdd_HHmm') + '.aegiswifi'
        if ($dialog.ShowDialog() -ne 'OK') { return }
        $backupPath = $dialog.FileName

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0
        $progressBar.Maximum = $targets.Count
        try {
            Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
            & $CreateEncryptedWifiBackup -Targets $targets -OutputPath $backupPath | Out-Null
            $lblStatus.Text = "Respaldo cifrado creado: $($targets.Count) perfiles."
            [System.Windows.Forms.MessageBox]::Show("Respaldo protegido para el usuario actual de Windows.`n`nArchivo: $backupPath", "Resultado", 0, 64) | Out-Null
        } catch {
            Write-Log -LogLevel ERROR -Message "WIFI: Error creando respaldo cifrado: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("No se pudo crear el respaldo: $($_.Exception.Message)", "Error", 0, 16) | Out-Null
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

    # 4. RESTORE (IMPORTAR)
    $btnRestore.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = "Selecciona un respaldo Wi-Fi cifrado"
        $dialog.Filter = "Respaldo Wi-Fi Aegis (*.aegiswifi)|*.aegiswifi"
        $dialog.Multiselect = $false
        if ($dialog.ShowDialog() -ne 'OK') { return }
        $backupFile = $dialog.FileName

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0
        $progressBar.Maximum = 100
        $errors = 0
        $restored = 0
        $tempDir = $null
        
        try {
            Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
            if ((Get-Item -LiteralPath $backupFile -ErrorAction Stop).Length -gt 25MB) { throw 'El respaldo excede el tamaño permitido.' }
            $protectedBytes = [Convert]::FromBase64String((Get-Content -LiteralPath $backupFile -Raw -ErrorAction Stop).Trim())
            $entropy = [Text.Encoding]::UTF8.GetBytes('AegisPhoenixWiFiV1')
            $plainBytes = [Security.Cryptography.ProtectedData]::Unprotect($protectedBytes, $entropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
            $bundle = [Text.Encoding]::UTF8.GetString($plainBytes) | ConvertFrom-Json -ErrorAction Stop
            if ($bundle.SchemaVersion -ne 1 -or $bundle.Protection -ne 'DPAPI-CurrentUser') { throw 'Formato de respaldo no compatible.' }
            $tempDir = & $NewRestrictedTemp
            $profileCount = @($bundle.Profiles).Count
            $progressBar.Maximum = [math]::Max(1, $profileCount)
            foreach ($profile in @($bundle.Profiles)) {
                try {
                    $xmlBytes = [Convert]::FromBase64String([string]$profile.XmlBase64)
                    $sha = [System.Security.Cryptography.SHA256]::Create()
                    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($xmlBytes)) -replace '-', '') } finally { $sha.Dispose() }
                    if ($hash -ne [string]$profile.Sha256) { throw "Hash incorrecto para '$($profile.Name)'." }
                    $safeName = ([string]$profile.Name -replace '[^a-zA-Z0-9._-]', '_') + '.xml'
                    $xmlPath = Join-Path $tempDir $safeName
                    [System.IO.File]::WriteAllBytes($xmlPath, $xmlBytes)
                    $profileXml = Read-AegisSafeXml -Path $xmlPath -MaxCharacters 2097152
                    if ($profileXml.DocumentElement.LocalName -ne 'WLANProfile' -or $profileXml.DocumentElement.NamespaceURI -notmatch '^http://www\.microsoft\.com/networking/WLAN/profile/v\d+$') { throw 'XML WLAN invalido.' }
                    Invoke-AegisNativeProcess -FilePath 'netsh.exe' -ArgumentList @('wlan','add','profile',"filename=$xmlPath",'user=current') -TimeoutSeconds 60 | Out-Null
                    $restored++
                    $progressBar.Value = [math]::Min($progressBar.Maximum, $restored + $errors)
                } catch {
                    $errors++
                    Write-Log -LogLevel ERROR -Message "WIFI: Error importando '$($profile.Name)': $($_.Exception.Message)"
                }
            }
        } catch {
            $errors++
            Write-Log -LogLevel ERROR -Message "WIFI: Respaldo invalido o no descifrable: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("No se pudo abrir el respaldo. Debe restaurarse con el mismo usuario de Windows que lo creo.`n`n$($_.Exception.Message)", "Error", 0, 16) | Out-Null
        } finally {
            if ($tempDir -and (Test-Path -LiteralPath $tempDir)) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        $lblStatus.Text = "Importados $restored perfiles; $errors errores."
        [System.Windows.Forms.MessageBox]::Show($lblStatus.Text, "Resultado", 0, $(if ($errors -eq 0) { 64 } else { 48 }))
        & $ScanWifi
    })

    # 5. ELIMINAR
    $btnDelete.Add_Click({
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) { $targets += $row.Cells["Name"].Value }
        }

        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona una red para eliminar.", "Aviso", 0, 48); return }

        if ([System.Windows.Forms.MessageBox]::Show("Eliminar $($targets.Count) redes Wi-Fi del sistema?\n\nEsta accion olvidara las contrasenas y no se conectara automaticamente.", "Confirmar Eliminacion", 4, 32) -ne 'Yes') { return }

        $autoBackupDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Backup\WiFi'
        if (-not (Test-Path -LiteralPath $autoBackupDir)) { New-Item -Path $autoBackupDir -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        $autoBackupPath = Join-Path $autoBackupDir ("BeforeDelete_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.aegiswifi')
        try {
            Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
            & $CreateEncryptedWifiBackup -Targets $targets -OutputPath $autoBackupPath | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("No se eliminara ningun perfil porque el respaldo cifrado previo fallo:`n`n$($_.Exception.Message)", "Operacion cancelada", 0, 16) | Out-Null
            return
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0
        $progressBar.Maximum = $targets.Count
        $count = 0
        $errors = 0

        try {
            foreach ($ssid in $targets) {
                $count++
                $lblStatus.Text = "Eliminando: $ssid..."
                $progressBar.Value = $count
                $deleteResult = Invoke-AegisNativeProcess -FilePath 'netsh.exe' -ArgumentList @('wlan','delete','profile',"name=$ssid") -TimeoutSeconds 60 -NoThrow
                if (-not $deleteResult.Succeeded) {
                    $errors++
                    Write-Log -LogLevel ERROR -Message "WIFI: Error eliminando '$ssid' (codigo $($deleteResult.ExitCode))."
                }
            }
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        $lblStatus.Text = "Eliminadas $($targets.Count - $errors) redes; $errors errores."
        [System.Windows.Forms.MessageBox]::Show($lblStatus.Text, "Resultado", 0, $(if ($errors -eq 0) { 64 } else { 48 }))
        
        # Recargar lista
        & $ScanWifi
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}