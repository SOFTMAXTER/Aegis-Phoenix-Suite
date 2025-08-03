<#
.SYNOPSIS
    Suite definitiva de optimizacion, gestion, seguridad y diagnostico para Windows 11 y 10.
.DESCRIPTION
    Aegis Phoenix Suite v3.5 by SOFTMAXTER es la herramienta PowerShell definitiva. Con una estructura de submenus y una
    logica de verificacion inteligente, permite maximizar el rendimiento, reforzar la seguridad, gestionar
    software y drivers, y personalizar la experiencia de usuario.
    Requiere ejecucion como Administrador.
.AUTHOR
    SOFTMAXTER
.VERSION
    3.5
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
# Cada objeto define un ajuste, permitiendo que los menus y las acciones se generen dinamicamente.
$script:SystemTweaks = @(
    # Categoria: Rendimiento UI
    [PSCustomObject]@{
        Name           = "Acelerar la Aparicion de Menus"
        Category       = "Rendimiento UI"
        Description    = "Reduce el retraso (en ms) al mostrar los menus contextuales del Explorador."
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
        EnableCommand  = { if ((Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue).Status -ne 'Running') { Write-Warning "Windows Defender no esta activo. No se puede cambiar este ajuste."; return }; Set-MpPreference -EnableControlledFolderAccess Enabled }
        DisableCommand = { if ((Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue).Status -ne 'Running') { Write-Warning "Windows Defender no esta activo. No se puede cambiar este ajuste."; return }; Set-MpPreference -EnableControlledFolderAccess Disabled }
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

# Objeto a añadir para Cortana
    [PSCustomObject]@{
        Name           = "Deshabilitar Cortana por Completo"
        Category       = "Privacidad y Telemetria"
        Description    = "Desactiva Cortana a nivel de sistema para que no se pueda ejecutar ni consuma recursos."
        Method         = "Registry"
        RegistryPath   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        RegistryKey    = "AllowCortana"
        EnabledValue   = 0 # Un valor de '0' deshabilita Cortana.
        DefaultValue   = 1 # Un valor de '1' la permite (estado por defecto).
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    }

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
	
# Objeto a añadir para el icono de Spotlight
    [PSCustomObject]@{
        Name           = "Ocultar Icono 'Más Información' de Spotlight"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Elimina el ícono superpuesto en el escritorio cuando se usa Windows Spotlight como fondo."
        Method         = "Registry"
        RegistryPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Feeds"
        RegistryKey    = "ShellFeedsTaskbarViewMode"
        EnabledValue   = 2 # Un valor de '2' desactiva el icono.
        DefaultValue   = 0 # Un valor de '0' lo activa (estado por defecto).
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    }
)
# --- CATALOGO CENTRAL DE SERVICIOS ---
# Define todos los servicios gestionables, su proposito, categoria y estado por defecto.
# Esto hace que la funcion sea facilmente extensible.
$script:ServiceCatalog = @(
    # Categoria: Estandar (Servicios que a menudo se pueden desactivar para liberar recursos)
    [PSCustomObject]@{
        Name               = "Fax"
        Description        = "Permite enviar y recibir faxes. Innecesario si no se usa un modem de fax."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "PrintSpooler"
        Description        = "Gestiona los trabajos de impresion. Desactivar si no se utiliza ninguna impresora (fisica o virtual como PDF)."
        Category           = "Estandar"
        DefaultStartupType = "Automatic"
    },
    [PSCustomObject]@{
        Name               = "RemoteRegistry"
        Description        = "Permite a usuarios remotos modificar el registro. Se recomienda desactivarlo por seguridad."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "SysMain"
        Description        = "Mantiene y mejora el rendimiento del sistema (antes Superfetch). Puede causar uso de disco en HDD."
        Category           = "Estandar"
        DefaultStartupType = "Automatic"
    },
    [PSCustomObject]@{
        Name               = "TouchKeyboardAndHandwritingPanelService"
        Description        = "Habilita el teclado tactil y el panel de escritura. Innecesario en equipos de escritorio sin pantalla tactil."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "WalletService"
        Description        = "Servicio del sistema para la Cartera de Windows. Innecesario si no se utiliza."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
    },
    # Categoria: Avanzado/Opcional (Servicios para funciones especificas)
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
        Checkpoint-Computer -Description "AegisPhoenixSuite_v3.5_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')" -RestorePointType "MODIFY_SETTINGS"
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
                            $statusText += " [En Ejecucion]"
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
        Write-Host "   [Numero] - Activar/Desactivar servicio"
        Write-Host "   [R <Numero>] - Restaurar servicio a su estado por defecto (Ej: R 2)"
        Write-Host "   [V] - Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $rawChoice = Read-Host "Selecciona una opcion"
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
                 Write-Warning "Opcion no valida."
            }
        } catch {
            Write-Error "Ocurrio un error: $($_.Exception.Message)"
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

# --- MODULO DE BLOATWARE REFACTORIZADO ---

function Get-RemovableApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft', 'ThirdParty')]
        [string]$Type
    )

    Write-Host "`n[+] Escaneando aplicaciones de tipo '$Type'..." -ForegroundColor Yellow
    $apps = @()

    if ($Type -eq 'Microsoft') {
        # Lista de aplicaciones de Microsoft consideradas esenciales y que no se deben mostrar para eliminar.
        $essentialAppsBlocklist = @(
            "Microsoft.WindowsStore", "Microsoft.WindowsCalculator", "Microsoft.Windows.Photos", 
            "Microsoft.Windows.Camera", "Microsoft.SecHealthUI", "Microsoft.UI.Xaml", "Microsoft.VCLibs",
            "Microsoft.NET.Native", "Microsoft.WebpImageExtension", "Microsoft.HEIFImageExtension",
            "Microsoft.VP9VideoExtensions", "Microsoft.ScreenSketch", "Microsoft.WindowsTerminal",
            "Microsoft.Paint", "Microsoft.WindowsNotepad"
        )
        
        $allApps = Get-AppxPackage -AllUsers | Where-Object { 
            $_.Publisher -like "*Microsoft*" -and $_.IsFramework -eq $false -and $_.NonRemovable -eq $false 
        }

        foreach ($app in $allApps) {
            $isEssential = $false
            foreach ($essential in $essentialAppsBlocklist) {
                if ($app.Name -like "*$essential*") {
                    $isEssential = $true
                    break
                }
            }
            if (-not $isEssential) {
                $apps += [PSCustomObject]@{
                    Name        = $app.Name
                    PackageName = $app.PackageFullName
                }
            }
        }
    } else { # ThirdParty
        $apps = Get-AppxPackage -AllUsers | Where-Object { 
            $_.Publisher -notlike "*Microsoft*" -and $_.IsFramework -eq $false 
        } | ForEach-Object { 
            [PSCustomObject]@{
                Name        = $_.Name
                PackageName = $_.PackageFullName
            }
        }
    }
    
    Write-Host "[OK] Se encontraron $($apps.Count) aplicaciones." -ForegroundColor Green
    return $apps | Sort-Object Name
}

