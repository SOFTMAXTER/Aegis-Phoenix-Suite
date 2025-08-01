<#
.SYNOPSIS
    Suite definitiva de optimizacion, gestion, seguridad y diagnostico para Windows 11 y 10.
.DESCRIPTION
    Aegis Phoenix Suite v2.0 by SOFTMAXTER es la herramienta PowerShell definitiva. Con una estructura de submenus y una
    logica de verificacion inteligente, permite maximizar el rendimiento, reforzar la seguridad, gestionar
    software y drivers, y personalizar la experiencia de usuario.
    Requiere ejecucion como Administrador.
.AUTHOR
    SOFTMAXTER
.VERSION
    2.0
#>

# --- Verificacion de Privilegios de Administrador ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script necesita ser ejecutado como Administrador."
    Write-Host "Por favor, cierra esta ventana, haz clic derecho en el archivo del script y selecciona 'Ejecutar como Administrador'."
    Read-Host "Presiona Enter para salir."
    exit
}

# --- FUNCIONES DE ACCION (Las herramientas que hacen el trabajo) ---

function Create-RestorePoint {
    Write-Host "`n[+] Creando un punto de restauracion del sistema..." -ForegroundColor Yellow
    try {
        Checkpoint-Computer -Description "AegisPhoenixSuite_v11.4_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')" -RestorePointType "MODIFY_SETTINGS"
        Write-Host "[OK] Punto de restauracion creado exitosamente." -ForegroundColor Green
    } catch { Write-Error "No se pudo crear el punto de restauracion. Error: $_" }
    Read-Host "`nPresiona Enter para volver..."
}

function Disable-UnnecessaryServices {
    Write-Host "`n[+] Verificando y desactivando servicios innecesarios (Modo Estandar)..." -ForegroundColor Yellow
    $servicesToDisable = @("Fax", "PrintSpooler", "RemoteRegistry", "SysMain", "TouchKeyboardAndHandwritingPanelService", "WalletService", "dmwappushservice", "DusmSvc", "DsSvc", "lfsvc")
    foreach ($s in $servicesToDisable) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.StartupType -eq 'Disabled') { Write-Host "[INFO] El servicio '$s' ya estaba deshabilitado." -ForegroundColor Gray }
            else { if ($svc.Status -eq 'Running') { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Host "[OK] Servicio '$s' deshabilitado." -ForegroundColor Green }
        }
    }
    Write-Host "`n[+] Optimizacion de servicios estandar completada." -ForegroundColor Green
    Read-Host "`nPresiona Enter para volver..."
}

function Show-OptionalServicesMenu {
    $serviceChoice = ''; do { Clear-Host; Write-Host "Desactivar Servicios Opcionales (Avanzado)" -ForegroundColor Cyan; Write-Host "ADVERTENCIA: Desactiva estos servicios solo si sabes que no los necesitas." -ForegroundColor Yellow; Write-Host ""; Write-Host "   [1] Desactivar Servicios de Escritorio Remoto (TermService)"; Write-Host ""; Write-Host "   [2] Desactivar Uso Compartido de Red de Windows Media Player (WMPNetworkSvc)"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $serviceChoice = Read-Host "Selecciona una opcion"; switch ($serviceChoice) { '1' { if ((Read-Host "Estas seguro? (S/N)").ToUpper() -eq 'S') { Set-Service -Name "TermService" -StartupType Disabled -ErrorAction SilentlyContinue; Write-Host "[OK] Servicios de Escritorio Remoto desactivados." -ForegroundColor Green } } '2' { if ((Read-Host "Estas seguro? (S/N)").ToUpper() -eq 'S') { Set-Service -Name "WMPNetworkSvc" -StartupType Disabled -ErrorAction SilentlyContinue; Write-Host "[OK] Servicio de Uso Compartido de Red de WMP desactivado." -ForegroundColor Green } } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red } }; if ($serviceChoice -ne 'V') { Read-Host "`nPresiona Enter para continuar..." } } while ($serviceChoice -ne 'V')
}

