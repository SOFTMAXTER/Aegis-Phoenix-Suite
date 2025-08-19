<#
.SYNOPSIS
    Suite definitiva de optimizacion, gestion, seguridad y diagnostico para Windows 11 y 10.
.DESCRIPTION
    Aegis Phoenix Suite v4 by SOFTMAXTER es la herramienta PowerShell definitiva. Con una estructura de submenus y una
    logica de verificacion inteligente, permite maximizar el rendimiento, reforzar la seguridad, gestionar
    software y drivers, y personalizar la experiencia de usuario.
    Requiere ejecucion como Administrador.
.AUTHOR
    SOFTMAXTER
.VERSION
    4.0
#>

# --- CARGA DE CATALOGOS EXTERNOS ---
Write-Host "Cargando catalogos..."
try {
    . "$PSScriptRoot\Catalogos\Ajustes.ps1"
    . "$PSScriptRoot\Catalogos\Servicios.ps1"
}
catch {
    Write-Error "Error critico: No se pudieron cargar los archivos de catálogo."
    Write-Error "Asegurate de que 'Ajustes.ps1' y 'Servicios.ps1' existen en la subcarpeta 'Catalogos'."
    Read-Host "Presiona Enter para salir."
    exit
}

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
        Checkpoint-Computer -Description "AegisPhoenixSuite_v4.0_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')" -RestorePointType "MODIFY_SETTINGS"
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
        Write-Host "     Gestion de Servicios No Esenciales de Windows     " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Selecciona un servicio para cambiar su estado (Activado/Desactivado)."
        Write-Host ""

        # Almacenar los objetos de servicio con su estado actual
        $displayItems = [System.Collections.Generic.List[object]]::new()

        foreach ($category in ($script:ServiceCatalog | Select-Object -ExpandProperty Category -Unique)) {
            Write-Host "--- Categoria: $category ---" -ForegroundColor Yellow
            $servicesInCategory = $script:ServiceCatalog | Where-Object { $_.Category -eq $category }

            foreach ($serviceDef in $servicesInCategory) {
                $itemIndex = $displayItems.Count + 1
                $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($serviceDef.Name)'" -ErrorAction SilentlyContinue
                
                $statusText = ""
                $statusColor = "Gray"

                if ($service) {
                    # Obtener StartupType real (Disabled, Manual, Automatic)
                    $startupType = $service.StartMode
                    $isRunning = $service.State -eq 'Running'

                    if ($startupType -eq 'Disabled') {
                        $statusText = "[Desactivado]"
                        $statusColor = "Red"
                    } else {
                        $statusText = "[Activado]"
                        $statusColor = "Green"
                        if ($isRunning) { $statusText += " [En Ejecucion]" }
                    }
                } else {
                    $statusText = "[No Encontrado]"
                }

                Write-Host ("   [{0,2}] " -f $itemIndex) -NoNewline
                Write-Host ("{0,-25}" -f $statusText) -ForegroundColor $statusColor -NoNewline
                Write-Host $serviceDef.Name -ForegroundColor White
                Write-Host ("        " + $serviceDef.Description) -ForegroundColor Gray
                
                $displayItems.Add($serviceDef)
            }
            Write-Host ""
        }
        
        Write-Host "--- Acciones ---" -ForegroundColor Cyan
        Write-Host "   [Numero] - Activar/Desactivar servicio"
		Write-Host "   [R <Numero>] - Restaurar servicio a su estado por defecto (Ej: R 2)"
        Write-Host ""
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
                    if (-not $service) { 
                        Write-Warning "El servicio '$($selectedServiceDef.Name)' no existe."
                        continue
                    }

                    # Obtener estado actual (StartupType)
                    $cimService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'"
                    $currentStartupType = $cimService.StartMode

                    if ($currentStartupType -eq 'Disabled') {
                        # Activar servicio (restaurar a DefaultStartupType)
                        $action = "Habilitar"
                        $newStartupType = $selectedServiceDef.DefaultStartupType
                    } else {
                        # Desactivar servicio
                        $action = "Deshabilitar"
                        $newStartupType = 'Disabled'
                    }

                    if ($PSCmdlet.ShouldProcess($selectedServiceDef.Name, $action)) {
                        # Cambiar tipo de inicio
                        $cimService | Set-Service -StartupType $newStartupType -ErrorAction Stop

                        # Si se activa y el servicio debe iniciarse automaticamente
                        if ($newStartupType -eq 'Automatic' -and $service.Status -ne 'Running') {
                            Start-Service -Name $service.Name -ErrorAction SilentlyContinue
                        }

                        Write-Host "[OK] Servicio '$($selectedServiceDef.Name)' $action." -ForegroundColor Green
                    }
                }
            } 
            elseif ($choice.ToUpper() -eq 'R' -and $number -match '^\d+$') {
                $index = [int]$number - 1
                if ($index -ge 0 -and $index -lt $displayItems.Count) {
                    $selectedServiceDef = $displayItems[$index]
                    if ($PSCmdlet.ShouldProcess($selectedServiceDef.Name, "Restaurar a estado por defecto ($($selectedServiceDef.DefaultStartupType))")) {
                        $service = Get-Service -Name $selectedServiceDef.Name -ErrorAction Stop
                        Set-Service -Name $service.Name -StartupType $selectedServiceDef.DefaultStartupType -ErrorAction Stop
                        
                        # Iniciar servicio si es necesario
                        if ($selectedServiceDef.DefaultStartupType -ne 'Disabled' -and $service.Status -ne 'Running') {
                            Start-Service -Name $service.Name -ErrorAction SilentlyContinue
                        }
                        
                        Write-Host "[OK] Servicio '$($selectedServiceDef.Name)' restaurado." -ForegroundColor Green
                    }
                }
            } 
            elseif ($choice.ToUpper() -ne 'V') {
                Write-Warning "Opcion no valida."
            }
        } catch {
            Write-Error "Error: $($_.Exception.Message)"
        }

        if ($choice.ToUpper() -ne 'V') { 
            Start-Sleep -Seconds 2 
        }
    }
}

# =========================================================================================
# MODULO DE GESTION DE SERVICIOS DE TERCEROS
# =========================================================================================