function Show-AppSelectionMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$AppList
    )

    # Añadir una propiedad 'Selected' a cada objeto para el menu
    $AppList | ForEach-Object { $_ | Add-Member -NotePropertyName 'Selected' -NotePropertyValue $false }

    $choice = ''
    while ($choice.ToUpper() -ne 'E' -and $choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "Eliminacion Selectiva de Bloatware" -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar una aplicacion."
        
        for ($i = 0; $i -lt $AppList.Count; $i++) {
            $status = if ($AppList[$i].Selected) { "[X]" } else { "[ ]" }
            Write-Host ("   [{0,2}] {1} {2}" -f ($i + 1), $status, $AppList[$i].Name)
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [E] Eliminar seleccionados"
        Write-Host "   [T] Seleccionar Todos"
        Write-Host "   [N] No seleccionar ninguno"
        Write-Host "   [V] Volver..." -ForegroundColor Red
        
        $choice = Read-Host "`nSelecciona una opcion"

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $AppList.Count) {
            $index = [int]$choice - 1
            $AppList[$index].Selected = -not $AppList[$index].Selected
        } elseif ($choice.ToUpper() -eq 'T') {
            $AppList.ForEach({$_.Selected = $true})
        } elseif ($choice.ToUpper() -eq 'N') {
            $AppList.ForEach({$_.Selected = $false})
        }
    }

    if ($choice.ToUpper() -eq 'E') {
        # Devolver solo las aplicaciones que el usuario ha seleccionado
        return $AppList | Where-Object { $_.Selected }
    } else {
        # Si el usuario elige volver, devolver un array vacio
        return @()
    }
}

function Start-AppUninstallation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory=$true)]
        [array]$AppsToUninstall
    )

    Write-Host "`n[+] Eliminando $($AppsToUninstall.Count) aplicaciones seleccionadas..." -ForegroundColor Yellow
    
    foreach ($app in $AppsToUninstall) {
        if ($PSCmdlet.ShouldProcess($app.Name, "Desinstalar")) {
            try {
                # Eliminar el paquete para el usuario actual y todos los usuarios
                Write-Host " - Eliminando '$($app.Name)'..." -ForegroundColor Gray
                Remove-AppxPackage -Package $app.PackageName -AllUsers -ErrorAction Stop

                # Buscar y eliminar el paquete "provisionado" para que no se reinstale para nuevos usuarios
                $provisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app.Name }
                if ($provisionedPackage) {
                    foreach ($pkg in $provisionedPackage) {
                        Write-Host "   - Eliminando paquete provisionado: $($pkg.PackageName)" -ForegroundColor DarkGray
                        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop
                    }
                }
            } catch {
                Write-Warning "No se pudo desinstalar por completo '$($app.Name)'. Error: $($_.Exception.Message)"
            }
        }
    }
    Write-Host "`n[OK] Proceso de desinstalacion completado." -ForegroundColor Green
}

