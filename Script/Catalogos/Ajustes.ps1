# --- CATALOGO CENTRAL DE AJUSTES DEL SISTMA ---
# Esta es la "fuente de la verdad" para todos los tweaks, ajustes de seguridad, privacidad y UI.
# Cada objeto define un ajuste, permitiendo que los menus y las acciones se generen dinamicamente.
$script:SystemTweaks = @(
    # --- Categoria: Rendimiento UI ---
    [PSCustomObject]@{
        Name           = "Eliminar Retraso Visual de Menus"
        Category       = "Rendimiento UI"
        Description    = "Hace que los menus del clic derecho aparezcan instantaneamente, eliminando la animacion de desvanecimiento para una sensacion de mayor rapidez."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Control Panel\Desktop"
        RegistryKey    = "MenuShowDelay"
        EnabledValue   = "0"
        DefaultValue   = "400"
        RegistryType   = "String"
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Retraso de Apps de Inicio"
        Category       = "Rendimiento UI"
        Description    = "Elimina una demora artificial que Windows aplica a los programas que inician con el sistema."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        RegistryKey    = "StartupDelayInMSec"
        EnabledValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Session"
	},
    [PSCustomObject]@{
        Name           = "Activar Modo de Maximo Rendimiento Visual"
        Category       = "Rendimiento UI"
        Description    = "Desactiva animaciones, sombras y transparencias para priorizar la fluidez y velocidad del sistema sobre los efectos visuales. Ideal para equipos de bajos recursos o para minimizar distracciones."
        Method         = "Command"
        EnableCommand  = {
            # --- VALORES VERIFICADOS POR EL USUARIO APLICADOS A HKLM ---
            $basePath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
            Set-ItemProperty -Path "$basePath\ControlAnimations" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\AnimateMinMax" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\TaskbarAnimations" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DWMAeroPeekEnabled" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\MenuAnimation" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\TooltipAnimation" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\SelectionFade" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DWMSaveThumbnailEnabled" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\CursorShadow" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ListviewShadow" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ThumbnailsOrIcon" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ListviewAlphaSelect" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DragFullWindows" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ComboBoxAnimation" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\FontSmoothing" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ListBoxSmoothScrolling" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DropShadow" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
        }
        DisableCommand = {
            # Restaura los valores por defecto de Windows para estas claves
            $basePath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
            Set-ItemProperty -Path "$basePath\ControlAnimations" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\AnimateMinMax" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\TaskbarAnimations" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DWMAeroPeekEnabled" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\MenuAnimation" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\TooltipAnimation" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\SelectionFade" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DWMSaveThumbnailEnabled" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\CursorShadow" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ListviewShadow" -Name 'DefaultValue' -Value 0 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ThumbnailsOrIcon" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ListviewAlphaSelect" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DragFullWindows" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ComboBoxAnimation" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\FontSmoothing" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\ListBoxSmoothScrolling" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
            Set-ItemProperty -Path "$basePath\DropShadow" -Name 'DefaultValue' -Value 1 -Type 'DWord' -Force;
        }
        CheckCommand   = {
            $basePath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
            $animate = (Get-ItemProperty -Path "$basePath\AnimateMinMax" -Name 'DefaultValue' -ErrorAction SilentlyContinue).DefaultValue
            $peek = (Get-ItemProperty -Path "$basePath\DWMAeroPeekEnabled" -Name 'DefaultValue' -ErrorAction SilentlyContinue).DefaultValue
            return ($animate -eq 0 -and $peek -eq 1)
        }
        RestartNeeded  = "Session"
    },

    # --- Categoria: Rendimiento del Sistema ---
    [PSCustomObject]@{
        Name           = "Priorizar Aplicacion en Primer Plano (CPU Boost)"
        Category       = "Rendimiento del Sistema"
        Description    = "Modifica el planificador de Windows para que la aplicacion que estas usando reciba mas potencia de la CPU, mejorando su capacidad de respuesta."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl"
        RegistryKey    = "Win32PrioritySeparation"
        EnabledValue   = 26
        DefaultValue   = 2
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Liberar 100% del Ancho de Banda de Red"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva la reserva de ancho de banda que Windows hace para streaming, permitiendo que todas las aplicaciones (juegos, descargas) usen la totalidad de tu conexion."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        RegistryKey    = "NetworkThrottlingIndex"
        EnabledValue   = '4294967295'
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Desactivar Aceleracion del Raton"
        Category       = "Rendimiento del Sistema"
        Description    = "Configura el raton para una precision 1:1, eliminando la aceleracion de Windows."
        Method         = "Command"
        EnableCommand  = {
			Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseSpeed' -Value "0";
			Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "0";
			Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "0"
			}
        DisableCommand = {
			Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseSpeed' -Value "1";
			Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "6"; 
			Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "10"
			}
        CheckCommand   = {
			$props = Get-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -ErrorAction SilentlyContinue;
			return ($props.MouseSpeed -eq "0" -and $props.MouseThreshold1 -eq "0" -and $props.MouseThreshold2 -eq "0")
			}
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Desactivar VBS para Maximo Rendimiento en Juegos"
        Category       = "Rendimiento del Sistema"
        Description    = "Aumenta los FPS en juegos y el rendimiento en emuladores al desactivar una capa de seguridad por virtualizacion. ADVERTENCIA: Reduce la proteccion del nucleo del sistema."
        Method         = "Command"
        EnableCommand  = { bcdedit /set hypervisorlaunchtype off }
        DisableCommand = { bcdedit /set hypervisorlaunchtype Auto }
        CheckCommand   = {
			$output = bcdedit /enum "{current}";
			if ($LASTEXITCODE -ne 0) { return 'NotApplicable' };
		return ($output -like "*hypervisorlaunchtype*Off*")
		}
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar la Barra de Juegos (Game Bar)"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva la Game Bar y la funcionalidad de grabacion DVR, lo que puede mejorar el rendimiento en juegos."
        Method         = "Command"
        EnableCommand  = {
			Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue;
			Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
			}
        DisableCommand = {
			Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue;
			Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
			}
        CheckCommand   = { $val1 = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\System\GameConfigStore" -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue).GameDVR_Enabled; $val2 = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue).AppCaptureEnabled; return ($val1 -eq 0 -and $val2 -eq 0) }
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Activar Plan de Energia de Maximo Rendimiento Definitivo"
        Category       = "Rendimiento del Sistema"
        Description    = "Activa el plan de energia de maximo rendimiento, ideal para juegos y estaciones de trabajo. Aumenta el consumo."
        Method         = "Command"
        EnableCommand  = {
			$ultimatePlanGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61";
			powercfg -duplicatescheme $ultimatePlanGuid | Out-Null;
			powercfg /setactive $ultimatePlanGuid
			}
        DisableCommand = {
			$balancedPlanGuid = "381b4222-f694-41f0-9685-ff5bb260df2e";
			powercfg /setactive $balancedPlanGuid
			}
        CheckCommand   = {
			$ultimatePlanGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61";
			$activeScheme = powercfg /getactivescheme;
			return ($activeScheme -match $ultimatePlanGuid)
			}
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Optimizar Uso de Memoria del Sistema de Archivos"
        Category       = "Rendimiento del Sistema"
        Description    = "Aumenta la memoria para la cache de archivos (NTFS), acelerando operaciones de disco. Recomendado para 16GB+ de RAM."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem"
        RegistryKey    = "NtfsMemoryUsage"
        EnabledValue   = 2
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
		},
    [PSCustomObject]@{
        Name           = "Reducir Tiempo de Espera del Menu de Arranque"
        Category       = "Rendimiento del Sistema"
        Description    = "Reduce el tiempo de espera del menu de arranque (si aparece) de 30 a 10 segundos, acelerando el inicio."
        Method         = "Command"
        EnableCommand  = { bcdedit /timeout 10 }
        DisableCommand = { bcdedit /timeout 30 }
        CheckCommand   = {
			$output = bcdedit /enum '{bootmgr}';
			$timeoutValue = ($output | Select-String 'timeout').Line -replace '\D','';
			return $timeoutValue -eq '10'
			}
        RestartNeeded  = "Reboot" 
    },
    [PSCustomObject]@{
        Name           = "Limitar Uso de CPU de Windows Defender al 25% (Directiva)"
        Category       = "Rendimiento del Sistema"
        Description    = "Establece un limite maximo del 25% de uso de CPU para los analisis de Windows Defender, reduciendo el impacto en el rendimiento."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan"
        RegistryKey    = "AvgCPULoadFactor"
        EnabledValue   = 25
        DefaultValue   = 50
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Mostrar Informacion Detallada en Pantalla Azul (BSOD)"
        Category       = "Rendimiento del Sistema"
        Description    = "Configura las pantallas azules de error (BSOD) para que muestren informacion tecnica detallada en lugar de la cara triste."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\CrashControl"
        RegistryKey    = "DisplayParameters"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Hibernacion (Elimina hiberfil.sys)"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva la funcion de hibernacion y elimina el archivo hiberfil.sys, liberando varios GB de espacio en disco."
        Method         = "Command"
        EnableCommand  = { powercfg.exe /hibernate off }
        DisableCommand = { powercfg.exe /hibernate on }
        CheckCommand   = {
            $status = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -ErrorAction SilentlyContinue
            return ($null -ne $status -and $status.HibernateEnabled -eq 0)
        }
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar la Barra de Juegos (Directiva GPO)"
        Category       = "Rendimiento del Sistema"
        Description    = "Deshabilitar la Game Bar de forma global, la forma mas robusta."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        RegistryKey    = "AllowGameDVR"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Session"
    },
	[PSCustomObject]@{
        Name           = "Reducir Latencia del Sistema (Gaming/Audio)"
        Category       = "Rendimiento del Sistema"
        Description    = "Ajusta el programador de tareas para que los procesos en segundo plano no interfieran con las aplicaciones en tiempo real, reduciendo el lag en juegos y audio."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        RegistryKey    = "SystemResponsiveness"
        EnabledValue   = 10
        DefaultValue   = 20
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Servicio NDU"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva el servicio de monitorizacion de red (NDU),"
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Ndu"
        RegistryKey    = "Start"
        EnabledValue   = 4
        DefaultValue   = 2
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },	
	[PSCustomObject]@{
        Name           = "Habilitar Descarga de Checksum (TCP/UDP)"
        Category       = "Rendimiento del Sistema"
        Description    = "Fuerza a la tarjeta de red a calcular los checksums de paquetes TCP/UDP, reduciendo la carga de la CPU. (Generalmente activado por defecto)."
        Method         = "Command"
        EnableCommand  = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            # Metodo universal (driver)
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*IPChecksumOffload' -RegistryValue '1' -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*TCPChecksumOffloadIPv4' -RegistryValue '1' -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*UDPChecksumOffloadIPv4' -RegistryValue '1' -ErrorAction SilentlyContinue
        }
        DisableCommand = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            # Metodo universal (driver)
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*IPChecksumOffload' -RegistryValue '0' -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*TCPChecksumOffloadIPv4' -RegistryValue '0' -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*UDPChecksumOffloadIPv4' -RegistryValue '0' -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            $prop = Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty -RegistryKeyword '*TCPChecksumOffloadIPv4' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -eq $prop) { return 'NotApplicable' }
            return ($prop.RegistryValue -eq '1')
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Habilitar Descarga de Envio Grande (LSO)"
        Category       = "Rendimiento del Sistema"
        Description    = "Permite al sistema enviar paquetes grandes a la NIC, y que sea la tarjeta de red (y no la CPU) quien los segmente. Mejora el rendimiento de envio."
        Method         = "Command"
        EnableCommand  = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            # Metodo universal (driver)
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*LSOv2IPv4' -RegistryValue '1' -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*LSOv2IPv6' -RegistryValue '1' -ErrorAction SilentlyContinue
        }
        DisableCommand = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            # Metodo universal (driver)
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*LSOv2IPv4' -RegistryValue '0' -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Set-NetAdapterAdvancedProperty -RegistryKeyword '*LSOv2IPv6' -RegistryValue '0' -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            $prop = Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty -RegistryKeyword '*LSOv2IPv4' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -eq $prop) { return 'NotApplicable' }
            return ($prop.RegistryValue -eq '1')
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Habilitar Escalado de Recepcion (RSS)"
        Category       = "Rendimiento del Sistema"
        Description    = "Distribuye el procesamiento de los paquetes de red recibidos entre multiples nucleos de la CPU, evitando cuellos de botella en un solo nucleo."
        Method         = "Command"
        EnableCommand  = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Enable-NetAdapterRss
        }
        DisableCommand = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Disable-NetAdapterRss
        }
        CheckCommand   = {
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            $rss = Get-NetAdapterRss -Name '*' -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -notlike '*Virtual*' -and $_.InterfaceDescription -notlike '*Loopback*' } | Select-Object -First 1
            if ($null -eq $rss) { return 'NotApplicable' }
            return ($rss.Enabled -eq $true)
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Habilitar Coalescencia de Segmentos (RSC)"
        Category       = "Rendimiento del Sistema"
        Description    = "Permite a la NIC agrupar multiples paquetes recibidos en uno solo antes de enviarlo a la CPU, reduciendo interrupciones y mejorando la latencia."
        Method         = "Command"
        EnableCommand  = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Enable-NetAdapterRsc -IPv4 -IPv6
        }
        DisableCommand = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            Get-NetAdapter -Physical | Disable-NetAdapterRsc -IPv4 -IPv6
        }
        CheckCommand   = {
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            $rsc = Get-NetAdapterRsc -Name '*' -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -notlike '*Virtual*' -and $_.InterfaceDescription -notlike '*Loopback*' } | Select-Object -First 1
            if ($null -eq $rsc) { return 'NotApplicable' }
            return ($rsc.IPv4Enabled -eq $true -and $rsc.IPv6Enabled -eq $true)
        }
        RestartNeeded  = "None"
    },
	[PSCustomObject]@{
        Name           = "Desactivar Inicio Rapido (Fast Startup)"
        Category       = "Rendimiento del Sistema"
        Description    = "Realiza un apagado completo en lugar de una hibernacion hibrida. Soluciona problemas de drivers, actualizaciones fallidas y acceso a BIOS, a costa de unos segundos mas al arrancar."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        RegistryKey    = "HiberbootEnabled"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },

    # --- Categoria: Seguridad ---
    [PSCustomObject]@{
        Name           = "Habilitar Escudo Anti-Ransomware (Carpetas Protegidas)"
        Category       = "Seguridad"
        Description    = "Activa la proteccion de Acceso Controlado a Carpetas de Windows Defender, impidiendo que aplicaciones no autorizadas modifiquen tus archivos personales."
        Method         = "Command"
        EnableCommand  = {
			if ((Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue).Status -ne 'Running')
			{ Write-Warning "Windows Defender no esta activo.";
			return };
			Set-MpPreference -EnableControlledFolderAccess Enabled }
        DisableCommand = { if ((Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue).Status -ne 'Running')
		{ Write-Warning "Windows Defender no esta activo.";
		return };
		Set-MpPreference -EnableControlledFolderAccess Disabled }
        CheckCommand   = {
			try {
				if ((Get-Service -Name "WinDefend" -ErrorAction Stop).Status -ne 'Running') { return 'NotApplicable' };
				return (Get-MpPreference -ErrorAction Stop).EnableControlledFolderAccess -eq 1 } catch { return 'NotApplicable' }
				}
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Protocolo Inseguro SMBv1"
        Category       = "Seguridad"
        Description    = "Desactiva el protocolo de red obsoleto SMBv1, una importante medida de seguridad."
        Method         = "Command"
        EnableCommand  = { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart }
        DisableCommand = { Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart }
        CheckCommand   = {
			try {
				$feature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop;
				return ($feature.State -eq 'Disabled')
				} catch {
					return 'NotApplicable' }
					}
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar PowerShell v2.0"
        Category       = "Seguridad"
        Description    = "Desactiva el antiguo motor de PowerShell v2.0 para reducir la superficie de ataque."
        Method         = "Command"
        EnableCommand  = {
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2" -NoRestart -ErrorAction Stop
                Disable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -NoRestart -ErrorAction Stop
            }
            catch {
                Write-Warning "No se pudo deshabilitar PowerShell v2.0. Es muy probable que esta caracteristica ya no exista en tu version de Windows, lo cual es bueno para la seguridad."
            }
        }
        DisableCommand = {
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2" -NoRestart -ErrorAction Stop
                Enable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -NoRestart -ErrorAction Stop
            }
            catch {
                Write-Warning "No se pudo habilitar PowerShell v2.0. Es probable que esta caracteristica no este disponible en tu version de Windows."
            }
        }
        CheckCommand   = {
			try {
				$feature = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -ErrorAction Stop;
				return ($feature.State -eq 'Disabled')
				} catch {
					return 'NotApplicable' }
					}
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Biometria (Inhabilita Windows Hello)"
        Category       = "Seguridad"
        Description    = "ADVERTENCIA: Desactiva por directiva el uso de datos biometricos (huella, rostro). Esto rompera el inicio de sesion con Windows Hello."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Biometrics"
        RegistryKey    = "Enabled"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Desactivar Escritorio Seguro en Avisos UAC"
        Category       = "Seguridad"
        Description    = "Los avisos de administrador (UAC) apareceran sobre tu escritorio actual sin atenuar la pantalla. Acelera el proceso pero reduce el aislamiento de seguridad del aviso."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        RegistryKey    = "PromptOnSecureDesktop"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },

    # --- Categoria: Privacidad y Telemetria ---
    [PSCustomObject]@{
        Name           = "Desactivar ID de Publicidad para Apps"
        Category       = "Privacidad y Telemetria"
        Description    = "Evita que las aplicaciones usen tu ID de publicidad para mostrar anuncios personalizados."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        RegistryKey    = "Enabled"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Desactivar Seguimiento de Ubicacion (Directiva)"
        Category       = "Privacidad y Telemetria"
        Description    = "Deshabilita el servicio de localizacion a nivel de sistema."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
        RegistryKey    = "DisableLocation"
        EnabledValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Windows Recall (Snapshots de IA)"
        Category       = "Privacidad y Telemetria"
        Description    = "Evita que el sistema guarde 'snapshots' de tu actividad para la funcion de IA Recall, protegiendo tu privacidad. (Directiva Oficial)"
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        RegistryKey    = "DisableAIDataAnalysis"
        EnabledValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Personalizacion de Entrada (Directiva)"
        Category       = "Privacidad y Telemetria"
        Description    = "Impide que Windows use el historial de escritura para personalizar la experiencia, mejorando la privacidad. (Directiva Oficial)"
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        RegistryKey    = "AllowInputPersonalization"
        EnabledValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Cortana por Completo (Directiva)"
        Category       = "Privacidad y Telemetria"
        Description    = "Desactiva Cortana a nivel de sistema para que no se pueda ejecutar ni consuma recursos."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        RegistryKey    = "AllowCortana"
        EnabledValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Telemetria de Microsoft Edge (Directiva)"
        Category       = "Privacidad y Telemetria"
        Description    = "Impide que Microsoft Edge envie datos de diagnostico y uso a Microsoft. Requiere reiniciar Edge."
        Method         = "Command"
        EnableCommand  = {
            $edgePolicyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge"
            if (-not (Test-Path $edgePolicyPath)) { New-Item -Path $edgePolicyPath -Force | Out-Null }
            # 0 = Desactiva el envio de datos de diagnostico obligatorios y opcionales
            Set-ItemProperty -Path $edgePolicyPath -Name "DiagnosticData" -Value 0 -Type DWord -Force
            # 0 = Desactiva el envio de metricas de uso
            Set-ItemProperty -Path $edgePolicyPath -Name "MetricsReportingEnabled" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            $edgePolicyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge"
            if (Test-Path $edgePolicyPath) {
                Remove-ItemProperty -Path $edgePolicyPath -Name "DiagnosticData" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $edgePolicyPath -Name "MetricsReportingEnabled" -Force -ErrorAction SilentlyContinue
            }
        }
        CheckCommand   = {
            $diagValue = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge" -Name "DiagnosticData" -ErrorAction SilentlyContinue
            $metricsValue = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge" -Name "MetricsReportingEnabled" -ErrorAction SilentlyContinue
            return ($null -ne $diagValue -and $diagValue.DiagnosticData -eq 0 -and $null -ne $metricsValue -and $metricsValue.MetricsReportingEnabled -eq 0)
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Sincronizacion en la Nube (Directiva)"
        Category       = "Privacidad y Telemetria"
        Description    = "Impide que la configuracion de Windows (temas, contraseñas, preferencias) se sincronice con la cuenta de Microsoft."
        Method         = "Command"
        EnableCommand  = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SettingSync"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            Set-ItemProperty -Path $policyPath -Name "DisableSettingSync" -Value 2 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "DisableSettingSyncUserOverride" -Value 1 -Type DWord -Force
        }
        DisableCommand = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SettingSync"
            if (Test-Path $policyPath) {
                Remove-ItemProperty -Path $policyPath -Name "DisableSettingSync" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "DisableSettingSyncUserOverride" -Force -ErrorAction SilentlyContinue
            }
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SettingSync" -Name "DisableSettingSync" -ErrorAction SilentlyContinue).DisableSettingSync
            return $val -eq 2
        }
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Historial de Actividad (Timeline) (Directiva)"
        Category       = "Privacidad y Telemetria"
        Description    = "Impide que Windows recopile y muestre el historial de actividades del usuario (Timeline)."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System"
        RegistryKey    = "EnableActivityFeed"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Desactivar Recopilacion de Datos de Microsoft"
        Category       = "Privacidad y Telemetria"
        Description    = "Deshabilita el servicio 'DiagTrack' y las tareas del 'Programa para la mejora de la experiencia del cliente' para minimizar el envio de datos de uso a Microsoft."
        Method         = "Command"
        EnableCommand  = {
            Get-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" -ErrorAction SilentlyContinue | Disable-ScheduledTask
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
            Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        }
        DisableCommand = {
            Get-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" -ErrorAction SilentlyContinue | Enable-ScheduledTask
            Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "DiagTrack" -StartupType "Automatic" -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            $task = Get-ScheduledTask -TaskName "Consolidator" -ErrorAction SilentlyContinue
            $telemetryValue = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
            return ($task.State -eq 'Disabled' -and $telemetryValue -eq 0)
        }
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Denegar Permisos Globales a Apps (Camara, Microfono, etc.)"
        Category       = "Privacidad y Telemetria"
        Description    = "Establece el permiso por defecto a 'Denegar' para el acceso a hardware y datos sensibles (camara, microfono, documentos)."
        Method         = "Command"
        EnableCommand  = {
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "Value" -Value "Deny" -Type String -Force
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name "Value" -Value "Deny" -Type String -Force
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary" -Name "Value" -Value "Deny" -Type String -Force
        }
        DisableCommand = {
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "Value" -Value "Allow" -Type String -Force
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name "Value" -Value "Allow" -Type String -Force
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary" -Name "Value" -Value "Allow" -Type String -Force
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "Value" -ErrorAction SilentlyContinue).Value
            return $val -eq "Deny"
        }
        RestartNeeded  = "None"
    },
	[PSCustomObject]@{
        Name           = "Aplicar Politicas Restrictivas a Microsoft Edge (Debloat)"
        Category       = "Privacidad y Telemetria"
        Description    = "Aplica un conjunto de politicas para reducir la telemetria y funciones no deseadas en Edge (Colecciones, Recompensas, etc.)."
        Method         = "Command"
        EnableCommand  = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            Set-ItemProperty -Path $policyPath -Name "ShowRecommendationsEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "HideFirstRunExperience" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "EdgeCollectionsEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "EdgeShoppingAssistantEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "ShowMicrosoftRewards" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "StartupBoostEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "SendSiteInfoToImproveServices" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "CryptoWalletEnabled" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge"
            if (Test-Path $policyPath) {
                Remove-ItemProperty -Path $policyPath -Name "ShowRecommendationsEnabled" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "HideFirstRunExperience" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "EdgeCollectionsEnabled" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "EdgeShoppingAssistantEnabled" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "ShowMicrosoftRewards" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "StartupBoostEnabled" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "SendSiteInfoToImproveServices" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "CryptoWalletEnabled" -Force -ErrorAction SilentlyContinue
            }
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge" -Name "StartupBoostEnabled" -ErrorAction SilentlyContinue).StartupBoostEnabled
            return $val -eq 0
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Bloquear Ejecucion de Apps en Segundo Plano"
        Category       = "Privacidad y Telemetria"
        Description    = "Aplica una directiva de sistema que impide que las aplicaciones de la Tienda se ejecuten en segundo plano, ahorrando bateria y recursos. (Mas efectivo en W10)."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
        RegistryKey    = "LetAppsRunInBackground"
        EnabledValue   = 2
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Session"
    },
	[PSCustomObject]@{
        Name           = "Desactivar Optimizacion de Entrega (P2P Updates)"
        Category       = "Privacidad y Telemetria"
        Description    = "Impide que Windows use tu ancho de banda para subir actualizaciones a otros equipos en Internet. (Modo de descarga: Simple)."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
        RegistryKey    = "DODownloadMode"
        EnabledValue   = 99 # 99 = Simple (Sin P2P), 0 = HTTP Only
        DefaultValue   = 1  # 1 = LAN P2P
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Desactivar Informe de Errores de Windows"
        Category       = "Privacidad y Telemetria"
        Description    = "Deshabilita el servicio WerSvc que recopila y envia informes de fallos a Microsoft."
        Method         = "Command"
        EnableCommand  = {
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -Type DWord -Force
            Set-Service -Name "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
        }
        DisableCommand = {
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 0 -Type DWord -Force
            Set-Service -Name "WerSvc" -StartupType Manual -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -ErrorAction SilentlyContinue).Disabled
            return $val -eq 1
        }
        RestartNeeded  = "Reboot"
    },

    # --- Categoria: Comportamiento del Sistema y UI ---
    [PSCustomObject]@{
        Name           = "Deshabilitar la Pantalla de Bloqueo (Directiva)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Va directamente a la pantalla de inicio de sesion, omitiendo la pantalla de bloqueo."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        RegistryKey    = "NoLockScreen"
        EnabledValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Restaurar Menu Contextual Completo (Anti Mostrar mas)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "En Windows 11, reemplaza el menu contextual simplificado, mostrando siempre el menu clasico con todas las opciones directamente, sin necesidad de un clic extra."
        Method         = "Command"
        EnableCommand  = {
			$regPath = 'Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32';
		    New-Item -Path $regPath -Force -ErrorAction SilentlyContinue | Out-Null;
		    Set-ItemProperty -Path $regPath -Name '(Default)' -Value '' }
        DisableCommand = { Remove-Item -Path 'Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue }
        CheckCommand   = { Test-Path 'Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' }
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Convertir Busqueda de Inicio en 100% Local"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Elimina por completo las sugerencias y resultados web de Bing del menu de inicio, haciendo que la busqueda se centre unicamente en tus archivos y aplicaciones locales."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        RegistryKey    = "DisableSearchBoxSuggestions"
        EnabledValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Anadir 'Bloquear en Firewall' al Menu Contextual"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Anade una opcion para bloquear una aplicacion en el Firewall. NOTA: Las reglas creadas no se borran al desactivar."
        Method         = "Command"
        EnableCommand  = {
	            	$keyPath = "Registry::HKEY_CLASSES_ROOT\exefile\shell\blockinfirewall";
		            New-Item -Path $keyPath -Force | Out-Null;
		            Set-ItemProperty -Path $keyPath -Name "(Default)" -Value "Bloquear en Firewall";
		            Set-ItemProperty -Path $keyPath -Name "Icon" -Value "firewall.cpl"; $commandPath = "$keyPath\command";
		            New-Item -Path $commandPath -Force | Out-Null;
	            	$command = "powershell -WindowStyle Hidden -Command `"New-NetFirewallRule -DisplayName 'AegisPhoenixBlock - %1' -Direction Outbound -Program `"%1`" -Action Block`"";
		            Set-ItemProperty -Path $commandPath -Name "(Default)" -Value $command
	            	}
        DisableCommand = {
		            Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\exefile\shell\blockinfirewall" -Recurse -Force -ErrorAction SilentlyContinue
		            }
        CheckCommand   = {
	           	   Test-Path "Registry::HKEY_CLASSES_ROOT\exefile\shell\blockinfirewall"
		           }
        RestartNeeded  = "Explorer"
    },
	[PSCustomObject]@{
        Name           = "Ocultar Icono 'Mas Informacion' de Spotlight"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Elimina el icono superpuesto en el escritorio cuando se usa Windows Spotlight como fondo."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Feeds"
        RegistryKey    = "ShellFeedsTaskbarViewMode"
        EnabledValue   = 2
        DefaultValue   = 0
        RegistryType   = "DWord" 
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Anadir 'Copiar Ruta' al Menu Contextual"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Anade una opcion util al menu contextual para copiar la ruta completa de cualquier archivo o carpeta al portapapeles."
        Method         = "Command"
        EnableCommand  = {
			$keyPath = "Registry::HKEY_CLASSES_ROOT\AllFilesystemObjects\shell\CopyPath";
			if (-not (Test-Path $keyPath)) {
				New-Item -Path $keyPath -Force | Out-Null };
				Set-ItemProperty -Path $keyPath -Name "(Default)" -Value "Copiar Ruta de Acceso";
				Set-ItemProperty -Path $keyPath -Name "Icon" -Value "imageres.dll,-5302"; $commandPath = Join-Path -Path $keyPath -ChildPath "command";
				if (-not (Test-Path $commandPath)) { New-Item -Path $commandPath -Force | Out-Null };
				$command = 'cmd.exe /c echo "%1" | clip'; Set-ItemProperty -Path $commandPath -Name "(Default)" -Value $command
				}
        DisableCommand = {
			$keyPath = "Registry::HKEY_CLASSES_ROOT\AllFilesystemObjects\shell\CopyPath";
			if (Test-Path $keyPath)
			{
				Remove-Item -Path $keyPath -Recurse -Force -ErrorAction SilentlyContinue }
			}
        CheckCommand   = { Test-Path "Registry::HKEY_CLASSES_ROOT\AllFilesystemObjects\shell\CopyPath\command" }
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Notificaciones y Centro de Accion"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Oculta el Centro de Accion y deshabilita las notificaciones emergentes (toasts)."
        Method         = "Command"
        EnableCommand  = {
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 1 -Type DWord -Force
        }
        CheckCommand   = {
            $val1 = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -ErrorAction SilentlyContinue).DisableNotificationCenter
            $val2 = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -ErrorAction SilentlyContinue).ToastEnabled
            return ($val1 -eq 1 -and $val2 -eq 0)
        }
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Activar Modo Oscuro para Sistema y Apps"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Establece el tema oscuro como predeterminado para las aplicaciones y la interfaz del sistema."
        Method         = "Command"
        EnableCommand  = {
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 1 -Type DWord -Force
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue).AppsUseLightTheme
            return $val -eq 0
        }
        RestartNeeded  = "None"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Widgets y Noticias en la Barra de Tareas (Directiva)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Desactiva completamente la funcionalidad de Widgets/Noticias e Intereses en la barra de tareas."
        Method         = "Command"
        EnableCommand  = {
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            Remove-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Force -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ErrorAction SilentlyContinue).TaskbarDa
            return $val -eq 0
        }
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Activar Mensajes Detallados de Inicio de Sesion"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Muestra informacion detallada sobre los procesos que se estan cargando durante el inicio y cierre de sesion."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        RegistryKey    = "VerboseStatus"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Anadir 'Finalizar Tarea' al Menu Contextual de la Barra de Tareas"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Agrega una opcion para forzar el cierre de programas al hacer clic derecho en su icono de la barra de tareas."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        RegistryKey    = "TaskbarEndTask"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Busqueda Web en Menu Inicio (Directiva GPO)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Eliminar completamente los resultados web de Bing y Cortana de la busqueda."
        Method         = "Command"
        EnableCommand  = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            Set-ItemProperty -Path $policyPath -Name "DisableWebSearch" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (Test-Path $policyPath) {
                Remove-ItemProperty -Path $policyPath -Name "DisableWebSearch" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "ConnectedSearchUseWeb" -Force -ErrorAction SilentlyContinue
            }
            Remove-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Force -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -ErrorAction SilentlyContinue).DisableWebSearch
            return ($null -ne $val -and $val -eq 1)
        }
        RestartNeeded  = "Explorer"
    },
	[PSCustomObject]@{
        Name           = "Mostrar Extensiones de Archivo (Seguridad)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Obliga al Explorador a mostrar siempre la extension de los archivos (.exe, .bat, .txt). Fundamental para detectar malware disfrazado."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        RegistryKey    = "HideFileExt"
        EnabledValue   = 0  # 0 = Mostrar (No ocultar)
        DefaultValue   = 1  # 1 = Ocultar
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    },
	[PSCustomObject]@{
        Name           = "Desactivar Atajo de Teclas Especiales (Sticky Keys)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Evita que aparezca el dialogo de 'Teclas Especiales' al presionar Shift 5 veces. Vital para gaming."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Control Panel\Accessibility\StickyKeys"
        RegistryKey    = "Flags"
        EnabledValue   = "506" # Valor magico que desactiva el atajo
        DefaultValue   = "510" # Valor por defecto
        RegistryType   = "String"
        RestartNeeded  = "Session"
    },

	# --- Categoria: Extras (Nuevos) ---
    [PSCustomObject]@{
        Name           = "Desinstalar OneDrive Completamente"
        Category       = "Extras"
        Description    = "ADVERTENCIA: Desinstala OneDrive y elimina sus datos locales. Mueve los archivos de OneDrive a la carpeta de usuario antes de proceder."
        Method         = "Command"
        EnableCommand  = {
            # --- PASO 1 (NUEVO Y CRITICO): Deshabilitar OneDrive via Directiva de Grupo ---
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\OneDrive"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            Set-ItemProperty -Path $policyPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force

            # --- PASO 2: Desinstalacion y Limpieza Profunda ---
            Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
            if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") { Start-Process -FilePath "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait }
            if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { Start-Process -FilePath "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait }
            
            # Limpieza de registro y carpetas
            Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -Force -ErrorAction SilentlyContinue
            
            $clsidPath = "Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
            if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
            Set-ItemProperty -Path $clsidPath -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force

            Get-ScheduledTask -TaskPath '\' -TaskName 'OneDrive*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
            Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        }
        DisableCommand = { 
            # Para reactivar, se elimina la directiva y se avisa para reinstalacion manual
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\OneDrive"
            if (Test-Path $policyPath) { Remove-ItemProperty -Path $policyPath -Name "DisableFileSyncNGSC" -Force -ErrorAction SilentlyContinue }
            Write-Warning "La directiva que bloquea OneDrive ha sido eliminada."
            Write-Warning "La reinstalacion de OneDrive debe hacerse manualmente descargando el instalador desde el sitio de Microsoft." 
        }
        CheckCommand   = {
            # --- DETECCION DEFINITIVA ---
            # El ajuste esta 'Activado' (desinstalado) si la directiva de bloqueo esta activa.
            $policyValue = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue).DisableFileSyncNGSC
            return ($null -ne $policyValue -and $policyValue -eq 1)
        }
        RestartNeeded  = "Reboot"
    }
)
