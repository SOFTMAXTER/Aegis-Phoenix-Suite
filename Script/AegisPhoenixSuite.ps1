<#
.SYNOPSIS
    Suite definitiva de optimizacion, gestion, seguridad y diagnostico para Windows 11 y 10.
.DESCRIPTION
    Aegis Phoenix Suite v3.0 by SOFTMAXTER es la herramienta PowerShell definitiva. Con una estructura de submenus y una
    logica de verificacion inteligente, permite maximizar el rendimiento, reforzar la seguridad, gestionar
    software y drivers, y personalizar la experiencia de usuario.
    Requiere ejecucion como Administrador.
.AUTHOR
    SOFTMAXTER
.VERSION
    3.0
#>

# --- Verificacion de Privilegios de Administrador ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script necesita ser ejecutado como Administrador."
    Write-Host "Por favor, cierra esta ventana, haz clic derecho en el archivo del script y selecciona 'Ejecutar como Administrador'."
    Read-Host "Presiona Enter para salir."
    exit
}

# --- CATALOGO CENTRAL DE AJUSTES DEL SISTEMA ---
# Esta es la "fuente de la verdad" para todos los tweaks, ajustes de seguridad, privacidad y UI.
# Cada objeto define un ajuste, permitiendo que los menús y las acciones se generen dinámicamente.
$script:SystemTweaks = @(
    # Categoria: Rendimiento UI
    [PSCustomObject]@{
        Name           = "Acelerar la Aparicion de Menus"
        Category       = "Rendimiento UI"
        Description    = "Reduce el retraso (en ms) al mostrar los menús contextuales del Explorador."
        Method         = "Registry"
        RegistryPath   = "HKCU:\Control Panel\Desktop"
        RegistryKey    = "MenuShowDelay"
        EnabledValue   = "0"
        DefaultValue   = "400"
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Retraso de Apps de Inicio"
        Category       = "Rendimiento UI"
        Description    = "Elimina una demora artificial que Windows aplica a los programas que inician con el sistema."
        Method         = "Registry"
        RegistryPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        RegistryKey    = "StartupDelayInMSec"
        EnabledValue   = 0
        DefaultValue   = 1 # El valor por defecto es no tener la clave, la restauracion la elimina
        RegistryType   = "DWord"
        RestartNeeded  = "Session"
    },

    # Categoria: Rendimiento del Sistema
    [PSCustomObject]@{
        Name           = "Aumentar Prioridad de CPU para Ventana Activa"
        Category       = "Rendimiento del Sistema"
        Description    = "Asigna mas ciclos de CPU a la aplicacion en primer plano, mejorando su respuesta."
        Method         = "Registry"
        RegistryPath   = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        RegistryKey    = "Win32PrioritySeparation"
        EnabledValue   = 26
        DefaultValue   = 2
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Limitacion de Red (Throttling)"
        Category       = "Rendimiento del Sistema"
        Description    = "Elimina el mecanismo de Windows que reserva un 20% del ancho de banda para QoS."
        Method         = "Registry"
        RegistryPath   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        RegistryKey    = "NetworkThrottlingIndex"
        EnabledValue   = 0xffffffff
        DefaultValue   = 1 # El valor por defecto es no tener la clave, la restauracion la elimina
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Desactivar Aceleracion del Raton"
        Category       = "Rendimiento del Sistema"
        Description    = "Configura el raton para una precision 1:1, eliminando la aceleracion de Windows."
        Method         = "Command"
        EnableCommand  = { Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value "0"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "0"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "0" }
        DisableCommand = { Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value "1"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "6"; Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "10" }
        CheckCommand   = { $props = Get-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -ErrorAction SilentlyContinue; return ($props.MouseSpeed -eq "0" -and $props.MouseThreshold1 -eq "0" -and $props.MouseThreshold2 -eq "0") }
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Desactivar VBS (Seguridad Basada en Virtualizacion)"
        Category       = "Rendimiento del Sistema"
        Description    = "Mejora el rendimiento en juegos y maquinas virtuales. Reduce la seguridad."
        Method         = "Command"
        EnableCommand  = { bcdedit /set hypervisorlaunchtype off }
        DisableCommand = { bcdedit /set hypervisorlaunchtype Auto }
        CheckCommand   = { return (bcdedit /enum {current} | Select-String "hypervisorlaunchtype") -like "*Off" }
        RestartNeeded  = "Reboot"
    },

    # Categoria: Seguridad
    [PSCustomObject]@{
        Name           = "Activar Proteccion contra Ransomware"
        Category       = "Seguridad"
        Description    = "Habilita la proteccion de carpetas controladas de Windows Defender."
        Method         = "Command"
        EnableCommand  = { if ((Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue).Status -ne 'Running') { Write-Warning "Windows Defender no está activo. No se puede cambiar este ajuste."; return }; Set-MpPreference -EnableControlledFolderAccess Enabled }
        DisableCommand = { if ((Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue).Status -ne 'Running') { Write-Warning "Windows Defender no está activo. No se puede cambiar este ajuste."; return }; Set-MpPreference -EnableControlledFolderAccess Disabled }
        CheckCommand   = { if ((Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue).Status -ne 'Running') { return 'NotApplicable' }; return (Get-MpPreference -ErrorAction SilentlyContinue).EnableControlledFolderAccess -eq 1 }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Protocolo Inseguro SMBv1"
        Category       = "Seguridad"
        Description    = "Desactiva el protocolo de red obsoleto SMBv1, una importante medida de seguridad."
        Method         = "Command"
        EnableCommand  = { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart }
        DisableCommand = { Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart }
        CheckCommand   = { (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol).State -eq 'Disabled' }
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar PowerShell v2.0"
        Category       = "Seguridad"
        Description    = "Desactiva el antiguo motor de PowerShell v2.0 para reducir la superficie de ataque."
        Method         = "Command"
        EnableCommand  = { Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart; Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart }
        DisableCommand = { Enable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart }
        CheckCommand   = { (Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2).State -eq 'Disabled' }
        RestartNeeded  = "Reboot"
    },

    # Categoria: Privacidad y Telemetria
    [PSCustomObject]@{
        Name           = "Desactivar ID de Publicidad para Apps"
        Category       = "Privacidad y Telemetria"
        Description    = "Evita que las aplicaciones usen tu ID de publicidad para mostrar anuncios personalizados."
        Method         = "Registry"
        RegistryPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        RegistryKey    = "Enabled"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Desactivar Seguimiento de Ubicacion"
        Category       = "Privacidad y Telemetria"
        Description    = "Deshabilita el servicio de localizacion a nivel de sistema."
        Method         = "Registry"
        RegistryPath   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
        RegistryKey    = "DisableLocation"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Limitar Envio de Datos de Escritura"
        Category       = "Privacidad y Telemetria"
        Description    = "Desactiva la personalizacion de entrada de texto para limitar el envio de datos a Microsoft."
        Method         = "Registry"
        RegistryPath   = "HKCU:\Software\Microsoft\Input\Settings"
        RegistryKey    = "IsInputPersonalizationEnabled"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },

     # Categoria: Comportamiento del Sistema y UI
    [PSCustomObject]@{
        Name           = "Deshabilitar la Pantalla de Bloqueo"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Va directamente a la pantalla de inicio de sesion, omitiendo la pantalla de bloqueo."
        Method         = "Registry"
        RegistryPath   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        RegistryKey    = "NoLockScreen"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Habilitar Menu Contextual Clasico (Estilo Win10)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Reemplaza el menu contextual de Windows 11 por el clasico mas completo."
        Method         = "Command"
        EnableCommand  = { $regPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; New-Item -Path $regPath -Force | Out-Null; Set-ItemProperty -Path $regPath -Name '(Default)' -Value '' }
        DisableCommand = { Remove-Item -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force }
        CheckCommand   = { Test-Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' }
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Busqueda con Bing en el Menu Inicio"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Evita que las busquedas en el menu de inicio muestren resultados web de Bing."
        Method         = "Registry"
        RegistryPath   = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
        RegistryKey    = "DisableSearchBoxSuggestions"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Copilot"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Desactiva el asistente Copilot de IA a nivel de directiva de sistema."
        Method         = "Registry"
        RegistryPath   = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
        RegistryKey    = "TurnOffWindowsCopilot"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    }
)
# --- CATALOGO CENTRAL DE SERVICIOS ---
# Define todos los servicios gestionables, su propósito, categoría y estado por defecto.
# Esto hace que la función sea fácilmente extensible.
$script:ServiceCatalog = @(
    # Categoria: Estándar (Servicios que a menudo se pueden desactivar para liberar recursos)
    [PSCustomObject]@{
        Name               = "Fax"
        Description        = "Permite enviar y recibir faxes. Innecesario si no se usa un módem de fax."
        Category           = "Estándar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "PrintSpooler"
        Description        = "Gestiona los trabajos de impresión. Desactivar si no se utiliza ninguna impresora (física o virtual como PDF)."
        Category           = "Estándar"
        DefaultStartupType = "Automatic"
    },
    [PSCustomObject]@{
        Name               = "RemoteRegistry"
        Description        = "Permite a usuarios remotos modificar el registro. Se recomienda desactivarlo por seguridad."
        Category           = "Estándar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "SysMain"
        Description        = "Mantiene y mejora el rendimiento del sistema (antes Superfetch). Puede causar uso de disco en HDD."
        Category           = "Estándar"
        DefaultStartupType = "Automatic"
    },
    [PSCustomObject]@{
        Name               = "TouchKeyboardAndHandwritingPanelService"
        Description        = "Habilita el teclado táctil y el panel de escritura. Innecesario en equipos de escritorio sin pantalla táctil."
        Category           = "Estándar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "WalletService"
        Description        = "Servicio del sistema para la Cartera de Windows. Innecesario si no se utiliza."
        Category           = "Estándar"
        DefaultStartupType = "Manual"
    },
    # Categoria: Avanzado/Opcional (Servicios para funciones específicas)
    [PSCustomObject]@{
        Name               = "TermService"
        Description        = "Permite a los usuarios conectarse de forma remota al equipo usando Escritorio Remoto."
        Category           = "Avanzado"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "WMPNetworkSvc"
        Description        = "Comparte bibliotecas de Windows Media Player con otros dispositivos de la red."
        Category           = "Avanzado"
        DefaultStartupType = "Manual"
    }
)

# --- FUNCIONES DE ACCION (Las herramientas que hacen el trabajo) ---

function Create-RestorePoint {
    Write-Host "`n[+] Creando un punto de restauracion del sistema..." -ForegroundColor Yellow
    try {
        Checkpoint-Computer -Description "AegisPhoenixSuite_v3.0_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')" -RestorePointType "MODIFY_SETTINGS"
        Write-Host "[OK] Punto de restauracion creado exitosamente." -ForegroundColor Green
    } catch { Write-Error "No se pudo crear el punto de restauracion. Error: $_" }
    Read-Host "`nPresiona Enter para volver..."
}

function Manage-SystemServices {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $choice = ''
    while ($choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "             Gestor Interactivo de Servicios           " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Selecciona un servicio para cambiar su estado (Activado/Desactivado)."
        Write-Host ""

        # Almacenar los objetos de servicio con su estado actual para poder seleccionarlos
        $displayItems = [System.Collections.Generic.List[object]]::new()

        foreach ($category in ($script:ServiceCatalog | Select-Object -ExpandProperty Category -Unique)) {
            Write-Host "--- Categoria: $category ---" -ForegroundColor Yellow
            $servicesInCategory = $script:ServiceCatalog | Where-Object { $_.Category -eq $category }

            foreach ($serviceDef in $servicesInCategory) {
                $itemIndex = $displayItems.Count + 1
                $service = Get-Service -Name $serviceDef.Name -ErrorAction SilentlyContinue
                
                $statusText = ""
                $statusColor = "Gray"

                if ($null -ne $service) {
                    if ($service.StartupType -eq 'Disabled') {
                        $statusText = "[Desactivado]"
                        $statusColor = "Red"
                    } else {
                        $statusText = "[Activado]"
                        $statusColor = "Green"
                        if ($service.Status -eq 'Running') {
                            $statusText += " [En Ejecución]"
                        }
                    }
                } else {
                    $statusText = "[No Encontrado]"
                }

                Write-Host ("   [{0,2}] " -f $itemIndex) -NoNewline
                Write-Host ("{0,-25}" -f $statusText) -ForegroundColor $statusColor -NoNewline
                Write-Host $serviceDef.Name -ForegroundColor White
                Write-Host ("        " + $serviceDef.Description) -ForegroundColor Gray
                
                # Añadir el servicio a nuestra lista de seleccionables
                $displayItems.Add($serviceDef)
            }
            Write-Host ""
        }
        
        Write-Host "--- Acciones ---" -ForegroundColor Cyan
        Write-Host "   [Número] - Activar/Desactivar servicio"
        Write-Host "   [R <Número>] - Restaurar servicio a su estado por defecto (Ej: R 2)"
        Write-Host "   [V] - Volver al menú anterior" -ForegroundColor Red
        Write-Host ""
        
        $rawChoice = Read-Host "Selecciona una opción"
        $choice = $rawChoice.Split(' ')[0]
        $number = if ($rawChoice.Split(' ').Count -gt 1) { $rawChoice.Split(' ')[1] } else { $null }

        try {
            if ($choice -match '^\d+$') {
                $index = [int]$choice - 1
                if ($index -ge 0 -and $index -lt $displayItems.Count) {
                    $selectedServiceDef = $displayItems[$index]
                    $service = Get-Service -Name $selectedServiceDef.Name -ErrorAction SilentlyContinue
                    if ($null -eq $service) { throw "El servicio '$($selectedServiceDef.Name)' no se encuentra en el sistema." }

                    $action = if ($service.StartupType -eq 'Disabled') { "Habilitar" } else { "Deshabilitar" }

                    if ($PSCmdlet.ShouldProcess($selectedServiceDef.Name, $action)) {
                        if ($action -eq 'Deshabilitar') {
                            if ($service.Status -eq 'Running') { Stop-Service -Name $service.Name -Force -ErrorAction Stop }
                            Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop
                            Write-Host "[OK] Servicio '$($selectedServiceDef.Name)' ha sido Desactivado." -ForegroundColor Green
                        } else {
                            # Al habilitar, lo restauramos a su estado por defecto
                            Set-Service -Name $service.Name -StartupType $selectedServiceDef.DefaultStartupType -ErrorAction Stop
                            Write-Host "[OK] Servicio '$($selectedServiceDef.Name)' ha sido Habilitado a su estado por defecto ('$($selectedServiceDef.DefaultStartupType)')." -ForegroundColor Green
                        }
                    }
                }
            } elseif ($choice.ToUpper() -eq 'R' -and $number -match '^\d+$') {
                 $index = [int]$number - 1
                 if ($index -ge 0 -and $index -lt $displayItems.Count) {
                    $selectedServiceDef = $displayItems[$index]
                    if ($PSCmdlet.ShouldProcess($selectedServiceDef.Name, "Restaurar a estado por defecto ($($selectedServiceDef.DefaultStartupType))")) {
                        Set-Service -Name $selectedServiceDef.Name -StartupType $selectedServiceDef.DefaultStartupType -ErrorAction Stop
                        Write-Host "[OK] Servicio '$($selectedServiceDef.Name)' restaurado a su estado por defecto." -ForegroundColor Green
                    }
                 }
            } elseif ($choice.ToUpper() -ne 'V') {
                 Write-Warning "Opción no válida."
            }
        } catch {
            Write-Error "Ocurrió un error: $($_.Exception.Message)"
        }

        if ($choice.ToUpper() -ne 'V') { Start-Sleep -Seconds 2 }
    }
}

function Show-CleaningMenu {
    $cleanChoice = '';
	do { Clear-Host;
	Write-Host "Modulo de Limpieza Profunda" -ForegroundColor Cyan;
	Write-Host "Selecciona el nivel de limpieza que deseas ejecutar.";
	Write-Host "";
	Write-Host "   [1] Limpieza Estandar (Archivos temporales)";
	Write-Host "";
	Write-Host "   [2] Limpieza Profunda (Estandar + Papelera, Miniaturas, Informes de Error)";
	Write-Host "";
	Write-Host "   [3] Limpieza Avanzada de Caches (DirectX, Optimizacion de Entrega)";
	Write-Host "";
	Write-Host "   [V] Volver..." -ForegroundColor Red;
    Write-Host ""
	$cleanChoice = Read-Host "Selecciona una opcion"; switch ($cleanChoice) {
		'1' { Write-Host "`n[+] Ejecutando Limpieza Estandar..." -ForegroundColor Yellow;
		Get-ChildItem -Path $env:TEMP, "$env:windir\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue;
		Write-Host "[OK] Archivos temporales eliminados." -ForegroundColor Green }
		'2' { Write-Host "`n[+] Ejecutando Limpieza Profunda..." -ForegroundColor Yellow;
		Get-ChildItem -Path $env:TEMP, "$env:windir\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue;
		Write-Host "[OK] Archivos temporales eliminados."; Clear-RecycleBin -Force -ErrorAction SilentlyContinue;
		Write-Host "[OK] Papelera de Reciclaje vaciada."; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue;
		Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue;
		Start-Process explorer; Write-Host "[OK] Cache de Miniaturas limpiada."; Remove-Item -Path "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue;
		Write-Host "[OK] Informes de Errores eliminados." -ForegroundColor Green } '3' { Write-Warning "Opcion para usuarios avanzados."; if ((Read-Host "Deseas continuar? (S/N)").ToUpper() -eq
		'S') { Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue;
		Write-Host "[OK] Cache de Shaders de DirectX eliminada."; Remove-Item -Path "$env:windir\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -ErrorAction SilentlyContinue;
		Write-Host "[OK] Archivos de Optimizacion de Entrega eliminados." -ForegroundColor Green } }
		'V' { continue };
		default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red } };
		if ($cleanChoice -ne 'V') {
			Read-Host "`nPresiona Enter para continuar..." }
			} while ($cleanChoice -ne 'V')
}