# --- NUEVA FUNCION ORQUESTADORA ---
function Get-RemovableApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft', 'ThirdParty')]
        [string]$Type
    )

    Write-Host "`n[+] Escaneando aplicaciones de tipo '$Type'..." -ForegroundColor Yellow
    $apps = @()

    if ($Type -eq 'Microsoft') {
        # Lista de aplicaciones de Microsoft consideradas esenciales y que no se deben mostrar para eliminar.
        $essentialAppsBlocklist = @(
            "Microsoft.WindowsStore", "Microsoft.WindowsCalculator", "Microsoft.Windows.Photos", 
            "Microsoft.Windows.Camera", "Microsoft.SecHealthUI", "Microsoft.UI.Xaml", "Microsoft.VCLibs",
            "Microsoft.NET.Native", "Microsoft.WebpImageExtension", "Microsoft.HEIFImageExtension",
            "Microsoft.VP9VideoExtensions", "Microsoft.ScreenSketch", "Microsoft.WindowsTerminal",
            "Microsoft.Paint", "Microsoft.WindowsNotepad"
        )
        
        $allApps = Get-AppxPackage -AllUsers | Where-Object { 
            $_.Publisher -like "*Microsoft*" -and $_.IsFramework -eq $false -and $_.NonRemovable -eq $false 
        }

        foreach ($app in $allApps) {
            $isEssential = $false
            foreach ($essential in $essentialAppsBlocklist) {
                if ($app.Name -like "*$essential*") {
                    $isEssential = $true
                    break
                }
            }
            if (-not $isEssential) {
                $apps += [PSCustomObject]@{
                    Name        = $app.Name
                    PackageName = $app.PackageFullName
                }
            }
        }
    } else { # ThirdParty
        $apps = Get-AppxPackage -AllUsers | Where-Object { 
            $_.Publisher -notlike "*Microsoft*" -and $_.IsFramework -eq $false 
        } | ForEach-Object { 
            [PSCustomObject]@{
                Name        = $_.Name
                PackageName = $_.PackageFullName
            }
        }
    }
    
    Write-Host "[OK] Se encontraron $($apps.Count) aplicaciones." -ForegroundColor Green
    return $apps | Sort-Object Name
}

function Show-AppSelectionMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$AppList
    )

    # Añadir una propiedad 'Selected' a cada objeto para el menu
    $AppList | ForEach-Object { $_ | Add-Member -NotePropertyName 'Selected' -NotePropertyValue $false }

    $choice = ''
    while ($choice.ToUpper() -ne 'E' -and $choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "Eliminacion Selectiva de Bloatware" -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar una aplicacion."
        
        for ($i = 0; $i -lt $AppList.Count; $i++) {
            $status = if ($AppList[$i].Selected) { "[X]" } else { "[ ]" }
            Write-Host ("   [{0,2}] {1} {2}" -f ($i + 1), $status, $AppList[$i].Name)
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [E] Eliminar seleccionados"
        Write-Host "   [T] Seleccionar Todos"
        Write-Host "   [N] No seleccionar ninguno"
        Write-Host "   [V] Volver..." -ForegroundColor Red
        
        $choice = Read-Host "`nSelecciona una opcion"

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $AppList.Count) {
            $index = [int]$choice - 1
            $AppList[$index].Selected = -not $AppList[$index].Selected
        } elseif ($choice.ToUpper() -eq 'T') {
            $AppList.ForEach({$_.Selected = $true})
        } elseif ($choice.ToUpper() -eq 'N') {
            $AppList.ForEach({$_.Selected = $false})
        }
    }

    if ($choice.ToUpper() -eq 'E') {
        # Devolver solo las aplicaciones que el usuario ha seleccionado
        return $AppList | Where-Object { $_.Selected }
    } else {
        # Si el usuario elige volver, devolver un array vacio
        return @()
    }
}

function Start-AppUninstallation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory=$true)]
        [array]$AppsToUninstall
    )

    Write-Host "`n[+] Eliminando $($AppsToUninstall.Count) aplicaciones seleccionadas..." -ForegroundColor Yellow
    
    foreach ($app in $AppsToUninstall) {
        if ($PSCmdlet.ShouldProcess($app.Name, "Desinstalar")) {
            try {
                # Eliminar el paquete para el usuario actual y todos los usuarios
                Write-Host " - Eliminando '$($app.Name)'..." -ForegroundColor Gray
                Remove-AppxPackage -Package $app.PackageName -AllUsers -ErrorAction Stop

                # Buscar y eliminar el paquete "provisionado" para que no se reinstale para nuevos usuarios
                $provisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app.Name }
                if ($provisionedPackage) {
                    foreach ($pkg in $provisionedPackage) {
                        Write-Host "   - Eliminando paquete provisionado: $($pkg.PackageName)" -ForegroundColor DarkGray
                        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop
                    }
                }
            } catch {
                Write-Warning "No se pudo desinstalar por completo '$($app.Name)'. Error: $($_.Exception.Message)"
            }
        }
    }
    Write-Host "`n[OK] Proceso de desinstalacion completado." -ForegroundColor Green
}