function Manage-ThirdPartyServices {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    # Almacenamiento de estados originales para restauración
    $originalStates = @{}

    # Detectar servicios de terceros (no Microsoft)
    function Get-ThirdPartyServices {
        $thirdPartyServices = @()
        $allServices = Get-CimInstance -ClassName Win32_Service
        
        foreach ($service in $allServices) {
            # Filtrar servicios no-Microsoft
            if ($service.PathName -and $service.PathName -notmatch '\\Windows\\' -and $service.PathName -notlike '*svchost.exe*') {
                $thirdPartyServices += $service
                # Guardar estado original solo en primera ejecución
                if (-not $originalStates.ContainsKey($service.Name)) {
                    $originalStates[$service.Name] = @{
                        StartupType = $service.StartMode
                    }
                }
            }
        }
        return $thirdPartyServices
    }

    $choice = ''
    while ($choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "   Gestion Inteligente de Servicios de Aplicaciones    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Selecciona un servicio para cambiar su estado (Activado/Desactivado)."
        Write-Host ""
        
        $services = Get-ThirdPartyServices
        $displayItems = [System.Collections.Generic.List[object]]::new()

        # Mostrar servicios
        foreach ($service in $services) {
            $itemIndex = $displayItems.Count + 1
            
            # Determinar estado actual
            $statusText = ""
            $statusColor = "Gray"
            $isRunning = $service.State -eq 'Running'

            if ($service.StartMode -eq 'Disabled') {
                $statusText = "[Desactivado]"
                $statusColor = "Red"
            } else {
                $statusText = "[Activado]"
                $statusColor = "Green"
                if ($isRunning) { 
                    $statusText += " [En Ejecucion]" 
                }
            }

            # Mostrar entrada
            Write-Host ("   [{0,2}] " -f $itemIndex) -NoNewline
            Write-Host ("{0,-25}" -f $statusText) -ForegroundColor $statusColor -NoNewline
            Write-Host $service.DisplayName -ForegroundColor White
            Write-Host ("        " + $service.Description) -ForegroundColor Gray
            
            $displayItems.Add($service)
        }

        # Menú de acciones
        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] - Activar/Desactivar servicio"
        Write-Host "   [R <Numero>] - Restaurar estado original (Ej: R 2)"
        Write-Host ""
		Write-Host "   [V] - Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $rawChoice = Read-Host "Selecciona una opcion"
        $choice = $rawChoice.Split(' ')[0]
        $number = if ($rawChoice.Split(' ').Count -gt 1) { $rawChoice.Split(' ')[1] } else { $null }

        try {
            # Toggle estado
            if ($choice -match '^\d+$') {
                $index = [int]$choice - 1
                if ($index -ge 0 -and $index -lt $displayItems.Count) {
                    $selectedService = $displayItems[$index]
                    
                    if ($selectedService.StartMode -eq 'Disabled') {
                        # Activar (Manual como valor seguro)
                        $newStartupType = 'Manual'
                        $action = "Habilitar"
                    } else {
                        # Desactivar
                        $newStartupType = 'Disabled'
                        $action = "Deshabilitar"
                    }

                    if ($PSCmdlet.ShouldProcess($selectedService.DisplayName, $action)) {
                        # Cambiar tipo de inicio
                        Set-Service -Name $selectedService.Name -StartupType $newStartupType -ErrorAction Stop
                        
                        # Manejar estado de ejecución
                        if ($newStartupType -eq 'Disabled' -and $isRunning) {
                            Stop-Service -Name $selectedService.Name -Force -ErrorAction SilentlyContinue
                        } elseif ($newStartupType -ne 'Disabled' -and -not $isRunning) {
                            Start-Service -Name $selectedService.Name -ErrorAction SilentlyContinue
                        }
                        
                        Write-Host "[OK] Servicio '$($selectedService.DisplayName)' $action." -ForegroundColor Green
                    }
                }
            } 
            # Restaurar estado original
            elseif ($choice.ToUpper() -eq 'R' -and $number -match '^\d+$') {
                $index = [int]$number - 1
                if ($index -ge 0 -and $index -lt $displayItems.Count) {
                    $selectedService = $displayItems[$index]
                    $originalState = $originalStates[$selectedService.Name]
                    
                    if ($PSCmdlet.ShouldProcess($selectedService.DisplayName, "Restaurar estado original ($($originalState.StartupType))")) {
                        Set-Service -Name $selectedService.Name -StartupType $originalState.StartupType -ErrorAction Stop
                        
                        # Ajustar estado de ejecución según tipo de inicio
                        if ($originalState.StartupType -ne 'Disabled' -and $selectedService.State -ne 'Running') {
                            Start-Service -Name $selectedService.Name -ErrorAction SilentlyContinue
                        } elseif ($originalState.StartupType -eq 'Disabled' -and $selectedService.State -eq 'Running') {
                            Stop-Service -Name $selectedService.Name -Force -ErrorAction SilentlyContinue
                        }
                        
                        Write-Host "[OK] Servicio '$($selectedService.DisplayName)' restaurado." -ForegroundColor Green
                    }
                }
            }
            # Opción no válida
            elseif ($choice.ToUpper() -ne 'V') {
                Write-Warning "Opcion no valida."
            }
        } catch {
            Write-Error "Error: $($_.Exception.Message)"
        }

        if ($choice.ToUpper() -ne 'V') { 
            Start-Sleep -Seconds 2 
        }
    }
}
# =================================================================================
# --- INICIO DEL MÓDULO DE LIMPIEZA ACTUALIZADO ---
# Incluye la nueva función para limpieza de componentes del sistema.
# =================================================================================