function Show-CleaningMenu {
    $cleanChoice = ''; do { Clear-Host; Write-Host "Modulo de Limpieza Profunda" -ForegroundColor Cyan; Write-Host "Selecciona el nivel de limpieza que deseas ejecutar."; Write-Host ""; Write-Host "   [1] Limpieza Estandar (Archivos temporales)"; Write-Host ""; Write-Host "   [2] Limpieza Profunda (Estandar + Papelera, Miniaturas, Informes de Error)"; Write-Host ""; Write-Host "   [3] Limpieza Avanzada de Caches (DirectX, Optimizacion de Entrega)"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $cleanChoice = Read-Host "Selecciona una opcion"; switch ($cleanChoice) { '1' { Write-Host "`n[+] Ejecutando Limpieza Estandar..." -ForegroundColor Yellow; Get-ChildItem -Path $env:TEMP, "$env:windir\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "[OK] Archivos temporales eliminados." -ForegroundColor Green } '2' { Write-Host "`n[+] Ejecutando Limpieza Profunda..." -ForegroundColor Yellow; Get-ChildItem -Path $env:TEMP, "$env:windir\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "[OK] Archivos temporales eliminados."; Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Host "[OK] Papelera de Reciclaje vaciada."; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue; Start-Process explorer; Write-Host "[OK] Cache de Miniaturas limpiada."; Remove-Item -Path "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "[OK] Informes de Errores eliminados." -ForegroundColor Green } '3' { Write-Warning "Opcion para usuarios avanzados."; if ((Read-Host "Deseas continuar? (S/N)").ToUpper() -eq 'S') { Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "[OK] Cache de Shaders de DirectX eliminada."; Remove-Item -Path "$env:windir\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "[OK] Archivos de Optimizacion de Entrega eliminados." -ForegroundColor Green } } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red } }; if ($cleanChoice -ne 'V') { Read-Host "`nPresiona Enter para continuar..." } } while ($cleanChoice -ne 'V')
}

function Show-BloatwareMenu {
    $bloatwareChoice = ''; do { Clear-Host; Write-Host "Modulo de Eliminacion de Bloatware" -ForegroundColor Cyan; Write-Host "Selecciona el tipo de bloatware que deseas eliminar."; Write-Host ""; Write-Host "   [1] Eliminar Bloatware de Microsoft (Recomendado)"; Write-Host "       (Busca y permite eliminar apps preinstaladas por Microsoft)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [2] Eliminar Bloatware de Terceros (Avanzado)"; Write-Host "       (Busca apps preinstaladas por el fabricante del PC como HP, Dell, etc.)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $bloatwareChoice = Read-Host "Selecciona una opcion"; switch ($bloatwareChoice.ToUpper()) { '1' { Manage-Bloatware -Type 'Microsoft' } '2' { Manage-Bloatware -Type 'ThirdParty' } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host } } } while ($bloatwareChoice.ToUpper() -ne 'V')
}

function Manage-Bloatware {
    param([string]$Type)
    if ($Type -eq 'Microsoft') {
        Write-Host "`n[+] Escaneando aplicaciones de Microsoft no esenciales..." -ForegroundColor Yellow
        $essentialAppsBlocklist = @("Microsoft.WindowsStore", "Microsoft.WindowsCalculator", "Microsoft.Windows.Photos", "Microsoft.Windows.Camera", "Microsoft.SecHealthUI", "Microsoft.UI.Xaml", "Microsoft.VCLibs", "Microsoft.NET.Native", "Microsoft.WebpImageExtension", "Microsoft.HEIFImageExtension", "Microsoft.VP9VideoExtensions", "Microsoft.ScreenSketch", "Microsoft.WindowsTerminal", "Microsoft.Paint", "Microsoft.WindowsNotepad")
        $allApps = Get-AppxPackage -AllUsers | Where-Object { $_.Publisher -like "*Microsoft*" -and $_.IsFramework -eq $false -and $_.NonRemovable -eq $false }
        $apps = @(); foreach ($app in $allApps) { $isEssential = $false; foreach ($essential in $essentialAppsBlocklist) { if ($app.Name -like "*$essential*") { $isEssential = $true; break } }; if (-not $isEssential) { $apps += [PSCustomObject]@{Name=$app.Name; PackageName=$app.PackageFullName; Selected=$false} } }
    } else {
        Write-Host "`n[+] Escaneando aplicaciones de terceros..." -ForegroundColor Yellow
        $apps = Get-AppxPackage -AllUsers | Where-Object { $_.Publisher -notlike "*Microsoft*" -and $_.IsFramework -eq $false } | ForEach-Object { [PSCustomObject]@{Name=$_.Name; PackageName=$_.PackageFullName; Selected=$false} }
    }
    if ($apps.Count -eq 0) { Write-Host "`n[OK] No se encontro bloatware de este tipo para eliminar." -ForegroundColor Green; Read-Host "`nPresiona Enter para volver..."; return }
    $choice = ''; while ($choice -ne 'E' -and $choice -ne 'V') { Clear-Host; Write-Host "Eliminacion Selectiva de Bloatware ($Type)" -ForegroundColor Cyan; Write-Host "Escribe el numero para marcar/desmarcar una aplicacion."; for ($i = 0; $i -lt $apps.Count; $i++) { $status = if ($apps[$i].Selected) { "[X]" } else { "[ ]" }; Write-Host ("   [{0,2}] {1} {2}" -f ($i+1), $status, $apps[$i].Name) }; Write-Host ""; Write-Host "--- Acciones ---" -ForegroundColor Yellow; Write-Host "   [E] Eliminar seleccionados"; Write-Host "   [T] Seleccionar Todos"; Write-Host "   [N] No seleccionar ninguno"; Write-Host "   [V] Volver..." -ForegroundColor Red; $choice = (Read-Host "`nSelecciona una opcion").ToUpper(); if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $apps.Count) { $index = [int]$choice - 1; $apps[$index].Selected = -not $apps[$index].Selected } elseif ($choice -eq 'T') { $apps.ForEach({$_.Selected = $true}) } elseif ($choice -eq 'N') { $apps.ForEach({$_.Selected = $false}) } }; if ($choice -eq 'E') { $appsToUninstall = $apps | Where-Object { $_.Selected }; if ($appsToUninstall.Count -eq 0) { Write-Host "`nNo se selecciono ninguna aplicacion." -ForegroundColor Yellow } else { Write-Host "`n[+] Eliminando aplicaciones seleccionadas..." -ForegroundColor Yellow; foreach ($app in $appsToUninstall) { Write-Host " - Eliminando $($app.Name)..."; Remove-AppxPackage -Package $app.PackageName -AllUsers -ErrorAction SilentlyContinue; $provisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app.Name }; if ($provisionedPackage) { foreach ($pkg in $provisionedPackage) { Write-Host "   - Eliminando paquete provisionado: $($pkg.PackageName)" -ForegroundColor Gray; Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue } } }; Write-Host "`n[OK] Proceso completado." -ForegroundColor Green } }; Read-Host "`nPresiona Enter para volver..."
}

function Repair-SystemFiles {
    Write-Host "`n[+] Iniciando la verificacion de archivos del sistema (SFC)..." -ForegroundColor Yellow
    $sfcOutput = sfc /scannow
    $sfcRepaired = $false
    if ($sfcOutput -match "found corrupt files and successfully repaired them|encontro archivos danados y los reparo correctamente") { $sfcRepaired = $true }
    Write-Host "`n[+] Escaneando la salud de la imagen de Windows (DISM ScanHealth)..." -ForegroundColor Yellow
    $dismScanOutput = DISM /Online /Cleanup-Image /ScanHealth
    $dismScanOutputString = $dismScanOutput -join " "
    $dismRepaired = $false
    if ($dismScanOutputString -match "The component store is repairable|El almacen de componentes es reparable") {
        Write-Host "`n[!] Se detecto corrupcion. Iniciando la reparacion (DISM RestoreHealth)..." -ForegroundColor Yellow
        DISM /Online /Cleanup-Image /RestoreHealth
        $dismRepaired = $true
    } else { Write-Host "`n[OK] No se detecto corrupcion en la imagen de Windows." -ForegroundColor Green }
    Write-Host "`n[+] Verificacion y reparacion del sistema completadas." -ForegroundColor Green
    if ($sfcRepaired -or $dismRepaired) { Write-Host "[RECOMENDACION] Se realizaron reparaciones en el sistema. Se recomienda reiniciar el equipo." -ForegroundColor Cyan }
    Read-Host "`nPresiona Enter para volver..."
}

function Clear-SystemCaches { Write-Host "`nLimpiando caches..."; ipconfig /flushdns; wsreset.exe -q; Write-Host "[OK] Caches de DNS y Tienda limpiadas."; Read-Host "`nPresiona Enter para volver..." }
function Optimize-Drives { Write-Host "`nOptimizando unidades..."; Optimize-Volume -DriveLetter C -Verbose; Read-Host "`nPresiona Enter para volver..." }
function Generate-SystemReport { $parentDir = Split-Path -Parent $PSScriptRoot; $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"; if (-not (Test-Path $diagDir)) { New-Item -Path $diagDir -ItemType Directory | Out-Null }; $reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Salud_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').html"; Write-Host "`n[+] Generando reporte de energia..."; powercfg /energy /output $reportPath /duration 30; if (Test-Path $reportPath) { Write-Host "[OK] Reporte generado en: '$reportPath'" -ForegroundColor Green; Start-Process $reportPath } else { Write-Error "No se pudo generar el reporte." }; Read-Host "`nPresiona Enter para volver..." }

# --- FUNCIONES DE SUBMENUS AVANZADOS ---
function Show-AdvancedTweaksMenu {
    $tweakChoice = ''; do { Clear-Host; Write-Host "Modulo de Tweaks de Sistema y Rendimiento" -ForegroundColor Cyan; Write-Host ""; Write-Host "--- Rendimiento de UI ---" -ForegroundColor Yellow; Write-Host "   [1] Acelerar la Aparicion de Menus (MenuShowDelay)"; Write-Host "   [2] Deshabilitar el Retraso de las Aplicaciones de Inicio"; Write-Host ""; Write-Host "--- Rendimiento del Sistema ---" -ForegroundColor Yellow; Write-Host "   [3] Aumentar prioridad de CPU para ventana activa"; Write-Host "   [4] Deshabilitar la Limitacion de Red (NetworkThrottling)"; Write-Host "   [5] Desactivar VBS para maximo rendimiento en juegos"; Write-Host "   [6] Desactivar Aceleracion del Raton (Precision 1:1)"; Write-Host ""; Write-Host "--- Comportamiento del Sistema ---" -ForegroundColor Yellow; Write-Host "   [7] Deshabilitar la Pantalla de Bloqueo"; Write-Host "   [8] Deshabilitar Almacenamiento Reservado"; Write-Host "   [9] Habilitar Mensajes de Estado Detallados"; Write-Host "   [10] Deshabilitar Copilot (Directiva del Sistema)"; Write-Host "   [11] Deshabilitar Cortana (Directiva del Sistema)"; Write-Host "   [12] Deshabilitar Busqueda con Bing en el menu Inicio"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $tweakChoice = Read-Host "Selecciona una opcion"; 
        switch ($tweakChoice) {
            '1' { $delay = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -ErrorAction SilentlyContinue; if ($delay -and $delay.MenuShowDelay -eq '0') { Write-Host "`n[INFO] La aparicion de menus ya esta acelerada." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0'; Write-Host "`n[OK] Aparicion de menus acelerada." -ForegroundColor Green } }
            '2' { $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; $delay = Get-ItemProperty -Path $regPath -Name 'StartupDelayInMSec' -ErrorAction SilentlyContinue; if ($delay -and $delay.StartupDelayInMSec -eq 0) { Write-Host "`n[INFO] El retraso de inicio de apps ya esta deshabilitado." -ForegroundColor Gray } else { New-Item -Path $regPath -Force | Out-Null; Set-ItemProperty -Path $regPath -Name 'StartupDelayInMSec' -Value 0 -Type DWord -Force; Write-Host "`n[OK] Retraso de inicio de apps deshabilitado." -ForegroundColor Green } }
            '3' { $priority = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -ErrorAction SilentlyContinue; if ($priority -and $priority.Win32PrioritySeparation -eq 26) { Write-Host "`n[INFO] La prioridad de CPU para la ventana activa ya esta aumentada." -ForegroundColor Gray } else { New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Force | Out-Null; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 26 -Type DWord -Force; Write-Host "`n[OK] Prioridad de CPU aumentada. Reinicia para aplicar." -ForegroundColor Green } }
            '4' { $throttle = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -ErrorAction SilentlyContinue; if ($throttle -and $throttle.NetworkThrottlingIndex -eq 0xffffffff) { Write-Host "`n[INFO] La limitacion de red ya esta deshabilitada." -ForegroundColor Gray } else { New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Force | Out-Null; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Value 0xFFFFFFFF -Type DWord -Force; Write-Host "`n[OK] Limitacion de red deshabilitada. Reinicia para aplicar." -ForegroundColor Green } }
            '5' { $vbsStatus = (bcdedit /enum {current} | Select-String "hypervisorlaunchtype").ToString().Trim().Split(' ')[-1]; if ($vbsStatus -eq 'Off') { Write-Host "`n[INFO] VBS ya esta desactivado." -ForegroundColor Gray } else { Write-Warning "ADVERTENCIA: Reduce la seguridad."; if ((Read-Host "Estas seguro? (S/N)").ToUpper() -eq 'S') { bcdedit /set hypervisorlaunchtype off; Write-Host "`n[OK] VBS ha sido desactivado. Se requiere un reinicio completo." -ForegroundColor Green } } }
            '6' { $props = Get-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -ErrorAction SilentlyContinue; if ($props.MouseSpeed -eq "0" -and $props.MouseThreshold1 -eq "0" -and $props.MouseThreshold2 -eq "0") { Write-Host "`n[INFO] La aceleracion del raton ya esta desactivada." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value "0"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "0"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "0"; Write-Host "`n[OK] Aceleracion del raton desactivada. Cierra y vuelve a abrir sesion para aplicar." -ForegroundColor Green } }
            '7' { $lockScreen = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreen' -ErrorAction SilentlyContinue; if ($lockScreen -and $lockScreen.NoLockScreen -eq 1) { Write-Host "`n[INFO] La pantalla de bloqueo ya esta deshabilitada." -ForegroundColor Gray } else { New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Force | Out-Null; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreen' -Value 1 -Type DWord -Force; Write-Host "`n[OK] Pantalla de bloqueo deshabilitada." -ForegroundColor Green } }
            '8' { $dismOutput = dism /Online /Get-ReservedStorageState; $stateLine = $dismOutput | Where-Object { $_ -match 'Reserved storage state|Estado de almacenamiento reservado' }; $storageState = if ($stateLine) { $stateLine.Split(':')[-1].Trim() } else { "" }; if ($storageState -eq 'Disabled' -or $storageState -eq 'Deshabilitado') { Write-Host "`n[INFO] El Almacenamiento Reservado ya esta desactivado." -ForegroundColor Gray } else { Write-Warning "Puede causar problemas con actualizaciones si el disco se llena."; if ((Read-Host "Deseas desactivar el Almacenamiento Reservado? (S/N)").ToUpper() -eq 'S') { dism /Online /Set-ReservedStorageState /State:Disabled; Write-Host "`n[OK] Almacenamiento reservado desactivado." -ForegroundColor Green } } }
            '9' { $verboseStatus = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'VerboseStatus' -ErrorAction SilentlyContinue; if ($verboseStatus -and $verboseStatus.VerboseStatus -eq 1) { Write-Host "`n[INFO] Los mensajes de estado detallados ya estan habilitados." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'VerboseStatus' -Value 1 -Type DWord -Force; Write-Host "`n[OK] Mensajes de estado detallados habilitados." -ForegroundColor Green } }
            '10' { $copilotStatus = Get-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -ErrorAction SilentlyContinue; if ($copilotStatus -and $copilotStatus.TurnOffWindowsCopilot -eq 1) { Write-Host "`n[INFO] Copilot ya esta deshabilitado a nivel de sistema." -ForegroundColor Gray } else { $regPath = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; New-Item -Path $regPath -Force | Out-Null; Set-ItemProperty -Path $regPath -Name 'TurnOffWindowsCopilot' -Value 1 -Type DWord -Force; Write-Host "`n[OK] Copilot deshabilitado a nivel de sistema. Reinicia para aplicar." -ForegroundColor Green } }
            '11' { $cortanaStatus = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -ErrorAction SilentlyContinue; if ($cortanaStatus -and $cortanaStatus.AllowCortana -eq 0) { Write-Host "`n[INFO] Cortana ya esta deshabilitada a nivel de sistema." -ForegroundColor Gray } else { $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; New-Item -Path $regPath -Force | Out-Null; Set-ItemProperty -Path $regPath -Name 'AllowCortana' -Value 0 -Type DWord -Force; Write-Host "`n[OK] Cortana deshabilitada a nivel de sistema. Reinicia para aplicar." -ForegroundColor Green } }
            '12' { $bingStatus = Get-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -ErrorAction SilentlyContinue; if ($bingStatus -and $bingStatus.DisableSearchBoxSuggestions -eq 1) { Write-Host "`n[INFO] La busqueda con Bing en el menu Inicio ya esta deshabilitada." -ForegroundColor Gray } else { $regPath = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; New-Item -Path $regPath -Force | Out-Null; Set-ItemProperty -Path $regPath -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord -Force; Write-Host "`n[OK] Busqueda con Bing deshabilitada. Reinicia el Explorador para aplicar." -ForegroundColor Green } }
            'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red }
        }
        if ($tweakChoice -ne 'V') { Read-Host "`nPresiona Enter para continuar..." }
    } while ($tweakChoice -ne 'V')
}
function Show-InventoryMenu {
    $parentDir = Split-Path -Parent $PSScriptRoot; $reportDir = Join-Path -Path $parentDir -ChildPath "Reportes"; if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory | Out-Null }; $reportFile = Join-Path -Path $reportDir -ChildPath "Reporte_Inventario_$(Get-Date -Format 'yyyy-MM-dd').txt"; Write-Host "`n[+] Generando reporte en '$reportFile'..." -ForegroundColor Yellow; "--- REPORTE DE HARDWARE ---`n" | Out-File -FilePath $reportFile -Encoding utf8; (Get-ComputerInfo | Select-Object CsName, WindowsProductName, OsHardwareAbstractionLayer, CsProcessors, PhysiscalMemorySize) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; (Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; "`n--- REPORTE DE SOFTWARE INSTALADO ---`n" | Out-File -FilePath $reportFile -Append -Encoding utf8; Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, InstallDate | Format-Table | Out-File -FilePath $reportFile -Append -Encoding utf8; "`n--- REPORTE DE RED ---`n" | Out-File -FilePath $reportFile -Append -Encoding utf8; (Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; Write-Host "[OK] Reporte completo generado en la carpeta '$reportDir'." -ForegroundColor Green; Read-Host "`nPresiona Enter para volver..."
}
function Show-DriverMenu {
    $driverChoice = ''; do { Clear-Host; Write-Host "Modulo de Gestion de Drivers" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [1] Copia de Seguridad de TODOS los drivers (Backup)"; Write-Host "   [2] Listar drivers de terceros instalados"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $driverChoice = Read-Host "Selecciona una opcion"; switch ($driverChoice) { '1' { $destPath = Read-Host "Introduce la ruta completa para guardar la copia (ej: C:\MisDrivers)"; if (-not (Test-Path $destPath)) { New-Item -Path $destPath -ItemType Directory | Out-Null }; Write-Host "`n[+] Exportando drivers a '$destPath'..." -ForegroundColor Yellow; Export-WindowsDriver -Online -Destination $destPath; Write-Host "[OK] Copia de seguridad completada." -ForegroundColor Green } '2' { Write-Host "`n[+] Listando drivers no-Microsoft instalados..." -ForegroundColor Yellow; Get-WindowsDriver -Online | Where-Object { $_.ProviderName -ne 'Microsoft' } | Format-Table ProviderName, ClassName, Date, Version -AutoSize } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red } }; if ($driverChoice -ne 'V') { Read-Host "`nPresiona Enter para continuar..." } } while ($driverChoice -ne 'V')
}
function Show-AdminMenu {
    $adminChoice = ''; do { Clear-Host; Write-Host "Modulo de Administracion de Sistema" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [1] Limpiar Registros de Eventos de Windows"; Write-Host "   [2] Gestionar Tareas Programadas de Terceros"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $adminChoice = Read-Host "Selecciona una opcion"; switch ($adminChoice) { '1' { if ((Read-Host "ADVERTENCIA: Esto eliminara los registros de eventos. Estas seguro? (S/N)").ToUpper() -eq 'S') { $logs = @("Application", "Security", "System", "Setup"); foreach ($log in $logs) { Clear-EventLog -LogName $log; Write-Host "[OK] Registro '$log' limpiado." -ForegroundColor Green } } } '2' { Manage-ScheduledTasks } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red } }; if ($adminChoice -ne 'V') { Read-Host "`nPresiona Enter para continuar..." } } while ($adminChoice -ne 'V')
}
function Manage-ScheduledTasks {
    $script:tasks = Get-ScheduledTask | Where-Object { $_.Principal.GroupId -ne 'S-1-5-18' } | ForEach-Object { [PSCustomObject]@{Name=$_.TaskName; Path=$_.TaskPath; State=$_.State; Selected=$false} }
    $choice = ''
    while ($choice -ne 'V') {
        Clear-Host
        Write-Host "Gestion de Tareas Programadas de Terceros" -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar una tarea."
        for ($i = 0; $i -lt $script:tasks.Count; $i++) {
            $status = if ($script:tasks[$i].Selected) { "[X]" } else { "[ ]" }
            $stateColor = if ($script:tasks[$i].State -eq 'Ready' -or $script:tasks[$i].State -eq 'Running') { "Green" } else { "Red" }
            Write-Host ("   [{0,2}] {1} {2,-40}" -f ($i+1), $status, $script:tasks[$i].Name) -NoNewline
            Write-Host ("[{0}]" -f $script:tasks[$i].State) -ForegroundColor $stateColor
        }
        Write-Host ""; Write-Host "--- Acciones ---" -ForegroundColor Yellow; Write-Host "   [D] Deshabilitar Seleccionadas"; Write-Host "   [H] Habilitar Seleccionadas"; Write-Host "   [T] Seleccionar Todas"; Write-Host "   [N] No seleccionar ninguna"; Write-Host "   [V] Volver..." -ForegroundColor Red
        $choice = (Read-Host "`nSelecciona una opcion").ToUpper()
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $script:tasks.Count) { $index = [int]$choice - 1; $script:tasks[$index].Selected = -not $script:tasks[$index].Selected }
        elseif ($choice -eq 'T') { $script:tasks.ForEach({$_.Selected = $true}) }
        elseif ($choice -eq 'N') { $script:tasks.ForEach({$_.Selected = $false}) }
        elseif ($choice -eq 'D' -or $choice -eq 'H') {
            $selectedTasks = $script:tasks | Where-Object { $_.Selected }
            if ($selectedTasks.Count -gt 0) {
                foreach ($task in $selectedTasks) {
                    try {
                        if ($choice -eq 'D') { Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name; $task.State = 'Disabled' }
                        else { Enable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name; $task.State = 'Ready' }
                    } catch { Write-Warning "No se pudo cambiar el estado de la tarea '$($task.Name)'." }
                }
                Write-Host "`n[OK] Accion completada para las tareas seleccionadas." -ForegroundColor Green
            } else { Write-Host "`nNo se selecciono ninguna tarea." -ForegroundColor Yellow }
            $script:tasks.ForEach({$_.Selected = $false}) # Desmarcar todo despues de la accion
            Read-Host "`nPresiona Enter para continuar..."
        }
    }
}
function Show-SoftwareMenu {
    $softwareChoice = ''; do { Clear-Host; Write-Host "Modulo de Gestion de Software" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [1] Buscar y aplicar actualizaciones de software (Interactivo)"; Write-Host "   [2] Instalar software en masa desde un archivo de texto"; Write-Host "   [3] Buscar e Instalar un software especifico"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $softwareChoice = Read-Host "Selecciona una opcion"; switch ($softwareChoice.ToUpper()) { '1' { Manage-SoftwareUpdates } '2' { Install-SoftwareFromList } '3' { Search-And-Install-Software } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host } } } while ($softwareChoice.ToUpper() -ne 'V')
}
function Manage-SoftwareUpdates {
    Write-Host "`n[+] Buscando actualizaciones de software disponibles..." -ForegroundColor Yellow
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Host ""; Write-Error "El comando 'winget' no esta instalado o no se encuentra en la ruta del sistema."; Write-Host "Winget es parte del 'Instalador de aplicacion' de la Tienda de Microsoft." -ForegroundColor Gray; Read-Host "`nPresiona Enter para volver..."; return }
    
    Write-Host "[INFO] Sincronizando fuentes de Winget, esto puede tardar un momento..." -ForegroundColor Gray
    try {
        winget source update
    } catch {
        Write-Warning "No se pudieron actualizar las fuentes de Winget. Los resultados pueden no estar al dia."
    }

    try {
        $upgradableOutput = winget upgrade --include-unknown
        if ($LASTEXITCODE -ne 0) { throw "Winget devolvio un error." }
    } catch { Write-Host ""; Write-Error "Ocurrio un error al ejecutar Winget. Puede que sus fuentes esten corruptas o haya un problema de red."; Write-Host "Intenta ejecutar 'winget source reset --force' en una terminal para solucionarlo." -ForegroundColor Gray; Read-Host "`nPresiona Enter para volver..."; return }
    
    $lines = ($upgradableOutput | Out-String) -split "\r?\n"; $apps = @(); $startProcessing = $false
    foreach ($line in $lines) {
        if ($startProcessing -and $line -match '^(?<Name>.+?)\s{2,}(?<Id>\S+)\s{2,}(?<Version>\S+)\s{2,}(?<Available>\S+)\s{2,}(?<Source>\S+)') { $apps += [PSCustomObject]@{ Name = $matches.Name.Trim(); Id = $matches.Id.Trim(); Selected = $false } }
        if ($line -like '----*') { $startProcessing = $true }
    }
    if ($apps.Count -eq 0) { Write-Host "`n[OK] ¡Todo tu software esta actualizado!" -ForegroundColor Green; Read-Host "`nPresiona Enter para continuar..."; return }
    $choice = ''; while ($choice -ne 'I' -and $choice -ne 'V') { Clear-Host; Write-Host "Actualizacion Selectiva de Software" -ForegroundColor Cyan; Write-Host "Se encontraron $($apps.Count) actualizaciones. Escribe el numero para marcar/desmarcar."; for ($i = 0; $i -lt $apps.Count; $i++) { $status = if ($apps[$i].Selected) { "[X]" } else { "[ ]" }; Write-Host ("   [{0,2}] {1} {2}" -f ($i+1), $status, $apps[$i].Name) }; Write-Host ""; Write-Host "--- Acciones ---" -ForegroundColor Yellow; Write-Host "   [I] Instalar Seleccionadas"; Write-Host "   [T] Seleccionar Todas"; Write-Host "   [N] No seleccionar ninguna"; Write-Host "   [V] Volver..." -ForegroundColor Red; $choice = (Read-Host "`nSelecciona una opcion").ToUpper(); if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $apps.Count) { $index = [int]$choice - 1; $apps[$index].Selected = -not $apps[$index].Selected } elseif ($choice -eq 'T') { $apps.ForEach({$_.Selected = $true}) } elseif ($choice -eq 'N') { $apps.ForEach({$_.Selected = $false}) } }; if ($choice -eq 'I') { $appsToUpgrade = $apps | Where-Object { $_.Selected }; if ($appsToUpgrade.Count -eq 0) { Write-Host "`nNo se selecciono ningun programa para actualizar." -ForegroundColor Yellow } else { Write-Host "`n[+] Actualizando software seleccionado..." -ForegroundColor Yellow; foreach ($app in $appsToUpgrade) { Write-Host " - Actualizando $($app.Name)..."; try { winget upgrade --id $app.Id --exact --silent --accept-package-agreements } catch { Write-Warning "No se pudo actualizar '$($app.Name)'." } }; Write-Host "`n[OK] Proceso de actualizacion completado." -ForegroundColor Green } }
    Read-Host "`nPresiona Enter para volver..."
}
function Install-SoftwareFromList {
    $filePath = Read-Host "Introduce la ruta completa al archivo .txt"; if (Test-Path $filePath) { $programs = Get-Content $filePath; foreach ($program in $programs) { Write-Host "`n[+] Instalando '$program'..." -ForegroundColor Yellow; winget install --id $program --exact --silent --accept-package-agreements }; Write-Host "[OK] Proceso completado." -ForegroundColor Green } else { Write-Error "Archivo no encontrado." }; Read-Host "`nPresiona Enter para volver..."
}
function Search-And-Install-Software {
    Write-Host "`n[+] Busqueda e Instalacion de Software via Winget" -ForegroundColor Yellow
    $searchTerm = Read-Host "Introduce el nombre del software a buscar"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { Write-Warning "No se introdujo un termino de busqueda."; Read-Host "`nPresiona Enter para volver..."; return }
    
    Write-Host "`nBuscando '$searchTerm'..." -ForegroundColor Gray
    try {
        $searchOutput = winget search $searchTerm
        $lines = ($searchOutput | Out-String) -split "\r?\n"; $apps = @(); $startProcessing = $false
        foreach ($line in $lines) {
            if ($startProcessing -and $line -match '^(?<Name>.+?)\s{2,}(?<Id>\S+)\s{2,}(?<Version>\S+)') { $apps += [PSCustomObject]@{ Name = $matches.Name.Trim(); Id = $matches.Id.Trim() } }
            if ($line -like '----*') { $startProcessing = $true }
        }
        if ($apps.Count -eq 0) { Write-Host "`n[INFO] No se encontraron resultados para '$searchTerm'." -ForegroundColor Yellow; Read-Host "`nPresiona Enter para volver..."; return }
        
        Clear-Host
        Write-Host "Resultados de la busqueda para '$searchTerm':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $apps.Count; $i++) { Write-Host ("   [{0,2}] {1} ({2})" -f ($i+1), $apps[$i].Name, $apps[$i].Id) }
        Write-Host ""
        $installChoice = Read-Host "Escribe el numero del programa a instalar, o 'V' para volver"
        if ($installChoice.ToUpper() -ne 'V') {
            if ($installChoice -match '^\d+$' -and [int]$installChoice -ge 1 -and [int]$installChoice -le $apps.Count) {
                $appToInstall = $apps[[int]$installChoice - 1]
                Write-Host "`n[+] Instalando $($appToInstall.Name)..." -ForegroundColor Yellow
                try {
                    winget install --id $appToInstall.Id --exact --silent --accept-package-agreements
                    Write-Host "`n[OK] Instalacion completada." -ForegroundColor Green
                } catch { Write-Error "No se pudo instalar '$($appToInstall.Name)'." }
            } else { Write-Warning "Seleccion no valida." }
        }
    } catch { Write-Error "Ocurrio un error al ejecutar la busqueda con Winget." }
    Read-Host "`nPresiona Enter para volver..."
}
function Show-SecurityMenu {
    $securityChoice = ''; do { Clear-Host; Write-Host "Modulo de Refuerzo de Seguridad" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [1] Activar Proteccion contra Ransomware"; Write-Host "   [2] Deshabilitar protocolo inseguro SMBv1"; Write-Host "   [3] Deshabilitar PowerShell v2.0 (Recomendado)"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $securityChoice = Read-Host "Selecciona una opcion"; 
        switch ($securityChoice) {
            '1' { $cfaStatus = (Get-MpPreference).EnableControlledFolderAccess; if ($cfaStatus -eq 1) { Write-Host "`n[INFO] La Proteccion contra Ransomware ya esta activada." -ForegroundColor Gray } else { Set-MpPreference -EnableControlledFolderAccess Enabled; Write-Host "`n[OK] Proteccion contra Ransomware activada." -ForegroundColor Green } }
            '2' { $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol; if ($smb1.State -eq 'Disabled') { Write-Host "`n[INFO] El protocolo SMBv1 ya esta deshabilitado." -ForegroundColor Gray } else { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue; Write-Host "`n[OK] SMBv1 deshabilitado. Requiere reinicio." -ForegroundColor Green } }
            '3' { $ps2 = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2; if ($ps2.State -eq 'Disabled') { Write-Host "`n[INFO] PowerShell v2.0 ya esta deshabilitado." -ForegroundColor Gray } else { Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart -ErrorAction SilentlyContinue; Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart -ErrorAction SilentlyContinue; Write-Host "`n[OK] PowerShell v2.0 deshabilitado. Requiere reinicio." -ForegroundColor Green } }
            'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red }
        }
        if ($securityChoice -ne 'V') { Read-Host "`nPresiona Enter para continuar..." }
    } while ($securityChoice -ne 'V')
}
function Show-UICustomizationMenu {
    $uiChoice = ''; do { Clear-Host; Write-Host "Modulo de Personalizacion Avanzada de UI" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [1] Alinear Barra de Tareas a la Izquierda"; Write-Host "   [2] Alinear Barra de Tareas al Centro (Default)"; Write-Host "   [3] Activar/Desactivar Menu Contextual Clasico (Win10)"; Write-Host "   [4] Quitar/Restaurar icono 'Mas informacion' del escritorio"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $uiChoice = Read-Host "Selecciona una opcion"; 
        switch ($uiChoice) {
            '1' { $align = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -ErrorAction SilentlyContinue; if ($align -and $align.TaskbarAl -eq 0) { Write-Host "`n[INFO] La barra de tareas ya esta alineada a la izquierda." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 0 -Force; Write-Host "`n[OK] Barra de tareas a la izquierda." -ForegroundColor Green } }
            '2' { $align = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -ErrorAction SilentlyContinue; if ($align -and $align.TaskbarAl -eq 1) { Write-Host "`n[INFO] La barra de tareas ya esta alineada al centro." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 1 -Force; Write-Host "`n[OK] Barra de tareas al centro." -ForegroundColor Green } }
            '3' { $regPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"; if (Test-Path $regPath) { Remove-Item -Path $regPath -Recurse -Force; Write-Host "`n[OK] Menu contextual moderno (Win11) restaurado." -ForegroundColor Green } else { New-Item -Path "$regPath\InprocServer32" -Force | Out-Null; Set-ItemProperty -Path "$regPath\InprocServer32" -Name '(Default)' -Value ''; Write-Host "`n[OK] Menu contextual clasico (Win10) activado." -ForegroundColor Green } }
            '4' { $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-648d-4f29-a13a-a10c2f2dc6b4}"; if (-not(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null; Write-Host "`n[OK] Icono 'Mas informacion sobre esta imagen' restaurado." -ForegroundColor Green } else { Remove-Item -Path $regPath -Recurse -Force; Write-Host "`n[OK] Icono 'Mas informacion sobre esta imagen' quitado." -ForegroundColor Green } }
            'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red }
        }
        if ($uiChoice -ne 'V') { Write-Host "`n[INFO] Reiniciando el Explorador..." -ForegroundColor Gray; Stop-Process -Name explorer -Force; Read-Host "`nPresiona Enter..." }
    } while ($uiChoice -ne 'V')
}
function Show-PrivacyMenu {
    $privacyChoice = ''; do { Clear-Host; Write-Host "Modulo de Privacidad" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [1] Desactivar ID de publicidad para apps"; Write-Host "   [2] Desactivar seguimiento de ubicacion"; Write-Host "   [3] Desactivar sugerencias y contenido promocionado"; Write-Host "   [4] Limitar envio de datos de escritura"; Write-Host ""; Write-Host "   [V] Volver..." -ForegroundColor Red; $privacyChoice = Read-Host "Selecciona una opcion"; 
        switch ($privacyChoice) {
            '1' { $adId = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -ErrorAction SilentlyContinue; if ($adId -and $adId.Enabled -eq 0) { Write-Host "`n[INFO] El ID de publicidad ya esta desactivado." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0 -Force; Write-Host "`n[OK] ID de publicidad desactivado." -ForegroundColor Green } }
            '2' { $loc = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -ErrorAction SilentlyContinue; if ($loc -and $loc.DisableLocation -eq 1) { Write-Host "`n[INFO] El seguimiento de ubicacion ya esta desactivado." -ForegroundColor Gray } else { New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1 -Type DWord -Force; Write-Host "`n[OK] Seguimiento de ubicacion desactivado." -ForegroundColor Green } }
            '3' { $suggestions = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -ErrorAction SilentlyContinue; if ($suggestions -and $suggestions.SilentInstalledAppsEnabled -eq 0) { Write-Host "`n[INFO] Las sugerencias ya estan desactivadas." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-3b3e-4bff-8355-3c44f6a52bb5' -Value 0 -Force -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 0 -Force; Write-Host "`n[OK] Sugerencias desactivadas." -ForegroundColor Green } }
            '4' { $typing = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Input\Settings' -Name 'IsInputPersonalizationEnabled' -ErrorAction SilentlyContinue; if ($typing -and $typing.IsInputPersonalizationEnabled -eq 0) { Write-Host "`n[INFO] El envio de datos de escritura ya esta limitado." -ForegroundColor Gray } else { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Input\Settings' -Name 'IsInputPersonalizationEnabled' -Value 0 -Type DWord -Force; Write-Host "`n[OK] Envio de datos de escritura limitado." -ForegroundColor Green } }
            'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red }
        }
        if ($privacyChoice -ne 'V') { Read-Host "`nPresiona Enter..." }
    } while ($privacyChoice -ne 'V')
}

# --- MODULO DE RESTAURACION ---

function Restore-Services {
    Write-Host "`n[+] Restaurando servicios a sus valores por defecto..." -ForegroundColor Yellow
    Set-Service -Name "Fax" -StartupType Manual -ErrorAction SilentlyContinue; Write-Host "[OK] Servicio 'Fax' restaurado a Manual."
    Set-Service -Name "PrintSpooler" -StartupType Automatic -ErrorAction SilentlyContinue; Write-Host "[OK] Servicio 'PrintSpooler' restaurado a Automatic."
    Set-Service -Name "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue; Write-Host "[OK] Servicio 'SysMain' restaurado a Automatic."
    Read-Host "`nPresiona Enter para volver..."
}

function Restore-Tweaks {
    Write-Host "`n[+] Restaurando tweaks a sus valores por defecto..." -ForegroundColor Yellow
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '400'; Write-Host "[OK] Retraso de menus restaurado."
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -ErrorAction SilentlyContinue; Write-Host "[OK] Retraso de inicio de apps restaurado."
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 2 -Type DWord -Force; Write-Host "[OK] Prioridad de CPU restaurada."
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -ErrorAction SilentlyContinue; Write-Host "[OK] Limitacion de red restaurada."
    bcdedit /set hypervisorlaunchtype Auto; Write-Host "[OK] VBS restaurado a Automatico (Requiere reinicio)."
    Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value "1"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "6"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "10"; Write-Host "[OK] Aceleracion de raton restaurada."
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreen' -ErrorAction SilentlyContinue; Write-Host "[OK] Pantalla de bloqueo restaurada."
    dism /Online /Set-ReservedStorageState /State:Enabled; Write-Host "[OK] Almacenamiento Reservado restaurado."
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'VerboseStatus' -ErrorAction SilentlyContinue; Write-Host "[OK] Mensajes de estado detallados restaurados."
    Remove-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -ErrorAction SilentlyContinue; Write-Host "[OK] Directiva de Copilot restaurada."
    Read-Host "`nPresiona Enter para volver..."
}

function Restore-Security {
    Write-Host "`n[+] Restaurando configuraciones de seguridad a sus valores por defecto..." -ForegroundColor Yellow
    Set-MpPreference -EnableControlledFolderAccess Disabled; Write-Host "[OK] Proteccion contra Ransomware desactivada."
    Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue; Write-Host "[OK] SMBv1 restaurado (Requiere reinicio)."
    Enable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart -ErrorAction SilentlyContinue; Write-Host "[OK] PowerShell v2.0 restaurado (Requiere reinicio)."
    Read-Host "`nPresiona Enter para volver..."
}

function Restore-Privacy {
    Write-Host "`n[+] Restaurando configuraciones de privacidad a sus valores por defecto..." -ForegroundColor Yellow
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 1 -Force; Write-Host "[OK] ID de publicidad reactivado."
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -ErrorAction SilentlyContinue; Write-Host "[OK] Seguimiento de ubicacion reactivado."
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 1 -Force; Write-Host "[OK] Sugerencias reactivadas."
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Input\Settings' -Name 'IsInputPersonalizationEnabled' -Value 1 -Type DWord -Force; Write-Host "[OK] Envio de datos de escritura reactivado."
    Read-Host "`nPresiona Enter para volver..."
}

# --- FUNCIONES DE MENU PRINCIPAL ---

function Show-OptimizationMenu {
    $optimChoice = '';
    do {
    Clear-Host;
    Write-Host "=======================================================" -ForegroundColor Cyan;
    Write-Host "            Modulo de Optimizacion y Limpieza          " -ForegroundColor Cyan;
    Write-Host "=======================================================" -ForegroundColor Cyan;
    Write-Host "";
    Write-Host "   [1] Desactivar Servicios Innecesarios (Estandar)";
    Write-Host "       (Libera memoria RAM y recursos del sistema)" -ForegroundColor Gray;
    Write-Host "";
    Write-Host "   [2] Desactivar Servicios Opcionales (Avanzado)";
    Write-Host "       (Para funciones especificas como Escritorio Remoto)" -ForegroundColor Gray;
    Write-Host "";
    Write-Host "   [3] Modulo de Limpieza Profunda";
    Write-Host "       (Libera espacio en disco eliminando archivos basura)" -ForegroundColor Gray;
    Write-Host ""; Write-Host "   [4] Eliminar Apps Preinstaladas (Dinamico)";
    Write-Host "       (Detecta y te permite elegir que bloatware quitar)" -ForegroundColor Gray;
    Write-Host "";
    Write-Host "-------------------------------------------------------"; Write-Host "";
    Write-Host "   [V] Volver al menu principal" -ForegroundColor Red;
    $optimChoice = Read-Host "Selecciona una opcion"; switch ($optimChoice.ToUpper()) {
    '1' { Disable-UnnecessaryServices }
    '2' { Show-OptionalServicesMenu }
    '3' { Show-CleaningMenu }
    '4' { Show-BloatwareMenu }
    'V' { continue };
    default {
    Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host }
    }
  } while ($optimChoice.ToUpper() -ne 'V')
}

function Show-MaintenanceMenu {
    $maintChoice = ''; do { Clear-Host; Write-Host "=======================================================" -ForegroundColor Cyan; Write-Host "           Modulo de Mantenimiento y Reparacion        " -ForegroundColor Cyan; Write-Host "=======================================================" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [1] Verificar y Reparar Archivos del Sistema (SFC/DISM)"; Write-Host "       (Soluciona errores de sistema, cuelgues y pantallas azules)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [2] Limpiar Caches de Sistema (DNS, Tienda, etc.)"; Write-Host "       (Resuelve problemas de conexion a internet y de la Tienda Windows)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [3] Optimizar Unidades (Desfragmentar/TRIM)"; Write-Host "       (Mejora la velocidad de lectura y la vida util de tus discos)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [4] Generar Reporte de Salud del Sistema (Energia)"; Write-Host "       (Diagnostica problemas de bateria y consumo de energia)" -ForegroundColor Gray; Write-Host ""; Write-Host "-------------------------------------------------------"; Write-Host ""; Write-Host "   [V] Volver al menu principal" -ForegroundColor Red; $maintChoice = Read-Host "Selecciona una opcion"; switch ($maintChoice.ToUpper()) { '1' { Repair-SystemFiles } '2' { Clear-SystemCaches } '3' { Optimize-Drives } '4' { Generate-SystemReport } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host } } } while ($maintChoice.ToUpper() -ne 'V')
}

function Show-AdvancedMenu {
    $advChoice = ''; do { Clear-Host; Write-Host "=======================================================" -ForegroundColor Cyan; Write-Host "                 Herramientas Avanzadas                " -ForegroundColor Cyan; Write-Host "=======================================================" -ForegroundColor Cyan; Write-Host ""; Write-Host "   [T] Tweaks de Sistema y Rendimiento"; Write-Host "       (Ajustes finos para gaming, productividad y comportamiento del sistema)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [I] Inventario y Reportes del Sistema"; Write-Host "       (Genera un informe detallado del hardware y software de tu PC)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [D] Gestion de Drivers (Backup/Listar)"; Write-Host "       (Crea una copia de seguridad de tus drivers, esencial para reinstalar Windows)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [L] Gestion de Logs y Tareas Programadas"; Write-Host "       (Herramientas para depuracion y analisis avanzado)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [W] Gestion de Software (Winget)"; Write-Host "       (Actualiza e instala todas tus aplicaciones facilmente)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [H] Refuerzo de Seguridad (Hardening)"; Write-Host "       (Aplica configuraciones para hacer tu sistema mas resistente a ataques)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [U] Personalizacion Avanzada de UI"; Write-Host "       (Modifica la apariencia de Windows 11 a tu gusto)" -ForegroundColor Gray; Write-Host ""; Write-Host "   [P] Privacidad"; Write-Host "       (Reduce la cantidad de datos que tu sistema envia a Microsoft)" -ForegroundColor Gray; Write-Host ""; Write-Host "-------------------------------------------------------"; Write-Host ""; Write-Host "   [V] Volver al menu principal" -ForegroundColor Red; $advChoice = Read-Host "Selecciona una opcion"; switch ($advChoice.ToUpper()) { 'T' { Show-AdvancedTweaksMenu } 'I' { Show-InventoryMenu } 'D' { Show-DriverMenu } 'L' { Show-AdminMenu } 'W' { Show-SoftwareMenu } 'H' { Show-SecurityMenu } 'U' { Show-UICustomizationMenu } 'P' { Show-PrivacyMenu } 'V' { continue }; default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host } } } while ($advChoice.ToUpper() -ne 'V')
}

function Show-RestoreMenu {
    $restoreChoice = '';
    do { Clear-Host;
    Write-Host "=======================================================" -ForegroundColor Cyan;
    Write-Host "                 Modulo de Restauracion                " -ForegroundColor Cyan;
    Write-Host "=======================================================" -ForegroundColor Cyan;
    Write-Host "";
    Write-Host "   [1] Restaurar Servicios a valores por defecto";
    Write-Host "       (Rehabilita los servicios desactivados por la suite)" -ForegroundColor Gray;
    Write-Host "";
    Write-Host "   [2] Restaurar Tweaks a valores por defecto";
    Write-Host "       (Revierte todos los cambios del modulo de Tweaks)" -ForegroundColor Gray;
    Write-Host "";
    Write-Host "   [3] Restaurar Configuraciones de Seguridad";
    Write-Host "       (Revierte los cambios del modulo de Refuerzo de Seguridad)" -ForegroundColor Gray;
    Write-Host "";
    Write-Host "   [4] Restaurar Configuraciones de Privacidad";
    Write-Host "       (Rehabilita la telemetria y otras funciones de datos)" -ForegroundColor Gray;
    Write-Host ""; Write-Host "-------------------------------------------------------";
    Write-Host "";
    Write-Host "   [V] Volver al menu principal" -ForegroundColor Red;
    $restoreChoice = Read-Host "Selecciona una opcion"; switch ($restoreChoice.ToUpper()) {
    '1' { Restore-Services }
    '2' { Restore-Tweaks }
    '3' { Restore-Security }
    '4' { Restore-Privacy }
    'V' { continue };
    default {
    Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red;
    Read-Host } 
    }
  } while ($restoreChoice.ToUpper() -ne 'V')
}

# --- BUCLE PRINCIPAL DEL SCRIPT ---
$mainChoice = ''
do {
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "        Aegis Phoenix Suite v2.0 by SOFTMAXTER        " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1] Crear Punto de Restauracion" -ForegroundColor White
    Write-Host "       (Tu red de seguridad. ¡Usar siempre antes de hacer cambios!)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "--- MODULOS PRINCIPALES ---" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [2] Modulo de Optimizacion y Limpieza" -ForegroundColor Green
    Write-Host "       (Mejora el rendimiento y libera espacio en disco)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   [3] Modulo de Mantenimiento y Reparacion" -ForegroundColor Green
    Write-Host "       (Soluciona problemas y diagnostica el estado de tu sistema)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   [4] Herramientas Avanzadas" -ForegroundColor Yellow
    Write-Host "       (Accede a todos los modulos de personalizacion, seguridad y gestion)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   [5] Modulo de Restauracion" -ForegroundColor Magenta
    Write-Host "       (Revierte los cambios aplicados por la suite a los valores por defecto)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "-------------------------------------------------------"
    Write-Host ""
    Write-Host "   [S] Salir del script" -ForegroundColor Red
    Write-Host ""

    $mainChoice = Read-Host "Selecciona una opcion y presiona Enter"

    switch ($mainChoice.ToUpper()) {
        '1' { Create-RestorePoint }
        '2' { Show-OptimizationMenu }
        '3' { Show-MaintenanceMenu }
        '4' { Show-AdvancedMenu }
        '5' { Show-RestoreMenu }
        'S' { Write-Host "`nGracias por usar Aegis Phoenix Suite by SOFTMAXTER!" }
        default {
            Write-Host "`n[ERROR] Opcion no valida. Por favor, intenta de nuevo." -ForegroundColor Red
            Read-Host "`nPresiona Enter para continuar..."
        }
    }

} while ($mainChoice.ToUpper() -ne 'S')