# --- NUEVA FUNCION ORQUESTADORA ---
function Manage-Bloatware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft', 'ThirdParty')]
        [string]$Type
    )
    
    # 1. Obtener la lista de aplicaciones
    $removableApps = Get-RemovableApps -Type $Type
    if ($removableApps.Count -eq 0) {
        Read-Host "`nPresiona Enter para volver..."
        return
    }

    # 2. Mostrar el menu de seleccion y obtener las elegidas por el usuario
    $appsToUninstall = Show-AppSelectionMenu -AppList $removableApps
    if ($appsToUninstall.Count -eq 0) {
        Write-Host "`n[INFO] No se selecciono ninguna aplicacion o se cancelo la operacion." -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para volver..."
        return
    }

    # 3. Iniciar la desinstalacion
    Start-AppUninstallation -AppsToUninstall $appsToUninstall
    Read-Host "`nPresiona Enter para volver..."
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
            return 'Enabled' # Si la clave no existe, todo esta habilitado por defecto
        }

        $property = Get-ItemProperty -Path $approvedKeyPath -Name $ItemName -ErrorAction SilentlyContinue
        
        if ($null -eq $property) {
            return 'Enabled' # Si la propiedad no existe para este item, esta habilitado
        }

        $binaryData = $property.$ItemName
        if ($null -ne $binaryData -and $binaryData.Length -gt 0) {
            # El estado esta en el primer byte. Impar = Deshabilitado, Par = Habilitado.
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
    Write-Host "`n[+] Iniciando la secuencia de reparacion del sistema." -ForegroundColor Cyan
    Write-Host "Este proceso puede tardar bastante tiempo y no debe interrumpirse." -ForegroundColor Yellow
    
    $repairsMade = $false
    $imageIsRepairable = $false

    # --- PASO 1: Reparar la Imagen de Windows con DISM ---
    # DISM repara el almacén de componentes que SFC usa como fuente. Es crucial ejecutarlo primero.
    
    # --- PASO 1a: Escanear la salud de la imagen ---
    Write-Host "`n[+] PASO 1/3: Ejecutando DISM para escanear la salud de la imagen de Windows..." -ForegroundColor Yellow
    Write-Host "    (Este paso busca problemas y puede tardar varios minutos)..." -ForegroundColor Gray
    
    # Capturamos la salida para analizarla, pero también la mostramos para que el usuario la vea.
    $dismScanOutput = (DISM.exe /Online /Cleanup-Image /ScanHealth | Tee-Object -Variable tempOutput) -join "`n"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "DISM encontro un error durante el escaneo."
    } else {
        Write-Host "[OK] Escaneo de DISM completado." -ForegroundColor Green
        # Verificamos si la imagen necesita reparacion
        if ($dismScanOutput -match "The component store is repairable|El almacen de componentes es reparable") {
            $imageIsRepairable = $true
        }
    }

    # --- PASO 1b: Reparar la imagen si es necesario ---
    if ($imageIsRepairable) {
        Write-Host "`n[+] PASO 2/3: Se detecto corrupcion. Ejecutando DISM para reparar la imagen..." -ForegroundColor Yellow
        Write-Host "    (Esto puede parecer atascado en ciertos porcentajes, es normal)..." -ForegroundColor Gray
        DISM.exe /Online /Cleanup-Image /RestoreHealth
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "DISM encontro un error y podria no haber completado la reparacion."
        } else {
            Write-Host "[OK] Reparacion de DISM completada." -ForegroundColor Green
            $repairsMade = $true
        }
    } else {
        Write-Host "`n[+] PASO 2/3: No se detecto corrupcion en la imagen de Windows. Omitiendo reparacion." -ForegroundColor Green
    }

    # --- PASO 2: Reparar Archivos del Sistema con SFC ---
    Write-Host "`n[+] PASO 3/3: Ejecutando SFC para verificar los archivos del sistema..." -ForegroundColor Yellow
    sfc.exe /scannow

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "SFC encontro un error o no pudo reparar todos los archivos."
    } else {
        Write-Host "[OK] SFC ha completado su operacion." -ForegroundColor Green
    }

    # Verificamos si SFC hizo reparaciones.
    $cbsLogPath = "$env:windir\Logs\CBS\CBS.log"
    if (Test-Path $cbsLogPath) {
        $sfcEntries = Get-Content $cbsLogPath | Select-String -Pattern "\[SR\]"
        if ($sfcEntries -match "Repairing file|Fixed|Repaired") {
            $repairsMade = $true
        }
    }

    # --- Conclusion ---
    Write-Host "`n[+] Secuencia de reparacion del sistema completada." -ForegroundColor Green
    if ($repairsMade) {
        Write-Host "[RECOMENDACIoN] Se realizaron reparaciones en el sistema. Se recomienda encarecidamente reiniciar el equipo." -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] No se detectaron corrupciones que requirieran reparacion." -ForegroundColor Green
    }

    Read-Host "`nPresiona Enter para volver..."
}