# --- NUEVA FUNCIÓN: Limpieza Avanzada de Componentes del Sistema ---
function Invoke-AdvancedSystemClean {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Host "`n[+] Iniciando Limpieza Avanzada de Componentes del Sistema..." -ForegroundColor Cyan
    Write-Warning "Esta operacion eliminara archivos de instalaciones anteriores de Windows (Windows.old) y restos de actualizaciones."
    Write-Warning "Despues de esta limpieza, NO podras volver a la version anterior de Windows."
    
    if ((Read-Host "¿Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') {
        Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
        return
    }

    if ($PSCmdlet.ShouldProcess("Componentes del Sistema", "Limpieza Profunda via cleanmgr.exe")) {
        try {
            Write-Host "[+] Configurando el Liberador de Espacio en Disco para una limpieza maxima..." -ForegroundColor Yellow
            # Usamos un numero de sageset alto para no interferir con configuraciones del usuario
            $sagesetNum = 65535
            
            # Habilitamos todos los handlers de limpieza disponibles en el registro para que cleanmgr los use
            $handlers = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            foreach ($handler in $handlers) {
                try {
                    Set-ItemProperty -Path $handler.PSPath -Name "StateFlags0000" -Value 2 -Type DWord -Force
                } catch {
                    # Ignorar errores en claves que no se pueden modificar, no es crítico
                }
            }

            Write-Host "[+] Ejecutando el Liberador de Espacio en Disco. Por favor, espera..." -ForegroundColor Yellow
            Write-Host "    (Esta operacion puede tardar varios minutos y parecera que no avanza, es normal)" -ForegroundColor Gray
            
            # Ejecutamos la limpieza. /sagerun es mas seguro y proporciona feedback visual de la herramienta de Windows.
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:$sagesetNum" -Wait -Verb RunAs
            
            Write-Host "`n[OK] Limpieza avanzada completada." -ForegroundColor Green
        } catch {
            Write-Error "Ocurrio un error durante la limpieza avanzada: $($_.Exception.Message)"
        }
    }
}

# --- FUNCIÓN DE MENÚ ACTUALIZADA ---
function Show-CleaningMenu {
    # Función auxiliar para medir y limpiar rutas de forma segura
    function Invoke-SafeClean {
        param(
            [string[]]$Paths,
            [string]$Description
        )
        $totalSize = 0
        $itemsToDelete = @()

        Write-Host "`n[+] Calculando espacio para: $Description..." -ForegroundColor Yellow
        foreach ($path in $Paths) {
            if (Test-Path $path) {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                if ($null -ne $items) {
                    $itemsToDelete += $items
                    $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $totalSize += $size
                }
            }
        }

        if ($totalSize -gt 0) {
            $sizeInMB = [math]::Round($totalSize / 1MB, 2)
            Write-Host "[INFO] Se pueden liberar aproximadamente $($sizeInMB) MB." -ForegroundColor Cyan
            if ((Read-Host "¿Deseas continuar? (S/N)").ToUpper() -eq 'S') {
                Write-Host "[+] Limpiando $Description..."
                foreach ($item in $itemsToDelete) {
                    try {
                        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                    } catch {
                        Write-Warning "No se pudo eliminar '$($item.FullName)'. Puede que este en uso o requiera permisos especiales."
                    }
                }
                Write-Host "[OK] Limpieza de '$Description' completada." -ForegroundColor Green
            }
        } else {
            Write-Host "[OK] No se encontraron archivos para limpiar en '$Description'." -ForegroundColor Green
        }
    }

    $cleanChoice = ''
    do {
        Clear-Host
        Write-Host "Modulo de Limpieza Profunda" -ForegroundColor Cyan
        Write-Host "Selecciona el tipo de limpieza que deseas ejecutar."
        Write-Host ""
        Write-Host "--- Limpieza Rapida (Archivos de Usuario) ---" -ForegroundColor Yellow
        Write-Host ""
		Write-Host "   [1] Limpieza Estandar (Archivos temporales)"
        Write-Host ""
		Write-Host "   [2] Limpieza de Caches (DirectX, Miniaturas, etc.)"
        Write-Host ""
		Write-Host "   [3] Vaciar Papelera de Reciclaje"
        Write-Host ""
        Write-Host "--- Limpieza Profunda (Archivos de Sistema) ---" -ForegroundColor Yellow
        Write-Host ""
		Write-Host "   [4] Limpieza de Componentes de Windows (Windows.old, Actualizaciones)" -ForegroundColor Red
        Write-Host "       (Libera mucho espacio, pero es irreversible)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   [T] TODO (Ejecutar todas las limpiezas rapidas [1-3])"
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
		$cleanChoice = Read-Host "`nSelecciona una opcion"

        switch ($cleanChoice.ToUpper()) {
            '1' { Invoke-SafeClean -Paths @("$env:TEMP", "$env:windir\Temp") -Description "Archivos Temporales" }
            '2' {
                Invoke-SafeClean -Paths @("$env:LOCALAPPDATA\D3DSCache", "$env:windir\SoftwareDistribution\DeliveryOptimization") -Description "Caches de Sistema"
                Write-Host "[+] Limpiando cache de miniaturas..."
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                try {
                    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction Stop
                    Write-Host "[OK] Cache de miniaturas limpiada." -ForegroundColor Green
                } catch {
                    Write-Warning "No se pudo limpiar la cache de miniaturas."
                } finally {
                    Start-Process "explorer"
                }
            }
            '3' {
                Write-Host "[+] Vaciando la Papelera de Reciclaje..."
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-Host "[OK] Papelera vaciada." -ForegroundColor Green
            }
            '4' {
                Invoke-AdvancedSystemClean
            }
            'T' {
                Invoke-SafeClean -Paths @("$env:TEMP", "$env:windir\Temp") -Description "Archivos Temporales"
                Invoke-SafeClean -Paths @("$env:LOCALAPPDATA\D3DSCache", "$env:windir\SoftwareDistribution\DeliveryOptimization") -Description "Caches de Sistema"
                Write-Host "[+] Limpiando cache de miniaturas..."
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                try { Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction Stop; Write-Host "[OK] Cache de miniaturas limpiada." -ForegroundColor Green } catch { Write-Warning "No se pudo limpiar la cache de miniaturas." } finally { Start-Process "explorer" }
                Write-Host "[+] Vaciando la Papelera de Reciclaje..."
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-Host "[OK] Papelera vaciada." -ForegroundColor Green
            }
            'V' { continue }
            default { Write-Warning "Opcion no valida." }
        }
        if ($cleanChoice.ToUpper() -ne 'V') { Read-Host "`nPresiona Enter para continuar..." }
    } while ($cleanChoice.ToUpper() -ne 'V')
}

function Show-BloatwareMenu {
    $bloatwareChoice = ''
    do {
        Clear-Host
        Write-Host "Modulo de Eliminacion de Bloatware y Apps" -ForegroundColor Cyan
        Write-Host "Selecciona el tipo de aplicacion que deseas eliminar."
        Write-Host ""
        Write-Host "   [1] Eliminar Bloatware de Microsoft (Preinstalado por Windows)"
        Write-Host "       (Busca y permite eliminar apps preinstaladas por Microsoft)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Eliminar Bloatware de Terceros (Preinstalado por Fabricante)"
        Write-Host "       (Busca apps preinstaladas por HP, Dell, etc., para TODOS los usuarios)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Desinstalar Mis Apps (Instaladas desde la Tienda)" -ForegroundColor Yellow
        Write-Host "       (Busca apps que Tu has instalado desde la Microsoft Store)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        $bloatwareChoice = Read-Host "Selecciona una opcion"
        
        switch ($bloatwareChoice.ToUpper()) {
            '1' { Manage-Bloatware -Type 'Microsoft' }
            '2' { Manage-Bloatware -Type 'ThirdParty_AllUsers' }
            '3' { Manage-Bloatware -Type 'ThirdParty_CurrentUser' }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
                Read-Host 
            }
        }
    } while ($bloatwareChoice.ToUpper() -ne 'V')
}

# --- FUNCIoN 2: El Orquestador ---
# Llama a las funciones de obtencion de datos, seleccion y desinstalacion en el orden correcto.
function Manage-Bloatware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft', 'ThirdParty_AllUsers', 'ThirdParty_CurrentUser')]
        [string]$Type
    )
    
    $removableApps = Get-RemovableApps -Type $Type
    if ($removableApps.Count -eq 0) {
        Read-Host "`nNo se encontraron aplicaciones para esta categoria. Presiona Enter para volver..."
        return
    }

    $appsToUninstall = Show-AppSelectionMenu -AppList $removableApps
    if ($appsToUninstall.Count -eq 0) {
        Write-Host "`n[INFO] No se selecciono ninguna aplicacion o se cancelo la operacion." -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para volver..."
        return
    }

    Start-AppUninstallation -AppsToUninstall $appsToUninstall
    Read-Host "`nPresiona Enter para volver..."
}