function Show-BloatwareMenu {
    $bloatwareChoice = '';
	do { Clear-Host;
	Write-Host "Modulo de Eliminacion de Bloatware" -ForegroundColor Cyan;
	Write-Host "Selecciona el tipo de bloatware que deseas eliminar.";
	Write-Host "";
	Write-Host "   [1] Eliminar Bloatware de Microsoft (Recomendado)";
	Write-Host "       (Busca y permite eliminar apps preinstaladas por Microsoft)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [2] Eliminar Bloatware de Terceros (Avanzado)";
	Write-Host "       (Busca apps preinstaladas por el fabricante del PC como HP, Dell, etc.)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [V] Volver..." -ForegroundColor Red;
    Write-Host ""
	$bloatwareChoice = Read-Host "Selecciona una opcion"; switch ($bloatwareChoice.ToUpper()) {
		'1' { Manage-Bloatware -Type 'Microsoft' }
		'2' { Manage-Bloatware -Type 'ThirdParty' }
		'V' { continue };
		default {
			Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red;
			Read-Host }
		}
    } while ($bloatwareChoice.ToUpper() -ne 'V')
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

function Manage-StartupApps {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    #region Funciones Auxiliares
    
    function Get-StartupApprovedStatus {
        param(
            [string]$ItemName,
            [string]$BaseKeyPath, # e.g., "HKCU:\Software\Microsoft\Windows\CurrentVersion"
            [string]$ItemType     # 'Run' o 'StartupFolder'
        )

        $approvedKeyPath = "$BaseKeyPath\Explorer\StartupApproved\$ItemType"
        
        if (-not (Test-Path $approvedKeyPath)) {
            return 'Enabled' # Si la clave no existe, todo está habilitado por defecto
        }

        $property = Get-ItemProperty -Path $approvedKeyPath -Name $ItemName -ErrorAction SilentlyContinue
        
        if ($null -eq $property) {
            return 'Enabled' # Si la propiedad no existe para este item, está habilitado
        }

        $binaryData = $property.$ItemName
        if ($null -ne $binaryData -and $binaryData.Length -gt 0) {
            # El estado está en el primer byte. Impar = Deshabilitado, Par = Habilitado.
            if ($binaryData[0] % 2 -ne 0) {
                return 'Disabled'
            }
        }
        return 'Enabled'
    }

    function Get-AllStartupItems {
        $allItems = [System.Collections.Generic.List[psobject]]::new()
        $shell = New-Object -ComObject WScript.Shell

        # 1. Elementos de Registro
        $regLocations = @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion"; Type = "Run" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"; Type = "Run" },
            @{ Path = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion"; Type = "Run" }
        )
        foreach ($location in $regLocations) {
            if (Test-Path $location.Path) {
                Get-Item -Path $location.Path | Get-ItemProperty | ForEach-Object {
                    $propertyNames = $_.PSObject.Properties.Name | Where-Object { $_ -ne 'PSPath' -and $_ -ne 'PSParentPath' -and $_ -ne 'PSChildName' -and $_ -ne 'PSDrive' -and $_ -ne 'PSProvider' }
                    foreach ($name in $propertyNames) {
                        $allItems.Add([PSCustomObject]@{
                            Name     = $name
                            Type     = 'Registry'
                            Status   = Get-StartupApprovedStatus -ItemName $name -BaseKeyPath $location.BaseKey -ItemType $location.Type
                            Command  = $_.$name
                            Path     = $location.Path
                            Selected = $false
                        })
                    }
                }
            }
        }

        # 2. Elementos de Carpetas de Inicio
        $folderLocations = @(
            @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; BaseKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion"; Type = "StartupFolder" },
            @{ Path = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"; BaseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"; Type = "StartupFolder" }
        )
        foreach ($location in $folderLocations) {
            if (Test-Path $location.Path) {
                Get-ChildItem -Path $location.Path -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $targetPath = ""
                    try { $targetPath = $shell.CreateShortcut($_.FullName).TargetPath } catch { $targetPath = "Acceso directo roto" }
                    $allItems.Add([PSCustomObject]@{
                        Name     = $_.Name
                        Type     = 'Folder'
                        Status   = Get-StartupApprovedStatus -ItemName $_.Name -BaseKeyPath $location.BaseKey -ItemType $location.Type
                        Command  = $targetPath
                        Path     = $_.FullName
                        Selected = $false
                    })
                }
            }
        }

        # 3. Elementos Deshabilitados por este script (método propio)
        $disabledRegKeys = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run-Disabled",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run-Disabled",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run-Disabled"
        )
        foreach ($keyPath in $disabledRegKeys) {
            if (Test-Path $keyPath) {
                 Get-Item -Path $keyPath | Get-ItemProperty | ForEach-Object {
                    $propertyNames = $_.PSObject.Properties.Name | Where-Object { $_ -ne 'PSPath' -and $_ -ne 'PSParentPath' -and $_ -ne 'PSChildName' -and $_ -ne 'PSDrive' -and $_ -ne 'PSProvider' }
                    foreach ($name in $propertyNames) {
                        $allItems.Add([PSCustomObject]@{
                            Name     = $name
                            Type     = 'Registry'
                            Status   = 'Disabled'
                            Command  = $_.$name
                            Path     = $keyPath
                            Selected = $false
                        })
                    }
                }
            }
        }
        $disabledFolderPaths = @(
            (Join-Path -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -ChildPath "disabled"),
            (Join-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" -ChildPath "disabled")
        )
        foreach ($folderPath in $disabledFolderPaths) {
            if (Test-Path $folderPath) {
                Get-ChildItem -Path $folderPath -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $targetPath = ""
                    try { $targetPath = $shell.CreateShortcut($_.FullName).TargetPath } catch { $targetPath = "Acceso directo roto" }
                    $allItems.Add([PSCustomObject]@{
                        Name     = $_.Name
                        Type     = 'Folder'
                        Status   = 'Disabled'
                        Command  = $targetPath
                        Path     = $_.FullName
                        Selected = $false
                    })
                }
            }
        }

        # 4. Tareas Programadas
        Get-ScheduledTask | Where-Object { $_.Triggers.TriggerType -contains 'Logon' } | ForEach-Object {
            $action = ($_.Actions | Select-Object -First 1).Execute
            $arguments = ($_.Actions | Select-Object -First 1).Arguments
            $allItems.Add([PSCustomObject]@{
                Name     = $_.TaskName
                Type     = 'Task'
                Status   = if ($_.State -eq 'Disabled') { 'Disabled' } else { 'Enabled' }
                Command  = "$action $arguments"
                Path     = $_.TaskPath
                Selected = $false
            })
        }
        
        # Ordenar por Estado (Habilitados primero) y luego por Nombre
        return $allItems | Sort-Object @{Expression={if ($_.Status -eq 'Enabled') {0} else {1}}}, Name
    }

    #endregion

    # --- Bucle Principal de la Interfaz ---
    $startupItems = Get-AllStartupItems
    $choice = ''

    while ($choice -ne 'V') {
        Clear-Host
        Write-Host "Gestion de Programas de Inicio" -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar un programa."
        
        for ($i = 0; $i -lt $startupItems.Count; $i++) {
            $item = $startupItems[$i]
            $statusMarker = if ($item.Selected) { "[X]" } else { "[ ]" }
            $statusColor = if ($item.Status -eq 'Enabled') { 'Green' } else { 'Red' }

            Write-Host ("   [{0,2}] {1} " -f ($i + 1), $statusMarker) -NoNewline
            Write-Host ("{0,-60}" -f $item.Name) -NoNewline
            Write-Host ("[{0}]" -f $item.Status) -ForegroundColor $statusColor
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [D] Deshabilitar Seleccionados    [H] Habilitar Seleccionados"
        Write-Host "   [T] Seleccionar Todos             [N] Deseleccionar Todos"
        Write-Host "   [R] Refrescar Lista               [V] Volver..." -ForegroundColor Red
        
        $choice = (Read-Host "`nSelecciona una opcion").ToUpper()

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $startupItems.Count) {
            $index = [int]$choice - 1
            $startupItems[$index].Selected = -not $startupItems[$index].Selected
        }
        elseif ($choice -eq 'T') { $startupItems.ForEach({$_.Selected = $true}) }
        elseif ($choice -eq 'N') { $startupItems.ForEach({$_.Selected = $false}) }
        elseif ($choice -eq 'R') { $startupItems = Get-AllStartupItems }
        elseif ($choice -eq 'D' -or $choice -eq 'H') {
            $selectedItems = $startupItems | Where-Object { $_.Selected }
            if ($selectedItems.Count -eq 0) {
                Write-Host "`n[AVISO] No se selecciono ningun programa." -ForegroundColor Yellow
                Read-Host "Presiona Enter para continuar..."
                continue
            }

            foreach ($item in $selectedItems) {
                $actionDescription = if ($choice -eq 'D') { "Deshabilitar" } else { "Habilitar" }
                if (-not($PSCmdlet.ShouldProcess($item.Name, $actionDescription))) {
                    continue
                }
                
                try {
                    switch ($item.Type) {
                        'Registry' {
                            if ($choice -eq 'D' -and $item.Status -eq 'Enabled') {
                                $disabledPath = $item.Path.Replace("\Run","\Run-Disabled")
                                if (-not(Test-Path $disabledPath)) { New-Item -Path $disabledPath -Force | Out-Null }
                                New-ItemProperty -Path $disabledPath -Name $item.Name -Value $item.Command -PropertyType String -Force -ErrorAction Stop
                                Remove-ItemProperty -Path $item.Path -Name $item.Name -Force -ErrorAction Stop
                            } elseif ($choice -eq 'H' -and $item.Status -eq 'Disabled') {
                                $enabledPath = $item.Path -replace "-Disabled", ""
                                New-ItemProperty -Path $enabledPath -Name $item.Name -Value $item.Command -PropertyType String -Force -ErrorAction Stop
                                Remove-ItemProperty -Path $item.Path -Name $item.Name -Force -ErrorAction Stop
                            }
                        }
                        'Folder' {
                             if ($choice -eq 'D' -and $item.Status -eq 'Enabled') {
                                $dir = Split-Path -Parent $item.Path
                                $disabledDir = Join-Path -Path $dir -ChildPath "disabled"
                                if (-not(Test-Path $disabledDir)) { New-Item -Path $disabledDir -ItemType Directory | Out-Null }
                                Move-Item -Path $item.Path -Destination $disabledDir -Force
                            } elseif ($choice -eq 'H' -and $item.Status -eq 'Disabled') {
                                $destinationDir = (Get-Item $item.Path).Directory.Parent.FullName
                                Move-Item -Path $item.Path -Destination $destinationDir -Force
                            }
                        }
                        'Task' {
                             if ($choice -eq 'D' -and $item.Status -ne 'Disabled') {
                                Disable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction Stop
                            } elseif ($choice -eq 'H' -and $item.Status -eq 'Disabled') {
                                Enable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction Stop
                            }
                        }
                    }
                } catch {
                    Write-Warning "No se pudo modificar la entrada '$($item.Name)'. Error: $($_.Exception.Message)"
                }
            }
            # Desmarcar todo y refrescar la lista para ver los cambios
            $startupItems.ForEach({$_.Selected = $false})
            Write-Host "`n[OK] Accion completada. Refrescando lista..." -ForegroundColor Green
            Start-Sleep -Seconds 1
            $startupItems = Get-AllStartupItems
        }
    }
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