function Clear-SystemCaches { Write-Host "`nLimpiando caches..."; ipconfig /flushdns; wsreset.exe -q; Write-Host "[OK] Caches de DNS y Tienda limpiadas."; Read-Host "`nPresiona Enter para volver..." }
function Optimize-Drives { Write-Host "`nOptimizando unidades..."; Optimize-Volume -DriveLetter C -Verbose; Read-Host "`nPresiona Enter para volver..." }
function Generate-SystemReport { $parentDir = Split-Path -Parent $PSScriptRoot; $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"; if (-not (Test-Path $diagDir)) { New-Item -Path $diagDir -ItemType Directory | Out-Null }; $reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Salud_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').html"; Write-Host "`n[+] Generando reporte de energia..."; powercfg /energy /output $reportPath /duration 30; if (Test-Path $reportPath) { Write-Host "[OK] Reporte generado en: '$reportPath'" -ForegroundColor Green; Start-Process $reportPath } else { Write-Error "No se pudo generar el reporte." }; Read-Host "`nPresiona Enter para volver..." }


function Show-InventoryMenu {
    $parentDir = Split-Path -Parent $PSScriptRoot; $reportDir = Join-Path -Path $parentDir -ChildPath "Reportes"; if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory | Out-Null }; $reportFile = Join-Path -Path $reportDir -ChildPath "Reporte_Inventario_$(Get-Date -Format 'yyyy-MM-dd').txt"; Write-Host "`n[+] Generando reporte en '$reportFile'..." -ForegroundColor Yellow; "--- REPORTE DE HARDWARE ---`n" | Out-File -FilePath $reportFile -Encoding utf8; (Get-ComputerInfo | Select-Object CsName, WindowsProductName, OsHardwareAbstractionLayer, CsProcessors, PhysiscalMemorySize) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; (Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; "`n--- REPORTE DE SOFTWARE INSTALADO ---`n" | Out-File -FilePath $reportFile -Append -Encoding utf8; Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, InstallDate | Format-Table | Out-File -FilePath $reportFile -Append -Encoding utf8; "`n--- REPORTE DE RED ---`n" | Out-File -FilePath $reportFile -Append -Encoding utf8; (Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed) | Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8; Write-Host "[OK] Reporte completo generado en la carpeta '$reportDir'." -ForegroundColor Green; Read-Host "`nPresiona Enter para volver..."
}

function Show-DriverMenu {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $driverChoice = ''
    do {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "            Modulo de Gestion de Drivers               " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Copia de Seguridad de TODOS los drivers (Backup)"
        Write-Host "       (Crea un respaldo completo de los drivers instalados)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Listar drivers de terceros instalados"
        Write-Host "       (Muestra los drivers no provenientes de Microsoft)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Restaurar drivers desde una copia de seguridad"
        Write-Host "       (Instala masivamente los drivers desde una carpeta de respaldo)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [V] Volver..." -ForegroundColor Red
        Write-Host ""
        
        $driverChoice = Read-Host "Selecciona una opcion"
        
        switch ($driverChoice) {
            '1' {
                $destPath = Read-Host "Introduce la ruta completa para GUARDAR la copia (ej: C:\MisDrivers)"
                if ([string]::IsNullOrWhiteSpace($destPath)) {
                    Write-Warning "La ruta no puede estar vacia."
                } else {
                    if (-not (Test-Path $destPath)) {
                        New-Item -Path $destPath -ItemType Directory | Out-Null
                    }
                    Write-Host "`n[+] Exportando drivers a '$destPath'..." -ForegroundColor Yellow
                    Export-WindowsDriver -Online -Destination $destPath
                    Write-Host "[OK] Copia de seguridad completada." -ForegroundColor Green
                }
            }
            '2' {
                Write-Host "`n[+] Listando drivers no-Microsoft instalados..." -ForegroundColor Yellow
                Get-WindowsDriver -Online | Where-Object { $_.ProviderName -ne 'Microsoft' } | Format-Table ProviderName, ClassName, Date, Version -AutoSize
            }
            '3' {
                $sourcePath = Read-Host "Introduce la ruta completa de la CARPETA con la copia de drivers"
                if (-not (Test-Path $sourcePath)) {
                    Write-Error "La ruta especificada no existe: '$sourcePath'"
                } elseif ($PSCmdlet.ShouldProcess("el sistema", "Restaurar todos los drivers desde '$sourcePath'")) {
                    Write-Host "`n[+] Iniciando restauracion de drivers..." -ForegroundColor Yellow
                    Write-Host "Esto puede tardar varios minutos y podrias ver ventanas de instalacion." -ForegroundColor Yellow

                    $driverInfFiles = Get-ChildItem -Path $sourcePath -Filter "*.inf" -Recurse
                    if ($driverInfFiles.Count -eq 0) {
                        Write-Warning "No se encontraron archivos de driver (.inf) en la ruta especificada."
                    } else {
                        $total = $driverInfFiles.Count
                        $current = 0
                        foreach ($inf in $driverInfFiles) {
                            $current++
                            Write-Host " - Instalando driver ($current de $total): $($inf.FullName)" -ForegroundColor Gray
                            # PnPUtil es la herramienta moderna para gestionar drivers.
                            # /add-driver agrega el paquete de drivers.
                            # /install instala el driver en los dispositivos aplicables.
                            pnputil.exe /add-driver $inf.FullName /install
                        }
                        Write-Host "`n[OK] Proceso de restauracion de drivers completado." -ForegroundColor Green
                    }
                }
            }
            'V' {
                continue
            }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
            }
        } # Fin del switch

        if ($driverChoice -ne 'V') {
            Read-Host "`nPresiona Enter para continuar..."
        }
    } while ($driverChoice.ToUpper() -ne 'V')
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