# --- FUNCIoN 3: El Recolector de Datos ---
# Obtiene la lista de aplicaciones segun el tipo solicitado, incluyendo la informacion necesaria para la limpieza profunda.
function Get-RemovableApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft', 'ThirdParty_AllUsers', 'ThirdParty_CurrentUser')]
        [string]$Type
    )

    Write-Host "`n[+] Escaneando aplicaciones de tipo '$Type'..." -ForegroundColor Yellow
    $apps = @()
    $baseFilter = { $_.IsFramework -eq $false -and $_.IsResourcePackage -eq $false }

    $objectBuilder = {
        param($app)
        [PSCustomObject]@{
            Name              = $app.Name
            PackageName       = $app.PackageFullName
            PackageFamilyName = $app.PackageFamilyName
        }
    }

    if ($Type -eq 'Microsoft') {
        # Esta logica no cambia, ya que el bloqueo de apps esenciales es mas importante aqui.
        $essentialAppsBlocklist = @( "Microsoft.WindowsStore", "Microsoft.WindowsCalculator", "Microsoft.Windows.Photos", "Microsoft.Windows.Camera", "Microsoft.SecHealthUI", "Microsoft.UI.Xaml", "Microsoft.VCLibs", "Microsoft.NET.Native", "Microsoft.WebpImageExtension", "Microsoft.HEIFImageExtension", "Microsoft.VP9VideoExtensions", "Microsoft.ScreenSketch", "Microsoft.WindowsTerminal", "Microsoft.Paint", "Microsoft.WindowsNotepad" )
        $allApps = Get-AppxPackage -AllUsers | Where-Object { $_.Publisher -like "*Microsoft*" -and $_.NonRemovable -eq $false -and (& $baseFilter) }
        foreach ($app in $allApps) {
            $isEssential = $false
            foreach ($essential in $essentialAppsBlocklist) { if ($app.Name -like "*$essential*") { $isEssential = $true; break } }
            if (-not $isEssential) { $apps += (& $objectBuilder $app) }
        }
    } 
    elseif ($Type -eq 'ThirdParty_AllUsers') {
        # --- LoGICA MEJORADA PARA BLOATWARE DE TERCEROS ---
        # Ahora solo busca apps no-Microsoft que esten firmadas como parte del SISTEMA (tipico del bloatware de fabricante).
        $apps = Get-AppxPackage -AllUsers | Where-Object { 
            $_.Publisher -notlike "*Microsoft*" -and $_.SignatureKind -eq 'System' -and (& $baseFilter) 
        } | ForEach-Object { & $objectBuilder $_ }
    }
    elseif ($Type -eq 'ThirdParty_CurrentUser') {
        # --- LoGICA MEJORADA PARA APPS DEL USUARIO ---
        # Ahora solo busca apps no-Microsoft que el usuario instalo desde la TIENDA o de forma manual (Developer).
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $apps = Get-AppxPackage -User $currentUser | Where-Object { 
            $_.Publisher -notlike "*Microsoft*" -and $_.SignatureKind -in ('Store', 'Developer') -and (& $baseFilter) 
        } | ForEach-Object { & $objectBuilder $_ }
    }
    
    Write-Host "[OK] Se encontraron $($apps.Count) aplicaciones." -ForegroundColor Green
    return $apps | Sort-Object Name
}

# --- FUNCIoN 4: La Interfaz de Seleccion (Reutilizable) ---
# Muestra un menu interactivo para que el usuario marque las aplicaciones que desea desinstalar.
function Show-AppSelectionMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$AppList
    )

    $AppList | ForEach-Object { $_ | Add-Member -NotePropertyName 'Selected' -NotePropertyValue $false }

    $choice = ''
    while ($choice.ToUpper() -ne 'E' -and $choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "Eliminacion Selectiva de Aplicaciones" -ForegroundColor Cyan
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
        Write-Host ""
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
        return $AppList | Where-Object { $_.Selected }
    } else {
        return @()
    }
}

# --- FUNCIoN 5: El Motor de Ejecucion ---
# Realiza la desinstalacion y, posteriormente, ofrece la limpieza profunda de los datos de usuario.
function Start-AppUninstallation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory=$true)]
        [array]$AppsToUninstall
    )

    # --- FASE 1: Desinstalacion Estandar ---
    $totalApps = $AppsToUninstall.Count
    Write-Host "`n[+] Desinstalando $totalApps aplicaciones seleccionadas..." -ForegroundColor Yellow

    for ($i = 0; $i -lt $totalApps; $i++) {
        $app = $AppsToUninstall[$i]
        $currentAppNum = $i + 1
        Write-Progress -Activity "Desinstalando Aplicaciones" -Status "($currentAppNum/$totalApps) Eliminando: $($app.Name)" -PercentComplete ($i / $totalApps * 100)

        if ($PSCmdlet.ShouldProcess($app.Name, "Desinstalar (Estandar)")) {
            try {
                Remove-AppxPackage -Package $app.PackageName -AllUsers -ErrorAction Stop
                $provisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app.Name }
                if ($provisionedPackage) {
                    foreach ($pkg in $provisionedPackage) { Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop }
                }
            } catch { Write-Warning "No se pudo desinstalar por completo '$($app.Name)'. Error: $($_.Exception.Message)" }
        }
    }
    Write-Progress -Activity "Desinstalando Aplicaciones" -Completed
    Write-Host "`n[OK] Proceso de desinstalacion estandar completado." -ForegroundColor Green
    Write-Host "-------------------------------------------------------"

    # --- FASE 2 y 3: Modulo de Limpieza Profunda (Opcional) ---
    Write-Host "`n[+] Escaneando en busca de datos de usuario sobrantes..." -ForegroundColor Yellow
    $leftoverFolders = [System.Collections.Generic.List[object]]::new()

    foreach ($app in $AppsToUninstall) {
        $packagePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Packages\$($app.PackageFamilyName)"
        if (Test-Path $packagePath) {
            $folderSize = (Get-ChildItem $packagePath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $leftoverFolders.Add([PSCustomObject]@{
                Path     = $packagePath
                Size     = $folderSize
                Selected = $false
            })
        }
    }

    if ($leftoverFolders.Count -gt 0) {
        Write-Host "[INFO] Se encontraron $($leftoverFolders.Count) carpetas de datos de usuario (configuracion, cache, etc.)." -ForegroundColor Cyan
        
        $choice = ''
        while ($choice.ToUpper() -ne 'S' -and $choice.ToUpper() -ne 'E') {
            Clear-Host
            Write-Host "Modulo de Limpieza Profunda Post-Desinstalacion" -ForegroundColor Yellow
            Write-Host "Las siguientes carpetas de datos de usuario han quedado atras. Puedes eliminarlas para una limpieza completa."
            Write-Warning "¡La eliminacion de estas carpetas es PERMANENTE y borrara configuraciones, partidas guardadas, etc.!"
            
            for ($i = 0; $i -lt $leftoverFolders.Count; $i++) {
                $folder = $leftoverFolders[$i]
                $status = if ($folder.Selected) { "[X]" } else { "[ ]" }
                $sizeInMB = if ($folder.Size) { [math]::Round($folder.Size / 1MB, 2) } else { 0 }
                Write-Host ("   [{0,2}] {1} ({2} MB) - {3}" -f ($i + 1), $status, $sizeInMB, $folder.Path)
            }

            Write-Host "`n--- Acciones ---"
            Write-Host "   [Numero] - Marcar/Desmarcar para eliminar"
            Write-Host "   [T] - Marcar Todos   [N] - Desmarcar Todos"
            Write-Host "   [S] - Omitir y Salir   [E] - Eliminar Seleccionados" -ForegroundColor Red
            
            $rawChoice = Read-Host "`nSelecciona una opcion"
            if ($rawChoice -match '^\d+$' -and [int]$rawChoice -ge 1 -and [int]$rawChoice -le $leftoverFolders.Count) {
                $index = [int]$rawChoice - 1
                $leftoverFolders[$index].Selected = -not $leftoverFolders[$index].Selected
            }
            elseif ($rawChoice.ToUpper() -eq 'T') { $leftoverFolders.ForEach({$_.Selected = $true}) }
            elseif ($rawChoice.ToUpper() -eq 'N') { $leftoverFolders.ForEach({$_.Selected = $false}) }
            elseif ($rawChoice.ToUpper() -eq 'E') {
                $foldersToDelete = $leftoverFolders | Where-Object { $_.Selected }
                if ($foldersToDelete.Count -gt 0) {
                    foreach ($folder in $foldersToDelete) {
                        if ($PSCmdlet.ShouldProcess($folder.Path, "Eliminar Carpeta de Datos Permanentemente")) {
                            try {
                                Remove-Item -Path $folder.Path -Recurse -Force -ErrorAction Stop
                                Write-Host "[OK] Eliminado: $($folder.Path)" -ForegroundColor Green
                            } catch {
                                Write-Error "No se pudo eliminar '$($folder.Path)'. Error: $($_.Exception.Message)"
                            }
                        }
                    }
                }
                # Salir del bucle despues de eliminar
                break 
            }
            elseif ($rawChoice.ToUpper() -eq 'S') { break }
        }
    } else {
        Write-Host "[OK] No se encontraron datos de usuario sobrantes." -ForegroundColor Green
    }
}