function Show-InventoryMenu {
    $parentDir = Split-Path -Parent $PSScriptRoot; $reportDir = Join-Path -Path $parentDir -ChildPath "Reportes"; if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory | Out-Null }; $reportFile = Join-Path -Path $reportDir -ChildPath "Reporte_Inventario_$(Get-Date -Format 'yyyy-MM-dd').txt"; Write-Host "`n[+] Generando reporte en '$reportFile'..." -ForegroundColor Yellow; "--- REPORTE DE HARDWARE ---`n" | Out-File -FilePath $reportFile -Encoding utf8; (Get-ComputerInfo | Select-Object CsName, WindowsProductName, OsHardwareAbstractionLayer, CsProcessors, PhysiscalMemorySize) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; (Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; "`n--- REPORTE DE SOFTWARE INSTALADO ---`n" | Out-File -FilePath $reportFile -Append -Encoding utf8; Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, InstallDate | Format-Table | Out-File -FilePath $reportFile -Append -Encoding utf8; "`n--- REPORTE DE RED ---`n" | Out-File -FilePath $reportFile -Append -Encoding utf8; (Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; Write-Host "[OK] Reporte completo generado en la carpeta '$reportDir'." -ForegroundColor Green; Read-Host "`nPresiona Enter para volver..."
}

function Show-DriverMenu {
    $driverChoice = '';
    do { Clear-Host;
    Write-Host "Modulo de Gestion de Drivers" -ForegroundColor Cyan;
    Write-Host "";
    Write-Host "   [1] Copia de Seguridad de TODOS los drivers (Backup)";
    Write-Host ""
    Write-Host "   [2] Listar drivers de terceros instalados";
    Write-Host "";
    Write-Host "   [V] Volver..." -ForegroundColor Red;
    Write-Host ""
    $driverChoice = Read-Host "Selecciona una opcion"; switch ($driverChoice) {
    '1' { $destPath = Read-Host "Introduce la ruta completa para guardar la copia (ej: C:\MisDrivers)";
    if (-not (Test-Path $destPath)) { New-Item -Path $destPath -ItemType Directory | Out-Null };
    Write-Host "`n[+] Exportando drivers a '$destPath'..." -ForegroundColor Yellow;
    Export-WindowsDriver -Online -Destination $destPath; Write-Host "[OK] Copia de seguridad completada." -ForegroundColor Green }
    '2' { Write-Host "`n[+] Listando drivers no-Microsoft instalados..." -ForegroundColor Yellow;
    Get-WindowsDriver -Online | Where-Object { $_.ProviderName -ne 'Microsoft' } | Format-Table ProviderName, ClassName, Date, Version -AutoSize }
    'V' { continue };
    default {
    Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red } };
    if ($driverChoice -ne 'V') { Read-Host "`nPresiona Enter para continuar..." } 
    } while ($driverChoice -ne 'V')
}

function Show-AdminMenu {
    $adminChoice = '';
    do { Clear-Host;
    Write-Host "Modulo de Administracion de Sistema" -ForegroundColor Cyan;
    Write-Host "";
    Write-Host "   [1] Limpiar Registros de Eventos de Windows";
    Write-Host "   [2] Gestionar Tareas Programadas de Terceros";
    Write-Host "";
    Write-Host "   [V] Volver..." -ForegroundColor Red;
    $adminChoice = Read-Host "Selecciona una opcion"; switch ($adminChoice) {
    '1' { if ((Read-Host "ADVERTENCIA: Esto eliminara los registros de eventos. Estas seguro? (S/N)").ToUpper() -eq
    'S') { $logs = @("Application", "Security", "System", "Setup");
    foreach ($log in $logs) { Clear-EventLog -LogName $log; Write-Host "[OK] Registro '$log' limpiado." -ForegroundColor Green } } }
    '2' { Manage-ScheduledTasks }
    'V' { continue };
    default {
    Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red } };
    if ($adminChoice -ne 'V')
    { Read-Host "`nPresiona Enter para continuar..." }
    } while ($adminChoice -ne 'V')
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

# --- MODULO DE GESTION DE SOFTWARE (MULTI-MOTOR) ---

# Variable global para mantener el motor seleccionado

$script:SoftwareEngine = 'Winget'

function Ensure-ChocolateyIsInstalled {
    if (Get-Command 'choco' -ErrorAction SilentlyContinue) {
        return $true
    }

    Write-Warning "El gestor de paquetes 'Chocolatey' no esta instalado."
    $installChoice = Read-Host "¿Deseas instalarlo ahora? (Esto requiere conexion a internet) (S/N)"
    if ($installChoice.ToUpper() -eq 'S') {
        Write-Host "`n[+] Instalando Chocolatey..." -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force;
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            # Actualizar la variable de entorno PATH para la sesion actual
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Host "`n[OK] Chocolatey instalado correctamente." -ForegroundColor Green
            return $true
        } catch {
            Write-Error "Fallo la instalacion de Chocolatey. Error: $($_.Exception.Message)"
            return $false
        }
    }
    return $false
}

function Invoke-SoftwareAction { 
    [CmdletBinding()] 
    param( 
        [Parameter(Mandatory=$true)] 
        [ValidateSet('Search', 'Install', 'Upgrade')] 
        [string]$Action, 
        
        [Parameter(Mandatory=$true)] 
        [string]$Engine, 
        
        [string]$PackageName, 
        
        [string[]]$PackageId 
    )
    
    $results = @()
    switch ($Engine) {
        'Winget' {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "Winget no esta instalado." }
            switch ($Action) {
                'Search' {
                    $output = winget search $PackageName --accept-source-agreements 2>&1
                    if ($LASTEXITCODE -ne 0) { break }
                    $lines = $output -split "\r?\n"
                    $startProcessing = $false
                    $regex = '^(?<Name>.+?)\s{2,}(?<Id>\S+)\s{2,}(?<Version>\S+)\s*'
                    foreach ($line in $lines) {
                        if ($startProcessing -and $line -match $regex) {
                            $results += [PSCustomObject]@{ Name = $matches.Name.Trim(); Id = $matches.Id.Trim() }
                        }
                        if ($line -like '----*') { $startProcessing = $true }
                    }
                }
                'Install' {
                    winget install --id $PackageName --exact --silent --accept-package-agreements
                }
                'Upgrade' {
                    $output = winget upgrade --include-unknown --accept-source-agreements 2>&1
                    if (($LASTEXITCODE -ne 0) -and ($output -notmatch "No applicable update found|No se encontró ninguna actualización aplicable")) { throw "Fallo al ejecutar winget upgrade." }
                    if ($output -match "No applicable update found|No se encontró ninguna actualización aplicable") { break }
                    $lines = $output -split "\r?\n"
                    $startProcessing = $false
                    $regex = '^(?<Name>.+?)\s{2,}(?<Id>\S+)\s{2,}(?<Version>\S+)\s{2,}(?<Available>\S+)\s*'
                    foreach ($line in $lines) {
                        if ($startProcessing -and $line -match $regex) {
                            $results += [PSCustomObject]@{ Name = $matches.Name.Trim(); Id = $matches.Id.Trim(); Version = $matches.Version.Trim(); Available = $matches.Available.Trim(); Engine = 'Winget' }
                        }
                        if ($line -like '----*') { $startProcessing = $true }
                    }
                }
            }
        }
        'Chocolatey' {
            if (-not (Ensure-ChocolateyIsInstalled)) { throw "Chocolatey no esta disponible." }
            switch ($Action) {
                'Search' {
                    # CORRECCIÓN: Se eliminó --exact para permitir una búsqueda más amplia.
                    $output = choco search $PackageName --limit-output 2>&1
                    if ($output -match "0 packages found.") { break }
                    $lines = $output -split "\r?\n"
                    foreach ($line in $lines) {
                        # CORRECCIÓN: Se añade más robustez al análisis de la línea.
                        if (-not [string]::IsNullOrWhiteSpace($line) -and $line -match '\|') {
                            $parts = $line.Split('|')
                            if ($parts.Count -ge 1) { # Asegurarse de que la línea tiene al menos un nombre
                                $results += [PSCustomObject]@{ Name = $parts[0].Trim(); Id = $parts[0].Trim() }
                            }
                        }
                    }
                }
                'Install' {
                    choco install $PackageName --yes --no-progress
                }
                'Upgrade' {
                    $output = choco outdated --limit-output 2>&1
                    if ($output -match "Chocolatey has determined 0 packages are outdated") { break }
                    $lines = $output -split "\r?\n"
                    foreach ($line in $lines) {
                        if ($line -match '\|') {
                            $parts = $line.Split('|')
                            if ($parts.Count -ge 3) { # Asegurarse de que la línea tiene todos los campos
                               $results += [PSCustomObject]@{ Name = $parts[0].Trim(); Id = $parts[0].Trim(); Version = $parts[1].Trim(); Available = $parts[2].Trim(); Engine = 'Chocolatey' }
                           }
                        }
                    }
                }
            }
        }
    }
    return $results
}