# --- MODULO DE GESTION DE SOFTWARE (MULTI-MOTOR) REFACTORIZADO ---
# Version robusta con gestion de actualizaciones unificada y mejores practicas.
# Autor de la refactorizacion: Experto en PowerShell (Analisis de Gemini)
# Fecha: 2025-08-02

# Variable global para mantener el motor seleccionado para busqueda e instalacion.
$script:SoftwareEngine = 'Winget'

#region --- Funciones de Verificacion e Instalacion de Motores ---

# MEJORADO: Se mantiene la excelente logica de autoinstalacion. No se requieren cambios aqui.
function Ensure-ChocolateyIsInstalled {
    if (Get-Command 'choco' -ErrorAction SilentlyContinue) { return $true }
    Write-Warning "El gestor de paquetes 'Chocolatey' no esta instalado."
    if ((Read-Host "¿Deseas instalarlo ahora? (S/N)").ToUpper() -eq 'S') {
        Write-Host "`n[+] Instalando Chocolatey..." -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force;
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Host "`n[OK] Chocolatey instalado." -ForegroundColor Green
            return $true
        } catch { Write-Error "Fallo la instalacion de Chocolatey. Error: $($_.Exception.Message)"; return $false }
    }
    return $false
}

function Ensure-ScoopIsInstalled {
    if (Get-Command 'scoop' -ErrorAction SilentlyContinue) { return $true }
    Write-Warning "El gestor de paquetes 'Scoop' no esta instalado."
    if ((Read-Host "¿Deseas instalarlo ahora? (S/N)").ToUpper() -eq 'S') {
        Write-Host "`n[+] Instalando Scoop..." -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy RemoteSigned -Scope Process -Force
            irm get.scoop.sh | iex
            Write-Host "`n[OK] Scoop instalado." -ForegroundColor Green
            return $true
        } catch { Write-Error "Fallo la instalacion de Scoop. Error: $($_.Exception.Message)"; return $false }
    }
    return $false
}
# ... (Las demas funciones Ensure-* se mantienen igual)
#endregion

# MEJORADO: El corazon del modulo. Ahora es mas especifico y robusto.
function Invoke-SoftwareAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Search', 'Install', 'Upgrade', 'ListOutdated')]
        [string]$Action,
        [Parameter(Mandatory = $true)]
        [string]$Engine,
        [string]$PackageName,
        [string[]]$PackageIdsToUpdate
    )

    function Test-CommandExists($command) {
        return (Get-Command $command -ErrorAction SilentlyContinue)
    }

    $results = [System.Collections.Generic.List[pscustomobject]]::new()

    try {
        switch ($Engine) {
            'Winget' {
                if (-not (Test-CommandExists 'winget')) { throw "El motor 'Winget' es esencial y no se encuentra." }
                switch ($Action) {
                    'Search' {
                        $output = winget search $PackageName --accept-source-agreements
                        
                        # CORRECCIoN: Se reemplaza el método de analisis anterior por uno mas robusto.
                        # MEJORA: Se omiten las 2 primeras líneas (cabecera y separador) para evitar falsos positivos.
                        ($output -split "\r?\n" | Select-Object -Skip 2) | ForEach-Object {
                            # Se usa el operador -match. Si es verdadero, la variable automatica $Matches se puebla.
                            if ($_ -match '^(?<Name>.+?)\s{2,}(?<Id>\S+)') {
                                $results.Add([PSCustomObject]@{
                                    Name   = $Matches['Name'].Trim()
                                    Id     = $Matches['Id'].Trim()
                                    Engine = 'Winget'
                                })
                            }
                        }
                    }
                    'Install' {
                        if ($PSCmdlet.ShouldProcess($PackageName, "Instalar (Winget)")) {
                            winget install --id $PackageName --exact --silent --accept-package-agreements --accept-source-agreements
                        }
                    }
                    'ListOutdated' {
                        $output = winget upgrade --include-unknown --accept-source-agreements
                        if ($output -match "No applicable update found") { break }
                        
                        ($output -split "\r?\n" | Select-Object -Skip 2) | ForEach-Object {
                             if ($_ -match '^(?<Name>.+?)\s{2,}(?<Id>\S+)\s{2,}(?<Version>\S+)\s{2,}(?<Available>\S+)') {
                                $results.Add([PSCustomObject]@{
                                    Name      = $Matches['Name'].Trim()
                                    Id        = $Matches['Id'].Trim()
                                    Version   = $Matches['Version'].Trim()
                                    Available = $Matches['Available'].Trim()
                                    Engine    = 'Winget'
                                })
                            }
                        }
                    }
                    'Upgrade' {
                        foreach ($id in $PackageIdsToUpdate) {
                            if ($PSCmdlet.ShouldProcess($id, "Actualizar (Winget)")) {
                                winget upgrade --id $id --silent --accept-package-agreements --accept-source-agreements
                            }
                        }
                    }
                }
            }
            'Chocolatey' {
                if (-not (Ensure-ChocolateyIsInstalled)) { throw "Chocolatey no esta disponible." }
                switch ($Action) {
                    'Search' { choco search $PackageName -r | ? { $_ -match '\|' } | % { $p = $_.Split('|'); $results.Add([PSCustomObject]@{ Name = $p[0]; Id = $p[0]; Engine = 'Chocolatey' }) } }
                    'Install' { if ($PSCmdlet.ShouldProcess($PackageName, "Instalar (Choco)")) { choco install $PackageName -y } }
                    'ListOutdated' { choco outdated -r | ? { $_ -match '\|' } | % { $p = $_.Split('|'); $results.Add([PSCustomObject]@{ Name = $p[0]; Id = $p[0]; Version = $p[1]; Available = $p[2]; Engine = 'Chocolatey' }) } }
                    'Upgrade' { if ($PSCmdlet.ShouldProcess("Paquetes Seleccionados", "Actualizar (Choco)")) { choco upgrade -y $($PackageIdsToUpdate -join ' ') } }
                }
            }
            # Se pueden añadir logicas similares para Scoop, etc.
        }
    }
    catch {
        throw "Error ejecutando accion '$Action' con el motor '$Engine': $_"
    }
    return $results
}