function Manage-StartupApps {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    #region Funciones Auxiliares
    
    # --- AÑADIDO: Valores binarios exactos que usa el Administrador de Tareas ---
    $script:EnabledValue  = [byte[]](0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
    $script:DisabledValue = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)

    # --- NUEVA FUNCIoN: Escribe el estado (Habilitado/Deshabilitado) de la misma forma que el Administrador de Tareas ---
    function Set-StartupApprovedStatus {
        param(
            [string]$ItemName,
            [string]$BaseKeyPath,
            [string]$ItemType, # 'Run' o 'StartupFolder'
            [ValidateSet('Enable', 'Disable')][string]$Action
        )
        try {
            $approvedKeyPath = Join-Path -Path $BaseKeyPath -ChildPath "Explorer\StartupApproved\$ItemType"
            if (-not (Test-Path $approvedKeyPath)) {
                New-Item -Path $approvedKeyPath -Force | Out-Null
            }
            
            $valueToSet = if ($Action -eq 'Enable') { $script:EnabledValue } else { $script:DisabledValue }
            
            Set-ItemProperty -Path $approvedKeyPath -Name $ItemName -Value $valueToSet -Type Binary -Force
            return $true
        } catch {
            Write-Warning "No se pudo establecer el estado para '$ItemName'. Error: $($_.Exception.Message)"
            return $false
        }
    }

    # Detecta el estado real de un programa de inicio. Esta funcion es de la version anterior y es correcta.
    function Get-StartupApprovedStatus {
        param(
            [string]$ItemName,
            [string]$BaseKeyPath,
            [string]$ItemType
        )
        $approvedKeyPath = Join-Path -Path $BaseKeyPath -ChildPath "Explorer\StartupApproved\$ItemType"
        if (-not (Test-Path $approvedKeyPath)) { return 'Enabled' }
        $property = Get-ItemProperty -Path $approvedKeyPath -Name $ItemName -ErrorAction SilentlyContinue
        if ($null -eq $property) { return 'Enabled' }
        $binaryData = $property.$ItemName
        if ($null -ne $binaryData -and $binaryData.Length -gt 0) {
            if ($binaryData[0] % 2 -ne 0) { return 'Disabled' }
        }
        return 'Enabled'
    }

    # MODIFICADO: Se asegura de que el objeto devuelto contenga BaseKey y ItemType para las acciones.
    function Get-AllStartupItems {
        $allItems = [System.Collections.Generic.List[psobject]]::new()
        
        # 1. Elementos de Registro
        $regLocations = @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion"; ItemType = "Run" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"; ItemType = "Run" },
            @{ Path = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion"; ItemType = "Run" }
        )
        foreach ($location in $regLocations) {
            if (Test-Path $location.Path) {
                Get-ItemProperty $location.Path | ForEach-Object {
                    $itemProperties = $_
                    $itemProperties.PSObject.Properties | Where-Object { $_.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', '(Default)') } | ForEach-Object {
                        $allItems.Add([PSCustomObject]@{
                            Name      = $_.Name
                            Type      = 'Registry'
                            Status    = Get-StartupApprovedStatus -ItemName $_.Name -BaseKeyPath $location.BaseKey -ItemType $location.ItemType
                            Command   = $_.Value
                            Path      = $location.Path
                            BaseKey   = $location.BaseKey # Necesario para la accion
                            ItemType  = $location.ItemType  # Necesario para la accion
                            Selected  = $false
                        })
                    }
                }
            }
        }

        # 2. Elementos de Carpetas de Inicio
        $folderLocations = @(
            @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; BaseKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion"; ItemType = "StartupFolder" },
            @{ Path = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"; BaseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"; ItemType = "StartupFolder" }
        )
        foreach ($location in $folderLocations) {
            if (Test-Path $location.Path) {
                Get-ChildItem -Path $location.Path -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $allItems.Add([PSCustomObject]@{
                        Name      = $_.Name
                        Type      = 'Folder'
                        Status    = Get-StartupApprovedStatus -ItemName $_.Name -BaseKeyPath $location.BaseKey -ItemType $location.ItemType
                        Command   = $_.FullName
                        Path      = $_.FullName
                        BaseKey   = $location.BaseKey # Necesario para la accion
                        ItemType  = $location.ItemType  # Necesario para la accion
                        Selected  = $false
                    })
                }
            }
        }
        
        # 3. Tareas Programadas
        Get-ScheduledTask | Where-Object { ($_.Triggers.TriggerType -contains 'Logon') -and ($_.TaskPath -notlike "\Microsoft\*") } | ForEach-Object {
            $action = ($_.Actions | Select-Object -First 1).Execute
            $arguments = ($_.Actions | Select-Object -First 1).Arguments
            $allItems.Add([PSCustomObject]@{
                Name     = $_.TaskName
                Type     = 'Task'
                Status   = if ($_.State -eq 'Disabled') { 'Disabled' } else { 'Enabled' }
                Command  = "$action $arguments"
                Path     = $_.TaskPath
                BaseKey  = '' # No aplica
                ItemType = '' # No aplica
                Selected = $false
            })
        }
        
        return $allItems | Sort-Object @{Expression={if ($_.Status -eq 'Enabled') {0} else {1}}}, Name
    }
    #endregion

    # --- Bucle Principal de la Interfaz ---
    $startupItems = Get-AllStartupItems
    $choice = ''

    while ($choice -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "     Gestion de Programas de Inicio (Modo Nativo)      " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar un programa."
        Write-Host ""
        
        for ($i = 0; $i -lt $startupItems.Count; $i++) {
            $item = $startupItems[$i]
            $statusMarker = if ($item.Selected) { "[X]" } else { "[ ]" }
            $statusColor = if ($item.Status -eq 'Enabled') { 'Green' } else { 'Red' }

            Write-Host ("   [{0,2}] {1} " -f ($i + 1), $statusMarker) -NoNewline
            Write-Host ("{0,-50}" -f $item.Name) -NoNewline
            Write-Host ("[{0,-8}]" -f $item.Status) -ForegroundColor $statusColor
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [D] Deshabilitar Seleccionados    [H] Habilitar Seleccionados"
        Write-Host "   [T] Seleccionar Todos             [N] Deseleccionar Todos"
        Write-Host "   [R] Refrescar Lista               [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
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
                $action = if ($choice -eq 'D') { "Disable" } else { "Enable" }
                if (-not($PSCmdlet.ShouldProcess($item.Name, $action))) {
                    continue
                }
                
                # --- LoGICA DE ACCIoN 100% NATIVA ---
                switch ($item.Type) {
                    'Registry' {
                        Set-StartupApprovedStatus -ItemName $item.Name -BaseKeyPath $item.BaseKey -ItemType $item.ItemType -Action $action
                    }
                    'Folder' {
                        Set-StartupApprovedStatus -ItemName $item.Name -BaseKeyPath $item.BaseKey -ItemType $item.ItemType -Action $action
                    }
                    'Task' {
                         if ($action -eq 'Disable') {
                            Disable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction SilentlyContinue
                        } else {
                            Enable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
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
    # DISM repara el almacen de componentes que SFC usa como fuente. Es crucial ejecutarlo primero.
    
    # --- PASO 1a: Escanear la salud de la imagen ---
    Write-Host "`n[+] PASO 1/3: Ejecutando DISM para escanear la salud de la imagen de Windows..." -ForegroundColor Yellow
    Write-Host "    (Este paso busca problemas y puede tardar varios minutos)..." -ForegroundColor Gray
    
    # Capturamos la salida para analizarla, pero tambien la mostramos para que el usuario la vea.
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
		$choice = Read-Host "`n¿Deseas reiniciar ahora? (S/N)"
        if ($choice.ToUpper() -eq 'S') {
            Write-Host "Reiniciando el sistema en 60 segundos..." -ForegroundColor Yellow
            Start-Sleep -Seconds 60
            Restart-Computer -Force
        }
    } else {
        Write-Host "[INFO] No se detectaron corrupciones que requirieran reparacion." -ForegroundColor Green
    }

    Read-Host "`nPresiona Enter para volver..."
}

function Clear-SystemCaches {
    try {
        ipconfig /flushdns | Out-Null
        Write-Host "[OK] Cache DNS limpiada." -ForegroundColor Green
    }
    catch { Write-Warning "Error limpiando DNS: $_" }

    try {
        Start-Process "wsreset.exe" -ArgumentList "-q" -Wait -NoNewWindow
        Write-Host "[OK] Cache de Tienda Windows limpiada." -ForegroundColor Green
    }
    catch { Write-Warning "Error en wsreset: $_" }
}

function Optimize-Drives {
    $drive = Get-Volume -DriveLetter C
    if ($drive.DriveType -eq "SSD") {
        Optimize-Volume -DriveLetter C -ReTrim -Verbose
    }
    else {
        Optimize-Volume -DriveLetter C -Defrag -Verbose
    }
}

function Generate-SystemReport {
	$parentDir = Split-Path -Parent $PSScriptRoot;
	$diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos";
	if (-not (Test-Path $diagDir))
	{
		New-Item -Path $diagDir -ItemType Directory | Out-Null };
		$reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Salud_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').html";
		Write-Host "`n[+] Generando reporte de energia...";
		powercfg /energy /output $reportPath /duration 30;
		if (Test-Path $reportPath)
		{
			Write-Host "[OK] Reporte generado en: '$reportPath'" -ForegroundColor Green;
			Start-Process $reportPath
	} else {
     	Write-Error "No se pudo generar el reporte."
    };
		
	Read-Host "`nPresiona Enter para volver..."
}


function Show-InventoryMenu {
    $parentDir = Split-Path -Parent $PSScriptRoot
    $reportDir = Join-Path -Path $parentDir -ChildPath "Reportes"
    if (-not (Test-Path $reportDir)) { 
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    $reportFile = Join-Path -Path $reportDir -ChildPath "Reporte_Inventario_$(Get-Date -Format 'yyyy-MM-dd').txt"
    
    try {
        # 1. Hardware
        "=== REPORTE DE HARDWARE ===" | Out-File -FilePath $reportFile -Encoding utf8
        Get-ComputerInfo | Select-Object CsName, WindowsProductName, `
            OsHardwareAbstractionLayer, CsProcessors, PhysicalMemorySize | 
            Format-List | Out-File -FilePath $reportFile -Append -Encoding utf8
        
        # 2. Discos (Nuevo)
        "`n=== DISCOS ===" | Out-File -FilePath $reportFile -Append -Encoding utf8
        Get-WmiObject Win32_LogicalDisk | Format-Table DeviceID, VolumeName, 
            @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}}, 
            @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}} | 
            Out-File -FilePath $reportFile -Append -Encoding utf8
        
        # 3. Software Instalado (Nuevo)
        "`n=== SOFTWARE INSTALADO ===" | Out-File -FilePath $reportFile -Append -Encoding utf8
        $software = Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
        $software | Where-Object { $_.DisplayName } | Sort-Object DisplayName |
            Format-Table -AutoSize | Out-File -FilePath $reportFile -Append -Encoding utf8
        
        # 4. Drivers (Nuevo)
        "`n=== DRIVERS ===" | Out-File -FilePath $reportFile -Append -Encoding utf8
        Get-WindowsDriver -Online | 
            Select-Object Driver, OriginalFileName, Version, 
            @{Name="Device";Expression={(Get-WmiObject Win32_PnPSignedDriver | 
                Where-Object { $_.DriverVersion -eq $_.Version }).DeviceName }} | 
            Format-Table -AutoSize | Out-File -FilePath $reportFile -Append -Encoding utf8
        
        Write-Host "[OK] Reporte generado en: '$reportFile'" -ForegroundColor Green
        Start-Process $reportFile
    }
    catch {
        Write-Error "Error generando reporte: $_"
    }
    Read-Host "`nPresiona Enter para volver..."
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
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
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
	Write-Host ""
    Write-Host "   [2] Gestionar Tareas Programadas de Terceros";
    Write-Host "";
    Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red;
	Write-Host ""
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
    # MODIFICADO: Se aplica un orden personalizado para priorizar estados.
    $script:tasks = Get-ScheduledTask | Where-Object { $_.Principal.GroupId -ne 'S-1-5-18' } | ForEach-Object { [PSCustomObject]@{Name=$_.TaskName; Path=$_.TaskPath; State=$_.State; Selected=$false} } | Sort-Object @{Expression = {
        switch ($_.State) {
            'Ready'   { 0 } # Prioridad mas alta
            'Running' { 0 } # Misma prioridad que 'Ready'
            'Disabled'{ 1 } # Siguiente prioridad
            default   { 2 } # El resto de estados al final
        }
    }}
    $choice = ''
    while ($choice -ne 'V') {
        Clear-Host
        Write-Host "Gestion de Tareas Programadas de Terceros" -ForegroundColor Cyan
		Write-Host ""
        Write-Host "Escribe el numero para marcar/desmarcar una tarea."
		Write-Host ""
        for ($i = 0; $i -lt $script:tasks.Count; $i++) {
            $status = if ($script:tasks[$i].Selected) { "[X]" } else { "[ ]" }
            $stateColor = if ($script:tasks[$i].State -eq 'Ready' -or $script:tasks[$i].State -eq 'Running') { "Green" } else { "Red" }
            Write-Host ("   [{0,2}] {1} {2,-40}" -f ($i+1), $status, $script:tasks[$i].Name) -NoNewline
            Write-Host ("[{0}]" -f $script:tasks[$i].State) -ForegroundColor $stateColor
        }
        Write-Host "";
		Write-Host "--- Acciones ---" -ForegroundColor Yellow;
		Write-Host "   [D] Deshabilitar Seleccionadas";
		Write-Host "   [H] Habilitar Seleccionadas";
		Write-Host "   [T] Seleccionar Todas";
		Write-Host "   [N] No seleccionar ninguna";
		Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
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
    Clear-Host
    Write-Warning "El gestor de paquetes 'Scoop' no esta instalado."
    Write-Host "`nPara usar Scoop, debe instalarse manualmente desde una terminal SIN privilegios de Administrador." -ForegroundColor Yellow
    Write-Host "Por favor, sigue estos pasos:"
    Write-Host "1. Abre el Menu Inicio y busca 'PowerShell' (NO hagas clic derecho, solo abrelo)."
    Write-Host "2. En la nueva ventana de PowerShell (debe tener una barra de titulo azul, no negra), ejecuta este comando:"
    Write-Host "   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" -ForegroundColor Cyan
    Write-Host "3. Despues, ejecuta este otro comando para instalar Scoop:"
    Write-Host "   irm get.scoop.sh | iex" -ForegroundColor Cyan
    Write-Host "4. Una vez termine la instalacion, cierra esa ventana y vuelve a ejecutar este script (Aegis Phoenix Suite)."
    Write-Host ""
    Read-Host "Presiona Enter para volver al menu anterior..."
    
    return $false
}

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
                function Parse-WingetTable($output, [int]$expectedColumnCount) {
                    $items = [System.Collections.Generic.List[string[]]]::new()
                    $lines = ($output | Out-String).Split("`n")
                    $headerFound = $false
                    foreach ($line in $lines) {
                        if ($line -match "^Nombre\s+Id") { $headerFound = $true; continue }
                        if (-not $headerFound -or [string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("---")) { continue }
                        
                        $parts = $line.Trim() -split '\s{2,}'
                        if ($parts.Count -ge $expectedColumnCount) {
                            $items.Add($parts)
                        }
                    }
                    return $items
                }

                switch ($Action) {
                    'Search' {
                        $output = winget search $PackageName --accept-source-agreements
                        $tableData = Parse-WingetTable -output $output -expectedColumnCount 2
                        foreach ($row in $tableData) {
                            $results.Add([PSCustomObject]@{
                                Name   = $row[0].Trim()
                                Id     = $row[1].Trim()
                                Engine = 'Winget'
                            })
                        }
                    }
                    'Install' {
                        if ($PSCmdlet.ShouldProcess($PackageName, "Instalar (Winget)")) {
                            winget install --id $PackageName --exact --silent --accept-package-agreements --accept-source-agreements
                        }
                    }
                    'ListOutdated' {
                        $output = winget upgrade --include-unknown --accept-source-agreements
                        if (($output | Out-String) -match "No applicable update found") { break }
                        
                        $tableData = Parse-WingetTable -output $output -expectedColumnCount 4
                        foreach ($row in $tableData) {
                             $results.Add([PSCustomObject]@{
                                Name      = $row[0].Trim()
                                Id        = $row[1].Trim()
                                Version   = $row[2].Trim()
                                Available = $row[3].Trim()
                                Engine    = 'Winget'
                            })
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
            'Scoop' {
                if (-not (Ensure-ScoopIsInstalled)) { throw "Scoop no esta disponible." }
                switch ($Action) {
                    'Search' {
                        scoop search $PackageName | ForEach-Object {
                            
							$line = ([string]$_).Trim()
                            
                            if ($line -and $line -notmatch 'Results from' -and $line -notmatch 'Searching...' -and $line -notmatch '----') {
                                $appName = ($line -split '\s+')[0]
                                if (-not [string]::IsNullOrWhiteSpace($appName)) {
                                    $results.Add([PSCustomObject]@{ Name = $appName; Id = $appName; Engine = 'Scoop' })
                                }
                            }
                        }
                    }
                    'Install' {
                        if ($PSCmdlet.ShouldProcess($PackageName, "Instalar (Scoop)")) { scoop install $PackageName }
                    }
                    'ListOutdated' {
                        scoop status | ForEach-Object {
                            if ($_ -match "^\s*'(?<Name>\S+)'\s+is outdated: '(?<Version>[\d\.\w\-]+)' -> '(?<Available>[\d\.\w\-]+)'") {
                                $results.Add([PSCustomObject]@{
                                    Name      = $Matches['Name']
                                    Id        = $Matches['Name']
                                    Version   = $Matches['Version']
                                    Available = $Matches['Available']
                                    Engine    = 'Scoop'
                                })
                            }
                        }
                    }
                    'Upgrade' {
                        if ($PSCmdlet.ShouldProcess("Paquetes Seleccionados", "Actualizar (Scoop)")) {
                            scoop update $($PackageIdsToUpdate -join ' ')
                        }
                    }
                }
            }
        }
    }
    catch {
        throw "Error ejecutando accion '$Action' con el motor '$Engine': $_"
    }
    return $results
}

# NUEVA: Funcion generica para mostrar un menu de seleccion interactivo.
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
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
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
    $supportedEngines = @('Winget', 'Chocolatey', 'Scoop') # Añade mas motores aqui

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
        Write-Host "`n[OK] ¡Tu software esta al dia!" -ForegroundColor Green
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
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
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

# ===================================================================
# FUNCIONES DEL GESTOR DE AJUSTES (TWEAK MANAGER)
# CORREGIDAS Y OPTIMIZADAS POR UN EXPERTO
# ===================================================================

# --- FUNCIoN 1: El Diagnosta ---
# Verifica el estado REAL de un ajuste consultando el registro o ejecutando un comando de verificacion.
function Get-TweakState {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak
    )

    try {
        # --- Logica para ajustes basados en el Registro de Windows ---
        if ($Tweak.Method -eq 'Registry') {
            # Si la ruta base del registro no existe, el ajuste no puede estar habilitado.
            if (-not (Test-Path $Tweak.RegistryPath)) {
                return 'Disabled'
            }
            $currentValue = (Get-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -ErrorAction SilentlyContinue).($Tweak.RegistryKey)
            
            # Compara el valor actual con el valor que define el estado "Habilitado".
            # Se convierte a [string] para asegurar una comparacion consistente.
            if ([string]$currentValue -eq [string]$Tweak.EnabledValue) {
                return 'Enabled'
            } else {
                return 'Disabled'
            }
        }
        # --- Logica para ajustes basados en Comandos ---
        elseif ($Tweak.Method -eq 'Command') {
            # Si un ajuste de comando no tiene un CheckCommand, no podemos saber su estado.
            if (-not $Tweak.CheckCommand) {
                Write-Warning "El ajuste '$($Tweak.Name)' es de tipo Comando pero no tiene un 'CheckCommand'."
                return 'Disabled' # Se asume deshabilitado si no se puede verificar.
            }

            # Ejecuta el bloque de script de verificacion.
            $checkResult = & $Tweak.CheckCommand

            # Maneja el caso especial donde la verificacion no es aplicable en el sistema actual.
            if ($checkResult -is [string] -and $checkResult -eq 'NotApplicable') {
                return 'NotApplicable'
            }

            # CORRECCIÓN CLAVE: Se utiliza un bloque if/else estandar de PowerShell para retornar el estado.
            # La sintaxis anterior era el punto de fallo.
            if ($checkResult) {
                return 'Enabled'
            } else {
                return 'Disabled'
            }
        }
    } catch {
        # Captura cualquier error inesperado durante la verificacion.
        Write-Warning "Error al verificar el estado de '$($Tweak.Name)': $_"
        return 'Disabled'
    }

    return 'Disabled' # Estado por defecto si ninguna logica anterior aplica.
}

# --- FUNCIoN 2: El Ejecutor ---
# Aplica el estado 'Enable' o 'Disable' a un ajuste. No requiere cambios, ya era robusta.
function Set-TweakState {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Action
    )

    Write-Host " -> Aplicando '$Action' al ajuste '$($Tweak.Name)'..." -ForegroundColor Yellow
    try {
        if ($Action -eq 'Enable') {
            if ($Tweak.Method -eq 'Registry') {
                if (-not (Test-Path $Tweak.RegistryPath)) { New-Item -Path $Tweak.RegistryPath -Force | Out-Null }
                Set-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Value $Tweak.EnabledValue -Type ($Tweak.PSObject.Properties['RegistryType'].Value) -Force
            }
            elseif ($Tweak.Method -eq 'Command') {
                & $Tweak.EnableCommand
            }
        }
        else { # $Action -eq 'Disable'
            if ($Tweak.Method -eq 'Registry') {
                if (Test-Path $Tweak.RegistryPath) {
                    if ($null -ne $Tweak.PSObject.Properties['DefaultValue']) {
                        Set-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Value $Tweak.DefaultValue -Type ($Tweak.PSObject.Properties['RegistryType'].Value) -Force
                        Write-Host "    - Restaurado al valor por defecto." -ForegroundColor Gray
                    }
                    else {
                        Remove-ItemProperty -Path $Tweak.RegistryPath -Name $Tweak.RegistryKey -Force -ErrorAction SilentlyContinue
                        Write-Host "    - Propiedad de registro eliminada para restaurar el comportamiento por defecto." -ForegroundColor Gray
                    }
                }
            }
            elseif ($Tweak.Method -eq 'Command') {
                & $Tweak.DisableCommand
            }
        }
        Write-Host "    [OK] Accion completada." -ForegroundColor Green
    } catch {
        Write-Error "No se pudo modificar el ajuste '$($Tweak.Name)'. Error: $($_.Exception.Message)"
    }
}