function Show-SoftwareMenu {
    $softwareChoice = ''
    do {
        Clear-Host
        Write-Host "Modulo de Gestion de Software" -ForegroundColor Cyan
        Write-Host "Motor actual: " -NoNewline; Write-Host $script:SoftwareEngine -ForegroundColor Yellow
        Write-Host "-------------------------------------------------------"
        Write-Host "   [E] Cambiar motor (Winget/Chocolatey)"
        Write-Host ""
        Write-Host "   [1] Buscar y aplicar actualizaciones de software (Interactivo)"
        Write-Host ""
        Write-Host "   [2] Instalar software en masa desde un archivo de texto"
        Write-Host ""
        Write-Host "   [3] Buscar e Instalar un software especifico"
        Write-Host ""
        Write-Host "   [V] Volver..." -ForegroundColor Red
        Write-Host ""
        $softwareChoice = Read-Host "Selecciona una opcion"

        switch ($softwareChoice.ToUpper()) {
            'E' {
                if ($script:SoftwareEngine -eq 'Winget') { $script:SoftwareEngine = 'Chocolatey' }
                else { $script:SoftwareEngine = 'Winget' }
            }
            '1' { Manage-SoftwareUpdates }
            '2' { Install-SoftwareFromList }
            '3' { Search-And-Install-Software }
            'V' { continue }
            default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host }
        }
    } while ($softwareChoice.ToUpper() -ne 'V')
}