# NUEVA: Funcion genérica para mostrar un menu de seleccion interactivo.
function Show-InteractiveSelectionMenu {
    param(
        [Parameter(Mandatory=$true)] [array]$Items,
        [Parameter(Mandatory=$true)] [string]$Title,
        [Parameter(Mandatory=$true)] [string]$Noun # Ej: "actualizacion", "aplicacion"
    )
    $Items.ForEach({ $_ | Add-Member -NotePropertyName Selected -NotePropertyValue $false })
    $choice = ''
    while ($choice.ToUpper() -ne 'A' -and $choice.ToUpper() -ne 'V') {
        Clear-Host; Write-Host $Title -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar una $noun."
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $status = if ($Items[$i].Selected) { "[X]" } else { "[ ]" }
            $line = "   [{0,2}] {1} {2}" -f ($i + 1), $status, $Items[$i].Name
            if ($Items[$i].PSObject.Properties.Name -contains 'Version') {
                $line += " (v$($Items[$i].Version) -> v$($items[$i].Available))"
            }
            $line += " - [$($Items[$i].Engine)]"
            Write-Host $line
        }
        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [A] Aplicar a seleccionados   [T] Seleccionar Todos   [N] No seleccionar ninguno"
        Write-Host "   [V] Volver..." -ForegroundColor Red
        $choice = Read-Host "`nSelecciona una opcion"
        if ($choice -match '^\d+$' -and [int]$choice -in 1..$Items.Count) { $Items[[int]$choice - 1].Selected = -not $Items[[int]$choice - 1].Selected }
        elseif ($choice.ToUpper() -eq 'T') { $Items.ForEach({$_.Selected = $true}) }
        elseif ($choice.ToUpper() -eq 'N') { $Items.ForEach({$_.Selected = $false}) }
    }
    if ($choice.ToUpper() -eq 'A') { return $Items | Where-Object { $_.Selected } }
    else { return @() }
}

# MEJORADO: Usa la nueva logica de Invoke-SoftwareAction
function Search-And-Install-Software {
    $searchTerm = Read-Host "Introduce el nombre del software a buscar con '$($script:SoftwareEngine)'"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { return }

    Write-Host "`nBuscando '$searchTerm'..."
    try {
        $apps = Invoke-SoftwareAction -Action 'Search' -Engine $script:SoftwareEngine -PackageName $searchTerm
        if ($apps.Count -eq 0) { Write-Warning "No se encontraron resultados."; Read-Host; return }
        
        $appToInstall = Show-InteractiveSelectionMenu -Items $apps -Title "Resultados de la Busqueda" -Noun "aplicacion"
        if ($appToInstall.Count -gt 0) {
            # Asumimos que el usuario solo quiere instalar la primera seleccion del menu
            Invoke-SoftwareAction -Action 'Install' -Engine $appToInstall[0].Engine -PackageName $appToInstall[0].Id
        }
    } catch { Write-Error $_ }
    Read-Host "`nPresiona Enter para volver..."
}

# MEJORADO: Implementa SupportsShouldProcess
function Install-SoftwareFromList {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    $filePath = Read-Host "Introduce la ruta al archivo .txt con los IDs de los paquetes"
    if (-not (Test-Path $filePath)) { Write-Error "Archivo no encontrado."; Read-Host; return }
    
    $programs = Get-Content $filePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($programs.Count -eq 0) { Write-Warning "El archivo esta vacio."; Read-Host; return }

    Write-Host "`n[+] Se instalaran $($programs.Count) programas con el motor '$($script:SoftwareEngine)'..." -ForegroundColor Yellow
    foreach ($programId in $programs) {
        Invoke-SoftwareAction -Action 'Install' -Engine $script:SoftwareEngine -PackageName $programId
    }
    Write-Host "`n[OK] Proceso completado." -ForegroundColor Green
    Read-Host "`nPresiona Enter para volver..."
}

