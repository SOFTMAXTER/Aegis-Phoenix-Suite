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
        CheckCommand = {
            $basePath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    
            # Definimos los valores criticos esperados para considerar que esta "Activado"
            # Basado en tu EnableCommand
            $expectedValues = @{
                "ControlAnimations"       = 0
                "AnimateMinMax"           = 0
                "TaskbarAnimations"       = 0
                "DWMAeroPeekEnabled"      = 1
                "MenuAnimation"           = 0
                "TooltipAnimation"        = 0
                "SelectionFade"           = 0
                "DWMSaveThumbnailEnabled" = 0
                "CursorShadow"            = 1
                "ListviewShadow"          = 1
                "ThumbnailsOrIcon"        = 1
                "ListviewAlphaSelect"     = 1
                "DragFullWindows"         = 1
                "ComboBoxAnimation"       = 0
                "FontSmoothing"           = 1
                "ListBoxSmoothScrolling"  = 0
                "DropShadow"              = 0
            }

            $allMatch = $true
    
            foreach ($key in $expectedValues.Keys) {
                $current = (Get-ItemProperty -Path "$basePath\$key" -Name 'DefaultValue' -ErrorAction SilentlyContinue).DefaultValue
                # Comparamos como enteros para evitar errores de tipo
                if ([int]$current -ne [int]$expectedValues[$key]) {
                        $allMatch = $false
                        break # Si uno falla, ya no es necesario seguir
                }
            }
    
            return $allMatch
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
        Name           = "Desactivar Aceleracion del Raton"
        Category       = "Rendimiento del Sistema"
        Description    = "Configura el raton para una precision 1:1, eliminando la aceleracion de Windows."
        Method         = "Command"
        EnableCommand  = {
            # Desactivar aceleracion (Plano)
            # IMPORTANTE: Se fuerza el tipo 'String' para respetar el formato del registro
            Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseSpeed' -Value "0" -Type String -Force
            Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "0" -Type String -Force
            Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "0" -Type String -Force
        }
        DisableCommand = {
            # Restaurar valores por defecto de Windows (Aceleracion Estandar)
            Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseSpeed' -Value "1" -Type String -Force
            Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold1' -Value "6" -Type String -Force
            Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold2' -Value "10" -Type String -Force
        }
        CheckCommand   = {
            $props = Get-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Control Panel\Mouse' -ErrorAction SilentlyContinue
            if ($null -eq $props) { return $false }
        
            # Convertimos a entero para asegurar comparacion numerica segura
            $speed = [int]$props.MouseSpeed
            $thresh1 = [int]$props.MouseThreshold1
            $thresh2 = [int]$props.MouseThreshold2
        
            return ($speed -eq 0 -and $thresh1 -eq 0 -and $thresh2 -eq 0)
        }
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Desactivar VBS para Maximo Rendimiento en Juegos"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva la seguridad basada en virtualizacion para ganar FPS. (Protegido: Detecta si usas WSL2/Docker/Sandbox y te advierte que dejaran de funcionar)."
        Method         = "Command"
        EnableCommand  = {
            # 1. Deteccion de Conflictos (WSL2 / Virtual Machine Platform)
            $hasConflict = $false
            $conflictList = @()
            
            # Verificacion ligera de caracteristicas (evitamos cargar todo DISM si es posible)
            # Buscamos servicios clave de WSL/Hyper-V
            if (Get-Service "LxssManager" -ErrorAction SilentlyContinue) { 
                $conflictList += "Subsistema Linux (WSL2)"
                $hasConflict = $true
            }
            if ((Get-WindowsOptionalFeature -Online -FeatureName "Containers" -ErrorAction SilentlyContinue).State -eq 'Enabled') {
                $conflictList += "Docker / Contenedores"
                $hasConflict = $true
            }

            # 2. Advertencia si se detectan conflictos
            if ($hasConflict) {
                Add-Type -AssemblyName System.Windows.Forms
                $msg = "ADVERTENCIA: Se han detectado componentes activos de virtualizacion:`n`n - " + ($conflictList -join "`n - ") + "`n`nSi desactivas VBS, estas herramientas DEJARAN DE FUNCIONAR.`n¿Deseas continuar de todos modos para priorizar el rendimiento en juegos?"
                $warn = [System.Windows.Forms.MessageBox]::Show($msg, "Conflicto de Virtualizacion", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                
                if ($warn -ne 'Yes') {
                    Write-Warning "Operacion cancelada para proteger WSL/Docker."
                    return
                }
            }

            # 3. Ejecucion
            bcdedit /set hypervisorlaunchtype off
            Write-Host "VBS desactivado. Reinicia para ganar rendimiento." -ForegroundColor Green
        }
        DisableCommand = { 
            bcdedit /set hypervisorlaunchtype Auto 
            Write-Host "VBS/Hipervisor reactivado (Auto). Reinicia para recuperar WSL/Docker." -ForegroundColor Green
        }
        CheckCommand   = {
			$output = bcdedit /enum "{current}";
			if ($LASTEXITCODE -ne 0) { return 'NotApplicable' };
		    return ($output -like "*hypervisorlaunchtype*Off*")
		}
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Barra de Juegos y DVR (Completo)"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva globalmente la Xbox Game Bar y la grabacion en segundo plano (DVR) aplicando ajustes de usuario y directivas de sistema. Libera recursos, mejora los FPS y evita que se reactive."
        Method         = "Command"
        EnableCommand  = {
            # 1. Ajustes de Usuario (HKCU)
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            
            # 2. Directiva de Maquina (HKLM) - GPO
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            Set-ItemProperty -Path $policyPath -Name "AllowGameDVR" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            # 1. Restaurar Ajustes de Usuario
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            
            # 2. Eliminar Directiva de Maquina
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
            if (Test-Path $policyPath) {
                Remove-ItemProperty -Path $policyPath -Name "AllowGameDVR" -Force -ErrorAction SilentlyContinue
            }
        }
        CheckCommand   = {
            # Verifica que tanto la configuracion de usuario como la directiva esten aplicadas
            $userVal = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\System\GameConfigStore" -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue).GameDVR_Enabled
            $policyVal = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -ErrorAction SilentlyContinue).AllowGameDVR
            
            # Si ambos son 0 (o la politica existe y es 0), consideramos que esta activado el tweak
            return ($userVal -eq 0 -and $policyVal -eq 0)
        }
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Activar Plan de Energia de Maximo Rendimiento Definitivo"
        Category       = "Rendimiento del Sistema"
        Description    = "Activa el plan 'Ultimate Performance'. ADVERTENCIA: En portatiles puede causar alto consumo de bateria y calor excesivo."
        Method         = "Command"
        EnableCommand  = {
            # --- PROTECCIoN PARA PORTaTILES ---
            $isPortable = $false
            try {
                # Metodo 1: Bateria
                if (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) { $isPortable = $true }
                
                # Metodo 2: Chasis (Tipos 8, 9, 10, 14, etc. son portatiles)
                $chassis = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue
                if ($chassis.ChassisTypes -match '^(8|9|10|11|12|14|30|31|32)$') { $isPortable = $true }
            } catch {}

            if ($isPortable) {
                # Requiere cargar WinForms si no esta cargado (normalmente ya lo esta por el menu padre)
                Add-Type -AssemblyName System.Windows.Forms
                $msg = "Se ha detectado que este equipo es un PORTaTIL.`n`nActivar el modo 'Maximo Rendimiento' impedira que el procesador reduzca su velocidad, lo que causara:`n- Drenaje rapido de bateria.`n- Mayor temperatura (riesgo en mochilas).`n`n¿Estas seguro de querer activarlo?"
                $warn = [System.Windows.Forms.MessageBox]::Show($msg, "Advertencia de Energia", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                
                if ($warn -ne 'Yes') { 
                    Write-Warning "Activacion cancelada por el usuario (Proteccion de Portatil)."
                    return 
                }
            }

            # Codigo original de activacion
            $ultimatePlanGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            # Intentar duplicar el esquema si no existe
            $check = powercfg /list
            if ($check -notmatch $ultimatePlanGuid) {
                powercfg -duplicatescheme $ultimatePlanGuid | Out-Null
            }
            powercfg /setactive $ultimatePlanGuid
            Write-Host "Plan de Maximo Rendimiento Activado."
        }
        DisableCommand = {
            # Volver a Equilibrado (Balanced)
            $balancedPlanGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
            powercfg /setactive $balancedPlanGuid
            Write-Host "Restaurado a Plan Equilibrado."
        }
        CheckCommand   = {
            $ultimatePlanGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            $activeScheme = powercfg /getactivescheme
            return ($activeScheme -match $ultimatePlanGuid)
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Optimizar Uso de Memoria del Sistema de Archivos (NtfsMemoryUsage)"
        Category       = "Rendimiento del Sistema"
        Description    = "Aumenta la memoria cache para operaciones de archivos (NTFS), acelerando la lectura/escritura en disco. (Protegido: Solo se activa si detecta 8 GB de RAM o mas)."
        Method         = "Command"
        EnableCommand  = {
            # 1. Obtener Memoria Total en GB (Redondeado)
            $totalRamBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
            $totalRamGB = [math]::Round($totalRamBytes / 1GB)

            # 2. Condicion de Seguridad: Minimo 8 GB requeridos
            if ($totalRamGB -lt 8) {
                Write-Warning "Este ajuste requiere al menos 8 GB de RAM para ser seguro."
                Write-Warning "Tu sistema tiene ${totalRamGB} GB. Activar esto podria ralentizar tu PC al agotar la memoria."
                Write-Warning "No se aplicaron cambios."
                return
            }

            # 3. Aplicar el ajuste si cumple la condicion
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsMemoryUsage" -Value 2 -Type DWord -Force
            Write-Host "Optimizacion de memoria NTFS activada (Sistema con ${totalRamGB} GB de RAM)." -ForegroundColor Green
        }
        DisableCommand = {
            # Restaurar valor por defecto (1)
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsMemoryUsage" -Value 1 -Type DWord -Force
            Write-Host "Restaurado a la configuracion estandar de Windows (Valor: 1)." -ForegroundColor Gray
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue).NtfsMemoryUsage
            return ($val -eq 2)
        }
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
        Description    = "Desactiva la hibernacion y elimina el archivo hiberfil.sys para liberar espacio (~tamaño de RAM). (Protegido: Advierte si detecta que es un portatil)."
        Method         = "Command"
        EnableCommand  = {
            # 1. Deteccion de Portatil (Bateria o Chasis)
            $isPortable = $false
            try {
                if (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) { $isPortable = $true }
                $chassis = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue
                # Tipos de chasis moviles: 8=Portable, 9=Laptop, 10=Notebook, etc.
                if ($chassis.ChassisTypes -match '^(8|9|10|11|12|14|30|31|32)$') { $isPortable = $true }
            } catch {}

            # 2. Valla de Seguridad para Portatiles
            if ($isPortable) {
                Add-Type -AssemblyName System.Windows.Forms
                $msg = "Se ha detectado que este equipo es un PORTATIL.`n`nDesactivar la hibernacion eliminara la funcion de 'Hibernar en Bateria Critica'.`nSi la bateria se agota durante la suspension, perderas los datos no guardados.`n`n¿Estas seguro de querer desactivarla para liberar espacio?"
                $warn = [System.Windows.Forms.MessageBox]::Show($msg, "Advertencia de Seguridad", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                
                if ($warn -ne 'Yes') { 
                    Write-Warning "Operacion cancelada por el usuario (Proteccion de Portatil)."
                    return 
                }
            }

            # 3. Ejecucion (Si es escritorio o el usuario acepto el riesgo)
            powercfg.exe /hibernate off
            Write-Host "Hibernacion desactivada y hiberfil.sys eliminado." -ForegroundColor Green
        }
        DisableCommand = { 
            powercfg.exe /hibernate on 
            Write-Host "Hibernacion reactivada." -ForegroundColor Green
        }
        CheckCommand   = {
            $status = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -ErrorAction SilentlyContinue
            return ($null -ne $status -and $status.HibernateEnabled -eq 0)
        }
        RestartNeeded  = "Reboot"
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
	[PSCustomObject]@{
        Name           = "Acelerar Apagado del Sistema (Kill Services)"
        Category       = "Rendimiento del Sistema"
        Description    = "Reduce el tiempo que Windows espera a que los servicios se detengan antes de forzar el apagado (de 5000ms a 2000ms)."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control"
        RegistryKey    = "WaitToKillServiceTimeout"
        EnabledValue   = "2000"
        DefaultValue   = "5000"
        RegistryType   = "String"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Aumentar Cache de Iconos (Carga mas rapida)"
        Category       = "Rendimiento del Sistema"
        Description    = "Aumenta el tamaño de la cache de iconos a 4MB. Evita que el Explorador tenga que reconstruir iconos frecuentemente, acelerando la navegacion por carpetas."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        RegistryKey    = "MaxCachedIcons"
        EnabledValue   = "4096"
        DefaultValue   = "500" # Valor tipico por defecto
        RegistryType   = "String"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Habilitar Programacion de GPU Acelerada por Hardware (HAGS)"
        Category       = "Rendimiento del Sistema"
        Description    = "Permite que la tarjeta grafica gestione su propia memoria, reduciendo latencia. (Protegido: Requiere Windows 10 v2004+ y drivers compatibles)."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        RegistryKey    = "HwSchMode"
        EnabledValue   = 2
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
        EnableCommand  = {
            # Verificacion de version minima (Win10 2004 = Build 19041)
            if ([Environment]::OSVersion.Version.Build -lt 19041) {
                Write-Warning "Tu version de Windows es demasiado antigua para soportar HAGS."
                return
            }
            # Aplicar registro
            $path = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -Path $path -Name "HwSchMode" -Value 2 -Type DWord -Force
        }
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Creacion de Nombres Cortos (8.3)"
        Category       = "Rendimiento del Sistema"
        Description    = "Mejora el rendimiento de escritura en NTFS al dejar de crear nombres compatibles con MS-DOS (ej. ARCHIV~1.TXT). Recomendado si no usas software de 16-bits."
        Method         = "Command"
        EnableCommand  = { fsutil behavior set disable8dot3 1 }
        DisableCommand = { fsutil behavior set disable8dot3 0 }
        CheckCommand   = { 
            # Verificacion directa en el registro en lugar de leer texto de consola
            $regVal = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisable8dot3NameCreation" -ErrorAction SilentlyContinue).NtfsDisable8dot3NameCreation
            # 1 significa deshabilitado
            return ($regVal -eq 1)
        }
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Acelerar Indexacion de Busqueda (Desactivar Backoff)"
        Category       = "Rendimiento del Sistema"
        Description    = "Obliga al indexador de Windows a trabajar a maxima velocidad (sin pausas) incluso si estas usando el PC. Garantiza que los archivos nuevos aparezcan en la busqueda al instante. (Puede aumentar el uso de CPU durante la indexacion)."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        RegistryKey    = "DisableBackoff"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Forzar Modo de Busqueda Clasico (Maximo Rendimiento)"
        Category       = "Rendimiento del Sistema"
        Description    = "Desactiva el indexado 'Mejorado' (que escanea todo el disco y ralentiza la busqueda). Fuerza el modo 'Clasico' que solo indexa bibliotecas y escritorio, resultando en una base de datos mas ligera y busquedas instantaneas."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search"
        RegistryKey    = "EnableEnhancedSearchMode"
        EnabledValue   = 0  # 0 = Clasico (Rapido), 1 = Mejorado (Lento)
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },

	# --- Categoria: Windows 11 UI y Nuevas Funciones ---
    [PSCustomObject]@{
        Name           = "Deshabilitar Windows Copilot (Sistema y App)"
        Category       = "Windows 11 UI"
        Description    = "Desactiva la integracion de Copilot. En versiones modernas (24H2+), tambien desinstala la aplicacion web de Copilot para evitar que se reactive."
        Method         = "Command"
        EnableCommand  = {
            # 1. Método Legacy (Registro para versiones 23H2 e inferiores)
            $regPath = "Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\WindowsCopilot"
            if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            Set-ItemProperty -Path $regPath -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force

            # 2. Método Moderno (Desinstalar el paquete Appx para 24H2+)
            Get-AppxPackage -Name "Microsoft.Copilot" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
        DisableCommand = {
            # Restaurar clave de registro
            $regPath = "Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\WindowsCopilot"
            if (Test-Path $regPath) { Remove-ItemProperty -Path $regPath -Name "TurnOffWindowsCopilot" -Force -ErrorAction SilentlyContinue }
            
            Write-Warning "Si estás en Windows 11 24H2, deberás reinstalar la app 'Microsoft Copilot' desde la Tienda manualmente."
        }
        CheckCommand   = {
            if ([Environment]::OSVersion.Version.Build -lt 22000) { return 'NotApplicable' }
            
            # Verificamos si la Appx NO existe O si la clave de registro está activa
            $appExists = Get-AppxPackage -Name "Microsoft.Copilot" -ErrorAction SilentlyContinue
            $regVal = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
            
            return ($null -eq $appExists -or $regVal -eq 1)
        }
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Alineacion Clasica de Barra de Tareas (Izquierda)"
        Category       = "Windows 11 UI"
        Description    = "Mueve el boton de Inicio y los iconos a la izquierda, restaurando el flujo de trabajo clasico. (Protegido: Solo aplica en Windows 11, en W10 ya es el defecto)."
        Method         = "Command"
        EnableCommand  = {
            # 1. Verificacion de Version: Windows 11 comienza en la Build 22000
            $currentBuild = [Environment]::OSVersion.Version.Build
            if ($currentBuild -lt 22000) {
                Write-Warning "Este ajuste es exclusivo para Windows 11."
                Write-Warning "Tu version actual (Windows 10) ya tiene la alineacion a la izquierda por defecto."
                return
            }

            # 2. Aplicar alineacion a la izquierda (0)
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            # Restaurar al centro (1) - Valor por defecto de Windows 11
            # Solo intentamos cambiarlo si estamos en Windows 11 para evitar errores
            if ([Environment]::OSVersion.Version.Build -ge 22000) {
                Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 1 -Type DWord -Force
            }
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -ErrorAction SilentlyContinue).TaskbarAl
            return ($val -eq 0)
        }
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Ocultar Icono de Chat/Teams en Barra de Tareas"
        Category       = "Windows 11 UI"
        Description    = "Elimina el icono de Chat (Teams personal) de la barra de tareas usando la directiva de sistema moderna (compatible con 23H2/24H2)."
        Method         = "Command"
        EnableCommand  = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Chat"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            
            # ChatIcon = 3 (Deshabilitado por política)
            Set-ItemProperty -Path $policyPath -Name "ChatIcon" -Value 3 -Type DWord -Force
        }
        DisableCommand = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Chat"
            if (Test-Path $policyPath) {
                Remove-ItemProperty -Path $policyPath -Name "ChatIcon" -Force -ErrorAction SilentlyContinue
            }
        }
        CheckCommand   = {
            if ([Environment]::OSVersion.Version.Build -lt 22000) { return 'NotApplicable' }
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Name "ChatIcon" -ErrorAction SilentlyContinue).ChatIcon
            return ($val -eq 3)
        }
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Publicidad en Menu Inicio (Iris)"
        Category       = "Windows 11 UI"
        Description    = "Evita que aparezcan recomendaciones promocionadas, consejos y accesos directos no solicitados en el menu de Inicio."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        RegistryKey    = "Start_IrisRecommendations"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar Search Highlights (Dibujos en Busqueda)"
        Category       = "Windows 11 UI"
        Description    = "Elimina los iconos animados, doodles de Bing y contenido sugerido del cuadro de busqueda en la barra de tareas y el menu inicio. Limpia la interfaz y evita conexiones innecesarias."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        RegistryKey    = "EnableSearchHighlights"
        EnabledValue   = 0
        DefaultValue   = 1
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    },
	[PSCustomObject]@{
        Name           = "Desactivar Boton Copilot y Barra Lateral en Edge (Definitivo)"
        Category       = "Windows 11 UI"
        Description    = "Desactiva la IA de Copilot en Edge, oculta el botón de Bing/Copilot y bloquea la barra lateral contenedora."
        Method         = "Command"
        EnableCommand  = {
            $edgePath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge"
            if (-not (Test-Path $edgePath)) { New-Item -Path $edgePath -Force | Out-Null }

            # Apagar funciones de IA y Barra Lateral
            Set-ItemProperty -Path $edgePath -Name "EdgeCopilotEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $edgePath -Name "HubsSidebarEnabled" -Value 0 -Type DWord -Force
            
            # Ocultar botones específicos (Crítico para versiones v139+)
            Set-ItemProperty -Path $edgePath -Name "ShowCopilotButton" -Value 0 -Type DWord -Force 
            Set-ItemProperty -Path $edgePath -Name "Microsoft365CopilotChatIconEnabled" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            $edgePath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge"
            if (Test-Path $edgePath) {
                Remove-ItemProperty -Path $edgePath -Name "EdgeCopilotEnabled" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $edgePath -Name "HubsSidebarEnabled" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $edgePath -Name "ShowCopilotButton" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $edgePath -Name "Microsoft365CopilotChatIconEnabled" -Force -ErrorAction SilentlyContinue
            }
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge" -Name "EdgeCopilotEnabled" -ErrorAction SilentlyContinue).EdgeCopilotEnabled
            return ($val -eq 0)
        }
        RestartNeeded  = "None"
    },
	[PSCustomObject]@{
        Name           = "Eliminar Seccion 'Recomendado' del Menu Inicio"
        Category       = "Windows 11 UI"
        Description    = "Elimina la lista de archivos recientes y aplicaciones nuevas del Menu Inicio, dejandolo ms limpio. (Efectivo en W11 SE/Pro/Enterprise)."
        Method         = "Command"
        EnableCommand  = {
            $path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer"
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -Path $path -Name "HideRecommendedSection" -Value 1 -Type DWord -Force
        }
        DisableCommand = {
            $path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer"
            if (Test-Path $path) { Remove-ItemProperty -Path $path -Name "HideRecommendedSection" -Force -ErrorAction SilentlyContinue }
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedSection" -ErrorAction SilentlyContinue).HideRecommendedSection
            return ($val -eq 1)
        }
        RestartNeeded  = "Explorer"
    },

	# --- Categoria: Red y Latencia (TCP/IP Avanzado) ---
    [PSCustomObject]@{
        Name           = "Establecer Algoritmo de Congestion TCP a CUBIC"
        Category       = "Rendimiento de Red"
        Description    = "Cambia el algoritmo de control de congestion a CUBIC (estandar en Linux/Android). Mejora la estabilidad del ping y la velocidad en conexiones de fibra optica modernas."
        Method         = "Command"
        EnableCommand  = { 
            # Activa CUBIC explicitamente
            netsh int tcp set supplemental template=internet congestionprovider=cubic
        }
        DisableCommand = {
            netsh int tcp set supplemental template=internet congestionprovider=ctcp
        }
        CheckCommand   = {
            try {
                $tcp = Get-NetTCPSetting -SettingName Internet -ErrorAction Stop
                return ($tcp.CongestionProvider -eq 'CUBIC')
            } catch {
                return $false
            }
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Desactivar Heuristica de Escalado de Ventana"
        Category       = "Rendimiento de Red"
        Description    = "Evita que Windows intente adivinar y limitar dinamicamente el tamano de la ventana TCP, lo que a menudo reduce la velocidad de descarga innecesariamente. (Nota: En Windows 10/11, si el Auto-Tuning es 'Normal', el sistema fuerza este ajuste a 'Desactivado' permanentemente)."
        Method         = "Command"
        EnableCommand  = { 
            # Intentamos desactivar (Optimizar)
            netsh int tcp set heuristics disabled
            Set-NetTCPSetting -SettingName Internet -ScalingHeuristics Disabled -ErrorAction SilentlyContinue
        }
        DisableCommand = { 
            # Intentamos restaurar (Windows podria bloquear esto, lo cual es normal)
            netsh int tcp set heuristics enabled
            Set-NetTCPSetting -SettingName Internet -ScalingHeuristics Enabled -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            # Verificacion robusta en Español e Ingles
            $res = netsh int tcp show heuristics
            return ($res -match "disabled" -or $res -match "deshabilitado")
        }
        RestartNeeded  = "None"
    },
	[PSCustomObject]@{
        Name           = "Liberar 100% del Ancho de Banda de Red"
        Category       = "Rendimiento de Red"
        Description    = "Desactiva la reserva de ancho de banda que Windows hace para streaming, permitiendo que todas las aplicaciones (juegos, descargas) usen la totalidad de tu conexion."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        RegistryKey    = "NetworkThrottlingIndex"
        EnabledValue   = '4294967295'
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },
	[PSCustomObject]@{
        Name           = "Deshabilitar Servicio NDU"
        Category       = "Rendimiento de Red"
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
        Category       = "Rendimiento de Red"
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
        Category       = "Rendimiento de Red"
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
        Category       = "Rendimiento de Red"
        Description    = "Distribuye el procesamiento de los paquetes de red recibidos entre multiples nucleos de la CPU."
        Method         = "Command"
        EnableCommand  = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            # Intento 1: Metodo estandar de PowerShell
            Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Enable-NetAdapterRss -ErrorAction SilentlyContinue
            # Intento 2: Metodo global (netsh) para casos con Hyper-V
            netsh int tcp set global rss=enabled
        }
        DisableCommand = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Disable-NetAdapterRss -ErrorAction SilentlyContinue
            netsh int tcp set global rss=disabled
        }
        CheckCommand   = {
            try {
                # Metodo agnostico al idioma: Obtenemos el objeto y verificamos su propiedad booleana
                $rssStatus = Get-NetAdapterRss -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true }
                # Si devuelve algo, es que al menos un adaptador tiene RSS activado
                return ($null -ne $rssStatus)
            } catch {
                return 'NotApplicable'
            }
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Habilitar Coalescencia de Segmentos (RSC)"
        Category       = "Rendimiento de Red"
        Description    = "Agrupa paquetes recibidos para reducir uso de CPU."
        Method         = "Command"
        EnableCommand  = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            # CAMBIO: Quitamos '-Physical' y apuntamos a cualquier adaptador activo (incluyendo vEthernet)
            Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Enable-NetAdapterRsc -IPv4 -IPv6 -ErrorAction SilentlyContinue
        }
        DisableCommand = { 
            Import-Module NetAdapter -ErrorAction SilentlyContinue
            # CAMBIO: Quitamos '-Physical' para evitar el error en adaptadores puenteados
            Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Disable-NetAdapterRsc -IPv4 -IPv6 -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            try {
                Import-Module NetAdapter -ErrorAction Stop
                # Buscamos si algun adaptador ACTIVO tiene RSC activado
                $rscStatus = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Get-NetAdapterRsc -ErrorAction SilentlyContinue
                
                # Si encontramos configuracion, verificamos si esta activo para IPv4 o IPv6
                if ($rscStatus) {
                    return ($rscStatus.IPv4Enabled -eq $true -or $rscStatus.IPv6Enabled -eq $true)
                }
                return $false
            } catch {
                return 'NotApplicable'
            }
        }
        RestartNeeded  = "None"
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
        Description    = "Desactiva el protocolo de red obsoleto SMBv1 (vector de ataque de WannaCry). Verifica primero si esta activo para evitar procesos innecesarios."
        Method         = "Command"
        EnableCommand  = {
            $featName = "SMB1Protocol"
            $feat = Get-WindowsOptionalFeature -Online -FeatureName $featName -ErrorAction SilentlyContinue
            
            if ($feat -and $feat.State -eq 'Enabled') {
                Write-Host "   - Desactivando SMBv1..." -ForegroundColor Yellow
                Disable-WindowsOptionalFeature -Online -FeatureName $featName -NoRestart -ErrorAction Stop | Out-Null
                Write-Host "   - SMBv1 Desactivado." -ForegroundColor Green
            } else {
                Write-Host "   - SMBv1 ya estaba desactivado o no existe." -ForegroundColor Gray
            }
        }
        DisableCommand = { 
            # Solo intentamos activarlo si el usuario lo pide explicitamente
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction Stop | Out-Null
            } catch {
                Write-Warning "No se pudo reactivar SMBv1. Puede que Windows ya no soporte esta caracteristica."
            }
        }
        CheckCommand   = {
			try {
				$feature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop;
                # Esta "Activado" el TWEAK (es decir, seguro) si el protocolo esta Disabled o no existe
				return ($null -eq $feature -or $feature.State -eq 'Disabled')
			} catch {
				return 'NotApplicable' 
            }
		}
        RestartNeeded  = "Reboot"
    },
    [PSCustomObject]@{
        Name           = "Deshabilitar PowerShell v2.0"
        Category       = "Seguridad"
        Description    = "Desactiva el antiguo motor de PowerShell v2.0 (obsoleto e inseguro) para reducir la superficie de ataque. Verifica primero si esta instalado."
        Method         = "Command"
        EnableCommand  = {
            $features = @("MicrosoftWindowsPowerShellV2", "MicrosoftWindowsPowerShellV2Root")
            
            foreach ($name in $features) {
                # Verificamos estado sin lanzar errores
                $feat = Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction SilentlyContinue
                
                if ($feat -and $feat.State -eq 'Enabled') {
                    Write-Host "   - Deshabilitando $name..." -ForegroundColor Yellow
                    Disable-WindowsOptionalFeature -Online -FeatureName $name -NoRestart -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
        DisableCommand = {
            # Reactivacion (Solo si el usuario realmente lo necesita)
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -NoRestart -ErrorAction Stop | Out-Null
                Enable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2" -NoRestart -ErrorAction Stop | Out-Null
            } catch {
                Write-Warning "No se pudo reactivar PowerShell 2.0. Es posible que los archivos fuente ya no existan en esta version de Windows."
            }
        }
        CheckCommand   = {
            # Consideramos que el ajuste esta "Activado" (Seguro) si:
            $feat = Get-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2" -ErrorAction SilentlyContinue
            return ($null -eq $feat -or $feat.State -eq 'Disabled')
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
	[PSCustomObject]@{
        Name           = "Configurar Windows Update Solo Seguridad (Empresarial)"
        Category       = "Seguridad"
        Description    = "Aplica una politica estricta: Solo descargas de seguridad, sin drivers automaticos, sin reinicios forzados y difiere grandes actualizaciones por 6 meses. Ideal para maxima estabilidad."
        Method         = "Command"
        EnableCommand  = {
            # 1. Metadatos de dispositivos (Evita trafico innecesario)
            $path1 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
            if (-not (Test-Path $path1)) { New-Item -Path $path1 -Force | Out-Null }
            Set-ItemProperty -Path $path1 -Name "PreventDeviceMetadataFromNetwork" -Value 1 -Type DWord -Force

            # 2. Busqueda de Drivers (Solo si faltan, sin avisos, prioriza WU)
            $path2 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
            if (-not (Test-Path $path2)) { New-Item -Path $path2 -Force | Out-Null }
            Set-ItemProperty -Path $path2 -Name "DontSearchWindowsUpdate" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path2 -Name "DontPromptForWindowsUpdate" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path2 -Name "DriverUpdateWizardWuSearchEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path2 -Name "SearchOrderConfig" -Value 1 -Type DWord -Force
            
            # Ajuste adicional de drivers en CurrentVersion
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 1 -Type DWord -Force

            # 3. Solo Seguridad y Sin Reinicios
            $path3 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            if (-not (Test-Path $path3)) { New-Item -Path $path3 -Force | Out-Null }
            Set-ItemProperty -Path $path3 -Name "AUOptions" -Value 2 -Type DWord -Force # Notificar descarga y notificar instalacion
            Set-ItemProperty -Path $path3 -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path3 -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path3 -Name "AUPowerManagement" -Value 0 -Type DWord -Force

            # 4. Canal Estable (Diferir 180 dias)
            $path4 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
            if (-not (Test-Path $path4)) { New-Item -Path $path4 -Force | Out-Null }
            Set-ItemProperty -Path $path4 -Name "BranchReadinessLevel" -Value 20 -Type DWord -Force
            Set-ItemProperty -Path $path4 -Name "DeferFeatureUpdatesPeriodInDays" -Value 180 -Type DWord -Force
            Set-ItemProperty -Path $path4 -Name "DeferQualityUpdatesPeriodInDays" -Value 180 -Type DWord -Force

            # 5. Asegurar instalacion de dispositivos habilitada
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DeviceInstallDisabled" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            # Revertir a valores por defecto (Eliminar politicas)
            Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            
            $path2 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
            Remove-ItemProperty -Path $path2 -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path2 -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path2 -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path2 -Name "SearchOrderConfig" -ErrorAction SilentlyContinue
            
            # Restaurar valor por defecto de busqueda de drivers
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 1 -Type DWord -Force # Se suele dejar en 1 o 2

            $path3 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            Remove-ItemProperty -Path $path3 -Name "AUOptions" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path3 -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path3 -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path3 -Name "AUPowerManagement" -ErrorAction SilentlyContinue

            $path4 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
            Remove-ItemProperty -Path $path4 -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path4 -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path4 -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            # Verificamos 3 claves criticas para determinar si el perfil esta activo
            $val1 = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -ErrorAction SilentlyContinue).AUOptions
            $val2 = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue).DeferFeatureUpdatesPeriodInDays
            $val3 = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue).ExcludeWUDriversInQualityUpdate
            
            return ($val1 -eq 2 -and $val2 -eq 180 -and $val3 -eq 1)
        }
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
        Name           = "Deshabilitar Historial de Actividad"
        Category       = "Privacidad y Telemetria"
        Description    = "Impide que Windows recopile tu historial de uso de aplicaciones y archivos (Timeline) tanto localmente como en la nube."
        Method         = "Command"
        EnableCommand  = {
            # 1. Directiva de Sistema (Feed)
            $polPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System"
            if (-not (Test-Path $polPath)) { New-Item -Path $polPath -Force | Out-Null }
            Set-ItemProperty -Path $polPath -Name "EnableActivityFeed" -Value 0 -Type DWord -Force
        
            # 2. Directiva de Usuario (Recolección Local y Subida)
            $polUser = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System"
            Set-ItemProperty -Path $polUser -Name "PublishUserActivities" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $polUser -Name "UploadUserActivities" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            $polPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System"
            Remove-ItemProperty -Path $polPath -Name "EnableActivityFeed" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $polPath -Name "PublishUserActivities" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $polPath -Name "UploadUserActivities" -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -ErrorAction SilentlyContinue).EnableActivityFeed
            return ($val -eq 0)
        }
        RestartNeeded  = "Session"
    },
    [PSCustomObject]@{
        Name           = "Desactivar Recopilacion de Datos de Microsoft"
        Category       = "Privacidad y Telemetria"
        Description    = "Deshabilita servicios de rastreo (DiagTrack, DmWapPush) y tareas del programa de experiencia del cliente."
        Method         = "Command"
        EnableCommand  = {
            # Tareas
            Get-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" -ErrorAction SilentlyContinue | Disable-ScheduledTask
            
            # Registro
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
            
            # Servicio 1: DiagTrack
            Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
            if ((Get-Service "DiagTrack" -ErrorAction SilentlyContinue).Status -eq 'Running') { Stop-Service "DiagTrack" -Force }

            # Servicio 2: dmwappushservice (Nuevo)
            Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
            if ((Get-Service "dmwappushservice" -ErrorAction SilentlyContinue).Status -eq 'Running') { Stop-Service "dmwappushservice" -Force }
        }
        DisableCommand = {
            Get-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" -ErrorAction SilentlyContinue | Enable-ScheduledTask
            Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Force -ErrorAction SilentlyContinue
            
            Set-Service -Name "DiagTrack" -StartupType "Automatic" -ErrorAction SilentlyContinue
            Set-Service -Name "dmwappushservice" -StartupType "Manual" -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            $telemetryValue = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
            $svc = Get-Service "dmwappushservice" -ErrorAction SilentlyContinue
            return ($telemetryValue -eq 0 -and $svc.StartType -eq 'Disabled')
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
	[PSCustomObject]@{
        Name           = "Desactivar Telemetria de Busqueda (Bing/Cortana)"
        Category       = "Privacidad y Telemetria"
        Description    = "Bloquea totalmente la conexion a internet del menu inicio. Evita que Windows envie lo que escribes a Microsoft y elimina el retraso (lag) de red al buscar archivos locales."
        Method         = "Command"
        EnableCommand  = {
            # Desactiva Bing Search en HKLM (Maquina)
            $pathLM = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (-not (Test-Path $pathLM)) { New-Item -Path $pathLM -Force | Out-Null }
            Set-ItemProperty -Path $pathLM -Name "DisableWebSearch" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $pathLM -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $pathLM -Name "AllowCortana" -Value 0 -Type DWord -Force
            
            # Desactiva Bing Search en HKCU (Usuario)
            $pathCU = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search"
            if (-not (Test-Path $pathCU)) { New-Item -Path $pathCU -Force | Out-Null }
            Set-ItemProperty -Path $pathCU -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $pathCU -Name "CortanaConsent" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            # Revierte cambios HKLM
            $pathLM = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            Remove-ItemProperty -Path $pathLM -Name "DisableWebSearch" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $pathLM -Name "ConnectedSearchUseWeb" -ErrorAction SilentlyContinue
            
            # Revierte cambios HKCU
            $pathCU = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search"
            Set-ItemProperty -Path $pathCU -Name "BingSearchEnabled" -Value 1 -Type DWord -Force
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -ErrorAction SilentlyContinue).DisableWebSearch
            return ($val -eq 1)
        }
        RestartNeeded  = "Explorer"
    },
	[PSCustomObject]@{
        Name           = "Bloquear Instalación Automática de Apps Patrocinadas"
        Category       = "Privacidad y Telemetria"
        Description    = "Impide que Windows descargue e instale silenciosamente aplicaciones de terceros (Candy Crush, TikTok, Disney+, etc.) en el Menú Inicio."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        RegistryKey    = "DisableWindowsConsumerFeatures"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "Reboot"
    },

    # --- Categoria: Comportamiento del Sistema y UI ---
    [PSCustomObject]@{
        Name           = "Deshabilitar la Pantalla de Bloqueo (Directiva)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Elimina la pantalla de bloqueo (la imagen antes del login) para entrar mas rapido. (Protegido: Advierte en portatiles por riesgo de pulsaciones accidentales o privacidad)."
        Method         = "Command"
        EnableCommand  = {
            # 1. Deteccion de Portatil
            $isPortable = $false
            try {
                if (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) { $isPortable = $true }
                $chassis = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue
                if ($chassis.ChassisTypes -match '^(8|9|10|11|12|14|30|31|32)$') { $isPortable = $true }
            } catch {}

            # 2. Valla de Seguridad
            if ($isPortable) {
                Add-Type -AssemblyName System.Windows.Forms
                $msg = "Se ha detectado que este equipo es un PORTATIL.`n`nDesactivar la pantalla de bloqueo aumenta el riesgo de:`n- Pulsaciones accidentales si el equipo se despierta en una mochila.`n- Menor privacidad al abrir la tapa en lugares publicos.`n`n¿Estas seguro de continuar?"
                $warn = [System.Windows.Forms.MessageBox]::Show($msg, "Advertencia de Privacidad", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                
                if ($warn -ne 'Yes') { 
                    Write-Warning "Operacion cancelada por el usuario (Proteccion de Portatil)."
                    return 
                }
            }

            # 3. Aplicacion
            $path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization"
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -Path $path -Name "NoLockScreen" -Value 1 -Type DWord -Force
            Write-Host "Pantalla de bloqueo deshabilitada." -ForegroundColor Green
        }
        DisableCommand = {
            $path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization"
            if (Test-Path $path) {
                Remove-ItemProperty -Path $path -Name "NoLockScreen" -Force -ErrorAction SilentlyContinue
            }
        }
        CheckCommand   = {
            $val = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -ErrorAction SilentlyContinue).NoLockScreen
            return ($val -eq 1)
        }
        RestartNeeded  = "None"
    },
    [PSCustomObject]@{
        Name           = "Restaurar Menu Contextual Completo (Anti 'Mostrar mas')"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "En Windows 11, recupera el menu de clic derecho clasico eliminando la opcion 'Mostrar mas opciones'. (Protegido: Solo se aplica si detecta Windows 11)."
        Method         = "Command"
        EnableCommand  = {
            # 1. Verificacion de Version: Windows 11 comienza en la Build 22000
            $currentBuild = [Environment]::OSVersion.Version.Build
            if ($currentBuild -lt 22000) {
                Write-Warning "Este ajuste es exclusivo para Windows 11."
                Write-Warning "Tu version actual (Build $currentBuild) ya utiliza el menu clasico nativamente."
                return
            }

            # 2. Aplicacion del Parche
            $regPath = 'Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
            if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            
            # El truco consiste en que la clave (Default) debe estar vacia (String vacio), no nula.
            Set-ItemProperty -Path $regPath -Name '(Default)' -Value '' -Force
            Write-Host "Menu clasico de Windows 11 activado." -ForegroundColor Green
        }
        DisableCommand = {
            # Borrar la clave restaura el menu moderno de Windows 11
            Remove-Item -Path 'Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            # Solo esta "Activado" si existe la clave especifica y es Windows 11
            $path = 'Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
            return (Test-Path $path)
        }
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
        Name           = "Anadir 'Desbloquear de Firewall' al Menu Contextual"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Agrega una opcion al clic derecho para eliminar la regla de bloqueo creada anteriormente para una aplicacion, restaurando su acceso a Internet."
        Method         = "Command"
        EnableCommand  = {
            $keyPath = "Registry::HKEY_CLASSES_ROOT\exefile\shell\removefromfirewall";
            New-Item -Path $keyPath -Force | Out-Null;
            Set-ItemProperty -Path $keyPath -Name "(Default)" -Value "Restaurar acceso a Internet (Desbloquear)";
            Set-ItemProperty -Path $keyPath -Name "Icon" -Value "firewall.cpl"; 
            
            $commandPath = "$keyPath\command";
            New-Item -Path $commandPath -Force | Out-Null;
            
            # El comando busca y elimina la regla especifica creada por Aegis Phoenix
            $command = "powershell -WindowStyle Hidden -Command `"Remove-NetFirewallRule -DisplayName 'AegisPhoenixBlock - %1' -ErrorAction SilentlyContinue`"";
            Set-ItemProperty -Path $commandPath -Name "(Default)" -Value $command
        }
        DisableCommand = {
            Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\exefile\shell\removefromfirewall" -Recurse -Force -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            Test-Path "Registry::HKEY_CLASSES_ROOT\exefile\shell\removefromfirewall"
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
            # 1. Ajuste de Usuario (HKCU) - Con manejo de errores para evitar mensajes rojos
            $userPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            try {
                if (-not (Test-Path $userPath)) { New-Item -Path $userPath -Force | Out-Null }
                Set-ItemProperty -Path $userPath -Name "TaskbarDa" -Value 0 -Type DWord -Force -ErrorAction Stop
            } catch {
                # Si falla (Permisos), no hacemos nada y dejamos que la Directiva HKLM se encargue
                Write-Log -LogLevel WARN -Message "No se pudo escribir TaskbarDa en HKCU (Permisos denegados). Se intentara via Directiva."
            }
            
            # 2. Directiva de Maquina (HKLM) - Esta es la que realmente manda
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            Set-ItemProperty -Path $policyPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            # Intentamos eliminar ambas. Si alguna falla, continuamos silenciosamente.
            try { Remove-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Force -ErrorAction SilentlyContinue } catch {}
            try { Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Force -ErrorAction SilentlyContinue } catch {}
        }
        CheckCommand   = {
            # Verificamos valores (usando SilentlyContinue por si no existen)
            $userVal = (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ErrorAction SilentlyContinue).TaskbarDa
            $policyVal = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue).AllowNewsAndInterests
            
            # Logica: Si ALGUNO de los dos es 0, visualmente los widgets desaparecen.
            $isUserDisabled = ($null -ne $userVal) -and ($userVal -eq 0)
            $isPolicyDisabled = ($null -ne $policyVal) -and ($policyVal -eq 0)
            
            return ($isUserDisabled -or $isPolicyDisabled)
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
        Description    = "Elimina completamente los resultados web de Bing, Cortana y las sugerencias flotantes (Highlights) de la caja de búsqueda."
        Method         = "Command"
        EnableCommand  = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            
            # Claves estándar
            Set-ItemProperty -Path $policyPath -Name "DisableWebSearch" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $policyPath -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -Force
            
            # Nueva clave crítica para eliminar popups de búsqueda
            Set-ItemProperty -Path $policyPath -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force
            
            # Ajuste de usuario
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
        }
        DisableCommand = {
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (Test-Path $policyPath) {
                Remove-ItemProperty -Path $policyPath -Name "DisableWebSearch" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "ConnectedSearchUseWeb" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $policyPath -Name "DisableSearchBoxSuggestions" -Force -ErrorAction SilentlyContinue
            }
            Remove-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Force -ErrorAction SilentlyContinue
        }
        CheckCommand   = {
            $val1 = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -ErrorAction SilentlyContinue).DisableWebSearch
            $val2 = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableSearchBoxSuggestions" -ErrorAction SilentlyContinue).DisableSearchBoxSuggestions
            return ($val1 -eq 1 -and $val2 -eq 1)
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
	[PSCustomObject]@{
        Name           = "Forzar Cierre de Apps al Apagar (AutoEndTasks)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Evita que Windows te pregunte si quieres cerrar programas abiertos al apagar. Los cierra automaticamente para un apagado mas rapido."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Control Panel\Desktop"
        RegistryKey    = "AutoEndTasks"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "String"
        RestartNeeded  = "Session"
    },
	[PSCustomObject]@{
        Name           = "Abrir Explorador en 'Este Equipo' (No Acceso Rapido)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Al abrir el explorador de archivos, muestra tus discos y carpetas directamente en lugar de la lista de 'Archivos recientes' o 'Acceso rapido'."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        RegistryKey    = "LaunchTo"
        EnabledValue   = 1 # 1 = Este Equipo, 2 = Acceso Rapido
        DefaultValue   = 2
        RegistryType   = "DWord"
        RestartNeeded  = "Explorer"
    },
    [PSCustomObject]@{
        Name           = "Desactivar 'Aero Shake' (Agitar ventana para minimizar)"
        Category       = "Comportamiento del Sistema y UI"
        Description    = "Evita que todas las ventanas se minimicen accidentalmente si mueves el mouse rapidamente mientras arrastras una ventana."
        Method         = "Registry"
        RegistryPath   = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        RegistryKey    = "DisallowShaking"
        EnabledValue   = 1
        DefaultValue   = 0
        RegistryType   = "DWord"
        RestartNeeded  = "None"
    },

	# --- Categoria: Extras ---
	[PSCustomObject]@{
        Name           = "Desinstalar OneDrive Completamente"
        Category       = "Extras"
        Description    = "ADVERTENCIA: Desinstala OneDrive buscando el desinstalador en multiples rutas y elimina sus datos locales. Mueve los archivos importantes fuera de la carpeta OneDrive antes de proceder."
        Method         = "Command"
        EnableCommand  = {
            # --- PASO 1: Deshabilitar OneDrive via Directiva de Grupo (Previene reinstalacion automatica) ---
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\OneDrive"
            if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
            Set-ItemProperty -Path $policyPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force

            # --- PASO 2: Detener el proceso ---
            Write-Host "   - Deteniendo procesos de OneDrive..." -ForegroundColor Gray
            Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue

            # --- PASO 3: Busqueda dinamica y ejecucion del desinstalador ---
            $installerPath = $null
            $possiblePaths = @(
                "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
                "$env:SystemRoot\System32\OneDriveSetup.exe",
                "$env:LOCALAPPDATA\Microsoft\OneDrive\Update\OneDriveSetup.exe",
                "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe",
                "$env:ProgramFiles\Microsoft OneDrive\OneDriveSetup.exe",
                "$env:ProgramFiles (x86)\Microsoft OneDrive\OneDriveSetup.exe"
            )

            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $installerPath = $path
                    break
                }
            }

            if ($installerPath) {
                Write-Host "   - Desinstalador encontrado en: $installerPath" -ForegroundColor Cyan
                Start-Process -FilePath $installerPath -ArgumentList "/uninstall" -Wait
            } else {
                Write-Warning "   - No se encontro el desinstalador oficial. Se procedera con la limpieza manual forzada."
            }
            
            # --- PASO 4: Limpieza de Registro (Iconos del Explorador) ---
            Write-Host "   - Limpiando claves de registro..." -ForegroundColor Gray
            Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -Force -ErrorAction SilentlyContinue
            
            # Ocultar del panel de navegacion por si acaso quedo algo
            $clsidPath = "Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
            if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
            Set-ItemProperty -Path $clsidPath -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force

            # --- PASO 5: Limpieza de Archivos y Tareas ---
            Write-Host "   - Eliminando archivos residuales y tareas..." -ForegroundColor Gray
            Get-ScheduledTask -TaskPath '\' -TaskName 'OneDrive*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
            
            # Eliminacion de carpetas de datos (Ojo: No borra la carpeta de documentos del usuario, solo la app)
            Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "C:\OneDriveTemp" -Recurse -Force -ErrorAction SilentlyContinue
        }
        DisableCommand = { 
            # Para reactivar, eliminamos la directiva que lo bloquea
            $policyPath = "Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\OneDrive"
            if (Test-Path $policyPath) { Remove-ItemProperty -Path $policyPath -Name "DisableFileSyncNGSC" -Force -ErrorAction SilentlyContinue }
            
            Write-Warning "La directiva de bloqueo ha sido eliminada."
            Write-Warning "Debes descargar e instalar OneDrive manualmente desde el sitio web de Microsoft para recuperarlo." 
        }
        CheckCommand   = {
            # Se considera "Activado" (es decir, el Tweak aplicado y OneDrive eliminado) si la directiva existe
            $policyValue = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue).DisableFileSyncNGSC
            return ($null -ne $policyValue -and $policyValue -eq 1)
        }
        RestartNeeded  = "Reboot"
    }
)