function Manage-SoftwareUpdates {
    Write-Host "`n[+] Buscando actualizaciones con el motor '$($script:SoftwareEngine)'..." -ForegroundColor Yellow
    try {
        $apps = Invoke-SoftwareAction -Action 'Upgrade' -Engine $script:SoftwareEngine
    } catch {
        Write-Error "No se pudieron obtener las actualizaciones. Error: $($_.Exception.Message)"
        Read-Host "`nPresiona Enter para volver..."; return
    }

    if ($apps.Count -eq 0) {
        Write-Host "`n[OK] ¡Todo tu software esta actualizado segun el motor '$($script:SoftwareEngine)'!" -ForegroundColor Green
        Read-Host "`nPresiona Enter para continuar..."; return
    }
    
    $apps | ForEach-Object { $_ | Add-Member -NotePropertyName 'Selected' -NotePropertyValue $false }

    $choice = ''
    while ($choice -ne 'I' -and $choice -ne 'V') {
        Clear-Host
        Write-Host "Actualizacion Selectiva de Software (Motor: $($script:SoftwareEngine))" -ForegroundColor Cyan
        Write-Host "Se encontraron $($apps.Count) actualizaciones. Escribe el numero para marcar/desmarcar."
        for ($i = 0; $i -lt $apps.Count; $i++) {
            $status = if ($apps[$i].Selected) { "[X]" } else { "[ ]" }
            Write-Host ("   [{0,2}] {1} {2} ({3} -> {4})" -f ($i+1), $status, $apps[$i].Name, $apps[$i].Version, $apps[$i].Available)
        }
        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [I] Instalar Seleccionadas"
        Write-Host "   [T] Seleccionar Todas       [N] No seleccionar ninguna"
        Write-Host "   [V] Volver..." -ForegroundColor Red
        $choice = (Read-Host "`nSelecciona una opcion").ToUpper()
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $apps.Count) {
            $index = [int]$choice - 1; $apps[$index].Selected = -not $apps[$index].Selected
        } elseif ($choice -eq 'T') { $apps.ForEach({$_.Selected = $true}) } 
          elseif ($choice -eq 'N') { $apps.ForEach({$_.Selected = $false}) }
    }

    if ($choice -eq 'I') {
        $appsToUpgrade = $apps | Where-Object { $_.Selected }
        if ($appsToUpgrade.Count -eq 0) { Write-Host "`nNo se selecciono ningun programa para actualizar." -ForegroundColor Yellow } 
        else {
            Write-Host "`n[+] Actualizando software seleccionado..." -ForegroundColor Yellow
            foreach ($app in $appsToUpgrade) {
                Write-Host " - Actualizando $($app.Name)..."
                try {
                    Invoke-SoftwareAction -Action 'Install' -Engine $app.Engine -PackageName $app.Id
                } catch { Write-Warning "No se pudo actualizar '$($app.Name)'. Error: $($_.Exception.Message)" }
            }
            Write-Host "`n[OK] Proceso de actualizacion completado." -ForegroundColor Green
        }
    }
    Read-Host "`nPresiona Enter para volver..."
}

