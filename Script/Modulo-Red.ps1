# =================================================================
#  Modulo-Red
#
#  CONTENIDO   : Show-NetworkDiagnosticsMenu
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-AegisJsonAtomic          : escritura atomica de archivos JSON (snapshots/config)
#    - Invoke-AegisNativeProcess      : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#
#  CARGA       : . "$PSScriptRoot\Modulo-Red.ps1"
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

function Show-NetworkDiagnosticsMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Centro de Diagnostico de Red Avanzado"
    $form.Size = New-Object System.Drawing.Size(1000, 720)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANELES ---
    $pnlLeft = New-Object System.Windows.Forms.Panel
    $pnlLeft.Location = New-Object System.Drawing.Point(10, 10)
    $pnlLeft.Size = New-Object System.Drawing.Size(290, 660)
    $pnlLeft.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $form.Controls.Add($pnlLeft)

    # --- SECCION 1: ESTADO EN VIVO ---
    $grpStatus = New-Object System.Windows.Forms.GroupBox
    $grpStatus.Text = "Monitor de Estado"
    $grpStatus.ForeColor = [System.Drawing.Color]::LightGray
    $grpStatus.Location = New-Object System.Drawing.Point(10, 10)
    $grpStatus.Size = New-Object System.Drawing.Size(270, 80)
    $pnlLeft.Controls.Add($grpStatus)

    $lblConnStatus = New-Object System.Windows.Forms.Label
    $lblConnStatus.Text = "Analizando..."
    $lblConnStatus.Location = New-Object System.Drawing.Point(15, 25)
    $lblConnStatus.AutoSize = $true
    $lblConnStatus.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $grpStatus.Controls.Add($lblConnStatus)

    $lblPublicIP = New-Object System.Windows.Forms.Label
    $lblPublicIP.Text = "IP Pub: ..."
    $lblPublicIP.Location = New-Object System.Drawing.Point(15, 50)
    $lblPublicIP.AutoSize = $true
    $lblPublicIP.ForeColor = [System.Drawing.Color]::Cyan
    $grpStatus.Controls.Add($lblPublicIP)

    # --- SECCION 2: DIAGNOSTICO INTELIGENTE ---
    $grpDiag = New-Object System.Windows.Forms.GroupBox
    $grpDiag.Text = "Analisis y Pruebas"
    $grpDiag.ForeColor = [System.Drawing.Color]::Cyan
    $grpDiag.Location = New-Object System.Drawing.Point(10, 100)
    $grpDiag.Size = New-Object System.Drawing.Size(270, 240)
    $pnlLeft.Controls.Add($grpDiag)

    $btnSmartDiag = New-Object System.Windows.Forms.Button
    $btnSmartDiag.Text = "DIAGNOSTICO INTELIGENTE"
    $btnSmartDiag.Location = New-Object System.Drawing.Point(15, 25)
    $btnSmartDiag.Size = New-Object System.Drawing.Size(240, 40)
    $btnSmartDiag.BackColor = [System.Drawing.Color]::Teal
    $btnSmartDiag.ForeColor = [System.Drawing.Color]::White
    $btnSmartDiag.FlatStyle = "Flat"
    $btnSmartDiag.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $grpDiag.Controls.Add($btnSmartDiag)

    $btnIpConfig = New-Object System.Windows.Forms.Button
    $btnIpConfig.Text = "Ver Detalles IP (ipconfig /all)"
    $btnIpConfig.Location = New-Object System.Drawing.Point(15, 75)
    $btnIpConfig.Size = New-Object System.Drawing.Size(240, 30)
    $btnIpConfig.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnIpConfig.ForeColor = [System.Drawing.Color]::White
    $btnIpConfig.FlatStyle = "Flat"
    $grpDiag.Controls.Add($btnIpConfig)

    $btnTrace = New-Object System.Windows.Forms.Button
    $btnTrace.Text = "Trazar Ruta (Tracert Google)"
    $btnTrace.Location = New-Object System.Drawing.Point(15, 115)
    $btnTrace.Size = New-Object System.Drawing.Size(240, 30)
    $btnTrace.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnTrace.ForeColor = [System.Drawing.Color]::White
    $btnTrace.FlatStyle = "Flat"
    $grpDiag.Controls.Add($btnTrace)

    $btnNslookup = New-Object System.Windows.Forms.Button
    $btnNslookup.Text = "Prueba DNS (Nslookup)"
    $btnNslookup.Location = New-Object System.Drawing.Point(15, 155)
    $btnNslookup.Size = New-Object System.Drawing.Size(240, 30)
    $btnNslookup.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnNslookup.ForeColor = [System.Drawing.Color]::White
    $btnNslookup.FlatStyle = "Flat"
    $grpDiag.Controls.Add($btnNslookup)
    
    $btnArp = New-Object System.Windows.Forms.Button
    $btnArp.Text = "Ver Tabla ARP (Dispositivos)"
    $btnArp.Location = New-Object System.Drawing.Point(15, 195)
    $btnArp.Size = New-Object System.Drawing.Size(240, 30)
    $btnArp.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnArp.ForeColor = [System.Drawing.Color]::White
    $btnArp.FlatStyle = "Flat"
    $grpDiag.Controls.Add($btnArp)

    # --- SECCION 3: REPARACION ---
    $grpRepair = New-Object System.Windows.Forms.GroupBox
    $grpRepair.Text = "Herramientas de Reparacion"
    $grpRepair.ForeColor = [System.Drawing.Color]::Orange
    $grpRepair.Location = New-Object System.Drawing.Point(10, 350)
    $grpRepair.Size = New-Object System.Drawing.Size(270, 200)
    $pnlLeft.Controls.Add($grpRepair)

    $btnFlush = New-Object System.Windows.Forms.Button
    $btnFlush.Text = "Limpiar Cache DNS"
    $btnFlush.Location = New-Object System.Drawing.Point(15, 30)
    $btnFlush.Size = New-Object System.Drawing.Size(240, 35)
    $btnFlush.BackColor = [System.Drawing.Color]::FromArgb(70, 50, 50)
    $btnFlush.ForeColor = [System.Drawing.Color]::White
    $btnFlush.FlatStyle = "Flat"
    $grpRepair.Controls.Add($btnFlush)

    $btnRenew = New-Object System.Windows.Forms.Button
    $btnRenew.Text = "Renovar IP (Release/Renew)"
    $btnRenew.Location = New-Object System.Drawing.Point(15, 75)
    $btnRenew.Size = New-Object System.Drawing.Size(240, 35)
    $btnRenew.BackColor = [System.Drawing.Color]::FromArgb(70, 50, 50)
    $btnRenew.ForeColor = [System.Drawing.Color]::White
    $btnRenew.FlatStyle = "Flat"
    $grpRepair.Controls.Add($btnRenew)

    $btnReset = New-Object System.Windows.Forms.Button
    $btnReset.Text = "RESET TOTAL DE RED (Reinicio)"
    $btnReset.Location = New-Object System.Drawing.Point(15, 120)
    $btnReset.Size = New-Object System.Drawing.Size(240, 35)
    $btnReset.BackColor = [System.Drawing.Color]::Maroon
    $btnReset.ForeColor = [System.Drawing.Color]::White
    $btnReset.FlatStyle = "Flat"
    $btnReset.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $grpRepair.Controls.Add($btnReset)
    
    $lblResetWarn = New-Object System.Windows.Forms.Label
    $lblResetWarn.Text = "* Reinicia Winsock y TCP/IP"
    $lblResetWarn.Location = New-Object System.Drawing.Point(15, 165)
    $lblResetWarn.AutoSize = $true
    $lblResetWarn.ForeColor = [System.Drawing.Color]::Gray
    $lblResetWarn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $grpRepair.Controls.Add($lblResetWarn)

    # --- BOTONES INFERIORES ---
    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "Exportar Log"
    $btnExport.Location = New-Object System.Drawing.Point(10, 570)
    $btnExport.Size = New-Object System.Drawing.Size(130, 30)
    $btnExport.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $btnExport.FlatStyle = "Flat"
    $btnExport.ForeColor = [System.Drawing.Color]::White
    $pnlLeft.Controls.Add($btnExport)

    $btnClearLog = New-Object System.Windows.Forms.Button
    $btnClearLog.Text = "Limpiar Log"
    $btnClearLog.Location = New-Object System.Drawing.Point(150, 570)
    $btnClearLog.Size = New-Object System.Drawing.Size(130, 30)
    $btnClearLog.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $btnClearLog.FlatStyle = "Flat"
    $btnClearLog.ForeColor = [System.Drawing.Color]::White
    $pnlLeft.Controls.Add($btnClearLog)

    # --- 3. CONSOLA VIRTUAL (OUTPUT) ---
    $consoleBox = New-Object System.Windows.Forms.RichTextBox
    $consoleBox.Location = New-Object System.Drawing.Point(310, 10)
    $consoleBox.Size = New-Object System.Drawing.Size(660, 660)
    $consoleBox.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 15)
    $consoleBox.ForeColor = [System.Drawing.Color]::LightGreen
    $consoleBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $consoleBox.ReadOnly = $true
    $consoleBox.ScrollBars = "Vertical"
    $form.Controls.Add($consoleBox)

    # --- TOOLTIPS ---
    $tt = New-Object System.Windows.Forms.ToolTip
    $tt.SetToolTip($btnSmartDiag, "Ejecuta una bateria de pruebas: Ping a Gateway, Ping a Internet, Resolucion DNS y Latencia.")
    $tt.SetToolTip($btnReset, "Restablece la pila TCP/IP y Winsock a valores de fabrica. Requiere reinicio.")

    # --- FUNCIONES DE LOGGING ---
    $LogToBox = {
        param($Msg, $Color = "LightGreen", $IsHeader = $false, $IsBold = $false)
        
        $consoleBox.SelectionStart = $consoleBox.TextLength
        $consoleBox.SelectionLength = 0
        $consoleBox.SelectionColor = [System.Drawing.Color]::FromName($Color)
        
        if ($IsBold) { $consoleBox.SelectionFont = New-Object System.Drawing.Font($consoleBox.Font, [System.Drawing.FontStyle]::Bold) }
        else { $consoleBox.SelectionFont = New-Object System.Drawing.Font($consoleBox.Font, [System.Drawing.FontStyle]::Regular) }
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        if ($IsHeader) {
            $consoleBox.AppendText("`r`n" + ("=" * 60) + "`r`n")
            $consoleBox.AppendText(" [$timestamp]  $Msg`r`n")
            $consoleBox.AppendText(("=" * 60) + "`r`n")
        } else {
            if ($Msg -match "^\s*$") { $consoleBox.AppendText("$Msg`r`n") }
            else { $consoleBox.AppendText(" [$timestamp] $Msg`r`n") }
        }
        $consoleBox.ScrollToCaret()
    }

    # --- FUNCION: EJECUCION NATIVA CONTROLADA ---
    $RunAsyncProcess = {
        param($Exe, [string[]]$ArgumentList, $Title, $ClearConsole = $true, [int]$TimeoutSeconds = 120)
        
        if ($ClearConsole) { $consoleBox.Clear() }
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        & $LogToBox -Msg "EJECUTANDO: $Title" -IsHeader $true -Color "Cyan"
        try {
            $nativeResult = Invoke-AegisNativeProcess -FilePath $Exe -ArgumentList $ArgumentList -TimeoutSeconds $TimeoutSeconds -NoThrow
            $stdout = $nativeResult.StdOut
            $err = $nativeResult.StdErr

            foreach ($line in @($stdout -split "`r?`n")) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $c = "White"
                if ($line -match "error|fallo|failed|unreachable|agotado|timed out") { $c = "Salmon" }
                elseif ($line -match "reply|respuesta|ms") { $c = "LightGreen" }
                elseif ($line -match "tracing|trazando|haciendo ping") { $c = "Yellow" }
                if ($line -match "IPv4") { $c = "Cyan" }
                $consoleBox.SelectionStart = $consoleBox.TextLength
                $consoleBox.SelectionColor = [System.Drawing.Color]::FromName($c)
                $consoleBox.AppendText("$line`r`n")
            }
            
            # --- NUEVO BLOQUE DE MANEJO DE STDERR ---
            if (-not [string]::IsNullOrWhiteSpace($err)) {
                # Procesar STDERR línea por línea para mayor precisión
                foreach ($errLine in @($err -split "`r?`n")) {
                    if ([string]::IsNullOrWhiteSpace($errLine)) { continue }
                    
                    # Ignorar la advertencia común de nslookup en múltiples idiomas
                    if ($errLine -notmatch "Non-authoritative|autoritativa") { 
                        # Imprimimos el error nativo directamente, sin el prefijo "STDERR: "
                        & $LogToBox -Msg $errLine.Trim() -Color "Salmon"
                    }
                }
            }
            if (-not $nativeResult.Succeeded) {
                $detail = if ($nativeResult.TimedOut) { "Tiempo de espera agotado." } else { "Codigo $($nativeResult.ExitCode)." }
                & $LogToBox -Msg "El proceso no termino correctamente: $detail" -Color "Salmon"
            }
        } catch {
            & $LogToBox -Msg "Error critico al ejecutar proceso: $_" -Color "Red"
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
        & $LogToBox -Msg "Fin del proceso." -Color "Gray"
    }

    # --- FUNCION: DIAGNOSTICO POR CAPAS ---
    $RunSmartDiag = {
        $consoleBox.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        & $LogToBox -Msg "INICIANDO DIAGNOSTICO INTELIGENTE" -IsHeader $true -Color "Cyan"
        
        $success = $true
        $activeAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')
        & $LogToBox -Msg "PASO 1: Adaptador y enlace..." -Color "Yellow" -IsBold $true
        if ($activeAdapters.Count -eq 0) {
            & $LogToBox -Msg "   [FALLO] No hay adaptadores de red activos." -Color "Red"
            $success = $false
        } else {
            & $LogToBox -Msg "   [OK] Adaptadores activos: $($activeAdapters.Name -join ', ')" -Color "LightGreen"
        }

        # 2. Ruta y gateway. ICMP es informativo, no decide por si solo.
        & $LogToBox -Msg "`r`nPASO 2: Ruta predeterminada y puerta de enlace..." -Color "Yellow" -IsBold $true
        $gateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
            Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
            Sort-Object RouteMetric, InterfaceMetric |
            Select-Object -First 1 -ExpandProperty NextHop
        if ($gateway) {
            try {
                $pingSender = New-Object System.Net.NetworkInformation.Ping
                $reply = $pingSender.Send($gateway, 1000)
                if ($reply.Status -eq 'Success') {
                    & $LogToBox -Msg "   [OK] Router accesible en $gateway (Latencia: $($reply.RoundtripTime) ms)" -Color "LightGreen"
                } else {
                    & $LogToBox -Msg "   [AVISO] El gateway $gateway no responde ICMP; puede estar bloqueado." -Color "Orange"
                }
            } catch {
                & $LogToBox -Msg "   [AVISO] No se pudo probar ICMP al gateway." -Color "Orange"
            }
        } else {
            & $LogToBox -Msg "   [FALLO] No se detecta Puerta de Enlace. Estas conectado?" -Color "Red"
            $success = $false
        }

        # 3. DNS
        & $LogToBox -Msg "`r`nPASO 3: Resolucion DNS..." -Color "Yellow" -IsBold $true
        try {
            $dns = [System.Net.Dns]::GetHostAddresses('www.microsoft.com')
            if (-not $dns) { throw 'Sin respuestas DNS.' }
            & $LogToBox -Msg "   [OK] DNS resolvio www.microsoft.com ($($dns[0].IPAddressToString))." -Color "LightGreen"
        } catch {
            & $LogToBox -Msg "   [FALLO] No se pudo resolver un nombre publico." -Color "Red"
            $success = $false
        }

        # 4. TCP 443 confirma salida aunque ICMP este bloqueado.
        & $LogToBox -Msg "`r`nPASO 4: Salida TCP/HTTPS..." -Color "Yellow" -IsBold $true
        try {
            $tcpOk = Test-NetConnection -ComputerName 'www.microsoft.com' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
            if (-not $tcpOk) { throw 'TCP 443 no disponible.' }
            & $LogToBox -Msg "   [OK] Conexion TCP 443 disponible." -Color "LightGreen"
        } catch {
            & $LogToBox -Msg "   [FALLO] No se pudo establecer HTTPS; revisa firewall, proxy, VPN o ISP." -Color "Red"
            $success = $false
        }

        $ipv6Default = Get-NetRoute -AddressFamily IPv6 -DestinationPrefix '::/0' -ErrorAction SilentlyContinue | Select-Object -First 1
        $vpnAdapters = @($activeAdapters | Where-Object { $_.InterfaceDescription -match 'VPN|TAP|TUN|WireGuard|Virtual' })
        $proxy = try { (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop).ProxyEnable } catch { 0 }
        & $LogToBox -Msg "`r`nCONTEXTO: IPv6=$(if($ipv6Default){'Disponible'}else{'Sin ruta'}); VPN=$($vpnAdapters.Count); Proxy=$(if($proxy){'Activo'}else{'Inactivo'})." -Color "Gray"

        if ($success) {
            & $LogToBox -Msg "`r`n[CONCLUSION] Tu red parece funcionar correctamente." -Color "Cyan" -IsBold $true
        } else {
            & $LogToBox -Msg "`r`n[CONCLUSION] Se detectaron problemas. Revisa los pasos en rojo." -Color "Salmon" -IsBold $true
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }

    # --- EVENTOS ---
    $btnSmartDiag.Add_Click({ & $RunSmartDiag })
    $btnIpConfig.Add_Click({ & $RunAsyncProcess -Exe "ipconfig.exe" -ArgumentList @('/all') -Title "Configuracion IP" })
    $btnTrace.Add_Click({ & $RunAsyncProcess -Exe "tracert.exe" -ArgumentList @('-d','1.1.1.1') -Title "Traza de Ruta" })
    $btnNslookup.Add_Click({ & $RunAsyncProcess -Exe "nslookup.exe" -ArgumentList @('www.microsoft.com') -Title "Prueba DNS" })
    $btnArp.Add_Click({ & $RunAsyncProcess -Exe "arp.exe" -ArgumentList @('-a') -Title "Tabla ARP" })

    $btnFlush.Add_Click({ & $RunAsyncProcess -Exe "ipconfig.exe" -ArgumentList @('/flushdns') -Title "Limpieza de Cache DNS" })
    $btnRenew.Add_Click({ 
        if ([System.Windows.Forms.MessageBox]::Show("Esto desconectara momentaneamente la red. Seguir?", "Confirmar", 'YesNo') -eq 'Yes') {
            & $RunAsyncProcess -Exe "ipconfig.exe" -ArgumentList @('/release') -Title "Liberacion de IP"
            & $RunAsyncProcess -Exe "ipconfig.exe" -ArgumentList @('/renew') -Title "Renovacion de IP" -ClearConsole $false
        }
    })

    $btnReset.Add_Click({
        if ([System.Windows.Forms.MessageBox]::Show("ADVERTENCIA: Esto reiniciara Winsock y la pila TCP/IP.\nEs necesario REINICIAR el PC despues.\n\nContinuar?", "Reset Critico", 'YesNo', 'Warning') -eq 'Yes') {
            $networkSnapshot = [ordered]@{
                CreatedAt=(Get-Date).ToString('o')
                IPConfiguration=@(Get-NetIPConfiguration -Detailed -ErrorAction SilentlyContinue)
                Dns=@(Get-DnsClientServerAddress -ErrorAction SilentlyContinue)
                Adapters=@(Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name,InterfaceDescription,Status,MacAddress,LinkSpeed)
                WinHttpProxy=(Invoke-AegisNativeProcess -FilePath 'netsh.exe' -ArgumentList @('winhttp','show','proxy') -TimeoutSeconds 30 -NoThrow).StdOut
            }
            $snapshotPath = Join-Path (Split-Path -Parent $PSScriptRoot) ("Backup\Network\NetworkBeforeReset_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.json')
            Write-AegisJsonAtomic -InputObject $networkSnapshot -Path $snapshotPath -Depth 20
            $journal = New-AegisOperationJournal -Module 'Red' -Action 'ResetNetwork' -Targets @('Winsock','TCP/IP') -Metadata @{ Snapshot=$snapshotPath }
            & $RunAsyncProcess -Exe "netsh.exe" -ArgumentList @('winsock','reset') -Title "Reset de Winsock"
            & $RunAsyncProcess -Exe "netsh.exe" -ArgumentList @('int','ip','reset') -Title "Reset de TCP/IP" -ClearConsole $false
            Complete-AegisOperationJournal -Journal $journal -Status Completed -Results @("Snapshot: $snapshotPath") | Out-Null
            [System.Windows.Forms.MessageBox]::Show("Reset completado. Por favor reinicia tu equipo.", "Informacion", 0, 64)
        }
    })

    $btnClearLog.Add_Click({ $consoleBox.Clear() })

    $btnExport.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = "Archivo de Texto (*.txt)|*.txt"
        $sfd.FileName = "Diagnostico_Red_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
        if ($sfd.ShowDialog() -eq 'OK') {
            $consoleBox.Text | Out-File $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Log guardado.", "Exito", 0, 64)
        }
    })

    $lblPublicIP.Text = 'IP publica: clic para consultar'
    $lblPublicIP.Cursor = [System.Windows.Forms.Cursors]::Hand
    $lblPublicIP.Add_Click({
        try {
            $lblPublicIP.Text = 'Consultando servicio externo...'
            $web = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 5 -ErrorAction Stop
            $lblPublicIP.Text = "IP publica: $($web.ip)"
        } catch { $lblPublicIP.Text = 'IP publica: no disponible' }
    })

    # Estado inicial local; la IP publica solo se consulta por decision del usuario.
    $form.Add_Shown({
        & $LogToBox -Msg "Bienvenido. Selecciona una opcion para comenzar." -Color "Gray"

        try {
            if (Test-NetConnection -ComputerName 'www.microsoft.com' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue) {
                $lblConnStatus.Text = "CONECTADO"
                $lblConnStatus.ForeColor = [System.Drawing.Color]::LightGreen
            } else {
                $lblConnStatus.Text = "SIN INTERNET"
                $lblConnStatus.ForeColor = [System.Drawing.Color]::Salmon
            }
        } catch {
            $lblConnStatus.Text = "ERROR RED"
            $lblConnStatus.ForeColor = [System.Drawing.Color]::Red
        }
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}