# NUEVA: La funcion central para la gestion de actualizaciones.
function Manage-SoftwareUpdates {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    $allOutdated = [System.Collections.Generic.List[pscustomobject]]::new()
    $supportedEngines = @('Winget', 'Chocolatey') # Añade mas motores aquí

    Write-Host "`n[+] Buscando actualizaciones en todos los motores soportados..." -ForegroundColor Yellow
    foreach ($engine in $supportedEngines) {
        Write-Host " - Consultando motor: $engine" -ForegroundColor Gray
        try {
            $outdatedInEngine = Invoke-SoftwareAction -Action 'ListOutdated' -Engine $engine
            
            # CORRECCIoN: Se ha modificado la forma de agregar los resultados a la lista.
            # En lugar de usar .AddRange(), que causa un conflicto de tipos, se usa un bucle ForEach-Object.
            # Esto procesa cada elemento devuelto de forma individual, evitando el error de conversion.
            if ($null -ne $outdatedInEngine -and $outdatedInEngine.Count -gt 0) {
                $outdatedInEngine | ForEach-Object { $allOutdated.Add($_) }
            }
        } catch { Write-Warning "No se pudo consultar el motor '$engine'. $_" }
    }

    if ($allOutdated.Count -eq 0) {
        Write-Host "`n[OK] ¡Tu software esta al día!" -ForegroundColor Green
        Read-Host "`nPresiona Enter para volver..."; return
    }

    $updatesToApply = Show-InteractiveSelectionMenu -Items $allOutdated -Title "Actualizaciones de Software Disponibles" -Noun "actualizacion"

    if ($updatesToApply.Count -eq 0) {
        Write-Warning "No se selecciono ninguna actualizacion."
        Read-Host "`nPresiona Enter para volver..."
        return
    }

    $updatesToApply | Group-Object -Property Engine | ForEach-Object {
        $engine = $_.Name
        $packageIds = $_.Group.Id
        Write-Host "`n[+] Aplicando $($packageIds.Count) actualizaciones con el motor '$engine'..." -ForegroundColor Yellow
        try {
            Invoke-SoftwareAction -Action 'Upgrade' -Engine $engine -PackageIdsToUpdate $packageIds -WhatIf:$WhatIfPreference
        } catch { Write-Error "Fallo la actualizacion con el motor '$engine'. $_" }
    }
    Write-Host "`n[OK] Proceso de actualizacion completado." -ForegroundColor Green
    Read-Host "`nPresiona Enter para volver..."
}

# MEJORADO: El menu principal que une todo.
function Show-SoftwareMenu {
    $availableEngines = @('Winget', 'Chocolatey', 'Scoop')
    $softwareChoice = ''
    do {
        Clear-Host
        Write-Host "Modulo de Gestion de Software" -ForegroundColor Cyan
        Write-Host "Motor para Busqueda/Instalacion: " -NoNewline; Write-Host $script:SoftwareEngine -ForegroundColor Yellow
        Write-Host "-------------------------------------------------------"
        Write-Host "   [1] Buscar y APLICAR ACTUALIZACIONES (Recomendado)"
        Write-Host "   [2] Buscar e INSTALAR un software especifico"
        Write-Host "   [3] Instalar software en MASA desde un archivo de texto"
        Write-Host ""
        Write-Host "   [E] Cambiar motor de busqueda/instalacion"
        Write-Host ""
        Write-Host "   [V] Volver..." -ForegroundColor Red
        Write-Host ""
        $softwareChoice = Read-Host "`nSelecciona una opcion"

        switch ($softwareChoice.ToUpper()) {
            '1' { Manage-SoftwareUpdates }
            '2' { Search-And-Install-Software }
            '3' { Install-SoftwareFromList }
            'E' {
                # Logica para cambiar el motor (sin cambios, ya era correcta)
                for ($i = 0; $i -lt $availableEngines.Count; $i++) { Write-Host "   [$($i+1)] $($availableEngines[$i])" }
                $engineChoice = Read-Host "`nElige un numero"
                if ($engineChoice -match '^\d+$' -and [int]$engineChoice -in 1..$availableEngines.Count) {
                    $script:SoftwareEngine = $availableEngines[[int]$engineChoice - 1]
                }
            }
            'V' { continue }
            default { Write-Warning "Opcion no valida." }
        }
    } while ($softwareChoice.ToUpper() -ne 'V')
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
			Write-Host ""
            $categories = $script:SystemTweaks | Select-Object -ExpandProperty Category -Unique | Sort-Object
            for ($i = 0; $i -lt $categories.Count; $i++) {
                Write-Host ("   [{0}] {1}" -f ($i + 1), $categories[$i])
            }
            Write-Host ""
            Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
			Write-Host ""
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
			Write-Host ""            
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
        '1' { Manage-SystemServices } # Llamada a la nueva funcion
        '2' { Show-CleaningMenu }     # Nota: el indice de las siguientes opciones puede necesitar ajuste si cambias el texto del menu
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
        # MODIFICADO: Se reemplazaron multiples entradas por una sola llamada al nuevo gestor.
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
        
        # MODIFICADO: El switch ahora apunta a la nueva funcion Show-TweakManagerMenu.
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