function Install-SoftwareFromList {
    $filePath = Read-Host "Introduce la ruta completa al archivo .txt con los IDs de los paquetes"
    if (-not (Test-Path $filePath)) { Write-Error "Archivo no encontrado."; Read-Host; return }
    
    $programs = Get-Content $filePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($programs.Count -eq 0) { Write-Warning "El archivo esta vacio."; Read-Host; return }

    Write-Host "`n[+] Instalando $($programs.Count) programas con el motor '$($script:SoftwareEngine)'..." -ForegroundColor Yellow
    foreach ($programId in $programs) {
        Write-Host "`n - Instalando '$programId'..."
        try {
            Invoke-SoftwareAction -Action 'Install' -Engine $script:SoftwareEngine -PackageName $programId
            Write-Host "   [OK] '$programId' instalado correctamente." -ForegroundColor Green
        } catch { Write-Warning "No se pudo instalar '$programId'. Error: $($_.Exception.Message)" }
    }
    Write-Host "`n[OK] Proceso completado." -ForegroundColor Green
    Read-Host "`nPresiona Enter para volver..."
}

function Search-And-Install-Software {
    $searchTerm = Read-Host "Introduce el nombre del software a buscar con '$($script:SoftwareEngine)'"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { Write-Warning "Termino de busqueda vacio."; Read-Host; return }
    
    Write-Host "`nBuscando '$searchTerm'..." -ForegroundColor Gray
    try {
        $apps = Invoke-SoftwareAction -Action 'Search' -Engine $script:SoftwareEngine -PackageName $searchTerm
    } catch { Write-Error "Fallo la busqueda. Error: $($_.Exception.Message)"; Read-Host; return }

    if ($apps.Count -eq 0) { Write-Host "`n[INFO] No se encontraron resultados." -ForegroundColor Yellow; Read-Host; return }
    
    Clear-Host
    Write-Host "Resultados de la busqueda para '$searchTerm':" -ForegroundColor Yellow
    for ($i = 0; $i -lt $apps.Count; $i++) { Write-Host ("   [{0,2}] {1} ({2})" -f ($i+1), $apps[$i].Name, $apps[$i].Id) }
    
    $installChoice = Read-Host "`nEscribe el numero del programa a instalar, o 'V' para volver"
    if ($installChoice.ToUpper() -eq 'V') { return }

    if ($installChoice -match '^\d+$' -and [int]$installChoice -ge 1 -and [int]$installChoice -le $apps.Count) {
        $appToInstall = $apps[[int]$installChoice - 1]
        Write-Host "`n[+] Instalando $($appToInstall.Name)..." -ForegroundColor Yellow
        try {
            Invoke-SoftwareAction -Action 'Install' -Engine $script:SoftwareEngine -PackageName $appToInstall.Id
            Write-Host "`n[OK] Instalacion completada." -ForegroundColor Green
        } catch { Write-Error "No se pudo instalar. Error: $($_.Exception.Message)" }
    } else { Write-Warning "Seleccion no valida." }
    Read-Host "`nPresiona Enter para volver..."
}