# --- FUNCIoN 3: La Interfaz de Usuario ---
# Orquesta la presentacion del menu y la interaccion con el usuario.
# --- FUNCIoN 3: La Interfaz de Usuario (Corregida para mostrar siempre el menu de acciones) ---
# Orquesta la presentacion del menu y la interaccion con el usuario.
function Show-TweakManagerMenu {
    $Category = $null
    while ($true) {
        Clear-Host
        if ($null -eq $Category) {
            # --- Menu de seleccion de categoria ---
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "           Gestor de Ajustes del Sistema (Tweaks)      " -ForegroundColor Cyan
            Write-Host "=======================================================" -ForegroundColor Cyan
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
        }
        else {
            # --- Menu de ajustes en la categoria seleccionada ---
            Write-Host "Gestor de Ajustes | Categoria: $Category" -ForegroundColor Cyan
            Write-Host "------------------------------------------------"
            $tweaksInCategory = $script:SystemTweaks | Where-Object { $_.Category -eq $Category }

            # --- Bucle foreach estable ---
            $itemNumber = 0
            foreach ($tweak in $tweaksInCategory) {
                $itemNumber++
                
                $state = Get-TweakState -Tweak $tweak

                $statusText = if ($state -eq 'Enabled') { "[Activado]" }
                              elseif ($state -eq 'Disabled') { "[Desactivado]" }
                              else { "[No Aplicable]" }
                $statusColor = if ($state -eq 'Enabled') { "Green" }
                               elseif ($state -eq 'Disabled') { "Red" }
                               else { "Gray" }

                Write-Host ("   [{0,2}] " -f $itemNumber) -NoNewline
                Write-Host ("{0,-15}" -f $statusText) -ForegroundColor $statusColor -NoNewline
                Write-Host $tweak.Name -ForegroundColor White
                Write-Host ("        " + $tweak.Description) -ForegroundColor Gray
                Write-Host ""
            }

            # --- Menú de acciones ---
            Write-Host "--- Acciones ---" -ForegroundColor Yellow
            Write-Host "   [Numero] - Activar/Desactivar un ajuste"
            Write-Host ""
			Write-Host "   [V]      - Volver a la seleccion de categoria" -ForegroundColor Red
            Write-Host ""
            $choice = Read-Host "Elige una opcion"

            if ($choice.ToUpper() -eq 'V') {
                $Category = $null
                continue
            }

            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $tweaksInCategory.Count) {
                $tweakToToggle = $tweaksInCategory[[int]$choice - 1]
                $currentState = Get-TweakState -Tweak $tweakToToggle

                if ($currentState -eq 'NotApplicable') {
                    Write-Host "`n[AVISO] Este ajuste no es aplicable en tu sistema." -ForegroundColor Yellow
                    Read-Host "Presiona Enter para continuar..."
                    continue
                }

                $action = if ($currentState -eq 'Enabled') { 'Disable' } else { 'Enable' }
                
                Set-TweakState -Tweak $tweakToToggle -Action $action

                if ($tweakToToggle.RestartNeeded -and $tweakToToggle.RestartNeeded -ne 'None') {
                    Write-Host "`n[AVISO] Este cambio requiere reiniciar '$($tweakToToggle.RestartNeeded)' para tener efecto completo." -ForegroundColor Yellow
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
    Write-Host "   [1] Gestor de Servicios No Esenciales de Windows";
    Write-Host "       (Activa, desactiva o restaura servicios de forma segura)" -ForegroundColor Gray;
	Write-Host "";
    Write-Host "   [2] Optimizar Servicios de Programas Instalados"
    Write-Host "       (Activa o desactiva servicios de tus aplicaciones)" -ForegroundColor Gray
    Write-Host ""
	Write-Host "   [3] Modulo de Limpieza Profunda";
	Write-Host "       (Libera espacio en disco eliminando archivos basura)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [4] Eliminar Apps Preinstaladas (Dinamico)";
	Write-Host "       (Detecta y te permite elegir que bloatware quitar)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [5] Gestionar Programas de Inicio (Interactivo)";
	Write-Host "       (Controla que aplicaciones arrancan con Windows)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "-------------------------------------------------------";
	Write-Host "";
	Write-Host "   [V] Volver al menu principal" -ForegroundColor Red;
	Write-Host ""
	$optimChoice = Read-Host "Selecciona una opcion"; switch ($optimChoice.ToUpper()) {
        '1' { Manage-SystemServices }
        '2' { Manage-ThirdPartyServices }
		'3' { Show-CleaningMenu }
        '4' { Show-BloatwareMenu }
        '5' { Manage-StartupApps }
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
        Write-Host "   [S] Administracion de Sistema"
        Write-Host "       (Limpia registros de eventos y gestiona tareas programadas)" -ForegroundColor Gray
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
            'S' { Show-AdminMenu } # <-- AÑADIDO
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
    Write-Host "         Aegis Phoenix Suite v4.0 by SOFTMAXTER          " -ForegroundColor Cyan
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
