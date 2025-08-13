# --- CATALOGO CENTRAL DE AJUSTES DEL SISTEMA ---
# Esta es la "fuente de la verdad" para todos los tweaks, ajustes de seguridad, privacidad y UI.
# Cada objeto define un ajuste, permitiendo que los menus y las acciones se generen dinamicamente.
$script:SystemTweaks = @(
    # --- Categoria: Rendimiento UI ---
    [PSCustomObject]@{
        Name           = "Acelerar la Aparicion de Menus"
        Category       = "Rendimiento UI"
        Description    = "Reduce el retraso (en ms) al mostrar los menus contextuales del Explorador."
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
        Name           = "Aplicar Configuracion Visual Personalizada (Rendimiento/Calidad)"
        Category       = "Rendimiento UI"
        Description    = "Máxima fluidez, cero distracciones. Elimina las animaciones lentas pero mantiene un escritorio funcional y moderno."
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
	[PSCustomObject]@{
        Name           = "Lanzar Explorador en Proceso Separado"
        Category       = "Rendimiento UI"
        Description    = "Ejecuta cada ventana del Explorador en su propio proceso. Mejora la estabilidad y la respuesta, evitando que una ventana bloqueada afecte a las demas."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        RegistryKey    = "SeparateProcess"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
	},
 
    # --- Categoria: Rendimiento del Sistema ---
    [PSCustomObject]@{
        Name           = "Aumentar Prioridad de CPU para Ventana Activa"
        Category       = "Rendimiento del Sistema"
        Description    = "Asigna mas ciclos de CPU a la aplicacion en primer plano, mejorando su respuesta."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl"
        RegistryKey    = "Win32PrioritySeparation"
        EnabledValue   = 26
        DefaultValue   = 2
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Limitacion de Red para Multimedia"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva la limitacion de red del Programador de Clases Multimedia (MMCSS) para maximizar el rendimiento de todo el trafico de red."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        RegistryKey    = "NetworkThrottlingIndex"
        EnabledValue   = '4294967295' # 4294967295 en DWord
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
        Name           = "Desactivar VBS (Seguridad Basada en Virtualizacion)"
        Category       = "Rendimiento del Sistema"
        Description    = "Mejora el rendimiento en juegos y maquinas virtuales. Reduce la seguridad."
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
        Name           = "Deshabilitar Vistas Previas (Thumbnails) en Carpetas de Red"
        Category       = "Rendimiento UI"
        Description    = "Acelera la navegacion en carpetas de red al no generar vistas previas de imagenes y videos. Se mostraran iconos genericos."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\Explorer"
        RegistryKey    = "DisableThumbnailsOnNetworkFolders"
        EnabledValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
	},

    # --- Categoria: Seguridad ---
    [PSCustomObject]@{
        Name           = "Activar Proteccion contra Ransomware"
        Category       = "Seguridad"
        Description    = "Habilita la proteccion de carpetas controladas de Windows Defender."
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
			Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart;
			Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart
			}
        DisableCommand = {
			Enable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart;
			Enable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart
			}
        CheckCommand   = {
			try {
				$feature = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -ErrorAction Stop;
				return ($feature.State -eq 'Disabled')
				} catch {
					return 'NotApplicable'
					}
				}
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Busqueda Automatica de Carpetas y F impresoras de Red"
        Category       = "Rendimiento del Sistema"
        Description    = "Evita que el Explorador de Archivos busque impresoras y carpetas de red automaticamente, reduciendo los retrasos al abrir 'Este equipo'."
        Method         = "Command"
        EnableCommand  = {
            $keysToRemove = @(
                "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{2227A280-3AEA-1069-A2DE-08002B30309D}", # Impresoras
                "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{D20BEEC4-5CA8-4905-AE3B-BF251EA09B53}"  # Work Folders
            )
            foreach ($key in $keysToRemove) {
                if (Test-Path $key) {
                    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        DisableCommand = {
            $printersKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{2227A280-3AEA-1069-A2DE-08002B30309D}"
            if (-not (Test-Path $printersKey)) { New-Item -Path $printersKey -Force | Out-Null }
            $workFoldersKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{D20BEEC4-5CA8-4905-AE3B-BF251EA09B53}"
            if (-not (Test-Path $workFoldersKey)) { New-Item -Path $workFoldersKey -Force | Out-Null }
        }
        CheckCommand   = {
            $printersKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{2227A280-3AEA-1069-A2DE-08002B30309D}"
            return -not (Test-Path $printersKey)
        }
        RestartNeeded  = "Explorer"
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
        Name           = "Deshabilitar Telemetria de CEIP (SQM) (Directiva)"
        Category       = "Privacidad y Telemetria"
        Description    = "Desactiva el Programa para la mejora de la experiencia del cliente a nivel de directiva."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\SQMClient\Windows"
        RegistryKey    = "CEIPEnable"
        EnabledValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "None"
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
        Name           = "Habilitar Menu Contextual Clasico (Estilo Win10)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Reemplaza el menu contextual de Windows 11 por el clasico mas completo."
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
        Name           = "Deshabilitar Busqueda con Bing en el Menu Inicio (Directiva)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Evita que las busquedas en el menu de inicio muestren resultados web de Bing."
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
    }
)