# --- NUEVO GESTOR DE AJUSTES DEL SISTEMA (BASADO EN CATALOGO) ---

function Get-TweakState {
    param($Tweak)
    try {
        if ($Tweak.Method -eq 'Registry') {
            if (-not (Test-Path $Tweak.RegistryPath)) { return 'Disabled' } # Si la ruta no existe, esta deshabilitado
            $currentValue = (Get-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -ErrorAction Stop).($Tweak.RegistryKey)
            if ($currentValue -eq $Tweak.EnabledValue) { return 'Enabled' } else { return 'Disabled' }
        } elseif ($Tweak.Method -eq 'Command') {
            $checkResult = Invoke-Command $Tweak.CheckCommand
            if ($checkResult -is [string] -and $checkResult -eq 'NotApplicable') {
                return 'NotApplicable'
            }
            if ($checkResult) { return 'Enabled' } else { return 'Disabled' }
        }
    } catch {
        return 'Disabled'
    }
    return 'Disabled'
}

function Set-TweakState {
    param($Tweak, [ValidateSet('Enable', 'Disable')]$Action)
    
    Write-Host " -> Aplicando ' $($Tweak.Name)'..." -ForegroundColor Yellow
    try {
        if ($Action -eq 'Enable') {
            if ($Tweak.Method -eq 'Registry') {
                if (-not (Test-Path $Tweak.RegistryPath)) { New-Item -Path $Tweak.RegistryPath -Force | Out-Null }
                Set-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Value $Tweak.EnabledValue -Type ($Tweak.PSObject.Properties['RegistryType'].Value) -Force
            } elseif ($Tweak.Method -eq 'Command') {
                Invoke-Command $Tweak.EnableCommand
            }
        } else { # Disable
            if ($Tweak.Method -eq 'Registry') {
                if ($Tweak.PSObject.Properties.Contains("DefaultValue") -and $Tweak.DefaultValue -eq 1 -and $Tweak.EnabledValue -eq 0 -and $Tweak.PSObject.Properties.Contains("RegistryKey") -and (Test-Path -Path ($Tweak.RegistryPath))) {
                     Remove-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Force -ErrorAction SilentlyContinue
                } else {
                     Set-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Value $Tweak.DefaultValue -Type ($Tweak.PSObject.Properties['RegistryType'].Value) -Force
                }
            } elseif ($Tweak.Method -eq 'Command') {
                Invoke-Command $Tweak.DisableCommand
            }
        }
        Write-Host "    [OK] Accion completada." -ForegroundColor Green
    } catch {
        Write-Error "No se pudo modificar el ajuste '$($Tweak.Name)'. Error: $($_.Exception.Message)"
    }
}

function Show-TweakManagerMenu {
    $Category = $null
    while ($true) {
        Clear-Host
        if ($null -eq $Category) {
            Write-Host "Gestor de Ajustes del Sistema" -ForegroundColor Cyan
            Write-Host "--------------------------------"
            Write-Host "Selecciona una categoria para ver y modificar los ajustes."
            $categories = $script:SystemTweaks | Select-Object -ExpandProperty Category -Unique | Sort-Object
            for ($i = 0; $i -lt $categories.Count; $i++) {
                Write-Host ("   [{0}] {1}" -f ($i + 1), $categories[$i])
            }
            Write-Host ""
            Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
            $choice = Read-Host "Selecciona una categoria"
            if ($choice.ToUpper() -eq 'V') { return }
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $categories.Count) {
                $Category = $categories[[int]$choice - 1]
            }
        } else {
            Write-Host "Gestor de Ajustes | Categoria: $Category" -ForegroundColor Cyan
            Write-Host "------------------------------------------------"
            $tweaksInCategory = $script:SystemTweaks | Where-Object { $_.Category -eq $Category }
            for ($i = 0; $i -lt $tweaksInCategory.Count; $i++) {
                $tweak = $tweaksInCategory[$i]
                $state = Get-TweakState -Tweak $tweak
                
                $statusText = "[Desactivado]"
                $statusColor = "Red"
                if ($state -eq 'Enabled') { $statusText = "[Activado]"; $statusColor = "Green" }
                if ($state -eq 'NotApplicable') { $statusText = "[No Aplicable]"; $statusColor = "Gray" }

                Write-Host ("   [{0,2}] " -f ($i + 1)) -NoNewline
                Write-Host ("{0,-14}" -f $statusText) -ForegroundColor $statusColor -NoNewline
                Write-Host $tweak.Name -ForegroundColor White
                Write-Host ("        " + $tweak.Description) -ForegroundColor Gray
                Write-Host ""
            }
            Write-Host "   [V] Volver a la seleccion de categoria" -ForegroundColor Red
            
            $choice = Read-Host "Elige un ajuste para [Activar/Desactivar] o selecciona 'V' para volver"

            if ($choice.ToUpper() -eq 'V') { $Category = $null; continue }
            
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $tweaksInCategory.Count) {
                $tweakToToggle = $tweaksInCategory[[int]$choice - 1]
                $currentState = Get-TweakState -Tweak $tweakToToggle
                
                if ($currentState -eq 'NotApplicable') {
                    Write-Warning "Este ajuste no es aplicable en tu sistema (ej. Defender desactivado por otro AV)."
                } else {
                    $action = if ($currentState -eq 'Enabled') { 'Disable' } else { 'Enable' }
                    Set-TweakState -Tweak $tweakToToggle -Action $action
                }

                if ($tweakToToggle.PSObject.Properties.Contains('RestartNeeded') -and $tweakToToggle.RestartNeeded -ne 'None') {
                    Write-Host "`n[AVISO] Este cambio requiere reiniciar $($tweakToToggle.RestartNeeded) para tener efecto completo." -ForegroundColor Yellow
                }
                Read-Host "Presiona Enter para continuar..."
            }
        }
    }
}

# --- FUNCIONES DE MENU PRINCIPAL ---

function Show-OptimizationMenu {
    $optimChoice = '';
	do { Clear-Host;
	Write-Host "=======================================================" -ForegroundColor Cyan;
	Write-Host "            Modulo de Optimizacion y Limpieza          " -ForegroundColor Cyan;
	Write-Host "=======================================================" -ForegroundColor Cyan;
	Write-Host "";
    Write-Host "   [1] Gestor Interactivo de Servicios del Sistema";
    Write-Host "       (Activa, desactiva o restaura servicios de forma segura)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [2] Modulo de Limpieza Profunda";
	Write-Host "       (Libera espacio en disco eliminando archivos basura)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [3] Eliminar Apps Preinstaladas (Dinamico)";
	Write-Host "       (Detecta y te permite elegir que bloatware quitar)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [4] Gestionar Programas de Inicio (Interactivo)";
	Write-Host "       (Controla que aplicaciones arrancan con Windows)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "-------------------------------------------------------";
	Write-Host "";
	Write-Host "   [V] Volver al menu principal" -ForegroundColor Red;
	Write-Host ""
	$optimChoice = Read-Host "Selecciona una opcion"; switch ($optimChoice.ToUpper()) {
        '1' { Manage-SystemServices } # Llamada a la nueva función
        '2' { Show-CleaningMenu }     # Nota: el índice de las siguientes opciones puede necesitar ajuste si cambias el texto del menú
        '3' { Show-BloatwareMenu }
        '4' { Manage-StartupApps }
		'V' { continue };
		default {
			Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red;
			Read-Host }
		} 
	} while ($optimChoice.ToUpper() -ne 'V')
}

function Show-MaintenanceMenu {
    $maintChoice = '';
	do { Clear-Host;
	Write-Host "=======================================================" -ForegroundColor Cyan;
	Write-Host "           Modulo de Mantenimiento y Reparacion        " -ForegroundColor Cyan;
	Write-Host "=======================================================" -ForegroundColor Cyan;
	Write-Host "";
	Write-Host "   [1] Verificar y Reparar Archivos del Sistema (SFC/DISM)";
	Write-Host "       (Soluciona errores de sistema, cuelgues y pantallas azules)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [2] Limpiar Caches de Sistema (DNS, Tienda, etc.)";
	Write-Host "       (Resuelve problemas de conexion a internet y de la Tienda Windows)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [3] Optimizar Unidades (Desfragmentar/TRIM)";
	Write-Host "       (Mejora la velocidad de lectura y la vida util de tus discos)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [4] Generar Reporte de Salud del Sistema (Energia)";
	Write-Host "       (Diagnostica problemas de bateria y consumo de energia)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "-------------------------------------------------------";
	Write-Host "";
	Write-Host "   [V] Volver al menu principal" -ForegroundColor Red;
	Write-Host ""
	$maintChoice = Read-Host "Selecciona una opcion"; switch ($maintChoice.ToUpper()) {
		'1' { Repair-SystemFiles }
		'2' { Clear-SystemCaches }
		'3' { Optimize-Drives }
		'4' { Generate-SystemReport }
		'V' { continue };
		default {
			Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red;
			Read-Host }
			} 
	} while ($maintChoice.ToUpper() -ne 'V')
}

function Show-AdvancedMenu {
    $advChoice = ''; do { 
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "                 Herramientas Avanzadas                " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        # MODIFICADO: Se reemplazaron múltiples entradas por una sola llamada al nuevo gestor.
        Write-Host "   [A] Gestor de Ajustes del Sistema (Tweaks, Seguridad, UI, Privacidad)"
        Write-Host "       (Activa y desactiva individualmente ajustes para optimizar tu sistema)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [I] Inventario y Reportes del Sistema"
        Write-Host "       (Genera un informe detallado del hardware y software de tu PC)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [D] Gestion de Drivers (Backup/Listar)"
        Write-Host "       (Crea una copia de seguridad de tus drivers, esencial para reinstalar Windows)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [W] Gestion de Software (Multi-Motor)"
        Write-Host "       (Actualiza e instala todas tus aplicaciones con Winget o Chocolatey)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------"
        Write-Host ""
        Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
		Write-Host ""
        
        $advChoice = Read-Host "Selecciona una opcion"
        
        # MODIFICADO: El switch ahora apunta a la nueva función Show-TweakManagerMenu.
        switch ($advChoice.ToUpper()) {
            'A' { Show-TweakManagerMenu }
            'I' { Show-InventoryMenu }
            'D' { Show-DriverMenu }
            'W' { Show-SoftwareMenu }
            'V' { continue }
            default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host }
        }
    } while ($advChoice.ToUpper() -ne 'V')
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
        'S' { Write-Host "`nGracias por usar Aegis Phoenix Suite by SOFTMAXTER!" }
        default {
            Write-Host "`n[ERROR] Opcion no valida. Por favor, intenta de nuevo." -ForegroundColor Red
            Read-Host "`nPresiona Enter para continuar..."
        }
    }

} while ($mainChoice.ToUpper() -ne 'S')
