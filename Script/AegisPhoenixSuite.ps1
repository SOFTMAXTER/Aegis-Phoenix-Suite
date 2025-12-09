<#
.SYNOPSIS
    Suite de optimizacion, gestion, seguridad y diagnostico para Windows 11 y 10.
.DESCRIPTION
    Aegis Phoenix Suite v4 by SOFTMAXTER es la herramienta PowerShell. Con una estructura de submenus y una
    logica de verificacion inteligente, permite maximizar el rendimiento, reforzar la seguridad, gestionar
    software y drivers, y personalizar la experiencia de usuario.
    Requiere ejecucion como Administrador.
.AUTHOR
    SOFTMAXTER
.VERSION
    4.8.5
#>

$script:Version = "4.8.5"

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('INFO', 'ACTION', 'WARN', 'ERROR')]
        [string]$LogLevel,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    try {
        $parentDir = Split-Path -Parent $PSScriptRoot
        $logDir = Join-Path -Path $parentDir -ChildPath "Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        $logFile = Join-Path -Path $logDir -ChildPath "Registro.log"
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] [$LogLevel] - $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
    catch {
        Write-Warning "No se pudo escribir en el archivo de log: $_"
    }
}

# --- INICIO DEL MODULO DE AUTO-ACTUALIZACION ---
function Invoke-FullRepoUpdater {
    # --- CONFIGURACION ---
    $repoUser = "SOFTMAXTER"
    $repoName = "Aegis-Phoenix-Suite"
    $repoBranch = "main"
    
    # URLs directas
    $versionUrl = "https://raw.githubusercontent.com/$repoUser/$repoName/$repoBranch/version.txt"
    $zipUrl = "https://github.com/$repoUser/$repoName/archive/refs/heads/$repoBranch.zip"
    
    $updateAvailable = $false
    $remoteVersionStr = ""

    try {
        # Timeout corto para no afectar el inicio si no hay red
        $response = Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 1 -ErrorAction Stop
        $remoteVersionStr = $response.Content.Trim()

        # --- LOGICA ROBUSTA DE VERSIONADO ---
        try {
            $localV = [System.Version]$script:Version
            $remoteV = [System.Version]$remoteVersionStr
            
            if ($remoteV -gt $localV) {
                $updateAvailable = $true
            }
        }
        catch {
            # Fallback: Comparación de texto simple si el formato no es estándar
            if ($remoteVersionStr -ne $script:Version) { 
                $updateAvailable = $true 
            }
        }
    }
    catch {
        # Silencioso si no hay conexión, no es crítico
        return
    }

    # --- Si hay una actualización, preguntamos al usuario ---
    if ($updateAvailable) {
        Write-Host "`n¡Nueva version encontrada!" -ForegroundColor Green
        Write-Host ""
		Write-Host "Version Local: v$($script:Version)" -ForegroundColor Gray
        Write-Host "Version Remota: v$remoteVersionStr" -ForegroundColor Yellow
        Write-Log -LogLevel INFO -Message "UPDATER: Nueva version detectada. Local: v$($script:Version) | Remota: v$remoteVersionStr"
        
		Write-Host ""
        $confirmation = Read-Host "¿Deseas descargar e instalar la actualizacion ahora? (S/N)"
        
        if ($confirmation.ToUpper() -eq 'S') {
            Write-Warning "`nEl actualizador se ejecutara en una nueva ventana."
            Write-Warning "Este script principal se cerrara para permitir la actualizacion."
            Write-Log -LogLevel ACTION -Message "UPDATER: Iniciando proceso de actualizacion. El script se cerrara."
            
            # --- Preparar el script del actualizador externo ---
            $tempDir = Join-Path $env:TEMP "AegisUpdater"
            if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
            New-Item -Path $tempDir -ItemType Directory | Out-Null
            
            $updaterScriptPath = Join-Path $tempDir "updater.ps1"
            $installPath = (Split-Path -Path $PSScriptRoot -Parent)
            $batchPath = Join-Path $installPath "Run.bat"

            # Contenido del script temporal
            $updaterScriptContent = @"
param(`$parentPID)
`$ErrorActionPreference = 'Stop'
`$Host.UI.RawUI.WindowTitle = 'PROCESO DE ACTUALIZACION DE AEGIS - NO CERRAR'

# Funcion auxiliar para logs del actualizador
function Write-UpdateLog { param([string]`$msg) Write-Host "`n`$msg" -ForegroundColor Cyan }

try {
    `$tempDir_updater = "$tempDir"
    `$tempZip_updater = Join-Path "`$tempDir_updater" "update.zip"
    `$tempExtract_updater = Join-Path "`$tempDir_updater" "extracted"

    Write-UpdateLog "[PASO 1/6] Descargando la nueva version v$remoteVersionStr..."
    Invoke-WebRequest -Uri "$zipUrl" -OutFile "`$tempZip_updater"

    Write-UpdateLog "[PASO 2/6] Descomprimiendo archivos..."
    Expand-Archive -Path "`$tempZip_updater" -DestinationPath "`$tempExtract_updater" -Force
    
    # GitHub extrae en una subcarpeta (ej: Aegis-Phoenix-Suite-main)
    `$updateSourcePath = (Get-ChildItem -Path "`$tempExtract_updater" -Directory | Select-Object -First 1).FullName

    Write-UpdateLog "[PASO 3/6] Esperando a que el proceso principal finalice..."
    try {
        # Espera segura con Timeout para no colgarse
        Get-Process -Id `$parentPID -ErrorAction Stop | Wait-Process -ErrorAction Stop -Timeout 30
    } catch {
        Write-Host "   - El proceso principal ya ha finalizado." -ForegroundColor Gray
    }

    Write-UpdateLog "[PASO 4/6] Preparando instalacion (limpiando archivos antiguos)..."
    
    # --- EXCLUSIONES ESPECIFICAS DE AEGIS PHOENIX SUITE ---
    `$itemsToRemove = Get-ChildItem -Path "$installPath" -Exclude "Logs", "Backup", "Reportes", "Diagnosticos", "Tools"
    if (`$null -ne `$itemsToRemove) { 
        Remove-Item -Path `$itemsToRemove.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-UpdateLog "[PASO 5/6] Instalando nuevos archivos..."
    Copy-Item -Path "`$updateSourcePath\*" -Destination "$installPath" -Recurse -Force
    
    # Desbloqueamos los archivos descargados
    Get-ChildItem -Path "$installPath" -Recurse | Unblock-File -ErrorAction SilentlyContinue

    Write-UpdateLog "[PASO 6/6] ¡Actualizacion completada con exito!"
    Write-Host "`nReiniciando Aegis Phoenix Suite en 5 segundos..." -ForegroundColor Green
    Start-Sleep -Seconds 5
    
    # Limpieza y reinicio
    Remove-Item -Path "`$tempDir_updater" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath "$batchPath"
}
catch {
    `$errFile = Join-Path "`$env:TEMP" "AegisUpdateError.log"
    "ERROR FATAL DE ACTUALIZACION: `$_" | Out-File -FilePath `$errFile -Force
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("La actualizacion fallo.`nRevisa: `$errFile", "Error Aegis", 'OK', 'Error')
    exit 1
}
"@
            # Guardar el script del actualizador con codificación UTF8 limpia
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($updaterScriptPath, $updaterScriptContent, $utf8NoBom)
            
            # Lanzar el actualizador y cerrar
            $launchArgs = "/c start `"PROCESO DE ACTUALIZACION`" powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$updaterScriptPath`" -parentPID $PID"
            Start-Process cmd.exe -ArgumentList $launchArgs -WindowStyle Normal
            
            exit
        } else {
            Write-Host "`nActualizacion omitida por el usuario." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}

# Ejecutar el actualizador DESPUES de definir la version
Invoke-FullRepoUpdater

# --- CARGA DE CATALOGOS EXTERNOS ---
Write-Host "Cargando catalogos..."
try {
    . "$PSScriptRoot\Catalogos\Ajustes.ps1"
    . "$PSScriptRoot\Catalogos\Servicios.ps1"
	. "$PSScriptRoot\Catalogos\Bloatware.ps1"
}
catch {
    Write-Error "Error critico: No se pudieron cargar los archivos de catalogo."
    Write-Error "Asegurate de que 'Ajustes.ps1', 'Servicios.ps1' y 'Bloatware.ps1' existen en la subcarpeta 'Catalogos'."
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

Write-Log -LogLevel INFO -Message "================================================="
Write-Log -LogLevel INFO -Message "Aegis Phoenix Suite v$($script:Version) iniciado en modo Administrador."

# --- NUEVA FUNCIoN AUXILIAR PARA AJUSTAR TEXTO (WORD WRAP) ---
function Format-WrappedText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,

        [Parameter(Mandatory=$true)]
        [int]$Indent,

        [Parameter(Mandatory=$true)]
        [int]$MaxWidth
    )

    # Calculamos el ancho real disponible para el texto, restando la sangria.
    $wrapWidth = $MaxWidth - $Indent
    if ($wrapWidth -le 0) { $wrapWidth = 1 } # Evitar un ancho negativo o cero

    $words = $Text -split '\s+'
    $lines = [System.Collections.Generic.List[string]]::new()
    $currentLine = ""

    foreach ($word in $words) {
        # Si la linea actual esta vacia, simplemente añadimos la palabra.
        if ($currentLine.Length -eq 0) {
            $currentLine = $word
        }
        # Si añadir la siguiente palabra (con un espacio) excede el limite...
        elseif (($currentLine.Length + $word.Length + 1) -gt $wrapWidth) {
            # ...guardamos la linea actual y empezamos una nueva con la palabra actual.
            $lines.Add($currentLine)
            $currentLine = $word
        }
        # Si no excede el limite, añadimos la palabra a la linea actual.
        else {
            $currentLine += " " + $word
        }
    }
    # Añadimos la ultima linea que se estaba construyendo.
    if ($currentLine) {
        $lines.Add($currentLine)
    }

    # Creamos el bloque de texto final con la sangria aplicada a cada linea.
    $indentation = " " * $Indent
    return $lines | ForEach-Object { "$indentation$_" }
}

# --- FUNCIONES DE ACCION (Las herramientas que hacen el trabajo) ---
function Create-RestorePoint {
    # 1. Verificamos y aseguramos que la Proteccion del Sistema este habilitada en C:
    try {
        Write-Host "[INFO] Verificando el estado de la Proteccion del Sistema en la unidad C:..." -ForegroundColor Gray
        Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
    } catch {
        Write-Error "No se pudo habilitar la Proteccion del Sistema en la unidad C:. Esta funcion es necesaria para crear puntos de restauracion."
        Write-Error "Por favor, habilitala manualmente desde 'Propiedades del Sistema > Proteccion del Sistema'. Error: $($_.Exception.Message)"
        Read-Host "`nOcurrio un error. Presiona Enter para continuar..."
        return
    }

    # 2. Gestionamos el servicio VSS
    $vssService = Get-Service -Name VSS -ErrorAction SilentlyContinue
    if (-not $vssService) {
        Write-Error "El servicio 'Volume Shadow Copy' (VSS) no se encuentra en este sistema."
        Read-Host "`nPresiona Enter para continuar..."
        return
    }

    $originalStartupType = $vssService.StartupType
    $originalStatus = $vssService.Status
    
    try {
        $serviceNeedsChange = $false
        if ($originalStartupType -eq 'Disabled') {
            $serviceNeedsChange = $true
            Write-Host "[INFO] El servicio VSS esta deshabilitado. Habilitandolo temporalmente..." -ForegroundColor Gray
            Set-Service -Name VSS -StartupType Manual
        }
        
        if ((Get-Service VSS).Status -eq 'Stopped') {
            $serviceNeedsChange = $true
            Write-Host "[INFO] Iniciando el servicio VSS..." -ForegroundColor Gray
            Start-Service -Name VSS -ErrorAction Stop
        }

        # 3. Creamos el punto de restauracion
        Write-Host "[+] Creando punto de restauracion. Esto puede tardar unos minutos..." -ForegroundColor Yellow
        Checkpoint-Computer -Description "Aegis Phoenix Suite v$($script:Version)" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        
        Write-Host "[OK] Punto de restauracion creado exitosamente." -ForegroundColor Green
        Write-Log -LogLevel ACTION -Message "SISTEMA: Se creo un punto de restauracion."

    } catch {
        Write-Error "Fallo la creacion del punto de restauracion. Error: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "SISTEMA: Fallo la creacion del punto de restauracion. Error: $($_.Exception.Message)"
        # La pausa en caso de error ya existe y es correcta.
        Read-Host "`nOcurrio un error. Presiona Enter para continuar..."
    } finally {
        # 4. Restauramos el estado original del servicio
        if ($serviceNeedsChange) {
            Write-Host "[INFO] Restaurando el estado original del servicio VSS..." -ForegroundColor Gray
            
            try {
                Set-Service -Name VSS -StartupType $originalStartupType -ErrorAction SilentlyContinue
                if ($originalStatus -eq 'Stopped' -and (Get-Service VSS).Status -eq 'Running') {
                    Stop-Service -Name VSS -ErrorAction SilentlyContinue
                }
                Write-Host "[OK] Estado del servicio VSS restaurado." -ForegroundColor Green
            } catch {
                Write-Error "Fallo al restaurar el estado original del servicio VSS. Por favor, revisalo manualmente. Error: $($_.Exception.Message)"
                Read-Host "`nOcurrio un error al restaurar el servicio. Presiona Enter para continuar..."
            }
        }
    }

    Read-Host "`nProceso finalizado. Presiona Enter para volver al menu principal..."
}

function Invoke-ExplorerRestart {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Host "`n[+] Reiniciando el Explorador de Windows para aplicar los cambios visuales..." -ForegroundColor Yellow
    Write-Log -LogLevel ACTION -Message "Reiniciando el Explorador de Windows a peticion del usuario."

    if ($PSCmdlet.ShouldProcess("explorer.exe", "Reiniciar")) {
        try {
            # Obtener todos los procesos del Explorador (puede haber más de uno)
            $explorerProcesses = Get-Process -Name explorer -ErrorAction Stop
            
            # Detener los procesos
            $explorerProcesses | Stop-Process -Force
            Write-Host "   - Proceso(s) detenido(s)." -ForegroundColor Gray
            
            # CORRECCIÓN: Esperar a que terminen uno por uno de forma segura
            foreach ($proc in $explorerProcesses) {
                try { 
                    $proc.WaitForExit() 
                } catch { 
                    # Si el proceso ya no existe, ignoramos el error
                }
            }
            
            # Iniciar un nuevo proceso del explorador
            Start-Process "explorer.exe"
            Write-Host "   - Proceso iniciado." -ForegroundColor Gray
            Write-Host "[OK] El Explorador de Windows se ha reiniciado." -ForegroundColor Green
        }
        catch {
            Write-Error "No se pudo reiniciar el Explorador de Windows. Es posible que deba reiniciar la sesion manualmente. Error: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "Fallo el reinicio del Explorador de Windows. Motivo: $($_.Exception.Message)"
            # Intento de emergencia para iniciar explorer por si se quedo detenido
            Start-Process "explorer.exe" -ErrorAction SilentlyContinue
        }
    }
}

# =========================================================================================
# MODULO DE GESTION DE SERVICIOS DE SISTEMA INECESARIOS
# =========================================================================================

function Manage-SystemServices {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    Write-Log -LogLevel INFO -Message "Usuario entro al Gestor de Servicios de Windows."

    # --- NUEVO: Bloque de código para refrescar la caché de servicios ---
    # Definimos esto como un ScriptBlock para poder llamarlo varias veces
    $RefreshServiceCache = {
        Write-Host "Actualizando estado de servicios..." -ForegroundColor Gray
        $hash = @{}
        try {
            $allServices = Get-CimInstance -ClassName Win32_Service -ErrorAction Stop
            foreach ($svc in $allServices) {
                $hash[$svc.Name] = $svc
            }
        } catch {
            Write-Error "No se pudieron obtener los servicios del sistema via WMI."
        }
        return $hash
    }

    # 1. Carga inicial (Primera vez que entras)
    $serviceHash = & $RefreshServiceCache

    $fullServiceList = @()
    foreach ($serviceDef in $script:ServiceCatalog) {
        $fullServiceList += [PSCustomObject]@{
            Definition = $serviceDef
            Selected   = $false
        }
    }

    $choice = ''
    while ($choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "     Gestion de Servicios No Esenciales de Windows     " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Usa los numeros para marcar/desmarcar. Luego, aplica una accion."
        Write-Host ""

        $itemIndex = 0
        $categories = $fullServiceList.Definition.Category | Select-Object -Unique
        
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        $descriptionIndent = 13

        foreach ($category in $categories) {
            Write-Host "--- Categoria: $category ---" -ForegroundColor Yellow
            $servicesInCategory = $fullServiceList | Where-Object { $_.Definition.Category -eq $category }

            foreach ($serviceItem in $servicesInCategory) {
                $itemIndex++
                $serviceDef = $serviceItem.Definition
                $checkbox = if ($serviceItem.Selected) { "[X]" } else { "[ ]" }
                
                # --- USO DE LA CACHÉ OPTIMIZADA ---
                $service = $serviceHash[$serviceDef.Name] 
                # ----------------------------------
                
                $statusText = ""
                $statusColor = "Gray"

                if ($service) {
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
                } else { $statusText = "[No Encontrado]" }
                
                Write-Host ("   [{0,2}] {1} " -f $itemIndex, $checkbox) -NoNewline
                Write-Host ("{0,-26}" -f $statusText) -ForegroundColor $statusColor -NoNewline
                Write-Host $serviceDef.Name -ForegroundColor White
                
                if (-not [string]::IsNullOrWhiteSpace($serviceDef.Description)) {
                    $wrappedDescription = Format-WrappedText -Text $serviceDef.Description -Indent $descriptionIndent -MaxWidth $consoleWidth
                    $wrappedDescription | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
                }
            }
            Write-Host ""
        }
        
        $selectedCount = $fullServiceList.Where({$_.Selected}).Count
        if ($selectedCount -gt 0) {
            Write-Host ""
            Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
        }
        
        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] - Marcar / Desmarcar servicio"
        Write-Host "   [H] Habilitar Seleccionados       [D] Deshabilitar Seleccionados"
        Write-Host "   [R] Restaurar Seleccionados a su estado por defecto"
        Write-Host "   [T] Marcar Todos                  [N] Desmarcar Todos"
        Write-Host ""
        Write-Host "   [V] - Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "Selecciona una opcion"

        try {
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $fullServiceList.Count) {
                $index = [int]$choice - 1
                $fullServiceList[$index].Selected = -not $fullServiceList[$index].Selected
            } 
            elseif ($choice.ToUpper() -eq 'T') { $fullServiceList.ForEach({$_.Selected = $true}) }
            elseif ($choice.ToUpper() -eq 'N') { $fullServiceList.ForEach({$_.Selected = $false}) }
            elseif ($choice.ToUpper() -in @('D', 'H', 'R')) {
                $selectedItems = $fullServiceList | Where-Object { $_.Selected }
                if ($selectedItems.Count -eq 0) {
                    Write-Warning "No has seleccionado ningun servicio."
                    Start-Sleep -Seconds 2
                    continue
                }

                foreach ($item in $selectedItems) {
                    $selectedServiceDef = $item.Definition
                    $actionDescription = ""
                    $newStartupType = ""

                    switch ($choice.ToUpper()) {
                        'D' { $actionDescription = "Deshabilitar"; $newStartupType = 'Disabled' }
                        'H' { $actionDescription = "Habilitar (Restaurar a por defecto)"; $newStartupType = $selectedServiceDef.DefaultStartupType }
                        'R' { $actionDescription = "Restaurar a por defecto ($($selectedServiceDef.DefaultStartupType))"; $newStartupType = $selectedServiceDef.DefaultStartupType }
                    }

                    if ($PSCmdlet.ShouldProcess($selectedServiceDef.Name, $actionDescription)) {
                        $serviceInstance = Get-Service -Name $selectedServiceDef.Name -ErrorAction SilentlyContinue
                        if ($serviceInstance) {
                            Set-Service -Name $serviceInstance.Name -StartupType $newStartupType -ErrorAction Stop
                            
                            if ($newStartupType -ne 'Disabled' -and $serviceInstance.Status -ne 'Running') {
                                Start-Service -Name $serviceInstance.Name -ErrorAction SilentlyContinue
                            }
                            Write-Log -LogLevel ACTION -Message "Servicio de Windows '$($selectedServiceDef.Name)' establecido a '$newStartupType'."
                        } else {
                            Write-Warning "El servicio '$($selectedServiceDef.Name)' no se encontro y fue omitido."
                        }
                    }
                }

                Write-Host "`n[OK] Accion completada para los servicios seleccionados." -ForegroundColor Green
                
                # --- ACTUALIZACION CRITICA: Refrescar la caché después de aplicar cambios ---
                # Esto asegura que el menú muestre el estado nuevo inmediatamente
                $serviceHash = & $RefreshServiceCache
                # ----------------------------------------------------------------------------

                $fullServiceList.ForEach({$_.Selected = $false})
                Read-Host "Presiona Enter para continuar..."
            }
            elseif ($choice.ToUpper() -ne 'V') {
                Write-Warning "Opcion no valida."
                Start-Sleep -Seconds 2
            }
        } catch {
            Write-Error "Error: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "Error en Manage-SystemServices: $($_.Exception.Message)"
            Read-Host "Presiona Enter para continuar..."
        }
    }
}

# =========================================================================================
# MODULO DE GESTION DE SERVICIOS DE TERCEROS
# =========================================================================================

function Manage-ThirdPartyServices {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    Write-Log -LogLevel INFO -Message "Usuario entro al Gestion Inteligente de Servicios de Aplicaciones."

    # Definir rutas
    $parentDir = Split-Path -Parent $PSScriptRoot
    $backupDir = Join-Path -Path $parentDir -ChildPath "Backup"
    if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
    $backupFile = Join-Path -Path $backupDir -ChildPath "ThirdPartyServicesBackup.json"

    # --- BLOQUE DE OPTIMIZACIÓN: CACHÉ INTELIGENTE ---
    # Este bloque obtiene TODOS los servicios una vez y los clasifica.
    # Devuelve un objeto con dos propiedades: 
    #   .List (Solo los de terceros para el menú)
    #   .Hash (Diccionario rápido para consultar estado)
    $RefreshServiceCache = {
        Write-Host "Escaneando y clasificando servicios..." -ForegroundColor Gray
        $hash = @{}
        $thirdPartyList = @()

        try {
            # UNA SOLA LLAMADA WMI PARA TODO
            $allServices = Get-CimInstance -ClassName Win32_Service -ErrorAction Stop
            
            foreach ($svc in $allServices) {
                # 1. Guardar en Hash para acceso rápido por nombre (O(1))
                $hash[$svc.Name] = $svc

                # 2. Filtrar si es de terceros (Lógica optimizada)
                if ($svc.PathName -and $svc.PathName -notmatch '\\Windows\\' -and $svc.PathName -notlike '*svchost.exe*') {
                    $thirdPartyList += $svc
                }
            }
        } catch {
            Write-Error "Error critico al obtener servicios: $($_.Exception.Message)"
        }
        
        # Ordenamos la lista para presentación
        $thirdPartyList = $thirdPartyList | Sort-Object DisplayName
        
        return @{ Hash = $hash; List = $thirdPartyList }
    }
    # ---------------------------------------------------

    # --- FUNCIÓN AUXILIAR: ACTUALIZAR BACKUP (OPTIMIZADA) ---
    # Ya no hace llamadas WMI, recibe la lista ya procesada
    function Update-ServicesBackup {
        param(
            [hashtable]$CurrentStates,
            [array]$LiveServices, # <-- Recibe la lista desde la caché
            [string]$BackupPath
        )
        
        $updated = $false
        
        foreach ($service in $LiveServices) {
            if (-not $CurrentStates.ContainsKey($service.Name)) {
                $CurrentStates[$service.Name] = @{
                    StartupType = $service.StartMode
                    DisplayName = $service.DisplayName
                    Description = $service.Description
                    AddedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                Write-Host "   [NUEVO] Agregado al backup: $($service.DisplayName)" -ForegroundColor Yellow
                $updated = $true
            }
        }
        
        if ($updated) {
            try {
                $CurrentStates | ConvertTo-Json -Depth 3 | Set-Content -Path $BackupPath -Encoding UTF8 -ErrorAction Stop
                Write-Host "   [INFO] Backup actualizado." -ForegroundColor Green
            } catch {
                Write-Host "   [ERROR] Al guardar backup: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        return $CurrentStates
    }

    # 1. Carga Inicial de Datos (Snapshot)
    $cacheData = & $RefreshServiceCache
    $originalStates = @{}

    # 2. Carga/Creación del JSON de Backup
    if (Test-Path $backupFile) {
        Write-Host "Cargando historial de servicios..." -ForegroundColor Gray
        try {
            $fileContent = Get-Content -Path $backupFile -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($fileContent)) {
                $jsonObject = $fileContent | ConvertFrom-Json -ErrorAction Stop
                foreach ($property in $jsonObject.PSObject.Properties) {
                    $originalStates[$property.Name] = @{
                        StartupType = $property.Value.StartupType
                        DisplayName = $property.Value.DisplayName
                        Description = $property.Value.Description
                        AddedDate = $property.Value.AddedDate
                    }
                }
                # Actualizamos backup usando la caché recién generada
                $originalStates = Update-ServicesBackup -CurrentStates $originalStates -LiveServices $cacheData.List -BackupPath $backupFile
            }
        } catch {
            Write-Warning "El archivo de respaldo esta defectuoso o vacío. Se regenerara."
        }
    }
    
    # Si no hay estados (archivo nuevo o dañado), creamos desde cero
    if ($originalStates.Keys.Count -eq 0) {
        $originalStates = Update-ServicesBackup -CurrentStates @{} -LiveServices $cacheData.List -BackupPath $backupFile
    }

    # Preparamos la lista de objetos visuales
    $displayItems = @()
    foreach ($service in $cacheData.List) {
        $displayItems += [PSCustomObject]@{
            ServiceName = $service.Name # Guardamos solo el nombre para buscar en Hash después
            DisplayName = $service.DisplayName
            Description = $service.Description
            Selected = $false
            InBackup = $originalStates.ContainsKey($service.Name)
        }
    }

    $choice = ''
    while ($choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "   Gestion Inteligente de Servicios de Aplicaciones    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Usa los numeros para marcar/desmarcar. Luego, aplica una accion."
        Write-Host ""
        
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        $descriptionIndent = 13
        
        $itemIndex = 0
        foreach ($item in $displayItems) {
            $itemIndex++
            $checkbox = if ($item.Selected) { "[X]" } else { "[ ]" }
            
            # --- BÚSQUEDA OPTIMIZADA (O(1)) ---
            # Usamos el Hash en lugar de llamar a WMI
            $liveService = $cacheData.Hash[$item.ServiceName]
            # ----------------------------------
            
            $statusText = "[No Encontrado]"
            $statusColor = "Gray"
            
            if ($liveService) {
                $isRunning = $liveService.State -eq 'Running'
                if ($liveService.StartMode -eq 'Disabled') {
                    $statusText = "[Desactivado]"
                    $statusColor = "Red"
                } else {
                    $statusText = "[Activado]"
                    $statusColor = "Green"
                    if ($isRunning) { $statusText += " [En Ejecucion]" }
                }
            }

            $backupIndicator = if ($item.InBackup) { " [BACKUP] " } else { " [NO BK] " }
            $backupColor = if ($item.InBackup) { "Green" } else { "Red" }
            
            Write-Host ("   [{0,2}] {1} " -f $itemIndex, $checkbox) -NoNewline
            Write-Host ("{0,-26}" -f $statusText) -ForegroundColor $statusColor -NoNewline
            Write-Host "$backupIndicator" -NoNewline -ForegroundColor $backupColor
            Write-Host $item.DisplayName -ForegroundColor White

            if (-not [string]::IsNullOrWhiteSpace($item.Description)) {
                $wrappedDescription = Format-WrappedText -Text $item.Description -Indent $descriptionIndent -MaxWidth $consoleWidth
                $wrappedDescription | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            }
        }
        
        $selectedCount = $displayItems.Where({$_.Selected}).Count
        if ($selectedCount -gt 0) {
            Write-Host ""
            Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] - Marcar / Desmarcar servicio"
        Write-Host "   [H] Habilitar Seleccionados       [D] Deshabilitar Seleccionados"
        Write-Host "   [R] Restaurar Seleccionados a su estado original"
        Write-Host "   [T] Marcar Todos                  [N] Desmarcar Todos"
        Write-Host "   [U] Forzar actualización del backup (Refresh)"
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "Selecciona una opcion"

        try {
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $displayItems.Count) {
                $index = [int]$choice - 1
                $displayItems[$index].Selected = -not $displayItems[$index].Selected
            }
            elseif ($choice.ToUpper() -eq 'T') { $displayItems.ForEach({$_.Selected = $true}) }
            elseif ($choice.ToUpper() -eq 'N') { $displayItems.ForEach({$_.Selected = $false}) }
            elseif ($choice.ToUpper() -eq 'U') {
                # Refresh forzado: Recargamos la caché y actualizamos el backup
                $cacheData = & $RefreshServiceCache
                $originalStates = Update-ServicesBackup -CurrentStates $originalStates -LiveServices $cacheData.List -BackupPath $backupFile
                
                # Actualizamos la interfaz visual si hubo cambios en la lista
                # (Nota: Reconstruimos displayItems por si aparecieron servicios nuevos)
                $displayItems = @()
                foreach ($service in $cacheData.List) {
                    $displayItems += [PSCustomObject]@{
                        ServiceName = $service.Name
                        DisplayName = $service.DisplayName
                        Description = $service.Description
                        Selected = $false
                        InBackup = $originalStates.ContainsKey($service.Name)
                    }
                }
                Read-Host "Backup y lista actualizados. Presiona Enter..."
            }
            elseif ($choice.ToUpper() -in @('D', 'H', 'R')) {
                $selectedItems = $displayItems | Where-Object { $_.Selected }
                if ($selectedItems.Count -eq 0) {
                    Write-Warning "No has seleccionado ningun servicio."
                    Start-Sleep -Seconds 2
                    continue
                }

                foreach ($itemAction in $selectedItems) {
                    # Recuperamos el objeto real desde el Hash usando el nombre
                    $selectedService = $cacheData.Hash[$itemAction.ServiceName]
                    if (-not $selectedService) { Write-Warning "El servicio $($itemAction.ServiceName) ya no parece existir."; continue }

                    $actionDescription = ""
                    switch ($choice.ToUpper()) {
                        'D' { $actionDescription = "Deshabilitar" }
                        'H' { $actionDescription = "Habilitar" }
                        'R' { 
                            if (-not $itemAction.InBackup) {
                                Write-Host "El servicio '$($itemAction.DisplayName)' no tiene un estado original guardado." -ForegroundColor Red
                                continue
                            }
                            $actionDescription = "Restaurar a estado original ($($originalStates[$itemAction.ServiceName].StartupType))" 
                        }
                    }
                    
                    if ($PSCmdlet.ShouldProcess($itemAction.DisplayName, $actionDescription)) {
                        $newStartupType = ''
                        if ($choice.ToUpper() -eq 'D') { $newStartupType = 'Disabled' }
                        if ($choice.ToUpper() -eq 'H') { $newStartupType = 'Manual' }
                        if ($choice.ToUpper() -eq 'R') { $newStartupType = $originalStates[$itemAction.ServiceName].StartupType }

                        try {
                            Set-Service -Name $itemAction.ServiceName -StartupType $newStartupType -ErrorAction Stop
                            
                            $svcNow = Get-Service -Name $itemAction.ServiceName
                            if ($newStartupType -eq 'Disabled' -and $svcNow.Status -eq 'Running') {
                                Stop-Service -Name $itemAction.ServiceName -Force -ErrorAction SilentlyContinue
                            } elseif ($newStartupType -ne 'Disabled' -and $svcNow.Status -ne 'Running') {
                                Start-Service -Name $itemAction.ServiceName -ErrorAction SilentlyContinue
                            }
                            Write-Log -LogLevel ACTION -Message "Servicio '$($itemAction.DisplayName)' modificado: $actionDescription."
                        } catch {
                            Write-Error "Fallo al modificar '$($itemAction.DisplayName)': $($_.Exception.Message)"
                        }
                    }
                }

                Write-Host "`n[OK] Accion completada." -ForegroundColor Green
                
                # Refrescamos solo la caché de estado para que el menú muestre los cambios
                $cacheData = & $RefreshServiceCache
                
                $displayItems.ForEach({$_.Selected = $false})
                Read-Host "Presiona Enter para continuar..."
            }
        } catch {
            Write-Error "Error inesperado: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "Error en Manage-ThirdPartyServices: $($_.Exception.Message)"
            Read-Host "Presiona Enter para continuar..."
        }
    }
}

# =================================================================================
# --- INICIO DEL MoDULO DE LIMPIEZA ---
# =================================================================================
# --- Calcula el tamaño recuperable con mejor manejo de errores ---
function Get-CleanableSize {
    param([string[]]$Paths)
    $totalSize = 0
    foreach ($path in $Paths) {
        try {
            if (Test-Path $path) {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction Stop -File
                if ($null -ne $items) {
                    $size = ($items | Measure-Object -Property Length -Sum).Sum
                    $totalSize += $size
                }
            }
        }
        catch {
            Write-Warning "No se pudo calcular el tamaño de '$path': $($_.Exception.Message)"
        }
    }
    return $totalSize
}

# --- FUNCIoN AUXILIAR NUEVA: Elimina archivos de forma robusta ---
function Remove-FilesSafely {
    param(
        [string]$Path,
        [switch]$ForceSystemFiles = $false
    )
    
    Write-Host "   - Limpiando: $Path" -ForegroundColor Gray
    
    try {
        # Verificar si la ruta existe y es accesible
        if (-not (Test-Path $Path)) {
            Write-Host "     [INFO] La ruta '$Path' no existe." -ForegroundColor Gray
            return 0L
        }

        # Obtener todos los archivos (ignorar errores de acceso)
        $files = Get-ChildItem -Path "$Path\*" -Recurse -Force -File -ErrorAction SilentlyContinue
        
        $deletedCount = 0
        $totalCount = 0
        $originalSize = 0L
        
        if ($null -ne $files) {
            # Asegurar que $files sea siempre un array, incluso si solo hay un archivo
            if ($files -isnot [array]) {
                $files = @($files)
            }
            $totalCount = $files.Count
            # Calcular el tamaño original de manera segura
            if ($totalCount -gt 0) {
                $originalSizeObj = $files | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
                # Manejo robusto para obtener el valor Sum
                if ($null -ne $originalSizeObj -and $originalSizeObj.PSObject.Properties.Match('Sum').Count -gt 0) {
                    $originalSize = [long]$originalSizeObj.Sum
                }
            }
        }
        
        if ($totalCount -eq 0) {
            Write-Host "     [INFO] No hay archivos para eliminar en esta ubicacion." -ForegroundColor Gray
            return 0L
        }

        foreach ($file in $files) {
            try {
                # Intentar eliminar con permisos elevados usando SID universal
                $acl = Get-Acl -Path $file.FullName -ErrorAction SilentlyContinue
                    if ($acl) {
                    # S-1-5-32-544 es el SID universal para el grupo de Administradores
                    $adminSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        
                    $acl.SetOwner($adminSid)
                    $acl.SetAccessRuleProtection($true, $false)
        
                    # Regla usando el SID en lugar del nombre "Administrators"
                    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid, "FullControl", "Allow")
                    $acl.AddAccessRule($rule)
        
                    Set-Acl -Path $file.FullName -AclObject $acl -ErrorAction SilentlyContinue
                }
    
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $deletedCount++
            }
            catch {
                # Intento alternativo para archivos bloqueados
                try {
                    $shortPath = Get-ShortPathName -Path $file.FullName
                    & cmd.exe /c "del /f /q `"$shortPath`"" 2>$null
                    $deletedCount++
                }
                catch {
                    # No registrar cada error individual para no saturar el log
                    continue
                }
            }
        }
        
        # Intentar eliminar directorios vacios
        try {
            $emptyDirs = Get-ChildItem -Path $Path -Directory -Force -Recurse | 
                Where-Object { $null -eq (Get-ChildItem -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue -File) -and
                               $null -eq (Get-ChildItem -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue -Directory) }
                
            if ($null -ne $emptyDirs) {
                if ($emptyDirs -isnot [array]) {
                    $emptyDirs = @($emptyDirs)
                }
                foreach ($dir in $emptyDirs) {
                    try {
                        Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    catch {
                        # No es critico si falla la eliminacion de algunos directorios vacios
                    }
                }
            }
        }
        catch {
            # No es critico si falla la eliminacion de directorios vacios
        }
        
        $percent = if ($totalCount -gt 0) { [math]::Round(($deletedCount / $totalCount) * 100, 1) } else { 0 }
        Write-Host "     [OK] Eliminados $deletedCount de $totalCount archivos ($percent%)" -ForegroundColor Green
        
        # Calcular espacio liberado de manera segura
        $currentSize = 0L
        try {
            $remainingFiles = Get-ChildItem -Path "$Path\*" -Recurse -Force -File -ErrorAction SilentlyContinue
            if ($null -ne $remainingFiles) {
                # Asegurar que $remainingFiles sea siempre un array
                if ($remainingFiles -isnot [array]) {
                    $remainingFiles = @($remainingFiles)
                }
                if ($remainingFiles.Count -gt 0) {
                    $remainingSizeObj = $remainingFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
                    # Manejo robusto para obtener el valor Sum
                    if ($null -ne $remainingSizeObj -and $remainingSizeObj.PSObject.Properties.Match('Sum').Count -gt 0) {
                        $currentSize = [long]$remainingSizeObj.Sum
                    }
                }
            }
        }
        catch {
            # Si hay un error al calcular el tamaño actual, asumimos que es 0
            $currentSize = 0L
        }
        
        $liberatedSpace = $originalSize - $currentSize
        if ($liberatedSpace -lt 0) { $liberatedSpace = 0L } # Prevenir valores negativos
        
        # Asegurar que siempre devuelva un valor numerico de tipo largo
        return [long]$liberatedSpace
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Warning "Error al limpiar '$Path': $errorMsg"

        try {
            Write-Log -LogLevel ERROR -Message "LIMPIEZA: Fallo crítico al limpiar '$Path'. Motivo: $errorMsg"
        } catch {
            # Fallback por si Write-Log no está disponible en este ámbito
            Write-Host "   [LOG ERROR] No se pudo escribir en el log." -ForegroundColor Red
        }

        return 0L
    }
}

# --- FUNCIoN AUXILIAR NUEVA: Obtener ruta corta de archivo (8.3 format) ---
function Get-ShortPathName {
    param([string]$Path)
    
    $shortPathBuffer = New-Object System.Text.StringBuilder 255
    $retVal = [Kernel32]::GetShortPathName($Path, $shortPathBuffer, $shortPathBuffer.Capacity)
    
    if ($retVal -eq 0) { return $Path }
    return $shortPathBuffer.ToString()
}

# Añadir tipos necesarios para GetShortPathName
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Kernel32 {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern uint GetShortPathName(string lpszLongPath, StringBuilder lpszShortPath, int cchBuffer);
}
"@ -ErrorAction SilentlyContinue

# --- FUNCIoN MEJORADA: Limpieza Avanzada de Componentes del Sistema ---
function Invoke-AdvancedSystemClean {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
	
	# --- VALIDACIÓN DE SEGURIDAD: REINICIO PENDIENTE ---
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        Write-Warning "AVISO CRITICO: Hay actualizaciones de Windows pendientes de reinicio."
        Write-Warning "Ejecutar una limpieza profunda de componentes ahora podria corromper el sistema."
        Write-Warning "Por favor, reinicia tu PC antes de usar esta funcion."
        
        $choice = Read-Host "¿Deseas cancelar (C) o arriesgarte y continuar (R)? [Se recomienda Cancelar]"
        if ($choice.ToUpper() -ne 'R') {
            Write-Host "Operacion cancelada por seguridad." -ForegroundColor Green
            return
        }
    }
    
    Write-Log -LogLevel INFO -Message "Usuario inicio la Limpieza Avanzada de Componentes de Windows."
    Write-Host "`n[+] Iniciando Limpieza Avanzada de Componentes del Sistema..." -ForegroundColor Cyan
    Write-Log -LogLevel ACTION -Message "Iniciando Limpieza Avanzada del Sistema."
    
    Write-Warning "Esta operacion eliminara archivos de instalaciones anteriores de Windows (Windows.old) y restos de actualizaciones."
    Write-Warning "Despues de esta limpieza, NO podras volver a la version anterior de Windows."
    
    if ((Read-Host "¿Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') {
        Write-Log -LogLevel WARN -Message "Usuario cancelo la Limpieza Avanzada de Componentes."
        Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Componentes del Sistema", "Limpieza Profunda")) {
        try {
            $totalFreed = 0
            $startSize = (Get-PSDrive C).Used
            
            # Paso 1: Ejecutar DISM para limpiar componentes de Windows
            Write-Host "[+] Paso 1 de 3: Limpiando cache de componentes de Windows con DISM..." -ForegroundColor Yellow
            DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "DISM no completo correctamente, pero continuaremos con otros metodos."
            }
            
            # Paso 2: Usar cleanmgr con configuracion correcta
            Write-Host "[+] Paso 2 de 3: Configurando Liberador de Espacio en Disco..." -ForegroundColor Yellow
            
            # Crear todas las claves necesarias y establecer los valores correctos (0x1 = ejecutar, 0x2 = no ejecutar)
            $handlers = @(
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\BranchCache",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Internet Cache Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Memory Dump Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old ChkDsk Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error memory dump files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error minidump files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Setup Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Upgrade Discarded Files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\User file versions",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Defender",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows ESD installation files",
                "Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Upgrade Log Files"
            )
            
            foreach ($handler in $handlers) {
                $regPath = "HKLM:\SOFTWARE\$handler"
                try {
                    if (-not (Test-Path $regPath)) {
                        New-Item -Path $regPath -Force | Out-Null
                    }
                    Set-ItemProperty -Path $regPath -Name "StateFlags0099" -Value 2 -Type DWord -Force
                }
                catch {
                    Write-Warning "No se pudo configurar '$handler' para la limpieza"
                }
            }
            
            # Ejecutar cleanmgr con el flag correcto
            Write-Host "[+] Paso 3 de 3: Ejecutando Liberador de Espacio en Disco..." -ForegroundColor Yellow
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:99" -Wait
            
            # Paso 4: Limpiar Windows.old manualmente (si existe)
            $winOldPath = "C:\Windows.old"
            if (Test-Path $winOldPath) {
                Write-Host "[+] Verificando y limpiando Windows.old..." -ForegroundColor Yellow
                
                try {
                    # Tomar posesión de la carpeta (takeown suele funcionar bien porque usa el usuario actual)
                    $takeOwnOutput = & takeown.exe /F $winOldPath /R /D S 2>&1 # Cambiado /D Y por /D S (Sí/Yes depende del idioma, S suele ser seguro en ES, pero mejor omitir si falla)
                    # MEJOR OPCIÓN: Omitir /D si no estamos seguros del idioma o usar un script recursivo de PowerShell.
                    # Pero para icacls, el uso de SID es la clave:
        
                    # Otorgar permisos completos usando el SID universal (*S-1-5-32-544)
                    $icaclsOutput = & icacls.exe $winOldPath /grant *S-1-5-32-544:F /T /C /Q 2>&1
        
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "No se pudieron establecer permisos en Windows.old: $($icaclsOutput | Out-String)"
                    }
                    
                    # Intentar eliminar (puede requerir multiples intentos)
                    Write-Host "   - Intentando eliminar Windows.old. Esto puede tardar mucho tiempo..." -ForegroundColor Gray
                    Remove-Item -Path $winOldPath -Recurse -Force -ErrorAction SilentlyContinue
                    
                    # Si no se elimino completamente, usar metodo alternativo
                    if (Test-Path $winOldPath) {
                        Write-Host "   - Usando metodo alternativo para eliminar Windows.old..." -ForegroundColor Gray
                        & cmd.exe /c "rd /s /q `"$winOldPath`"" 2>$null
                    }
                }
                catch {
                    Write-Warning "No se pudo eliminar Windows.old completamente: $($_.Exception.Message)"
                }
            }
            
            # Calcular espacio liberado
            $endSize = (Get-PSDrive C).Used
            $totalFreed = $startSize - $endSize
            
            $freedGB = [math]::Round($totalFreed / 1GB, 2)
            Write-Host "`n[OK] Limpieza avanzada completada." -ForegroundColor Green
            Write-Host "    ¡Se han liberado aproximadamente $freedGB GB de espacio!" -ForegroundColor Magenta
            Write-Log -LogLevel ACTION -Message "Limpieza avanzada completada. Espacio liberado: $freedGB GB."
            
        } catch {
            Write-Error "Ocurrio un error durante la limpieza avanzada: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "Error en Invoke-AdvancedSystemClean: $($_.Exception.Message)"
        }
    }
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIÓN MEJORADA Y BLINDADA: Menú Principal de Limpieza ---
function Show-CleaningMenu {
    Write-Log -LogLevel INFO -Message "Usuario entró al Módulo de Limpieza."
    
    # --- FUNCIÓN INTERNA PARA SUMAR DE FORMA SEGURA ---
    # Esta pequeña función se encarga de limpiar la "basura" que devuelve PowerShell
    # y extraer solo el número para evitar el error op_Addition.
    function Add-Safe {
        param($CurrentTotal, $NewValue)
        try {
            $valToAd = 0
            # Si es un array (lista), tomamos el último elemento (usualmente el return)
            if ($NewValue -is [array]) {
                $valToAd = $NewValue[-1]
            } else {
                $valToAd = $NewValue
            }
            
            # Intentamos convertir a número entero largo
            if ($valToAd -match '^\d+$') {
                return $CurrentTotal + [long]$valToAd
            }
            return $CurrentTotal
        } catch {
            return $CurrentTotal
        }
    }

    $cleanChoice = ''
    do {
        # --- Precalcular tamaños antes de mostrar el menú ---
        Write-Host "Refrescando datos de espacio, por favor espera..." -ForegroundColor Gray
        
        $tempPaths = @(
            "$env:TEMP",
            "$env:windir\Temp",
            "$env:windir\Minidump",
            "$env:LOCALAPPDATA\CrashDumps",
            "$env:windir\Prefetch",
            "$env:windir\SoftwareDistribution\Download",
            "$env:windir\LiveKernelReports"
        )
        
        $cachePaths = @(
            "$env:LOCALAPPDATA\D3DSCache",
            "$env:LOCALAPPDATA\NVIDIA\GLCache",
            "$env:windir\SoftwareDistribution\DeliveryOptimization"
        )
        
        # Calcular tamaños iniciales (protegidos contra errores)
        $sizeTempBytes = 0
        try { $sizeTempBytes = Get-CleanableSize -Paths $tempPaths } catch {}
        
        $sizeCachesBytes = 0
        try { $sizeCachesBytes = Get-CleanableSize -Paths $cachePaths } catch {}
        
        # --- Calcular tamaño de la Papelera de Reciclaje ---
        $recycleBinSize = 0
        $recycleBinItemCount = 0
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBinItems = $shell.NameSpace(0x0a).Items()
            $recycleBinItemCount = $recycleBinItems.Count
            foreach ($item in $recycleBinItems) {
                $recycleBinSize += [long]$item.Size
            }
        } catch {
            # Si falla el COM, ignorar
        }
        
        # Convertir a MB para visualización
        $sizeTempMB = [math]::Round($sizeTempBytes / 1MB, 2)
        $sizeCachesMB = [math]::Round($sizeCachesBytes / 1MB, 2)
        $sizeBinMB = [math]::Round($recycleBinSize / 1MB, 2)
        
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "               Módulo de Limpieza Profunda             " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Selecciona el tipo de limpieza que deseas ejecutar."
        Write-Host ""
        Write-Host "--- Limpieza Rapida (Archivos de Usuario) ---" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [1] Limpieza Estandar (Temporales y Dumps de Errores)" -NoNewline
        Write-Host " ($sizeTempMB MB)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [2] Limpieza de Caches (Sistema, Drivers y Miniaturas)" -NoNewline
        Write-Host " ($sizeCachesMB MB)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [3] Vaciar Papelera de Reciclaje" -NoNewline
        Write-Host " ($sizeBinMB MB)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "--- Limpieza Profunda (Archivos de Sistema) ---" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [4] Limpieza de Componentes de Windows (Windows.old, etc.)" -ForegroundColor Red
        Write-Host ""
        Write-Host "   [T] TODO (Ejecutar todas las limpiezas rapidas [1-3])"
        Write-Host ""
        Write-Host "   [V] Volver al menú anterior" -ForegroundColor Red
        Write-Host ""
        
        $cleanChoice = Read-Host "`nSelecciona una opcion"
        Write-Log -LogLevel INFO -Message "Usuario seleccionó la opcion de limpieza '$($cleanChoice.ToUpper())'"
        
        # Inicializar contador seguro
        [long]$totalFreed = 0

        switch ($cleanChoice.ToUpper()) {
           '1' {
                Write-Log -LogLevel ACTION -Message "Iniciando Limpieza Estándar (Temporales y Dumps)."
                Write-Host "`n[+] Limpiando archivos temporales y dumps de errores..." -ForegroundColor Yellow
        
                $processesToStop = @("explorer", "OneDrive", "Teams", "chrome", "firefox", "msedge")
                foreach ($proc in $processesToStop) {
                    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
                }
        
                foreach ($path in $tempPaths) {
                    if (Test-Path $path) {
                        $rawResult = Remove-FilesSafely -Path $path
                        $totalFreed = Add-Safe -CurrentTotal $totalFreed -NewValue $rawResult
                    }
                }
        
                Start-Process "explorer.exe"
            }
            '2' {
                Write-Log -LogLevel ACTION -Message "Iniciando Limpieza de Caches (Sistema y Drivers)."
                Write-Host "`n[+] Limpiando caches del sistema..." -ForegroundColor Yellow
                
                foreach ($path in $cachePaths) {
                    if (Test-Path $path) {
                        $rawResult = Remove-FilesSafely -Path $path
                        $totalFreed = Add-Safe -CurrentTotal $totalFreed -NewValue $rawResult
                    }
                }
                
                Write-Host "   - Limpiando caché de miniaturas..." -ForegroundColor Gray
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                try {
                    $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                    if (Test-Path "$thumbPath\thumbcache_*.db") {
                        Remove-Item -Path "$thumbPath\thumbcache_*.db" -Force -ErrorAction Stop
                        Write-Host "     [OK] Caché de miniaturas limpiada." -ForegroundColor Green
                    }
                } catch {} 
                finally {
                    Start-Process "explorer"
                }
            }
            '3' {
                if ($recycleBinItemCount -gt 0) {
                    Write-Host "`n[+] Vaciando la Papelera de Reciclaje..." -ForegroundColor Yellow
                    try {
                        Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop
                        $totalFreed += [long]$recycleBinSize
                        Write-Host "[OK] Papelera de Reciclaje vaciada correctamente." -ForegroundColor Green
                        Write-Log -LogLevel ACTION -Message "Papelera de Reciclaje vaciada exitosamente."
                    } catch {
                        Write-Warning "No se pudo vaciar la Papelera de Reciclaje."
                    }
                } else {
                    Write-Host "[OK] La Papelera de Reciclaje ya estaba vacía." -ForegroundColor Green
                }
            }
            '4' { 
                Invoke-AdvancedSystemClean
            }
            'T' {
                # Opción TODO: Usa la función Add-Safe para evitar errores de array
                Write-Log -LogLevel ACTION -Message "Iniciando Limpieza Completa (Opción TODO)."
                Write-Host "`n[+] Ejecutando limpieza completa..." -ForegroundColor Yellow
                
                $processesToStop = @("explorer", "OneDrive", "Teams", "chrome", "firefox", "msedge")
                foreach ($proc in $processesToStop) {
                    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
                }
                
                # 1. Temporales
                foreach ($path in $tempPaths) {
                    if (Test-Path $path) {
                        $rawResult = Remove-FilesSafely -Path $path
                        $totalFreed = Add-Safe -CurrentTotal $totalFreed -NewValue $rawResult
                    }
                }
                
                # 2. Cachés
                foreach ($path in $cachePaths) {
                    if (Test-Path $path) {
                        $rawResult = Remove-FilesSafely -Path $path
                        $totalFreed = Add-Safe -CurrentTotal $totalFreed -NewValue $rawResult
                    }
                }
                
                # 3. Miniaturas
                $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                if (Test-Path "$thumbPath\thumbcache_*.db") {
                    Remove-Item -Path "$thumbPath\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                }
                
                # 4. Papelera
                if ($recycleBinItemCount -gt 0) {
                    Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
                    $totalFreed += [long]$recycleBinSize
                }
                
                Start-Process "explorer.exe"
            }
            'V' { continue }
            default { Write-Warning "Opcion no válida." }
        }
        
        # Mostrar resumen de espacio liberado
        if ($totalFreed -gt 0 -and $cleanChoice.ToUpper() -ne '4') {
            $freedMB = [math]::Round($totalFreed / 1MB, 2)
            Write-Host "`n[EXITO] ¡Se han liberado aproximadamente $freedMB MB!" -ForegroundColor Magenta
            Write-Log -LogLevel ACTION -Message "Limpieza completada. Espacio liberado: $freedMB MB."
        }
        
        if ($cleanChoice.ToUpper() -ne 'V' -and $cleanChoice.ToUpper() -ne '4') {
            Read-Host "`nPresiona Enter para continuar..."
        }
    } while ($cleanChoice.ToUpper() -ne 'V')
}

function Show-BloatwareMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Bloatware."
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
            '1' {
				Write-Log -LogLevel INFO -Message "BLOATWARE: Usuario selecciono 'Eliminar Bloatware de Microsoft'."
				Manage-Bloatware -Type 'Microsoft'
				}
            '2' {
				Write-Log -LogLevel INFO -Message "BLOATWARE: Usuario selecciono 'Eliminar Bloatware de Terceros'."
				Manage-Bloatware -Type 'ThirdParty_AllUsers'
				}
            '3' {
				Write-Log -LogLevel INFO -Message "BLOATWARE: Usuario selecciono 'Desinstalar Mis Apps'."
				Manage-Bloatware -Type 'ThirdParty_CurrentUser'
				}
            'V' {
				continue
				}
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
        $allApps = Get-AppxPackage -AllUsers | Where-Object { $_.Publisher -like "*Microsoft*" -and $_.NonRemovable -eq $false -and (& $baseFilter) }
        foreach ($app in $allApps) {
            $isEssential = $false
            foreach ($essential in $script:ProtectedAppList) { 
                if ($app.Name -like "*$essential*") { $isEssential = $true; break } 
            }
            if (-not $isEssential) { $apps += (& $objectBuilder $app) }
        }
    }
    elseif ($Type -eq 'ThirdParty_AllUsers') {
        # Ahora solo busca apps no-Microsoft que esten firmadas como parte del SISTEMA (tipico del bloatware de fabricante).
        $apps = Get-AppxPackage -AllUsers | Where-Object { 
            $_.Publisher -notlike "*Microsoft*" -and $_.SignatureKind -eq 'System' -and (& $baseFilter) 
        } | ForEach-Object { & $objectBuilder $_ }
    }
    elseif ($Type -eq 'ThirdParty_CurrentUser') {
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
		
	    $selectedCount = $AppList.Where({$_.Selected}).Count
        if ($selectedCount -gt 0) {
			Write-Host ""
            Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] Marcar/Desmarcar  [E] Eliminar seleccionados"
        Write-Host "   [T] Seleccionar Todos      [N] No seleccionar ninguno"
        Write-Host ""
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
			Write-Log -LogLevel ACTION -Message "BLOATWARE: Desinstalando '$($app.Name)' ($($app.PackageName))."
            try {
                Remove-AppxPackage -Package $app.PackageName -AllUsers -ErrorAction Stop
                $provisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app.Name }
                if ($provisionedPackage) {
                    foreach ($pkg in $provisionedPackage) { Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop }
                }
            } catch {
				Write-Warning "No se pudo desinstalar por completo '$($app.Name)'. Error: $($_.Exception.Message)"
				Write-Log -LogLevel WARN -Message "BLOATWARE: Fallo al desinstalar '$($app.Name)'. Motivo: $($_.Exception.Message)"
			}
        }
    }
    Write-Progress -Activity "Desinstalando Aplicaciones" -Completed
    Write-Host "`n[OK] Proceso de desinstalacion estandar completado." -ForegroundColor Green
	    
		if ($AppsToUninstall.Count -gt 0) {
        $userResponse = Read-Host "`n[?] ¿Deseas guardar un informe con las aplicaciones eliminadas para referencia futura? (S/N)"
	    if ($userResponse.ToUpper() -eq 'S') {
		    $parentDir = Split-Path -Parent $PSScriptRoot
            $reportDir = Join-Path -Path $parentDir -ChildPath "Reportes"
            if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory -Force | Out-Null }
            $reportFile = Join-Path -Path $reportDir -ChildPath "Reporte_Apps_Eliminadas_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"

            $reportContent = "=== Aplicaciones Desinstaladas el $(Get-Date) ==="
            $AppsToUninstall | ForEach-Object {
                $reportContent += "`n- Nombre: $($_.Name)"
                $reportContent += "`n  PackageFamilyName: $($_.PackageFamilyName)`n"
            }

            Out-File -FilePath $reportFile -InputObject $reportContent -Encoding utf8
			Write-Log -LogLevel ACTION -Message "BLOATWARE: Informe de desinstalacion guardado en '$reportFile'."
            Write-Host "[OK] Informe guardado en: '$reportFile'" -ForegroundColor Green
        }
    }
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

            Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
            Write-Host "   [Numero] Marcar/Desmarcar para eliminar"
            Write-Host "   [T] - Marcar Todos     [N] - Desmarcar Todos"
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
								Write-Log -LogLevel ACTION -Message "BLOATWARE: Carpeta de datos '$($folder.Path)' eliminada permanentemente."
                                Write-Host "[OK] Eliminado: $($folder.Path)" -ForegroundColor Green
                            } catch {
                                Write-Error "No se pudo eliminar '$($folder.Path)'. Error: $($_.Exception.Message)"
								Write-Log -LogLevel ERROR -Message "BLOATWARE: No se pudo eliminar la carpeta '$($folder.Path)'. Motivo: $($_.Exception.Message)"
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

    Write-Log -LogLevel INFO -Message "Usuario entro al Gestor de Programas de Inicio."
    
    # --- Valores binarios exactos para Habilitar/Deshabilitar en Registro ---
    $script:EnabledValue  = [byte[]](0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
    $script:DisabledValue = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)

    # --- HELPER: Escribe el estado en el registro ---
    function Set-StartupApprovedStatus {
        param($ItemName, $BaseKeyPath, $ItemType, $Action)
        try {
            $approvedKeyPath = Join-Path -Path $BaseKeyPath -ChildPath "Explorer\StartupApproved\$ItemType"
            if (-not (Test-Path $approvedKeyPath)) { New-Item -Path $approvedKeyPath -Force | Out-Null }
            $valueToSet = if ($Action -eq 'Enable') { $script:EnabledValue } else { $script:DisabledValue }
            Set-ItemProperty -Path $approvedKeyPath -Name $ItemName -Value $valueToSet -Type Binary -Force
            return $true
        } catch {
            Write-Warning "Error al establecer estado para '$ItemName': $($_.Exception.Message)"
            return $false
        }
    }

    # --- BLOQUE DE OPTIMIZACIÓN: CACHÉ INTELIGENTE ---
    $RefreshStartupCache = {
        Write-Host "Escaneando programas de inicio..." -ForegroundColor Gray
        $allItems = [System.Collections.Generic.List[psobject]]::new()
        
        # 1. PRE-CARGA DE ESTADOS DEL REGISTRO (Optimización O(1))
        # Leemos las claves de "StartupApproved" UNA sola vez y las guardamos en memoria.
        $statusCache = @{}
        $approvalPaths = @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; Type = "Run" },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"; Type = "StartupFolder" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; Type = "Run" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"; Type = "StartupFolder" }
        )

        foreach ($loc in $approvalPaths) {
            if (Test-Path $loc.Path) {
                $props = Get-ItemProperty -Path $loc.Path -ErrorAction SilentlyContinue
                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', '(Default)')) {
                        # Clave única para el cache: "Run|NombreApp"
                        $key = "$($loc.Type)|$($p.Name)"
                        $statusCache[$key] = $p.Value
                    }
                }
            }
        }

        # Helper interno para consultar el cache local
        $CheckCache = {
            param($Name, $Type)
            $key = "$Type|$Name"
            if ($statusCache.ContainsKey($key)) {
                $bytes = $statusCache[$key]
                if ($null -ne $bytes -and $bytes.Length -gt 0 -and ($bytes[0] % 2 -ne 0)) { return 'Disabled' }
            }
            return 'Enabled' # Por defecto habilitado si no existe entrada
        }

        # 2. ESCANEO DE REGISTRO (Items de Inicio)
        $regLocations = @(
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion"; ItemType = "Run" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"; ItemType = "Run" },
            @{ Path = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"; BaseKey = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion"; ItemType = "Run" }
        )

        foreach ($location in $regLocations) {
            if (Test-Path $location.Path) {
                $items = Get-ItemProperty $location.Path -ErrorAction SilentlyContinue
                foreach ($prop in $items.PSObject.Properties) {
                    if ($prop.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', '(Default)')) {
                        $allItems.Add([PSCustomObject]@{
                            Name      = $prop.Name
                            Type      = 'Registry'
                            Status    = & $CheckCache -Name $prop.Name -Type $location.ItemType
                            Command   = $prop.Value
                            Path      = $location.Path
                            BaseKey   = $location.BaseKey
                            ItemType  = $location.ItemType
                            Selected  = $false
                        })
                    }
                }
            }
        }

        # 3. ESCANEO DE CARPETAS
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
                        Status    = & $CheckCache -Name $_.Name -Type $location.ItemType
                        Command   = $_.FullName
                        Path      = $_.FullName
                        BaseKey   = $location.BaseKey
                        ItemType  = $location.ItemType
                        Selected  = $false
                    })
                }
            }
        }
        
        # 4. TAREAS PROGRAMADAS (Filtrado Optimizado)
        # Obtenemos SOLO las que tienen triggers de Logon para reducir ruido, si es posible, o filtramos post-query.
        Get-ScheduledTask | Where-Object { ($_.Triggers.TriggerType -contains 'Logon') -and ($_.TaskPath -notlike "\Microsoft\*") } | ForEach-Object {
            $action = ($_.Actions | Select-Object -First 1).Execute
            $arguments = ($_.Actions | Select-Object -First 1).Arguments
            $allItems.Add([PSCustomObject]@{
                Name     = $_.TaskName
                Type     = 'Task'
                Status   = if ($_.State -eq 'Disabled') { 'Disabled' } else { 'Enabled' }
                Command  = "$action $arguments"
                Path     = $_.TaskPath
                BaseKey  = '' 
                ItemType = ''
                Selected = $false
            })
        }
        
        return $allItems | Sort-Object @{Expression={if ($_.Status -eq 'Enabled') {0} else {1}}}, Name
    }
    # ---------------------------------------------------

    # Carga Inicial
    $startupItems = & $RefreshStartupCache
    $choice = ''

    while ($choice -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Gestion de Programas de Inicio              " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar un programa."
        Write-Host ""
        
        # Bucle de visualización (Ahora es rápido porque $startupItems ya está en memoria)
        for ($i = 0; $i -lt $startupItems.Count; $i++) {
            $item = $startupItems[$i]
            $statusMarker = if ($item.Selected) { "[X]" } else { "[ ]" }
            $statusColor = if ($item.Status -eq 'Enabled') { 'Green' } else { 'Red' }
            
            # Recortamos el nombre si es muy largo para que no rompa la tabla visual
            $displayName = if ($item.Name.Length -gt 45) { $item.Name.Substring(0, 42) + "..." } else { $item.Name }

            Write-Host ("   [{0,2}] {1} " -f ($i + 1), $statusMarker) -NoNewline
            Write-Host ("{0,-50}" -f $displayName) -NoNewline
            Write-Host ("[{0,-8}]" -f $item.Status) -ForegroundColor $statusColor
        }
        
        $selectedCount = $startupItems.Where({$_.Selected}).Count
        if ($selectedCount -gt 0) {
            Write-Host ""
            Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] Marcar/Desmarcar        [D] Deshabilitar Seleccionados"
        Write-Host "   [H] Habilitar Seleccionados      [T] Seleccionar Todos"
        Write-Host "   [R] Refrescar Lista              [N] Deseleccionar Todos"
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        $choice = (Read-Host "`nSelecciona una opcion").ToUpper()

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $startupItems.Count) {
            $index = [int]$choice - 1
            $startupItems[$index].Selected = -not $startupItems[$index].Selected
        }
        elseif ($choice -eq 'T') { $startupItems.ForEach({$_.Selected = $true}) }
        elseif ($choice -eq 'N') { $startupItems.ForEach({$_.Selected = $false}) }
        elseif ($choice -eq 'R') { $startupItems = & $RefreshStartupCache }
        elseif ($choice -eq 'D' -or $choice -eq 'H') {
            $selectedItems = $startupItems | Where-Object { $_.Selected }
            if ($selectedItems.Count -eq 0) {
                Write-Host "`n[AVISO] No se selecciono ningun programa." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                continue
            }

            foreach ($item in $selectedItems) {
                $action = if ($choice -eq 'D') { "Disable" } else { "Enable" }
                if (-not($PSCmdlet.ShouldProcess($item.Name, $action))) { continue }               
                
                try {
                    Write-Log -LogLevel ACTION -Message "INICIO: Se aplico la accion '$action' al programa '$($item.Name)'."
                    switch ($item.Type) {
                        'Registry' {
                            Set-StartupApprovedStatus -ItemName $item.Name -BaseKeyPath $item.BaseKey -ItemType $item.ItemType -Action $action
                        }
                        'Folder' {
                            Set-StartupApprovedStatus -ItemName $item.Name -BaseKeyPath $item.BaseKey -ItemType $item.ItemType -Action $action
                        }
                        'Task' {
                             if ($action -eq 'Disable') {
                                Disable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction Stop
                            } else {
                                Enable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction Stop
                            }
                        }
                    }
                    # Actualizamos el estado en memoria inmediatamente para evitar re-escanear
                    $item.Status = if ($action -eq 'Disable') { 'Disabled' } else { 'Enabled' }
                }
                catch {
                    Write-Log -LogLevel ERROR -Message "INICIO: Fallo al aplicar '$action' a '$($item.Name)'. Motivo: $($_.Exception.Message)"
                }
            }
            
            Write-Host "`n[OK] Accion completada." -ForegroundColor Green
            $startupItems.ForEach({$_.Selected = $false})
            $startupItems = $startupItems | Sort-Object @{Expression={if ($_.Status -eq 'Enabled') {0} else {1}}}, Name
            Read-Host "Presiona Enter para continuar..."

        }
    }
}

function Repair-SystemFiles {
    Write-Log -LogLevel INFO -Message "Usuario inicio la secuencia de reparacion del sistema (SFC/DISM/CHKDSK)."
    Write-Host "`n[+] Iniciando la secuencia de reparacion del sistema." -ForegroundColor Cyan
    Write-Host "Este proceso consta de varias etapas de diagnostico y reparacion." -ForegroundColor Yellow
    
    $repairsMade = $false
    $imageIsRepairable = $false
    $chkdskScheduled = $false

    # --- PASO 1: Reparar la Imagen de Windows con DISM ---
    Write-Host "`n[+] PASO 1/4: Ejecutando DISM para escanear la salud de la imagen..." -ForegroundColor Yellow
    
    $dismScanOutput = (DISM.exe /Online /Cleanup-Image /ScanHealth | Tee-Object -Variable tempOutput) -join "`n"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "DISM encontro un error durante el escaneo."
    } else {
        Write-Host "[OK] Escaneo de DISM completado." -ForegroundColor Green
        # Regex compatible con Español e Inglés
        if ($dismScanOutput -match "repairable|reparable") {
            $imageIsRepairable = $true
        }
    }

    # --- PASO 2: Reparar la imagen si es necesario ---
    if ($imageIsRepairable) {
        Write-Host "`n[+] PASO 2/4: Se detecto corrupcion. Reparando imagen con DISM..." -ForegroundColor Yellow
        Write-Log -LogLevel ACTION -Message "DISM: Almacen de componentes reparable detectado. Iniciando RestoreHealth."
        DISM.exe /Online /Cleanup-Image /RestoreHealth
        if ($LASTEXITCODE -ne 0) {
            Write-Log -LogLevel WARN -Message "DISM: RestoreHealth finalizo con un codigo de error ($LASTEXITCODE)."
            Write-Warning "DISM encontro un error y podria no haber completado la reparacion."
        } else {
            Write-Host "[OK] Reparacion de DISM completada." -ForegroundColor Green
            $repairsMade = $true
        }
    } else {
        Write-Host "`n[+] PASO 2/4: No se detecto corrupcion en la imagen. Omitiendo reparacion." -ForegroundColor Green
    }

    # --- PASO 3: Reparar Archivos del Sistema con SFC ---
    Write-Host "`n[+] PASO 3/4: Ejecutando SFC para verificar los archivos del sistema..." -ForegroundColor Yellow
    sfc.exe /scannow

    if ($LASTEXITCODE -ne 0) {
        Write-Log -LogLevel WARN -Message "SFC: Scannow finalizo con un codigo de error ($LASTEXITCODE)."
        Write-Warning "SFC encontro un error o no pudo reparar todos los archivos."
    } else {
        Write-Host "[OK] SFC ha completado su operacion." -ForegroundColor Green
        Write-Log -LogLevel ACTION -Message "REPAIR/SFC: Se encontraron y repararon archivos de sistema corruptos."
    }

    # Verificacion de reparaciones SFC
    $cbsLogPath = "$env:windir\Logs\CBS\CBS.log"
    if (Test-Path $cbsLogPath) {
        $sfcEntries = Get-Content $cbsLogPath | Select-String -Pattern "\[SR\]"
        # Regex compatible con Español e Inglés
        if ($sfcEntries -match "Repairing file|Fixed|Repaired|Reparando archivo|Reparado") {
            $repairsMade = $true
        }
    }

    # --- PASO 4 (UNIVERSAL): CHKDSK PROFUNDO ---
    Write-Host "`n[+] PASO 4/4 (OPCIONAL): Analisis Profundo de Disco (CHKDSK /r /f /b /x)" -ForegroundColor Cyan
    Write-Host "    Este comando busca sectores fisicos defectuosos y re-evalua todo el disco." -ForegroundColor Gray
    Write-Warning "Esta operacion requiere reiniciar y puede tardar VARIAS HORAS."
    Write-Warning "Durante el analisis (pantalla negra al inicio), NO podras usar el equipo."
    
    $chkdskChoice = Read-Host "`n¿Deseas programar este analisis profundo para el proximo reinicio? (S/N)"
    
    if ($chkdskChoice.ToUpper() -eq 'S') {
        try {
            Write-Host "Programando CHKDSK en unidad C:..." -ForegroundColor Yellow
            
            # --- DETECCION INTELIGENTE DE IDIOMA ---
            # Detectamos el idioma del sistema para enviar la tecla correcta (Y, S, O, J, etc.)
            $sysLang = (Get-UICulture).TwoLetterISOLanguageName.ToUpper()
            $yesKey = "Y" # Valor por defecto (Inglés y mayoría de idiomas)

            switch ($sysLang) {
                "ES" { $yesKey = "S" } # Español
                "FR" { $yesKey = "O" } # Francés (Oui)
                "DE" { $yesKey = "J" } # Alemán (Ja)
                "IT" { $yesKey = "S" } # Italiano (Si)
                "PT" { $yesKey = "S" } # Portugués (Sim)
            }
            # ---------------------------------------

            # Ejecutamos con la tecla detectada
            $result = cmd.exe /c "echo $yesKey | chkdsk C: /f /r /b /x" 2>&1
            
            # Validación robusta: Código 0 o mensaje de éxito en ES o EN
            if ($LASTEXITCODE -eq 0 -or $result -match "se comprobar|checked the next time") {
                Write-Host "[OK] CHKDSK programado exitosamente ($sysLang detected -> '$yesKey')." -ForegroundColor Green
                Write-Log -LogLevel ACTION -Message "REPAIR: Se programo CHKDSK /f /r /b  /x para el proximo reinicio (Idioma: $sysLang)."
                $chkdskScheduled = $true
                $repairsMade = $true 
            } else {
                Write-Error "No se pudo programar CHKDSK. Windows devolvio:`n$result"
            }
        } catch {
            Write-Error "Error al invocar CHKDSK: $($_.Exception.Message)"
        }
    } else {
        Write-Host "   - Analisis de disco omitido por el usuario." -ForegroundColor Gray
    }

    # --- Conclusion ---
    Write-Host "`n[+] Secuencia de reparacion completada." -ForegroundColor Green
    
    if ($repairsMade -or $chkdskScheduled) {
        $msg = if ($chkdskScheduled) { 
            "Se ha programado un analisis de disco. El equipo se reiniciara y comenzara el analisis." 
        } else { 
            "Se realizaron reparaciones en el sistema. Se recomienda reiniciar." 
        }
        
        Write-Host "[RECOMENDACIoN] $msg" -ForegroundColor Cyan
        $choice = Read-Host "`n¿Deseas reiniciar ahora? (S/N)"
        if ($choice.ToUpper() -eq 'S') {
            Write-Host "Reiniciando el sistema en 60 segundos..." -ForegroundColor Yellow
            Start-Sleep -Seconds 60
            Restart-Computer -Force
        }
    } else {
        Write-Host "[INFO] No se detectaron problemas criticos que requieran reinicio inmediato." -ForegroundColor Green
    }

    Read-Host "`nPresiona Enter para volver..."
}
function Clear-RAMCache {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
	Write-Log -LogLevel INFO -Message "Usuario entro a la funcion de purgado de cache de RAM."

    Write-Host "`n[+] Purgando la Memoria RAM en Cache (Standby List)..." -ForegroundColor Cyan
    Write-Warning "Esto es para usos especificos (como benchmarks) y normalmente no es necesario."
    
    if ((Read-Host "¿Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') {
		Write-Log -LogLevel WARN -Message "Usuario cancelo el purgado de cache de RAM."
        Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
        return
    }

    # Ruta donde se guardara la herramienta
    $toolDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath "Tools"
    if (-not (Test-Path $toolDir)) {
        New-Item -Path $toolDir -ItemType Directory | Out-Null
    }
    $toolPath = Join-Path -Path $toolDir -ChildPath "EmptyStandbyList.exe"

    # Descargar la herramienta si no existe
    if (-not (Test-Path $toolPath)) {
        Write-Host "`n[+] La herramienta 'EmptyStandbyList.exe' no se ha encontrado." -ForegroundColor Yellow
        Write-Host "    Descargando desde una fuente confiable (Archive)..."
        $url = "https://ia800303.us.archive.org/9/items/empty-standby-list/EmptyStandbyList.exe"
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $toolPath -UseBasicParsing
            Write-Host "[OK] Herramienta descargada." -ForegroundColor Green
        } catch {
            Write-Error "No se pudo descargar la herramienta. Verifica tu conexion a internet o si un antivirus la esta bloqueando."
            Write-Error "Error especifico: $_"
			Write-Log -LogLevel ERROR -Message "Fallo la descarga de EmptyStandbyList.exe: $_"
            Read-Host "`nPresiona Enter para volver al menu..."
            return
        }
    }

    # Ejecutar la herramienta para limpiar la cache de la Standby List
    if ($PSCmdlet.ShouldProcess("Sistema", "Purgar la lista de memoria en espera (Standby List)")) {
        try {
            # Usamos -WindowStyle Hidden para que no haya un parpadeo de una ventana negra
            Start-Process -FilePath $toolPath -ArgumentList "standbylist" -Verb RunAs -Wait -WindowStyle Hidden
            Write-Log -LogLevel ACTION -Message "La memoria en cache (Standby List) fue purgada exitosamente."
			Write-Host "`n[OK] La memoria en cache (Standby List) ha sido purgada." -ForegroundColor Green
			Read-Host "`nPresiona Enter para volver al menu..."
        } catch {
            Write-Error "Ocurrio un error al ejecutar la herramienta. El archivo puede estar corrupto o bloqueado por un antivirus."
            Write-Error "Error especifico: $_"
            Read-Host "`nPresiona Enter para volver al menu..."
        }
    }
}

function Clear-SystemCaches {
    Clear-Host
	Write-Log -LogLevel INFO -Message "CACHES: Usuario inicio la limpieza de caches del sistema."
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "                  Limpiando Caches del Sistema" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan

    Invoke-FlushDnsCache -Force
	Write-Log -LogLevel ACTION -Message "CACHES: Cache de DNS limpiada."

    Write-Host "`n[+] Limpiando cache de la Tienda de Windows..." -ForegroundColor Cyan
    wsreset.exe -q
    if ($LASTEXITCODE -eq 0) {
		Write-Host "   [OK] Cache de la Tienda limpiada." -ForegroundColor Green
		Write-Log -LogLevel ACTION -Message "CACHES: Cache de la Tienda de Windows limpiada."
		} else {
			Write-Error "   [FALLO] No se pudo limpiar la cache de la Tienda."
		}

    Write-Host "`n[+] Limpiando cache de iconos..." -ForegroundColor Cyan
    try {
        Stop-Process -Name explorer -Force -ErrorAction Stop
        $iconCachePath = "$env:LOCALAPPDATA\IconCache.db"
        if (Test-Path $iconCachePath) {
            Remove-Item $iconCachePath -Force -ErrorAction Stop
            Write-Host "   [OK] Cache de iconos eliminada." -ForegroundColor Green
			Write-Log -LogLevel ACTION -Message "CACHES: Cache de iconos eliminada."
        } else {
            Write-Host "   [INFO] No se encontro el archivo de cache de iconos." -ForegroundColor Yellow
        }
    } catch {
        Write-Error "   [FALLO] No se pudo limpiar la cache de iconos. Error: $($_.Exception.Message)"
    } finally {
        Start-Process explorer.exe
    }

    Write-Host "`n[EXITO] Proceso de limpieza de caches finalizado." -ForegroundColor Green
	Read-Host "`nPresiona Enter para volver al menu..."
}

function Optimize-Drives {
	Write-Log -LogLevel INFO -Message "Usuario inicio la optimizacion de unidades."
    $drive = Get-Volume -DriveLetter C
    if ($drive.DriveType -eq "SSD") {
        Optimize-Volume -DriveLetter C -ReTrim -Verbose
		Write-Log -LogLevel ACTION -Message "Optimizando unidad C: via ReTrim (SSD)."
    }
    else {
        Optimize-Volume -DriveLetter C -Defrag -Verbose
		Write-Log -LogLevel ACTION -Message "Optimizando unidad C: via Defrag (HDD)."
    }
}

function Generate-SystemReport {
	$parentDir = Split-Path -Parent $PSScriptRoot
	$diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
    
	if (-not (Test-Path $diagDir)) {
		New-Item -Path $diagDir -ItemType Directory | Out-Null
    }
    
    $reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Salud_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').html"
    Write-Log -LogLevel INFO -Message "Generando reporte de energia del sistema."
    powercfg /energy /output $reportPath /duration 60
    
    if (Test-Path $reportPath) {
        Write-Host "[OK] Reporte generado en: '$reportPath'" -ForegroundColor Green
        Start-Process $reportPath
	} else {
     	Write-Error "No se pudo generar el reporte."
    }
		
	Read-Host "`nPresiona Enter para volver..."
}

# ===================================================================
# --- MoDULO DE DIAGNoSTICO Y REPARACIoN DE RED ---
# ===================================================================
function Invoke-ShowIpConfig {
    Write-Host "`n[+] Mostrando configuracion de red detallada (ipconfig /all)..." -ForegroundColor Cyan
    ipconfig.exe /all
    Read-Host "`nPresiona Enter para continuar..."
}

function Invoke-PingTest {
    Write-Host "`n[+] Realizando prueba de conectividad a los servidores DNS de Google (8.8.8.8)..." -ForegroundColor Cyan
    Test-NetConnection -ComputerName "8.8.8.8" -WarningAction SilentlyContinue
    Read-Host "`nPresiona Enter para continuar..."
}

function Invoke-DnsResolutionTest {
    Write-Host "`n[+] Realizando prueba de resolucion de nombres de dominio (google.com)..." -ForegroundColor Cyan
    Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue | Format-Table
    Read-Host "`nPresiona Enter para continuar..."
}

function Invoke-TraceRoute {
    Write-Host "`n[+] Trazando la ruta de red hacia 8.8.8.8 (puede tardar un momento)..." -ForegroundColor Cyan
    Test-NetConnection -ComputerName "8.8.8.8" -TraceRoute -WarningAction SilentlyContinue
    Read-Host "`nPresiona Enter para continuar..."
}

function Invoke-FlushDnsCache {
    param([switch]$Force) # Anadimos el parametro -Force

    Write-Host "`n[+] Limpiando la cache de resolucion de DNS..." -ForegroundColor Cyan
    
    # Si se usa -Force O el usuario confirma, procedemos.
    if ($Force -or (Read-Host "Estas seguro de que deseas continuar? (S/N)").ToUpper() -eq 'S') {
        ipconfig.exe /flushdns
        # --- VERIFICACION DE EXITO ---
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Cache de DNS limpiada exitosamente." -ForegroundColor Green
        } else {
            Write-Error "FALLO: El comando para limpiar la cache de DNS no se completo correctamente."
        }
    } else {
        Write-Host "[INFO] Operacion cancelada." -ForegroundColor Yellow
    }

    # Si no se usa -Force, pausamos. Si se usa, continuamos sin pausa.
    if (-not $Force) {
        Read-Host "`nPresiona Enter para continuar..."
    }
}

function Invoke-RenewIpAddress {
    Write-Host "`n[+] Liberando y renovando la direccion IP..." -ForegroundColor Cyan
    if ((Read-Host "Estas seguro de que deseas continuar? (S/N)").ToUpper() -eq 'S') {
        $releaseSuccess = $false
        $renewSuccess = $false
        
        Write-Host " - Liberando IP actual (ipconfig /release)..." -ForegroundColor Gray
        ipconfig.exe /release
        # --- VERIFICACION DE EXITO ---
        if ($LASTEXITCODE -eq 0) { $releaseSuccess = $true }

        Write-Host " - Solicitando nueva IP (ipconfig /renew)..." -ForegroundColor Gray
        ipconfig.exe /renew
        # --- VERIFICACION DE EXITO ---
        if ($LASTEXITCODE -eq 0) { $renewSuccess = $true }

        if ($releaseSuccess -and $renewSuccess) {
            Write-Host "[OK] Proceso de renovacion de IP completado." -ForegroundColor Green
        } else {
            Write-Error "FALLO: Una o mas operaciones de renovacion de IP no se completaron correctamente."
        }
    } else {
        Write-Host "[INFO] Operacion cancelada." -ForegroundColor Yellow
    }
    Read-Host "`nPresiona Enter para continuar..."
}

function Invoke-ResetNetworkStacks {
    Write-Host "`n[+] Restableciendo la Pila de Red (Winsock y TCP/IP)..." -ForegroundColor Red
    Write-Warning "ADVERTENCIA! Esta accion requiere reiniciar el equipo para completarse."
    if ((Read-Host "Estas seguro de que deseas continuar? (S/N)").ToUpper() -eq 'S') {
        $winsockSuccess = $false
        $tcpSuccess = $false
        $errorStrings = @("Error", "Failed", "Acceso denegado", "Access denied")

        Write-Host " - Restableciendo el catalogo de Winsock..." -ForegroundColor Gray
        # Capturamos toda la salida (estandar y error)
        $winsockOutput = netsh.exe winsock reset 2>&1
        
        # Verificamos el codigo de salida Y que no haya texto de error
        if ($LASTEXITCODE -eq 0 -and ($winsockOutput -notmatch ($errorStrings -join '|'))) {
            $winsockSuccess = $true
        } else {
            Write-Warning "  -> Salida de Winsock: $winsockOutput"
        }

        Write-Host " - Restableciendo la pila TCP/IP..." -ForegroundColor Gray
        $tcpOutput = netsh.exe int ip reset 2>&1
        
        if ($LASTEXITCODE -eq 0 -and ($tcpOutput -notmatch ($errorStrings -join '|'))) {
            $tcpSuccess = $true
        } else {
            Write-Warning "  -> Salida de TCP/IP: $tcpOutput"
        }

        if ($winsockSuccess -and $tcpSuccess) {
            Write-Host "[OK] Pila de red restablecida. Por favor, reinicia tu equipo." -ForegroundColor Green
        } else {
            Write-Error "FALLO: Uno o mas comandos de restablecimiento de red no se completaron correctamente. Revisa la salida."
        }
    } else {
        Write-Host "[INFO] Operacion cancelada." -ForegroundColor Yellow
    }
    Read-Host "`nPresiona Enter para continuar..."
}

# --- Funcion del Menu Principal del Modulo de Red ---
function Show-NetworkDiagnosticsMenu {
    $netChoice = ''
    do {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "          Modulo de Diagnostico y Reparacion de Red    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        
        Write-Host "Comprobando estado de la conexion..." -ForegroundColor Gray
        if (Test-NetConnection -ComputerName "1.1.1.1" -InformationLevel Quiet -WarningAction SilentlyContinue) {
            Write-Host "Estado de la Conexion: " -NoNewline
			Write-Host "CONECTADO A INTERNET" -ForegroundColor Green
        } else {
            Write-Host "Estado de la Conexion: " -NoNewline
			Write-Host "SIN CONEXION A INTERNET" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "--- Acciones de Diagnostico ---" -ForegroundColor Yellow
        Write-Host "   [1] Ver configuracion IP detallada (ipconfig /all)"
        Write-Host "   [2] Probar conectividad a Internet (ping)"
        Write-Host "   [3] Probar resolucion de DNS (nslookup)"
        Write-Host "   [4] Trazar ruta de red (tracert)"
        Write-Host ""
        Write-Host "--- Acciones de Reparacion ---" -ForegroundColor Red
        Write-Host "   [5] Limpiar cache de DNS"
        Write-Host "   [6] Renovar concesion de IP"
        Write-Host "   [7] Restablecer la Pila de Red (Requiere Reinicio)"
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $netChoice = Read-Host "Selecciona una opcion"
        Write-Log -LogLevel INFO -Message "NETWORK: Usuario selecciono la opcion '$netChoice'."
		
        switch ($netChoice.ToUpper()) {
            '1' { Invoke-ShowIpConfig }
            '2' { Invoke-PingTest }
            '3' { Invoke-DnsResolutionTest }
            '4' { Invoke-TraceRoute }
            '5' { Invoke-FlushDnsCache }
            '6' { Invoke-RenewIpAddress }
            '7' { Invoke-ResetNetworkStacks }
            'V' { continue }
            default { Write-Warning "Opcion no valida." ; Start-Sleep -Seconds 2 }
        }
    } while ($netChoice.ToUpper() -ne 'V')
}

# ===================================================================
# --- MODULO DE ANALIZADOR DE REGISTROS DE EVENTOS ---
# ===================================================================
function Show-EventLogAnalyzerMenu {
    [CmdletBinding()]
    param()
    Write-Log -LogLevel INFO -Message "EVENTLOG: Usuario entro al Analizador Inteligente de Registros de Eventos."
    
    $logChoice = ''
    do {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "      Analizador Inteligente de Registros de Eventos    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Escaneo Rapido de Eventos Criticos (ultimas 24h)"
        Write-Host "       (Detecta automaticamente patrones de problemas comunes)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [2] Analisis Profundo Personalizado" -ForegroundColor Green
        Write-Host "       (Filtra eventos por severidad, origen, fecha y palabras clave)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Generar Reporte HTML Completo" -ForegroundColor Cyan
        Write-Host "       (Reporte interactivo con busqueda, filtrado y secciones organizadas)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Buscar Soluciones para Errores Comunes"
        Write-Host "       (Base de datos integrada de soluciones para errores frecuentes de Windows)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [5] Monitoreo en Tiempo Real (Experimental)"
        Write-Host "       (Observa eventos mientras trabajas y alerta en problemas criticos)" -ForegroundColor Red
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        $logChoice = Read-Host "Selecciona una opcion"
        switch ($logChoice.ToUpper()) {
            '1' { Invoke-QuickEventScan }
            '2' { Invoke-AdvancedEventAnalysis }
            '3' { Generate-ComprehensiveHtmlReport }
            '4' { Search-EventSolutions }
            '5' { Start-RealTimeMonitoring }
            'V' { continue }
            default { 
                Write-Warning "Opcion no valida." 
                Start-Sleep -Seconds 1
            }
        }
    } while ($logChoice.ToUpper() -ne 'V')
}

# --- FUNCIoN 1: Escaneo Rapido de Eventos Criticos ---
function Invoke-QuickEventScan {
    Clear-Host
    Write-Host "`n[+] Ejecutando escaneo rapido de eventos criticos..." -ForegroundColor Yellow
    
    $startTime = (Get-Date).AddDays(-1)
    $detectedIssues = @()
    
    $problemPatterns = @{
        "Disk Errors" = @("disk", "harddisk", "volume", "bad block", "disk reset", "controller error", "disk failure", "disk corruption")
        "Driver Issues" = @("driver_irql_not_less_or_equal", "driver_power_state_failure", "nvlddmkm", "atikmdag", "amdkmdag", "intelppm", "dxgkrnl", "nvlddm")
        "Memory Problems" = @("memory_management", "page fault", "pool corruption", "memory leak", "bad_pool_header", "pool_nx_fault", "page_not_zero")
        "Network Failures" = @("tcpip", "dns", "dhcp", "network adapter", "connection reset", "network link", "ip address", "gateway")
        "Startup Failures" = @("service control manager", "group policy client", "logonui", "winlogon", "shell infrastructure", "appx deployment", "appx staging")
        "Application Crashes" = @("application error", "application hang", "faulting module", "exception code", "stopped working", "exception information", "error code")
        "System Freezes" = @("dpc watchdog violation", "whea_uncorrectable_error", "system thread exception", "critical process died", "system service exception")
    }
    
    # Definir que logs y niveles de severidad analizar
    $eventFilters = @(
        @{LogName="System"; Level=@(1,2); Hours=24},
        @{LogName="Application"; Level=@(1,2); Hours=24},
        @{LogName="Security"; ProviderName="Microsoft-Windows-Security-Auditing"; Keywords=[uint64]"0x8020000000000000"} # Fallos de inicio de sesion
    )
    
    foreach ($eventFilter in $eventFilters) {
        try {
            $filterHashtable = @{
                LogName = $eventFilter.LogName
                StartTime = $startTime
            }
            
            if ($eventFilter.Level) {
                $filterHashtable.Add("Level", $eventFilter.Level)
            }
            
            $events = Get-WinEvent -FilterHashtable $filterHashtable -MaxEvents 100 -ErrorAction SilentlyContinue
            
            if ($events) {
                foreach ($event in $events) {
                    $eventText = $event.Message.ToLower()
                    $eventTime = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    $eventId = $event.Id
                    $eventSource = $event.ProviderName
                    
                    # Buscar patrones de problemas comunes
                    foreach ($patternName in $problemPatterns.Keys) {
                        foreach ($keyword in $problemPatterns[$patternName]) {
                            if ($eventText -like "*$keyword*") {
                                $detectedIssues += [PSCustomObject]@{
                                    Time = $eventTime
                                    Type = $patternName
                                    Source = $eventSource
                                    Id = $eventId
                                    Message = ($event.Message -split "`r`n")[0]
                                    Details = $event.Message
                                    Log = $eventFilter.LogName
                                    EventObject = $event
                                }
                                break
                            }
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "No se pudieron obtener eventos del log $($eventFilter.LogName): $($_.Exception.Message)"
        }
    }
    
    # Mostrar resultados
    Clear-Host
    if ($detectedIssues.Count -gt 0) {
        Write-Host "`n[!] PROBLEMAS DETECTADOS EN LAS uLTIMAS 24 HORAS:" -ForegroundColor Red
        Write-Host "    Se encontraron $($detectedIssues.Count) eventos criticos que requieren atencion." -ForegroundColor Yellow
        
        $issuesByType = $detectedIssues | Group-Object Type | Sort-Object Count -Descending
        foreach ($issueGroup in $issuesByType) {
            $color = if ($issueGroup.Count -gt 5) { "Red" } elseif ($issueGroup.Count -gt 2) { "Yellow" } else { "Cyan" }
            Write-Host "`n=== $($issueGroup.Name) ($($issueGroup.Count) eventos) ===" -ForegroundColor $color
            
            $relevantEvents = $issueGroup.Group | Select-Object -First 3
            foreach ($event in $relevantEvents) {
                Write-Host "   [$($event.Time)] $($event.Source) (ID: $($event.Id))" -ForegroundColor Gray
                Write-Host "   $($event.Message)" -ForegroundColor White
            }
            
            if ($issueGroup.Count -gt 3) {
                Write-Host "   ... y $($issueGroup.Count - 3) eventos mas del mismo tipo." -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n[+] Recomendacion:" -ForegroundColor Yellow
        $topIssue = $issuesByType[0].Name
        switch ($topIssue) {
            "Disk Errors" { Write-Host "   Ejecuta un analisis de disco con 'chkdsk /f' y revisa la salud del S.M.A.R.T." -ForegroundColor Cyan }
            "Driver Issues" { Write-Host "   Actualiza los controladores, especialmente de video y chipset." -ForegroundColor Cyan }
            "Memory Problems" { Write-Host "   Ejecuta Windows Memory Diagnostic para verificar problemas de RAM." -ForegroundColor Cyan }
            "Network Failures" { Write-Host "   Reinicia tu router y actualiza los controladores de red." -ForegroundColor Cyan }
            "Startup Failures" { Write-Host "   Ejecuta 'sfc /scannow' para reparar archivos del sistema." -ForegroundColor Cyan }
            "Application Crashes" { Write-Host "   Actualiza las aplicaciones problematicas y busca actualizaciones de Windows." -ForegroundColor Cyan }
            "System Freezes" { Write-Host "   Verifica la temperatura del hardware y actualiza BIOS/controladores." -ForegroundColor Cyan }
            default { Write-Host "   Revisa los eventos detallados y considera buscar soluciones especificas." -ForegroundColor Cyan }
        }
    }
    else {
        Write-Host "`n[OK] No se detectaron problemas criticos en el ultimo dia." -ForegroundColor Green
        Write-Host "    Tu sistema parece estar funcionando correctamente." -ForegroundColor Gray
    }
    
    # Opcion para generar un reporte detallado
    if ($detectedIssues.Count -gt 0) {
        $exportChoice = Read-Host "`n¿Deseas exportar los resultados a un reporte detallado? (S/N)"
        if ($exportChoice.ToUpper() -eq 'S') {
            Export-DetailedEventReport -Events $detectedIssues
        }
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIoN 2: Analisis Profundo Personalizado ---
function Invoke-AdvancedEventAnalysis {
    Clear-Host
    Write-Host "`n[+] Analisis Profundo Personalizado de Registros de Eventos" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------"
    
    # Parametros de analisis
    $params = @{
        LogName = "System"  # Valor por defecto
        Level = @(1,2,3)    # Critico, Error, Advertencia
        Hours = 24
        Keywords = "*"
        ProviderName = "*"
    }
    
    # Seleccionar log
    Write-Host "`n[1/5] Selecciona el Log a analizar:"
    Write-Host "   [1] System (eventos del sistema)"
    Write-Host "   [2] Application (eventos de aplicaciones)"
    Write-Host "   [3] Security (eventos de seguridad)"
    Write-Host "   [4] Setup (eventos de instalacion)"
    Write-Host "   [5] ForwardedEvents (eventos reenviados)"
    $logChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $logChoice = if ([string]::IsNullOrWhiteSpace($logChoice)) { "1" } else { $logChoice }
    
    switch ($logChoice) {
        "2" { $params.LogName = "Application" }
        "3" { $params.LogName = "Security" }
        "4" { $params.LogName = "Setup" }
        "5" { $params.LogName = "ForwardedEvents" }
        default { $params.LogName = "System" }
    }
    
    # Seleccionar nivel de severidad
    Write-Host "`n[2/5] Selecciona niveles de severidad:"
    Write-Host "   [1] Solo Criticos (nivel 1)"
    Write-Host "   [2] Criticos y Errores (niveles 1-2)"
    Write-Host "   [3] Criticos, Errores y Advertencias (niveles 1-3)"
    Write-Host "   [4] Todos los niveles"
    $levelChoice = Read-Host "Elige una opcion (por defecto: 2)"
    $levelChoice = if ([string]::IsNullOrWhiteSpace($levelChoice)) { "2" } else { $levelChoice }
    
    switch ($levelChoice) {
        "1" { $params.Level = @(1) }
        "3" { $params.Level = @(1,2,3) }
        "4" { $params.Level = $null } # Todos los niveles
        default { $params.Level = @(1,2) }
    }
    
    # Seleccionar periodo de tiempo
    Write-Host "`n[3/5] Selecciona el periodo de tiempo:"
    Write-Host "   [1] ultima hora"
    Write-Host "   [2] ultimas 24 horas (por defecto)"
    Write-Host "   [3] ultimos 7 dias"
    Write-Host "   [4] Personalizado (en horas)"
    $timeChoice = Read-Host "Elige una opcion (por defecto: 2)"
    $timeChoice = if ([string]::IsNullOrWhiteSpace($timeChoice)) { "2" } else { $timeChoice }
    
    switch ($timeChoice) {
        "1" { $params.Hours = 1 }
        "3" { $params.Hours = 168 } # 7 dias
        "4" { 
            $customHours = Read-Host "Introduce el numero de horas para analizar"
            $params.Hours = if ($customHours -match '^\d+$' -and [int]$customHours -gt 0) { [int]$customHours } else { 24 }
        }
        default { $params.Hours = 24 }
    }
    
    # Filtro por origen
    Write-Host "`n[4/5] Filtro por origen (opcional):"
    Write-Host "   Ejemplos: 'disk', 'service', 'Microsoft-Windows-*', '*nvlddmkm*'"
    $providerFilter = Read-Host "Introduce filtro de origen (dejar en blanco para todos)"
    if (-not [string]::IsNullOrWhiteSpace($providerFilter)) {
        $params.ProviderName = $providerFilter
    }
    
    # Filtro por palabras clave
    Write-Host "`n[5/5] Filtro por palabras clave en mensaje (opcional):"
    Write-Host "   Ejemplos: 'error', 'fail*', '*memory*', 'service'"
    $keywordFilter = Read-Host "Introduce palabras clave (dejar en blanco para mostrar todos)"
    
    # Ejecutar analisis
    $startTime = (Get-Date).AddHours(-$params.Hours)
    Write-Host "`n[+] Buscando eventos desde $startTime..." -ForegroundColor Yellow
    
    $filterHashtable = @{
        LogName = $params.LogName
        StartTime = $startTime
    }
    
    if ($params.Level) { $filterHashtable.Add("Level", $params.Level) }
    if ($params.ProviderName -ne "*") { $filterHashtable.Add("ProviderName", $params.ProviderName) }
    
    try {
        Write-Host "   - Obteniendo eventos del registro..." -ForegroundColor Gray
        $events = Get-WinEvent -FilterHashtable $filterHashtable -MaxEvents 1000 -ErrorAction Stop
        
        if ($keywordFilter) {
            Write-Host "   - Aplicando filtro de texto: '$keywordFilter'..." -ForegroundColor Gray
            $events = $events | Where-Object { $_.Message -like "*$keywordFilter*" }
        }
        
        $events = $events | Sort-Object TimeCreated -Descending
        $totalEventsFound = $events.Count
        
        if ($totalEventsFound -eq 0) {
            Write-Host "`n[INFO] No se encontraron eventos que coincidan con los criterios de busqueda." -ForegroundColor Green
        }
        else {
            Write-Host "`n[OK] Se encontraron $totalEventsFound eventos." -ForegroundColor Green
            
            # Mostrar resultados paginados
            $pageSize = 10
            $currentPage = 0
            $totalPages = [math]::Ceiling($totalEventsFound / $pageSize)
            $selectedEvents = @()
            
            do {
                Clear-Host
                Write-Host "`n[+] RESULTADOS DEL ANaLISIS ($totalEventsFound eventos encontrados)" -ForegroundColor Cyan
                Write-Host "    Mostrando pagina $($currentPage + 1) de $totalPages" -ForegroundColor Gray
                
                $startIndex = $currentPage * $pageSize
                $endIndex = [math]::Min($startIndex + $pageSize - 1, $totalEventsFound - 1)
                
                for ($i = $startIndex; $i -le $endIndex; $i++) {
                    $event = $events[$i]
                    $severityColor = switch ($event.Level) {
                        1 { "Red" }     # Critico
                        2 { "Red" }     # Error
                        3 { "Yellow" }  # Advertencia
                        4 { "Gray" }    # Informacion
                        default { "White" }
                    }
                    
                    $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    $source = $event.ProviderName
                    $id = $event.Id
                    $message = ($event.Message -split "`r`n")[0]
                    
                    Write-Host "`n[$($i+1)] [$time] [$source] (ID: $id)" -ForegroundColor $severityColor
                    Write-Host "    $message" -ForegroundColor White
                }
                
                if ($totalPages -gt 1) {
                    Write-Host "`n[Navegacion] [S] Siguiente pagina  [A] Anterior pagina  [M] Marcar eventos  [T] Todas las paginas  [V] Volver" -ForegroundColor Cyan
                } else {
                    Write-Host "`n[Navegacion] [M] Marcar eventos  [V] Volver" -ForegroundColor Cyan
                }
                
                $navChoice = Read-Host "Elige una opcion"
                
                switch ($navChoice.ToUpper()) {
                    "S" { if ($currentPage -lt $totalPages - 1) { $currentPage++ } }
                    "A" { if ($currentPage -gt 0) { $currentPage-- } }
                    "T" { $pageSize = $totalEventsFound; $totalPages = 1 } # Mostrar todos
                    "M" {
                        $selection = Read-Host "Introduce los numeros de los eventos a marcar (separados por comas, ej: 1,3,5)"
                        $indices = $selection -split ',' | ForEach-Object { $_.Trim() }
                        
                        foreach ($index in $indices) {
                            if ($index -match '^\d+$' -and [int]$index -ge 1 -and [int]$index -le $totalEventsFound) {
                                $actualIndex = [int]$index - 1
                                $selectedEvents += $events[$actualIndex]
                            }
                        }
                        
                        if ($selectedEvents.Count -gt 0) {
                            Write-Host "`nSe han marcado $($selectedEvents.Count) eventos para exportacion." -ForegroundColor Green
                        }
                    }
                    "V" { break }
                }
            } while ($navChoice.ToUpper() -ne 'V')
            
            # Opcion para exportar resultados
            if ($totalEventsFound -gt 0) {
                Write-Host ""
                $exportOptions = @()
                if ($selectedEvents.Count -gt 0) {
                    $exportOptions += "   [S] Exportar SOLO los eventos marcados ($($selectedEvents.Count))"
                }
                $exportOptions += "   [T] Exportar TODOS los eventos encontrados ($totalEventsFound)"
                $exportOptions += "   [N] No exportar"
                
                Write-Host ($exportOptions -join "`n") -ForegroundColor Gray
                $exportChoice = Read-Host "`n¿Deseas exportar estos resultados a un archivo? (S/T/N)"
                
                if ($exportChoice.ToUpper() -eq 'S' -and $selectedEvents.Count -gt 0) {
                    Export-EventResults -Events $selectedEvents -FileNamePrefix "Eventos_Seleccionados"
                }
                elseif ($exportChoice.ToUpper() -eq 'T') {
                    Export-EventResults -Events $events -FileNamePrefix "Eventos_Completos"
                }
            }
        }
    }
    catch {
        Write-Error "No se pudieron recuperar los eventos. Error: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "Error al obtener eventos: $($_.Exception.Message)"
        Read-Host "`nPresiona Enter para continuar"
    }
}

# --- FUNCIoN 3: Generar Reporte HTML Completo ---
function Generate-ComprehensiveHtmlReport {
    Clear-Host
    Write-Host "`n[+] Generando Reporte HTML Completo de Registros de Eventos..." -ForegroundColor Cyan
    
    $startTime = (Get-Date).AddDays(-30)
    $reportData = @{
        SystemCritical = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=$startTime} -MaxEvents 50 -ErrorAction SilentlyContinue
        SystemErrors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$startTime} -MaxEvents 50 -ErrorAction SilentlyContinue
        ApplicationErrors = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=$startTime} -MaxEvents 50 -ErrorAction SilentlyContinue
        SecurityFailures = Get-WinEvent -FilterHashtable @{LogName='Security'; Keywords=[uint64]"0x8020000000000000"; StartTime=$startTime} -MaxEvents 50 -ErrorAction SilentlyContinue
    }
    
    # Calcular estadisticas
    $totalEvents = 0
    $eventCounts = @{}
    foreach ($key in $reportData.Keys) {
        $count = if ($reportData[$key]) { $reportData[$key].Count } else { 0 }
        $eventCounts[$key] = $count
        $totalEvents += $count
    }
    
    # Generar HTML
    $parentDir = Split-Path -Parent $PSScriptRoot
    $reportDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    $reportPath = Join-Path -Path $reportDir -ChildPath "Reporte_Eventos_Completo_$timestamp.html"
    
    # CSS y JavaScript para el reporte interactivo (Unificado con Inventario)
    $css = @"
    <style>
        :root { 
            --bg-color: #f4f7f9;
            --main-text-color: #2c3e50;
            --primary-color: #2980b9;
            --secondary-color: #34495e;
            --card-bg-color: #ffffff;
            --header-text-color: #ecf0f1;
            --border-color: #dfe6e9;
            --danger-color: #c0392b;
            --warning-color: #f39c12;
            --shadow: 0 5px 15px rgba(0,0,0,0.08);
        }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: var(--main-text-color); background-color: var(--bg-color); max-width: 1400px; margin: auto; padding: 20px; }
        .header { background: linear-gradient(135deg, var(--secondary-color) 0%, var(--primary-color) 100%); color: var(--header-text-color); padding: 30px; border-radius: 8px; margin-bottom: 30px; box-shadow: var(--shadow); }
        h1, h2 { margin: 0; font-weight: 600; }
        h1 { font-size: 2.8em; display: flex; align-items: center; } h1 i { margin-right: 15px; }
        h2 { color: var(--secondary-color); border-bottom: 2px solid var(--border-color); padding-bottom: 10px; margin: 0 0 20px 0; font-size: 1.8em; display: flex; align-items: center; } h2 i { margin-right: 10px; color: var(--primary-color); }
        .timestamp { font-size: 1em; opacity: 0.9; margin-top: 5px; }
        .section { background-color: var(--card-bg-color); border-radius: 8px; padding: 25px; margin-bottom: 25px; box-shadow: var(--shadow); }
        
        .summary {
            background-color: #e3f2fd;
            border-left: 4px solid var(--primary-color);
            padding: 15px;
            margin-bottom: 25px;
            border-radius: 0 8px 8px 0;
        }
        .category {
            background: var(--card-bg-color);
            border-radius: 8px;
            box-shadow: var(--shadow);
            margin-bottom: 25px;
            overflow: hidden;
        }
        .category-header {
            background: var(--primary-color);
            color: white;
            padding: 12px 20px;
            font-weight: bold;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .category-header.critical { background: var(--danger-color); }
        .category-header.error { background: var(--warning-color); color: var(--main-text-color); }
        .category-header.security { background: #9b59b6; }
        .event-list { padding: 0 15px; }

        .event {
            border-bottom: 1px solid var(--border-color);
            padding: 12px 0;
            transition: background-color 0.2s;
        }
        .event:hover {
            background-color: #f1f5f8;
        }
        .event-time {
            color: #7f8c8d;
            font-size: 14px;
            margin-bottom: 4px;
        }
        .event-source {
            font-weight: bold;
            color: var(--main-text-color);
        }
        .event-id {
            color: #7f8c8d;
            margin-left: 10px;
        }
        .event-message {
            margin-top: 5px;
            line-height: 1.4;
            color: var(--main-text-color);
        }
        .search-box {
            margin: 20px 0;
            text-align: right;
        }
        .search-box input {
            padding: 10px 15px;
            width: 98%;
            border: 1px solid var(--border-color);
            border-radius: 5px;
            font-size: 1em;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            color: #7f8c8d;
            font-size: 0.8em;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .stat-card {
            background: var(--card-bg-color);
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .stat-number {
            font-size: 28px;
            font-weight: bold;
            margin: 5px 0;
        }
        .stat-critical { color: var(--danger-color); }
        .stat-error { color: var(--warning-color); }
        .stat-security { color: #9b59b6; }
        .stat-total { color: var(--main-text-color); }

        /* --- INICIO: CSS de Barra de Navegacion --- */
        .navbar {
            background-color: var(--secondary-color);
            overflow: visible;
            position: sticky;
            top: 0;
            width: 100%;
            z-index: 1000;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            padding: 8px 5px;
        }
        .navbar a {
            color: var(--header-text-color);
            background-color: var(--primary-color);
            text-align: center;
            padding: 10px 15px;
            text-decoration: none;
            font-size: 0.9em;
            font-weight: 600;
            border-radius: 5px;
            margin: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
            transition: all 0.2s ease-out;
        }
        .navbar a:hover {
            background-color: var(--primary-color);
            color: #ffffff;
        }
        /* --- FIN: CSS de Barra de Navegacion --- */

    </style>
    <script>
        function toggleCategory(categoryId) {
            const content = document.getElementById(categoryId);
            const isHidden = content.style.display === 'none' || content.style.display === '';
            content.style.display = isHidden ? 'block' : 'none';
        }
        
        function searchEvents() {
            const filter = document.getElementById('searchInput').value.toLowerCase();
            const events = document.querySelectorAll('.event');
            
            events.forEach(event => {
                const text = event.textContent.toLowerCase();
                event.style.display = text.includes(filter) ? '' : 'none';
            });
        }
        
        function copyToClipboard(text) {
            navigator.clipboard.writeText(text)
                .then(() => alert('Copiado al portapapeles'))
                .catch(err => console.error('Error al copiar: ', err));
        }
    </script>
"@
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte Completo de Registros de Eventos - Aegis Phoenix Suite</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    $css
</head>
<body>
    <div class="navbar">
        <a href="#summary">Resumen</a>
        <a href="#category-systemcritical">Criticos</a>
        <a href="#category-systemerrors">Errores Sistema</a>
        <a href="#category-applicationerrors">Errores Apps</a>
        <a href="#category-securityfailures">Seguridad</a>
    </div>
    <div class="header">
        <h1><i class="fas fa-exclamation-triangle"></i>Reporte Completo de Registros de Eventos</h1>
        <p class="timestamp">Generado el: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") para el equipo: $($env:COMPUTERNAME)</p>
    </div>
    
    <div class="summary section" id="summary">
        <h2><i class="fas fa-chart-bar"></i>Resumen Ejecutivo - ultimos 30 Dias</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <div>Total de Eventos</div>
                <div class="stat-number stat-total">$totalEvents</div>
            </div>
            <div class="stat-card">
                <div>Eventos Criticos</div>
                <div class="stat-number stat-critical">$($eventCounts['SystemCritical'])</div>
            </div>
            <div class="stat-card">
                <div>Errores de Sistema</div>
                <div class="stat-number stat-error">$($eventCounts['SystemErrors'])</div>
            </div>
            <div class="stat-card">
                <div>Fallos de Seguridad</div>
                <div class="stat-number stat-security">$($eventCounts['SecurityFailures'])</div>
            </div>
        </div>
        <p>Este reporte muestra los eventos mas importantes de los registros de Windows en las ultimas 24 horas. Los eventos criticos y de error se muestran prioritariamente.</p>
    </div>
    
    <div class="search-box">
        <input type="text" id="searchInput" onkeyup="searchEvents()" placeholder="Buscar en todos los eventos...">
    </div>
"@
    
    # Generar secciones para cada categoria de eventos
    $categories = @(
        @{ Name = "Eventos Criticos del Sistema"; Key = "SystemCritical"; Class = "critical"; Icon = "exclamation-circle" },
        @{ Name = "Errores del Sistema"; Key = "SystemErrors"; Class = "error"; Icon = "times-circle" },
        @{ Name = "Errores de Aplicaciones"; Key = "ApplicationErrors"; Class = "error"; Icon = "window-close" },
        @{ Name = "Fallos de Seguridad"; Key = "SecurityFailures"; Class = "security"; Icon = "user-secret" }
    )
    
    foreach ($category in $categories) {
        $events = $reportData[$category.Key]
        $eventId = "category-" + $category.Key.ToLower()
        
        $htmlContent += @"
    
    <div class="category">
        <div class="category-header $($category.Class)" onclick="toggleCategory('$eventId')">
            <span><i class="fas fa-$($category.Icon)"></i> $($category.Name) ($($events.Count))</span>
            <span><i class="fas fa-chevron-down"></i></span>
        </div>
        <div id="$eventId" class="event-list">
"@
        
        if ($events.Count -eq 0) {
            $htmlContent += "            <div class='event'><p>No se encontraron eventos en esta categoria.</p></div>"
        }
        else {
            foreach ($event in $events) {
                $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                $source = $event.ProviderName
                $id = $event.Id
                $safeMessage = ""
                $rawMessage = "" # Para el boton de copiar

                if (-not [string]::IsNullOrWhiteSpace($event.Message)) {
                    # Si hay un mensaje, lo procesamos
                    $safeMessage = $event.Message.Replace("<", "<").Replace(">", ">") -split "`r`n" | Select-Object -First 3
                    $safeMessage = ($safeMessage -join "<br>")
                    $rawMessage = $event.Message.Replace('"', '&quot;').Replace("`r", "\r").Replace("`n", "\n")
                } else {
                    # Si $event.Message es $null, usamos un marcador de posición
                    $safeMessage = "(Mensaje no disponible o ilegible)"
                    $rawMessage = "(Mensaje no disponible)"
                }

                # Construimos el $fullMessage usando las variables seguras
                $fullMessage = $safeMessage + "<br><small style='color:#7f8c8d; cursor:pointer;' onclick='copyToClipboard(\`"$rawMessage\`")'>Copiar mensaje completo</small>"
                
                $htmlContent += @"
            <div class="event">
                <div class="event-time">[$time]</div>
                <div class="event-source">$source <span class="event-id">(ID: $id)</span></div>
                <div class="event-message">$fullMessage</div>
            </div>
"@
            }
        }
        
        $htmlContent += @"
        </div>
    </div>
"@
    }
    
    $htmlContent += @"
    
    <div class="footer">
        <p>Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER</p>
    </div>
</body>
</html>
"@
    
    # Guardar el reporte
    try {
        Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8 -Force
        Write-Host "`n[OK] Reporte HTML generado correctamente en: '$reportPath'" -ForegroundColor Green
        
        $openChoice = Read-Host "`n¿Deseas abrir el reporte ahora? (S/N)"
        if ($openChoice.ToUpper() -eq 'S') {
            Start-Process $reportPath
        }
    }
    catch {
        Write-Error "No se pudo generar el reporte HTML. Error: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "Error al generar reporte HTML: $($_.Exception.Message)"
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIoN 4: Buscar Soluciones para Errores Comunes ---
function Search-EventSolutions {
    Clear-Host
    Write-Host "`n[+] Buscar Soluciones para Errores Comunes de Windows" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------"
    
    # Base de conocimientos integrada para errores comunes
    $solutionsDb = @{
        # Errores de disco
        "153" = @{
            SourcePatterns = @("*disk*", "*volsnap*")
            Title = "Error de volumenes de sombra (VSS) - ID 153"
            Symptoms = "Problemas con copias de seguridad, restauracion de sistema, o errores al crear puntos de restauracion."
            Solutions = @(
                "Ejecutar 'chkdsk C: /f' y reiniciar el equipo.",
                "Verificar el servicio 'Volume Shadow Copy' esta en ejecucion: services.msc > Volume Shadow Copy > Iniciar.",
                "Ejecutar 'vssadmin list writers' en CMD para verificar el estado de los escritores VSS.",
                "Si persiste el problema, ejecutar 'sfc /scannow' para reparar archivos del sistema."
            )
            Resources = @(
                "https://support.microsoft.com/es-es/windows/usar-las-sombras-de-volumen-para-restaurar-versiones-anteriores-de-archivos-6a7a1a8a-4e3a-4df7-8e0e-9d8b9c8ad937"
            )
        }
        "9" = @{
            SourcePatterns = @("*disk*", "*harddisk*")
            Title = "Error de disco duro - ID 9"
            Symptoms = "Perdida de conexion con el disco, lentitud extrema, o mensajes de error relacionados con el disco."
            Solutions = @(
                "Verificar que los cables SATA/energia del disco esten correctamente conectados.",
                "Ejecutar 'chkdsk /f /r' para verificar y reparar sectores defectuosos.",
                "Verificar el estado S.M.A.R.T. del disco usando CrystalDiskInfo o similar.",
                "Si es una unidad externa, probar con otro puerto USB o cable."
            )
            Resources = @(
                "https://support.microsoft.com/es-es/windows/verificar-errores-en-una-unidad-en-windows-10-c991f1b4-e5ec-82c1-d2c0-1077a754df71"
            )
        }
        
        # Errores de controladores
        "14" = @{
            SourcePatterns = @("*nvlddmkm*", "*atikmdag*", "*amdkmdag*")
            Title = "Error de controlador de graficos - ID 14"
            Symptoms = "Pantalla negra, parpadeo, congelamiento del sistema, o reinicios inesperados durante uso intensivo de graficos."
            Solutions = @(
                "Actualizar el controlador de tarjeta grafica desde el sitio web del fabricante.",
                "Usar DDU (Display Driver Uninstaller) en modo seguro para eliminar completamente el controlador anterior.",
                "Reducir el overclocking de la GPU si se ha realizado.",
                "Verificar la temperatura de la tarjeta grafica con herramientas como HWMonitor."
            )
            Resources = @(
                "https://www.nvidia.com/es-es/drivers/",
                "https://www.amd.com/es/support"
            )
        }
        "41" = @{
            SourcePatterns = @("*kernel*", "*power*")
            Title = "El sistema se ha reiniciado sin apagarse correctamente - ID 41"
            Symptoms = "Reinicios inesperados o pantallazos azules sin mensaje de error claro."
            Solutions = @(
                "Verificar sobrecalentamiento del sistema (CPU, GPU, fuente de alimentacion).",
                "Ejecutar 'powercfg /energy' para generar un informe de energia.",
                "Actualizar la BIOS/UEFI a la ultima version.",
                "Probar con otra fuente de alimentacion si los problemas persisten.",
                "Verificar la memoria RAM con Windows Memory Diagnostic."
            )
            Resources = @(
                "https://support.microsoft.com/es-es/windows/diagnosticar-problemas-de-reinicio-inesperado-en-windows-10-1d0f2a3d-3b2d-4a0f-8c3e-8e2a3eef5a6a"
            )
        }
        
        # Errores de red
        "4227" = @{
            SourcePatterns = @("*tcpip*", "*dhcp*")
            Title = "Servidor DHCP no autorizado - ID 4227"
            Symptoms = "Problemas para obtener direccion IP, conexion intermitente a internet."
            Solutions = @(
                "Reiniciar el router y el modem.",
                "Liberar y renovar la direccion IP: 'ipconfig /release' seguido de 'ipconfig /renew'.",
                "Restablecer TCP/IP: 'netsh int ip reset' y 'netsh winsock reset'.",
                "Actualizar el controlador de la tarjeta de red."
            )
            Resources = @(
                "https://support.microsoft.com/es-es/windows/solucionar-problemas-de-conexion-a-internet-en-windows-10-8b3ecd78-2770-935b-849e-4c733c929a86"
            )
        }
        
        # Errores de inicio
        "7000" = @{
            SourcePatterns = @("*service*", "*control*")
            Title = "Error al iniciar servicio - ID 7000"
            Symptoms = "Servicios que no se inician automaticamente al arrancar Windows."
            Solutions = @(
                "Abrir services.msc y verificar el estado del servicio problematico.",
                "Revisar las dependencias del servicio en la pestana 'Dependencias'.",
                "Verificar si hay permisos incorrectos con Process Monitor de Sysinternals.",
                "Ejecutar 'sfc /scannow' para reparar archivos de sistema con defectos."
            )
            Resources = @(
                "https://support.microsoft.com/es-es/windows/administrar-servicios-en-windows-10-8af8e9e9-22e0-b4e1-9c59-4f3c92f29c58"
            )
        }
        "7031" = @{
            SourcePatterns = @("*service*", "*control*")
            Title = "Servicio critico fallo - ID 7031"
            Symptoms = "Servicios que se detienen inesperadamente causando problemas de sistema."
            Solutions = @(
                "Identificar que servicio falla revisando el mensaje completo.",
                "Verificar el registro de eventos para encontrar mas detalles sobre el fallo.",
                "Actualizar los controladores relacionados con el servicio.",
                "Usar System File Checker (sfc /scannow) para reparar archivos del sistema."
            )
            Resources = @(
                "https://support.microsoft.com/es-es/windows/fix-corrupted-system-files-in-windows-10-d2459226-f2d5-9123-3c65-2d5e591d6f2a"
            )
        }
    }
    
    # Buscar eventos criticos recientes para mostrar soluciones relevantes
    Write-Host "   - Analizando eventos recientes para encontrar errores conocidos..." -ForegroundColor Gray
    $recentEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=@(1,2); StartTime=(Get-Date).AddDays(-7)} -MaxEvents 100 -ErrorAction SilentlyContinue)
    
    $matchesFound = @()
    foreach ($event in $recentEvents) {
        $eventId = $event.Id.ToString()
        $eventSource = $event.ProviderName.ToLower()
        
        if ($solutionsDb.ContainsKey($eventId)) {
            $solution = $solutionsDb[$eventId]
            $sourceMatch = $false
            
            foreach ($pattern in $solution.SourcePatterns) {
                if ($eventSource -like $pattern) {
                    $sourceMatch = $true
                    break
                }
            }
            
            if ($sourceMatch) {
                $matchesFound += [PSCustomObject]@{
                    Event = $event
                    Solution = $solution
                }
            }
        }
    }
    
    Clear-Host
    if ($matchesFound.Count -gt 0) {
        Write-Host "`n[OK] Se encontraron soluciones para $($matchesFound.Count) errores conocidos:" -ForegroundColor Green
        
        $index = 1
        foreach ($match in $matchesFound) {
            $event = $match.Event
            $solution = $match.Solution
            
            Write-Host "`n===== [Error #$index] =====" -ForegroundColor Cyan
            Write-Host "Fecha: $($event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))"
            Write-Host "Origen: $($event.ProviderName) | ID: $($event.Id)"
            Write-Host "Mensaje: " -NoNewline
            $firstLine = ($event.Message -split "`r`n")[0]
            Write-Host "$firstLine" -ForegroundColor White
            
            Write-Host "`n[+] $([char]0x1b)[1m$($solution.Title)$([char]0x1b)[0m" -ForegroundColor Yellow
            Write-Host "Sintomas: $($solution.Symptoms)" -ForegroundColor Gray
            
            Write-Host "`nSoluciones:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $solution.Solutions.Count; $i++) {
                Write-Host "   [$(($i+1))] $($solution.Solutions[$i])" -ForegroundColor White
            }
            
            if ($solution.Resources.Count -gt 0) {
                Write-Host "`nRecursos adicionales:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $solution.Resources.Count; $i++) {
                    Write-Host "   - $($solution.Resources[$i])" -ForegroundColor Gray
                }
            }
            
            $index++
            Write-Host ""
        }
        
        # Ofrecer exportar las soluciones
        $exportChoice = Read-Host "`n¿Deseas exportar estas soluciones a un archivo de texto? (S/N)"
        if ($exportChoice.ToUpper() -eq 'S') {
            $parentDir = Split-Path -Parent $PSScriptRoot
            $reportDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory | Out-Null
            }
            
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
            $solutionPath = Join-Path -Path $reportDir -ChildPath "Soluciones_Eventos_$timestamp.txt"
            
            $exportContent = @"
=== SOLUCIONES PARA ERRORES COMUNES DE WINDOWS ===
Generado el: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") 
Sistema: $($env:COMPUTERNAME)

"@
            
            $index = 1
            foreach ($match in $matchesFound) {
                $event = $match.Event
                $solution = $match.Solution
                
                $exportContent += @"
===== [Error #$index] =====
Fecha: $($event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
Origen: $($event.ProviderName) | ID: $($event.Id)
Mensaje: $($event.Message -split "`r`n")[0]

+ $($solution.Title)
Sintomas: $($solution.Symptoms)

Soluciones:
"@
                
                for ($i = 0; $i -lt $solution.Solutions.Count; $i++) {
                    $exportContent += "   [$(($i+1))] $($solution.Solutions[$i])`n"
                }
                
                if ($solution.Resources.Count -gt 0) {
                    $exportContent += "`nRecursos adicionales:`n"
                    for ($i = 0; $i -lt $solution.Resources.Count; $i++) {
                        $exportContent += "   - $($solution.Resources[$i])`n"
                    }
                }
                
                $exportContent += "`n" + ("=" * 50) + "`n`n"
                $index++
            }
            
            $exportContent += @"
Reporte generado por Aegis Phoenix Suite v$($script:Version)
by SOFTMAXTER
"@
            
            Set-Content -Path $solutionPath -Value $exportContent -Encoding UTF8
            Write-Host "`n[OK] Soluciones exportadas a: '$solutionPath'" -ForegroundColor Green
        }
    }
    else {
        Write-Host "`n[INFO] No se encontraron errores comunes que coincidan con nuestra base de conocimientos." -ForegroundColor Yellow
        Write-Host "Puedes intentar:" -ForegroundColor Gray
        Write-Host "   1. Buscar en internet el ID del evento junto con 'solucion'"
        Write-Host "   2. Usar el Analisis Profundo Personalizado para filtrar eventos especificos"
        Write-Host "   3. Generar el Reporte HTML Completo para revisar todos los eventos"
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIoN 5: Monitoreo en Tiempo Real (Experimental) ---
function Start-RealTimeMonitoring {
    Clear-Host
    Write-Host "`n[+] Monitoreo en Tiempo Real de Eventos del Sistema" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------"
    Write-Host "   Este modo experimental muestra eventos a medida que ocurren."
    Write-Host "   Presiona Ctrl+C para detener el monitoreo en cualquier momento."
    Write-Warning "Este modo puede generar mucho texto en la consola."
    
    $confirm = Read-Host "`n¿Estas seguro de que deseas iniciar el monitoreo en tiempo real? (S/N)"
    if ($confirm.ToUpper() -ne 'S') {
        Write-Host "`n[INFO] Monitoreo cancelado por el usuario." -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para continuar..."
        return
    }
    
    # Configurar filtros para el monitoreo
    Write-Host "`n[1/3] Selecciona el tipo de eventos a monitorear:"
    Write-Host "   [1] Solo Criticos y Errores (recomendado)"
    Write-Host "   [2] Criticos, Errores y Advertencias"
    Write-Host "   [3] Todos los niveles"
    $levelChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $levelChoice = if ([string]::IsNullOrWhiteSpace($levelChoice)) { "1" } else { $levelChoice }
    
    $levelFilter = @(1, 2)  # Por defecto: criticos y errores
    switch ($levelChoice) {
        "2" { $levelFilter = @(1, 2, 3) }
        "3" { $levelFilter = $null }  # Todos los niveles
    }
    
    # Seleccionar logs a monitorear
    Write-Host "`n[2/3] Selecciona que registros monitorear:"
    Write-Host "   [1] System (recomendado)"
    Write-Host "   [2] System y Application"
    Write-Host "   [3] System, Application y Security"
    $logChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $logChoice = if ([string]::IsNullOrWhiteSpace($logChoice)) { "1" } else { $logChoice }
    
    $logNames = @("System")
    switch ($logChoice) {
        "2" { $logNames += "Application" }
        "3" { $logNames += "Application", "Security" }
    }
    
    # Duracion del monitoreo
    Write-Host "`n[3/3] Duracion del monitoreo (en minutos):"
    Write-Host "   [1] 5 minutos (recomendado para pruebas)"
    Write-Host "   [2] 15 minutos"
    Write-Host "   [3] 30 minutos"
    Write-Host "   [4] 60 minutos"
    Write-Host "   [M] Manual (introduce minutos)"
    $durationChoice = Read-Host "Elige una opcion (por defecto: 1)"
    $durationChoice = if ([string]::IsNullOrWhiteSpace($durationChoice)) { "1" } else { $durationChoice }
    
    $durationMinutes = 5  # Por defecto
    switch ($durationChoice) {
        "2" { $durationMinutes = 15 }
        "3" { $durationMinutes = 30 }
        "4" { $durationMinutes = 60 }
        "M" { 
            $customDuration = Read-Host "Introduce la duracion en minutos"
            $durationMinutes = if ($customDuration -match '^\d+$' -and [int]$customDuration -gt 0) { [int]$customDuration } else { 5 }
        }
    }
    
    $endTime = (Get-Date).AddMinutes($durationMinutes)
    $elapsedMinutes = 0
    
    # Preparar para el monitoreo
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "      MONITOREO EN TIEMPO REAL - $durationMinutes minutos      " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "Iniciado: $(Get-Date -Format 'HH:mm:ss')"
    Write-Host "Finalizara: $($endTime.ToString('HH:mm:ss'))"
    Write-Host "Registros: $($logNames -join ', ')"
    Write-Host "Niveles: $(if ($levelFilter) { $levelFilter -join ', ' } else { 'Todos' })"
    Write-Host ""
    Write-Host "[INFO] Presiona Ctrl+C en cualquier momento para detener el monitoreo."
    Write-Host ""
    
    $eventCount = 0
    $criticalCount = 0
    $errorCount = 0
    
    try {
        # Crear una sesion de suscripcion a eventos
        $query = "*[System[("
        $levelConditions = @()
        if ($levelFilter) {
            foreach ($level in $levelFilter) {
                $levelConditions += "(Level=$level)"
            }
            $query += "(" + ($levelConditions -join " or ") + ")"
        }
        
        $logConditions = @()
        foreach ($logName in $logNames) {
            $logConditions += "(EventLog='$logName')"
        }
        $query += " and (" + ($logConditions -join " or ") + "))]]"
        
        # Iniciar el monitoreo
        $startTime = Get-Date
        $session = New-Object System.Diagnostics.Eventing.Reader.EventLogSession
        $subscription = New-Object System.Diagnostics.Eventing.Reader.EventLogWatcher($query, $session, $true)
        
        # Definir el manejador de eventos
        $subscription.Enabled = $true
        Register-ObjectEvent -InputObject $subscription -EventName EventRecordWritten -Action {
            param($eventRecord)
            try {
                $event = $eventRecord.EventRecord
                $time = $event.TimeCreated.ToString("HH:mm:ss")
                $source = $event.ProviderName
                $id = $event.Id
                $level = switch ($event.Level) {
                    1 { "CRiTICO"; $script:criticalCount++; break }
                    2 { "ERROR"; $script:errorCount++; break }
                    3 { "ADVERTENCIA"; break }
                    4 { "INFORMACIoN"; break }
                    default { "OTRO" }
                }
                $levelColor = switch ($event.Level) {
                    1 { "Red" }
                    2 { "Red" }
                    3 { "Yellow" }
                    4 { "Gray" }
                    default { "White" }
                }
                $message = ($event.FormatDescription() -split "`r`n")[0]
                
                $script:eventCount++
                
                Write-Host "[$time] [$level] [$source] (ID: $id)" -ForegroundColor $levelColor
                Write-Host "   $message" -ForegroundColor White
            }
            catch {
                # No hacer nada si hay un error en el manejador
            }
        } | Out-Null
        
        Write-Host "[+] Monitoreo iniciado correctamente." -ForegroundColor Green
        Write-Host ""
        
        # Mantener el script ejecutandose hasta que termine el tiempo
        while ((Get-Date) -lt $endTime) {
            Start-Sleep -Seconds 1
            $currentElapsed = [math]::Floor(((Get-Date) - $startTime).TotalMinutes)
            if ($currentElapsed -gt $elapsedMinutes) {
                $elapsedMinutes = $currentElapsed
                $remainingMinutes = $durationMinutes - $elapsedMinutes
                
                if ($remainingMinutes -gt 0) {
                    $progress = ($elapsedMinutes / $durationMinutes) * 100
                    Write-Host "   [PROGRESO] Tiempo transcurrido: $elapsedMinutes/$durationMinutes minutos - Eventos detectados: $eventCount (Criticos: $criticalCount, Errores: $errorCount)" -ForegroundColor Cyan
                }
            }
        }
    }
    catch {
        Write-Error "Error durante el monitoreo: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "Error en monitoreo en tiempo real: $($_.Exception.Message)"
    }
    finally {
        # Limpiar
        if ($subscription) {
            $subscription.Enabled = $false
            $subscription.Dispose()
        }
        
        # Mostrar resumen final
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "         RESUMEN DEL MONITOREO EN TIEMPO REAL          " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Duracion total: $durationMinutes minutos"
        Write-Host "Eventos detectados: $eventCount"
        Write-Host "   - CRiTICOS: $criticalCount" -ForegroundColor Red
        Write-Host "   - ERRORES: $errorCount" -ForegroundColor Red
        Write-Host "   - Otros niveles: $($eventCount - $criticalCount - $errorCount)" -ForegroundColor Gray
        Write-Host ""
        
        if ($eventCount -gt 0) {
            $exportChoice = Read-Host "¿Deseas exportar estos eventos a un archivo de registro? (S/N)"
            if ($exportChoice.ToUpper() -eq 'S') {
                $parentDir = Split-Path -Parent $PSScriptRoot
                $logDir = Join-Path -Path $parentDir -ChildPath "Logs"
                if (-not (Test-Path $logDir)) {
                    New-Item -Path $logDir -ItemType Directory | Out-Null
                }
                
                $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
                $logPath = Join-Path -Path $logDir -ChildPath "Monitoreo_En_Tiempo_Real_$timestamp.log"
                
                $logContent = @"
=== MONITOREO EN TIEMPO REAL DE EVENTOS ===
Inicio: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))
Fin: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duracion: $durationMinutes minutos
Registros monitoreados: $($logNames -join ', ')
Niveles monitoreados: $(if ($levelFilter) { $levelFilter -join ', ' } else { 'Todos' })
------------------------------------------------
Total de eventos detectados: $eventCount
   - CRiTICOS: $criticalCount
   - ERRORES: $errorCount
   - Otros niveles: $($eventCount - $criticalCount - $errorCount)

Este archivo solo contiene el resumen del monitoreo. Para ver los eventos especificos,
usa las otras funciones del analizador de eventos.
"@
                
                Set-Content -Path $logPath -Value $logContent -Encoding UTF8
                Write-Host "`n[OK] Resumen exportado a: '$logPath'" -ForegroundColor Green
            }
        }
        
        Read-Host "`nPresiona Enter para continuar..."
    }
}

# --- FUNCIONES AUXILIARES ---
function Export-DetailedEventReport {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Events
    )
    
    $parentDir = Split-Path -Parent $PSScriptRoot
    $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
    if (-not (Test-Path $diagDir)) {
        New-Item -Path $diagDir -ItemType Directory | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    $reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Eventos_Detallado_$timestamp.html"
    
    # CSS mejorado y unificado
    $css = @"
    <style>
        :root { 
            --bg-color: #f4f7f9;
            --main-text-color: #2c3e50;
            --primary-color: #2980b9;
            --secondary-color: #34495e;
            --card-bg-color: #ffffff;
            --header-text-color: #ecf0f1;
            --border-color: #dfe6e9;
            --danger-color: #c0392b;
            --warning-color: #f39c12;
            --shadow: 0 5px 15px rgba(0,0,0,0.08);
        }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: var(--main-text-color); background-color: var(--bg-color); max-width: 1400px; margin: auto; padding: 20px; }
        .header { background: linear-gradient(135deg, var(--secondary-color) 0%, var(--primary-color) 100%); color: var(--header-text-color); padding: 30px; border-radius: 8px; margin-bottom: 30px; box-shadow: var(--shadow); }
        h1, h2 { margin: 0; font-weight: 600; }
        h1 { font-size: 2.8em; display: flex; align-items: center; } h1 i { margin-right: 15px; }
        h2 { color: var(--secondary-color); border-bottom: 2px solid var(--border-color); padding-bottom: 10px; margin: 0 0 20px 0; font-size: 1.8em; display: flex; align-items: center; } h2 i { margin-right: 10px; color: var(--primary-color); }
        .timestamp { font-size: 1em; opacity: 0.9; margin-top: 5px; }
        
        .summary, .recommendations {
            background-color: var(--card-bg-color);
            border-radius: 8px;
            padding: 25px;
            margin-bottom: 25px;
            box-shadow: var(--shadow);
        }
        
        .issue-section {
            background-color: var(--card-bg-color);
            border-radius: 8px;
            box-shadow: var(--shadow);
            margin-bottom: 25px;
            overflow: hidden;
        }
        .issue-header {
            padding: 12px 20px;
            font-weight: bold;
            color: white;
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
        }
        
        .issue-header.critical { background: var(--danger-color); }
        .issue-header.warning { background: var(--warning-color); color: var(--main-text-color); }
        .issue-header.info { background: var(--primary-color); }
        .summary li.critical { color: var(--danger-color); font-weight: bold; }
        .summary li.warning { color: var(--warning-color); font-weight: bold; }
        .summary li.info { color: var(--main-text-color); }
        /* --- Fin de la adicion --- */

        .event { 
            padding: 12px 15px; 
            border-bottom: 1px solid var(--border-color); 
            transition: background-color 0.2s;
        }
        .event:hover { background-color: #f1f5f8; }
        .event:last-child { border-bottom: none; }
        .event-time { color: #7f8c8d; font-size: 14px; }
        .event-source { font-weight: bold; color: var(--main-text-color); }
        .event-message { margin-top: 5px; color: #212529; }
        
        .footer { text-align: center; margin-top: 40px; color: #7f8c8d; font-size: 0.8em; }
        .search-box { margin: 20px 0; text-align: right; }
        .search-box input { padding: 10px 15px; width: 98%; border: 1px solid var(--border-color); border-radius: 5px; font-size: 1em; }

        .navbar {
            background-color: var(--secondary-color);
            overflow: visible;
            position: sticky;
            top: 0;
            width: 100%;
            z-index: 1000;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            padding: 8px 5px;
        }
        .navbar a {
            color: var(--header-text-color);
            background-color: var(--primary-color);
            text-align: center;
            padding: 10px 15px;
            text-decoration: none;
            font-size: 0.9em;
            font-weight: 600;
            border-radius: 5px;
            margin: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
            transition: all 0.2s ease-out;
        }
        .navbar a:hover {
            background-color: var(--primary-color);
            color: #ffffff;
        }
        /* --- FIN: CSS de Barra de Navegacion --- */

    </style>
    <script>
        function searchEvents() {
            const filter = document.getElementById('searchInput').value.toLowerCase();
            const events = document.getElementsByClassName('event');
            
            for (let i = 0; i < events.length; i++) {
                const event = events[i];
                const text = event.textContent.toLowerCase();
                event.style.display = text.includes(filter) ? '' : 'none';
            }
        }
        
        function toggleSection(sectionId) {
            const section = document.getElementById(sectionId);
            const isHidden = section.style.display === 'none' || section.style.display === '';
            section.style.display = isHidden ? 'block' : 'none';
        }
    </script>
"@
    
    # Generar contenido HTML
    $htmlContent = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte Detallado de Eventos del Sistema - Aegis Phoenix Suite</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    $css
</head>
<body>
    <div class="navbar">
        <a href="#summary">Resumen</a>
        <a href="#detailed-events">Eventos</a>
        <a href="#recommendations">Recomendaciones</a>
    </div>
    <div class="header">
        <h1><i class="fas fa-clipboard-list"></i> Reporte Detallado de Eventos del Sistema</h1>
        <p class="timestamp">Generado el: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") para el equipo: $($env:COMPUTERNAME)</p>
    </div>
    
    <div class="summary" id="summary">
        <h2><i class="fas fa-chart-bar"></i> Resumen Ejecutivo</h2>
        <p>Se detectaron <strong>$($Events.Count)</strong> eventos criticos en las ultimas 24 horas.</p>
        
        <h3>Patrones de Problemas Detectados:</h3>
        <ul>
"@
    
    $issuesByType = $Events | Group-Object Type | Sort-Object Count -Descending
    foreach ($issueGroup in $issuesByType) {
        $severityClass = if ($issueGroup.Count -gt 5) { "critical" } elseif ($issueGroup.Count -gt 2) { "warning" } else { "info" }
        $htmlContent += "            <li class='$severityClass'>- $($issueGroup.Name): <strong>$($issueGroup.Count)</strong> eventos</li>`n"
    }
    
    $htmlContent += @"
        </ul>
    </div>
    
    <div class="search-box">
        <input type="text" id="searchInput" onkeyup="searchEvents()" placeholder="Buscar en eventos...">
    </div>
    
    <h2 id="detailed-events"><i class="fas fa-exclamation-triangle"></i> Eventos Detallados</h2>
"@
    
    # Agrupar eventos por tipo
    $currentSection = 1
    foreach ($issueGroup in $issuesByType) {
        $sectionId = "section-$currentSection"
        $severityClass = if ($issueGroup.Count -gt 5) { "critical" } elseif ($issueGroup.Count -gt 2) { "warning" } else { "info" }
        
        $htmlContent += @"
    
    <div class="issue-section">
        <div class="issue-header $severityClass" onclick="toggleSection('$sectionId')">
            <span><i class="fas fa-bug"></i> $($issueGroup.Name) ($($issueGroup.Count) eventos)</span>
            <span><i class="fas fa-chevron-down"></i></span>
        </div>
        <div id="$sectionId">
"@
        
        foreach ($event in $issueGroup.Group) {
            
            $safeMessage = ""
            if (-not [string]::IsNullOrWhiteSpace($event.Message)) {
                $safeMessage = $event.Message.Replace("<", "<").Replace(">", ">") -split "`r`n" | Select-Object -First 3
                $safeMessage = ($safeMessage -join "<br>")
            } else {
                $safeMessage = "(Mensaje no disponible o ilegible)"
            }
            
            $htmlContent += @"
            <div class="event">
                <div class="event-time">[$($event.Time)]</div>
                <div class="event-source">Fuente: $($event.Source) (ID: $($event.Id) | Log: $($event.Log))</div>
                <div class="event-message">$safeMessage</div>
            </div>
"@
        }
        
        $htmlContent += @"
        </div>
    </div>
"@
        
        $currentSection++
    }
    
    # Recomendaciones
    $htmlContent += @"
    
    <div class="recommendations" id="recommendations">
        <h2><i class="fas fa-lightbulb"></i> Recomendaciones de Accion</h2>
"@
    
    foreach ($issueGroup in $issuesByType) {
        $htmlContent += @"
        <h3>$($issueGroup.Name)</h3>
        <ul>
"@
        switch ($issueGroup.Name) {
            "Disk Errors" { 
                $htmlContent += @"
            <li>Ejecuta <strong>chkdsk C: /f</strong> y reinicia el equipo</li>
            <li>Verifica la salud del disco con CrystalDiskInfo o similar</li>
            <li>Revisa los cables de conexion del disco (SATA/Power)</li>
"@
            }
            "Driver Issues" { 
                $htmlContent += @"
            <li>Actualiza los controladores, especialmente de video y chipset</li>
            <li>Usa DDU (Display Driver Uninstaller) para una limpieza profunda de controladores de video</li>
            <li>Verifica en el Administrador de dispositivos si hay dispositivos con problemas (!)</li>
"@
            }
            "Memory Problems" { 
                $htmlContent += @"
            <li>Ejecuta Windows Memory Diagnostic (mdsched.exe)</li>
            <li>Si tienes modulos de RAM adicionales, prueba eliminando uno a la vez</li>
            <li>Verifica la configuracion de XMP/DOCP en la BIOS si aplicable</li>
"@
            }
            "Network Failures" { 
                $htmlContent += @"
            <li>Reinicia tu router y modem</li>
            <li>Actualiza los controladores de red</li>
            <li>Ejecuta los comandos: <strong>ipconfig /release</strong>, <strong>ipconfig /renew</strong>, <strong>ipconfig /flushdns</strong></li>
"@
            }
            "Startup Failures" { 
                $htmlContent += @"
            <li>Ejecuta <strong>sfc /scannow</strong> para reparar archivos del sistema</li>
            <li>Ejecuta <strong>DISM /Online /Cleanup-Image /RestoreHealth</strong></li>
            <li>Verifica los servicios de inicio criticos en services.msc</li>
"@
            }
            "Application Crashes" { 
                $htmlContent += @"
            <li>Actualiza las aplicaciones problematicas a la ultima version</li>
            <li>Revisa si hay actualizaciones disponibles de Windows</li>
            <li>Considera reinstalar la aplicacion problematica</li>
"@
            }
            "System Freezes" { 
                $htmlContent += @"
            <li>Verifica las temperaturas del sistema con HWMonitor</li>
            <li>Actualiza la BIOS/UEFI a la ultima version disponible</li>
            <li>Revisa si hay conflictos de hardware en el Administrador de dispositivos</li>
"@
            }
            default { 
                $htmlContent += @"
            <li>Busca en linea el ID del evento especifico ($($issueGroup.Group[0].Id)) combinado con el origen ($($issueGroup.Group[0].Source))</li>
            <li>Considera usar el Foro de Microsoft o comunidades especializadas para soluciones especificas</li>
"@
            }
        }
        $htmlContent += @"
        </ul>
"@
    }
    
    $htmlContent += @"
    </div>
    
    <div class="footer">
        <p>Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER</p>
    </div>
</body>
</html>
"@
    
    # Guardar el reporte
    Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8
    
    Write-Host "`n[OK] Reporte detallado generado en: '$reportPath'" -ForegroundColor Green
    $openChoice = Read-Host "¿Deseas abrir el reporte ahora? (S/N)"
    if ($openChoice.ToUpper() -eq 'S') {
        Start-Process $reportPath
    }
}

function Export-EventResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Events,
        [string]$FileNamePrefix = "Resultados_Eventos"
    )
    
    $parentDir = Split-Path -Parent $PSScriptRoot
    $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
    if (-not (Test-Path $diagDir)) {
        New-Item -Path $diagDir -ItemType Directory | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    $txtPath = Join-Path -Path $diagDir -ChildPath "$FileNamePrefix_$timestamp.txt"
    $csvPath = Join-Path -Path $diagDir -ChildPath "$FileNamePrefix_$timestamp.csv"
    
    # Exportar a TXT (formato legible)
    $txtContent = @"
=== RESULTADOS DEL ANÁLISIS DE EVENTOS ===
Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Sistema: $($env:COMPUTERNAME)
Número total de eventos: $($Events.Count)
============================================================

"@
    
    $index = 1
    foreach ($event in $Events) {
        $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        $source = $event.ProviderName
        $id = $event.Id
        $level = switch ($event.Level) {
            1 { "CRÍTICO" }
            2 { "ERROR" }
            3 { "ADVERTENCIA" }
            4 { "INFORMACION" }
            default { "OTRO" }
        }
        
        $txtContent += @"
[$index] $time | $level | $source (ID: $id)
------------------------------------------------------------
$($event.Message)
============================================================

"@
        $index++
    }
    
    $txtContent += @"
Reporte generado por Aegis Phoenix Suite v$($script:Version)
by SOFTMAXTER
"@
    
    Set-Content -Path $txtPath -Value $txtContent -Encoding UTF8
    
    # Exportar a CSV (para análisis de datos)
    $eventsForCsv = $Events | Select-Object @{
        Name = "FechaHora"
        Expression = { $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") }
    }, @{
        Name = "Nivel"
        Expression = { 
            switch ($_.Level) {
                1 { "CRÍTICO" }
                2 { "ERROR" }
                3 { "ADVERTENCIA" }
                4 { "INFORMACION" }
                default { "OTRO" }
            }
        }
    }, @{
        Name = "Origen"
        Expression = { $_.ProviderName }
    }, @{
        Name = "ID"
        Expression = { $_.Id }
    }, @{
        Name = "Mensaje"
        Expression = { ($_.Message -split "`r`n")[0] }
    }, @{
        Name = "Log"
        Expression = { $_.LogName }
    }
    
    $eventsForCsv | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
    
    Write-Host "`n[OK] Resultados exportados correctamente:" -ForegroundColor Green
    Write-Host "   - TXT (legible): $txtPath"
    Write-Host "   - CSV (análisis): $csvPath"
    
    $openChoice = Read-Host "`n¿Deseas abrir la carpeta con los resultados? (S/N)"
    if ($openChoice.ToUpper() -eq 'S') {
        Start-Process $diagDir
    }
}

# ===================================================================
# --- MODULO DE RESPALDO DE DATOS DE USUARIO (ROBOCOPY) ---
# ===================================================================
function Select-PathDialog {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Folder', 'File')]
        [string]$DialogType,

        [string]$Title,

        [string]$Filter = "Todos los archivos (*.*)|*.*"
    )
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        if ($DialogType -eq 'Folder') {
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = $Title
            if ($dialog.ShowDialog() -eq 'OK') {
                return $dialog.SelectedPath
            }
        } elseif ($DialogType -eq 'File') {
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Title = $Title
            $dialog.Filter = $Filter
            $dialog.CheckFileExists = $true
            $dialog.CheckPathExists = $true
            $dialog.Multiselect = $true # Permitimos seleccionar multiples archivos
            if ($dialog.ShowDialog() -eq 'OK') {
                return $dialog.FileNames # Devolvemos un array de nombres de archivo
            }
        }
    } catch {
        Write-Error "No se pudo mostrar el dialogo de seleccion. Error: $($_.Exception.Message)"
    }
    
    return $null # Devuelve nulo si el usuario cancela
}

function Invoke-BackupRobocopyVerification {
    [CmdletBinding()]
    param(
        $logFile, $baseRoboCopyArgs, $backupType, $sourcePaths, $destinationPath, $Mode
    )

    Write-Host "`n[+] Iniciando comprobacion de integridad (modo de solo listado)..." -ForegroundColor Yellow
    Write-Output "`r`n`r`n================================================`r`n" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Output "   INICIO DE LA COMPROBACION DE INTEGRIDAD (RAPIDA)`r`n" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Output "================================================`r`n" | Out-File -FilePath $logFile -Append -Encoding UTF8

    $verifyBaseArgs = $baseRoboCopyArgs + "/L"
    $logArg = "/LOG+:`"$logFile`""

    if ($backupType -eq 'Files') {
        $filesByDirectory = $sourcePaths | Get-Item | Group-Object -Property DirectoryName
        foreach ($group in $filesByDirectory) {
            $sourceDir = $group.Name
            $fileNames = $group.Group | ForEach-Object { "`"$($_.Name)`"" }
            Write-Host " - Verificando lote desde '$sourceDir'..." -ForegroundColor Gray
            $currentArgs = @("`"$sourceDir`"", "`"$destinationPath`"") + $fileNames + $verifyBaseArgs + $logArg
            Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow
        }
    } else {
        $folderArgs = $verifyBaseArgs + "/E"
        if ($Mode -eq 'Mirror') { $folderArgs = $verifyBaseArgs + "/MIR" }
        foreach ($sourceFolder in $sourcePaths) {
            $folderName = Split-Path $sourceFolder -Leaf
            $destinationFolder = Join-Path $destinationPath $folderName
            Write-Host "`n[+] Verificando '$folderName' en '$destinationFolder'..." -ForegroundColor Gray
            $currentArgs = @("`"$sourceFolder`"", "`"$destinationFolder`"") + $folderArgs + $logArg
            Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow
        }
    }
    
    Write-Host "[OK] Comprobacion de integridad finalizada. Revisa el registro para ver los detalles." -ForegroundColor Green
    Write-Host "   Si no aparecen archivos listados en la seccion de verificacion, la copia es integra." -ForegroundColor Gray
}

function Invoke-BackupHashVerification {
    [CmdletBinding()]
    param(
        $sourcePaths, $destinationPath, $backupType, $logFile
    )
    
    Write-Host "`n[+] Iniciando comprobacion profunda por Hash (SHA256). Esto puede ser MUY LENTO." -ForegroundColor Yellow
    
    $sourceFiles = @()
    if ($backupType -eq 'Files') {
        $sourceFiles = $sourcePaths | Get-Item
    } else {
        # Usamos ErrorAction SilentlyContinue para saltar archivos bloqueados/sistema
        $sourcePaths | ForEach-Object { $sourceFiles += Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue }
    }

    if ($sourceFiles.Count -eq 0) { Write-Warning "No se encontraron archivos de origen para verificar."; return }

    $totalFiles = $sourceFiles.Count
    $checkedFiles = 0
    $mismatchedFiles = 0
    $missingFiles = 0
    $mismatchedFileList = [System.Collections.Generic.List[string]]::new()
    $missingFileList = [System.Collections.Generic.List[string]]::new()

    foreach ($sourceFile in $sourceFiles) {
        $checkedFiles++
        # Progreso visual simple para no saturar la consola
        if ($checkedFiles % 10 -eq 0) {
            Write-Progress -Activity "Verificando hashes de archivos" -Status "Procesando ($checkedFiles/$totalFiles): $($sourceFile.Name)" -PercentComplete (($checkedFiles / $totalFiles) * 100)
        }
        
        $destinationFile = ""
        if ($backupType -eq 'Folders') {
             # CORRECCION CRITICA: Ordenamos por longitud descendente para encontrar la ruta mas especifica
             # Esto evita el error cuando "Videos" esta dentro de "Documentos"
             $baseSourceFolder = ($sourcePaths | Where-Object { $sourceFile.FullName.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Sort-Object Length -Descending | Select-Object -First 1)
             
             if ($baseSourceFolder) {
                 $relativePath = $sourceFile.FullName.Substring($baseSourceFolder.Length)
                 # Construimos la ruta destino replicando la estructura
                 $destinationFile = Join-Path (Join-Path $destinationPath (Split-Path $baseSourceFolder -Leaf)) $relativePath
             }
        } else {
             $destinationFile = Join-Path $destinationPath $sourceFile.Name
        }
        
        # Verificacion
        if (Test-Path $destinationFile) {
            try {
                $sourceHash = (Get-FileHash $sourceFile.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                $destHash = (Get-FileHash $destinationFile -Algorithm SHA256 -ErrorAction Stop).Hash
                
                if ($sourceHash -ne $destHash) {
                    $mismatchedFiles++
                    $message = "DISCREPANCIA DE HASH: $($sourceFile.Name)"
                    Write-Warning $message
                    $mismatchedFileList.Add("Fuente: $($sourceFile.FullName) | Destino: $destinationFile")
                }
            } catch {
                $message = "ERROR DE LECTURA (Archivo en uso o sin permisos): $($sourceFile.Name)"
                Write-Warning $message
                $mismatchedFileList.Add($message)
            }
        } else {
            $missingFiles++
            # Mensaje mejorado para depuracion: Muestra donde busco y no encontro
            $message = "ARCHIVO FALTANTE. Buscado en: $destinationFile"
            Write-Warning $message
            $missingFileList.Add("Fuente original: $($sourceFile.FullName) | Ruta esperada no encontrada: $destinationFile")
        }
    }

    Write-Progress -Activity "Verificacion por Hash" -Completed
    Write-Host "`n--- RESUMEN DE LA COMPROBACION PROFUNDA ---" -ForegroundColor Cyan
    Write-Host "Archivos totales verificados: $totalFiles"
    $mismatchColor = if ($mismatchedFiles -gt 0) { 'Red' } else { 'Green' }
    Write-Host "Archivos con discrepancias  : $mismatchedFiles" -ForegroundColor $mismatchColor
    $missingColor = if ($missingFiles -gt 0) { 'Red' } else { 'Green' }
    Write-Host "Archivos faltantes en destino: $missingFiles" -ForegroundColor $missingColor
    
    $logSummary = @"

-------------------------------------------------
   RESUMEN DE LA COMPROBACION PROFUNDA POR HASH
-------------------------------------------------
Archivos totales verificados: $totalFiles
Archivos con discrepancias  : $mismatchedFiles
Archivos faltantes en destino: $missingFiles
"@
    if ($mismatchedFileList.Count -gt 0) {
        $logSummary += "`r`n`r`n--- LISTA DE DISCREPANCIAS ---`r`n"
        $logSummary += ($mismatchedFileList | Out-String)
    }
    if ($missingFileList.Count -gt 0) {
        $logSummary += "`r`n`r`n--- LISTA DE ARCHIVOS FALTANTES ---`r`n"
        $logSummary += ($missingFileList | Out-String)
    }
    $logSummary | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    if ($mismatchedFiles -eq 0 -and $missingFiles -eq 0) {
        Write-Host "[OK] La integridad de todos los archivos ha sido verificada con exito." -ForegroundColor Green
    } else {
        Write-Error "Se encontraron problemas de integridad en la copia de seguridad."
    }
}

# --- FUNCION 2: LOGICA PRINCIPAL DEL RESPALDO (ROBOCOPY) ---
function Invoke-UserDataBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Copy', 'Mirror')]
        [string]$Mode,

        [string[]]$CustomSourcePath
    )

    # 1. Determinamos el origen: automatico o personalizado
    $backupType = 'Folders'
    $sourcePaths = @()
    
    if ($CustomSourcePath) {
        if ($CustomSourcePath.Count -eq 1 -and (Get-Item $CustomSourcePath[0]).PSIsContainer) {
            $backupType = 'Folders'
            $sourcePaths = $CustomSourcePath
        } else {
            $backupType = 'Files'
            $sourcePaths = $CustomSourcePath
        }
    } else {
        $backupType = 'Folders'
        
        # --- LOGICA AVANZADA PARA DETECTAR LA RUTA REAL DE 'DESCARGAS' ---
        # Consultamos el registro 'User Shell Folders' para obtener la ruta real, 
        # incluso si el usuario la ha movido a otro disco.
        $regPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
        $downloadsGuid = "{374DE290-123F-4565-9164-39C4925E467B}" # GUID oficial de Descargas
        
        $downloadsPath = try {
            $regValue = (Get-ItemProperty -Path $regPath -Name $downloadsGuid -ErrorAction SilentlyContinue).$downloadsGuid
            if ($regValue) {
                # Expandimos variables de entorno (ej: %USERPROFILE%\Downloads -> C:\Users\Juan\Downloads)
                [System.Environment]::ExpandEnvironmentVariables($regValue)
            } else {
                # Fallback por defecto si no existe la clave
                Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
            }
        } catch {
            Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
        }

        # Construimos la lista de rutas estandar + descargas inteligente
        $sourcePaths = @(
            [System.Environment]::GetFolderPath('Desktop'),
            [System.Environment]::GetFolderPath('MyDocuments'),
            [System.Environment]::GetFolderPath('MyPictures'),
            [System.Environment]::GetFolderPath('MyMusic'),
            [System.Environment]::GetFolderPath('MyVideos'),
            $downloadsPath
        ) | Where-Object { Test-Path $_ } | Select-Object -Unique
    }
    
    # 2. Solicitamos y validamos el destino
    Write-Host "`n[+] Por favor, selecciona la carpeta de destino para el respaldo..." -ForegroundColor Yellow
    $destinationPath = Select-PathDialog -DialogType 'Folder' -Title "Paso 2: Elige la Carpeta de Destino del Respaldo"
    
    if ([string]::IsNullOrWhiteSpace($destinationPath)) {
        Write-Warning "No se selecciono una carpeta de destino. Operacion cancelada." ; Start-Sleep -Seconds 2; return
    }

    # --- VALIDACION ANTI-BUCLE (CRITICO) ---
    $destFull = (Get-Item -Path $destinationPath).FullName.TrimEnd('\')
    foreach ($src in $sourcePaths) {
        if ($backupType -eq 'Folders') {
            $srcFull = (Get-Item -Path $src).FullName.TrimEnd('\')
            # Si el destino empieza con la ruta de origen, es una subcarpeta (Riesgo de bucle)
            if ($destFull.StartsWith($srcFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Error "ERROR CRITICO DE CONFIGURACION:"
                Write-Error "La carpeta de destino ($destFull) esta DENTRO de la carpeta de origen ($srcFull)."
                Write-Error "Esto causaria un bucle infinito que llenaria tu disco duro."
                Read-Host "Operacion abortada por seguridad. Presiona Enter..."
                return
            }
        }
    }

    # Validación de unidad idéntica (Aviso de seguridad)
    $sourceDriveLetter = (Get-Item -Path $sourcePaths[0]).PSDrive.Name
    $destinationDriveLetter = (Get-Item -Path $destinationPath).PSDrive.Name
    if ($sourceDriveLetter.ToUpper() -eq $destinationDriveLetter.ToUpper()) {
        Write-Warning "AVISO: El destino esta en la misma unidad fisica que el origen."
        Write-Warning "Esto protege contra borrados accidentales, pero NO contra fallos fisicos del disco."
        if ((Read-Host "Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') {
            return
        }
    }
    
    # 3. Calculamos espacio requerido
    Write-Host "`n[+] Calculando espacio requerido..." -ForegroundColor Yellow
    $sourceTotalSize = 0
    try {
        if ($backupType -eq 'Files') {
            $sourceTotalSize = ($sourcePaths | Get-Item | Measure-Object -Property Length -Sum).Sum
        } else {
            foreach ($folder in $sourcePaths) {
                $sourceTotalSize += (Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            }
        }
    } catch { Write-Warning "Calculo de tamaño aproximado (algunos archivos pueden estar bloqueados)." }
    
    $destinationFreeSpace = (Get-Volume -DriveLetter $destinationDriveLetter).SizeRemaining
    if ($sourceTotalSize -gt $destinationFreeSpace) {
        $neededGB = [math]::Round($sourceTotalSize / 1GB, 2)
        $freeGB = [math]::Round($destinationFreeSpace / 1GB, 2)
        Write-Error "ESPACIO INSUFICIENTE: Requieres ~$neededGB GB pero solo tienes $freeGB GB libres."
        Read-Host "Operacion abortada. Presiona Enter..."
        return
    }

    # 4. Configuración Robocopy (Optimizado)
    $logDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    $logFile = Join-Path $logDir "Respaldo_Robocopy_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

    # FLAGS DE ROBOCOPY:
    # /B  : Modo Backup (copia archivos saltando permisos NTFS si eres Admin)
    # /J  : Unbuffered I/O (Evita llenar la RAM con archivos grandes)
    # /XD : Excluir directorios basura
    $baseRoboCopyArgs = @("/COPY:DAT", "/R:2", "/W:3", "/XJ", "/NP", "/TEE", "/B", "/J")
    $excludeDirs = @("/XD", "`"$destinationPath`"", "System Volume Info", "`$RECYCLE.BIN", "AppData\Local\Temp")

    # 5. Menú de Confirmación
    Clear-Host
    $modeDescription = if ($Mode -eq 'Mirror') { "Sincronizacion (ESPEJO - Borra en destino lo que no esta en origen)" } else { "Respaldo Incremental (Solo copia nuevos/modificados)" }
    Write-Host "--- RESUMEN DE RESPALDO ---" -ForegroundColor Cyan
    Write-Host "Modo: $modeDescription"
    Write-Host "Destino: $destinationPath"
    Write-Host "Origen(es):"
    $sourcePaths | ForEach-Object { Write-Host " - $_" }
    
    Write-Host ""
    Write-Host "   [S] Iniciar Respaldo (Sin verificacion)"
    Write-Host "   [V] Iniciar + Verificacion Rapida (Robocopy /L)"
    Write-Host "   [H] Iniciar + Verificacion Profunda por Hash (LENTO pero Seguro)" -ForegroundColor Yellow
    Write-Host "   [N] Cancelar"
    $confirmChoice = Read-Host "`nElige una opcion"

    $verificationType = 'None'
    switch ($confirmChoice.ToUpper()) {
        'S' { $verificationType = 'None' }
        'V' { $verificationType = 'Fast' }
        'H' { $verificationType = 'Deep' }
        'N' { return }
        default { return }
    }

    # 6. Ejecución del Respaldo
    $logArg = "/LOG+:`"$logFile`""
    Write-Log -LogLevel ACTION -Message "BACKUP: Iniciando. Modo: $Mode. Destino: $destinationPath"

    if ($backupType -eq 'Files') {
        # Copia de Archivos Sueltos
        $filesByDirectory = $sourcePaths | Get-Item | Group-Object -Property DirectoryName
        foreach ($group in $filesByDirectory) {
            $sourceDir = $group.Name
            $fileNames = $group.Group | ForEach-Object { "`"$($_.Name)`"" }
            # Nota: Exclusiones de directorios (/XD) no aplican bien al modo archivo, se omiten aquí
            $currentArgs = @("`"$sourceDir`"", "`"$destinationPath`"") + $fileNames + $baseRoboCopyArgs + $logArg
            
            Write-Host "Procesando archivos desde: $sourceDir" -ForegroundColor Gray
            Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow
        }
    } else {
        # Copia de Carpetas Completas
        $folderArgs = $baseRoboCopyArgs
        if ($Mode -eq 'Mirror') { $folderArgs += "/MIR" } else { $folderArgs += "/E" }
        $folderArgs += $excludeDirs

        foreach ($sourceFolder in $sourcePaths) {
            $folderName = Split-Path $sourceFolder -Leaf
            $destinationFolder = Join-Path $destinationPath $folderName
            
            Write-Host "`n[ROBOCOPY] Procesando: $folderName" -ForegroundColor Cyan
            $currentArgs = @("`"$sourceFolder`"", "`"$destinationFolder`"") + $folderArgs + $logArg
            
            # Usamos PassThru para capturar el código de salida
            $proc = Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow -PassThru
            
            # Manejo de Códigos de Salida de Robocopy (0-7 es Exito, >=8 es Error)
            if ($proc.ExitCode -ge 8) {
                Write-Error "Errores detectados en '$folderName' (Codigo: $($proc.ExitCode)). Revisa el log."
                Write-Log -LogLevel ERROR -Message "BACKUP: Fallo en '$folderName'. Codigo Robocopy: $($proc.ExitCode)"
            } elseif ($proc.ExitCode -ge 0) {
                Write-Host "   -> Completado (Codigo: $($proc.ExitCode))." -ForegroundColor Green
            }
        }
    }

    Write-Host "`n[FIN] Copia finalizada." -ForegroundColor Green
    
    # 7. Ejecución de la Verificación (Si se seleccionó)
    switch ($verificationType) {
        'Fast' {
            Write-Log -LogLevel INFO -Message "BACKUP: Iniciando verificacion rapida."
            Invoke-BackupRobocopyVerification -logFile $logFile -baseRoboCopyArgs $baseRoboCopyArgs -backupType $backupType -sourcePaths $sourcePaths -destinationPath $destinationPath -Mode $Mode
        }
        'Deep' {
            Write-Log -LogLevel INFO -Message "BACKUP: Iniciando verificacion profunda (Hash SHA256)."
            # Llama a la funcion auxiliar de Hash (debe estar definida en el script principal)
            Invoke-BackupHashVerification -sourcePaths $sourcePaths -destinationPath $destinationPath -backupType $backupType -logFile $logFile
        }
    }
    
    Write-Host "Log guardado en: $logFile"
    Read-Host "Presiona Enter para volver..."
}

# --- FUNCION 3: INTERFAZ DE USUARIO DEL MODULO DE RESPALDO ---
function Show-UserDataBackupMenu {
    # Funcion interna para no repetir el menu de seleccion de modo
    function Get-BackupMode {
        Write-Host ""
        Write-Host "--- Elige un modo de respaldo ---" -ForegroundColor Yellow
        Write-Host "   [1] Simple (Copiar y Actualizar)"
        Write-Host "       Copia archivos nuevos o modificados. No borra nada en el destino." -ForegroundColor Gray
        Write-Host "   [2] Sincronizacion (Espejo)"
        Write-Host "       Hace que el destino sea identico al origen. Borra archivos en el destino." -ForegroundColor Red
        
        $modeChoice = Read-Host "`nSelecciona el modo"
        
        switch ($modeChoice) {
            '1' { return 'Copy' }
            '2' { return 'Mirror' }
            default {
                Write-Warning "Opcion invalida." ; Start-Sleep -Seconds 2
                return $null
            }
        }
    }

    $backupChoice = ''
    do {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Herramienta de Respaldo de Datos de Usuario " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "--- Elige un tipo de respaldo ---" -ForegroundColor Yellow
        Write-Host "   [1] Respaldo de Perfil de Usuario (Escritorio, Documentos, etc.)"
        Write-Host "   [2] Respaldo de Carpeta o Archivo(s) Personalizado"
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $backupChoice = Read-Host "Selecciona una opcion"
        
        switch ($backupChoice.ToUpper()) {
            '1' {
				Write-Log -LogLevel INFO -Message "BACKUP: Usuario selecciono 'Respaldo de Perfil de Usuario'."
                $backupMode = Get-BackupMode
                if ($backupMode) {
                    Invoke-UserDataBackup -Mode $backupMode
                }
            }
            '2' {
				Write-Log -LogLevel INFO -Message "BACKUP: Usuario selecciono 'Respaldo Personalizado'."
                $typeChoice = Read-Host "Deseas seleccionar una [C]arpeta o [A]rchivo(s)?"
                $dialogType = ""
                $dialogTitle = ""

                if ($typeChoice.ToUpper() -eq 'C') {
                    $dialogType = 'Folder'
                    $dialogTitle = "Respaldo Personalizado: Elige la Carpeta de Origen"
                } elseif ($typeChoice.ToUpper() -eq 'A') {
                    $dialogType = 'File'
                    $dialogTitle = "Respaldo Personalizado: Elige el o los Archivo(s) de Origen"
                } else {
                    Write-Warning "Opcion invalida."; Start-Sleep -Seconds 2; continue
                }

                $customPath = Select-PathDialog -DialogType $dialogType -Title $dialogTitle

                if ($customPath) {
                    $backupMode = Get-BackupMode
                    if ($backupMode) {
                        Invoke-UserDataBackup -Mode $backupMode -CustomSourcePath $customPath
                    }
                } else {
                    Write-Warning "No se selecciono ninguna ruta. Operacion cancelada."
                    Start-Sleep -Seconds 2
                }
            }
            'V' { continue }
            default { Write-Warning "Opcion no valida." ; Start-Sleep -Seconds 2 }
        }
    } while ($backupChoice.ToUpper() -ne 'V')
}

# ===================================================================
# --- MoDULO DE INVENTARIO PROFESIONAL ---
# ===================================================================

function Get-DetailedWindowsVersion {
    try {
        # Intentamos obtener los datos del registro. Si falla, no detiene el script (SilentlyContinue)
        $winVerInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue

        # Definimos valores por defecto por si el registro falla
        $baseProductName = "Windows (Desconocido)"
        $friendlyEdition = "Edición Desconocida"
        $fullBuildString = "Build Desconocida"
        $osArch = "Arquitectura Desconocida"

        # Intentamos obtener arquitectura de forma segura
        try { 
            $osArch = (Get-ComputerInfo -ErrorAction Stop).OsArchitecture 
        } catch { 
            $osArch = $env:PROCESSOR_ARCHITECTURE 
        }

        # Validación de datos del registro
        if ($winVerInfo) {
            $buildNumber = 0
            if ($winVerInfo.CurrentBuildNumber) { 
                $buildNumber = [int]$winVerInfo.CurrentBuildNumber 
            }
            
            $ubrNumber = if ($winVerInfo.UBR) { $winVerInfo.UBR } else { "0" }
            $fullBuildString = "$buildNumber.$ubrNumber"
            
            # Lógica de nombre base
            $baseProductName = "Windows 10"
            if ($buildNumber -ge 22000) { $baseProductName = "Windows 11" }

            # Lógica de Edición
            $editionId = if ($winVerInfo.EditionID) { $winVerInfo.EditionID } else { "Unknown" }
            
            $friendlyEdition = switch ($editionId) {
                "Core"                        { "Home" }
                "CoreSingleLanguage"          { "Home Single Language" }
                "Professional"                { "Pro" }
                "ProfessionalCountrySpecific" { "Pro Country Specific" }
                "ProfessionalSingleLanguage"  { "Pro Single Language" }
                "ProfessionalWorkstation"     { "Pro for Workstations" }
                "ProfessionalEducation"       { "Pro Education" }
                "Enterprise"                  { "Enterprise" }
                "EnterpriseS"                 { "Enterprise LTSC" }
                "IoTEnterprise"               { "IoT Enterprise" }
                "IoTEnterpriseS"              { "IoT Enterprise LTSC" }
                "IoTEnterpriseK"              { "IoT Enterprise K" }
                "Education"                   { "Education" }
                "ServerRdsh"                  { "Enterprise Multi-Session" }
                "CloudEdition"                { "Cloud" }
                default                       { $editionId }
            }
        }
        
        return "$baseProductName $friendlyEdition $osArch (Build: $fullBuildString)"
    }
    catch {
        # Fallback de emergencia en caso de error crítico
        Write-Warning "No se pudo detectar la versión detallada de Windows. Usando información básica."
        return "Windows Detectado (Error al leer versión detallada)"
    }
}

# --- FUNCIoN AUXILIAR 1: Recopilador de Datos Exhaustivo ---
function Get-SystemInventoryData {
    Write-Host "`n[+] Recopilando informacion exhaustiva del sistema. Esto puede tardar un momento..." -ForegroundColor Yellow
    
    # -- Sistema y Rendimiento --
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $csInfo = Get-ComputerInfo
    $uptime = (Get-Date) - $osInfo.LastBootUpTime
    $physicalCores = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
    
    # --- NUEVO: Calculo de RAM Maxima Soportada ---
    $maxRamInfo = Get-CimInstance -ClassName Win32_PhysicalMemoryArray | Measure-Object -Property MaxCapacity -Sum
    $maxRamGB = if ($maxRamInfo.Sum -gt 0) { 
        [math]::Round($maxRamInfo.Sum / 1024 / 1024, 0) # Convertir KB a GB
    } else { "Desconocido" }
    # ---------------------------------------------

    $systemData = @{
        WindowsVersion = Get-DetailedWindowsVersion
        Hostname = $csInfo.CsName
        Procesador = ($csInfo.CsProcessors | Select-Object -First 1).Name
        Nucleos = "$physicalCores fisicos. $($csInfo.CsNumberOfLogicalProcessors) logicos."
        MemoriaTotalGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        MemoriaMaxGB   = $maxRamGB  # <--- Agregado aqui
        MemoriaEnUsoPorc = [math]::Round((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100, 2)
        Uptime = "$($uptime.Days) dias, $($uptime.Hours) horas, $($uptime.Minutes) minutos"
    }

    # -- Hardware Detallado --
    $tempTxtPath = Join-Path $env:TEMP "dxdiag.txt"
    $gpuInfo = try {
        $dxdiagRegPath = "HKCU:\Software\Microsoft\DxDiag"
        if (-not (Test-Path $dxdiagRegPath)) { New-Item -Path $dxdiagRegPath -Force | Out-Null }
        Set-ItemProperty -Path $dxdiagRegPath -Name "bOnceRun" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $tempTxtPath) { Remove-Item $tempTxtPath -Force }

        Start-Process "dxdiag.exe" -ArgumentList "/t $tempTxtPath" -Wait -WindowStyle Hidden
        
        if (Test-Path $tempTxtPath) {
            $dxdiagContent = Get-Content $tempTxtPath
            $cardName = ($dxdiagContent | Select-String -Pattern "Card name:").Line -split ':', 2 | Select-Object -Last 1 | ForEach-Object { $_.Trim() }
            $driverVersion = ""
            foreach ($line in $dxdiagContent) {
                if ($line -match "^\s*Driver Version:\s*(.+)$") {
                    $driverVersion = $matches[1].Trim()
                    break
                }
            }
            $vramString = ($dxdiagContent | Select-String -Pattern "Dedicated Memory:").Line
            
            $vram_gb = 0
            if ($vramString -match '(\d+)\s*MB') {
                $vram_gb = [math]::Round([int]$matches[1] / 1024, 2)
            }

            [PSCustomObject]@{
                Name          = $cardName
                DriverVersion = $driverVersion
                VRAM_GB       = $vram_gb
            }
        } else {
            throw "El archivo DxDiag.txt no se pudo crear."
        }
    } catch {
        Write-Warning "El metodo principal con DxDiag.txt fallo. Usando WMI como fallback."
        Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1 | ForEach-Object {
            [PSCustomObject]@{
                Name          = $_.Name
                DriverVersion = $_.DriverVersion
                VRAM_GB       = [math]::Round($_.AdapterRAM / 1GB, 2)
            }
        }
    } finally {
        if (Test-Path $tempTxtPath) { Remove-Item $tempTxtPath -Force }
    }

    # -- Asignacion final al objeto de Hardware --
    $hardwareData = @{
        PlacaBase = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object Manufacturer, Product, SerialNumber
        BIOS      = "Ver. $((Get-CimInstance -ClassName Win32_BIOS).SMBIOSBIOSVersion) Tipo de Arranque. ($(if (Test-Path "$env:windir\Boot\EFI") { 'UEFI' } else { 'Legacy' }))"
        GPU       = $gpuInfo 
    }

    # -- Estado de Seguridad --
    $securityData = @{
        Antivirus = try { @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop) } catch { @() };
        Firewall = try { @(Get-NetFirewallProfile -ErrorAction Stop) } catch { @() };
        BitLocker = try {
            $vol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
            if ($vol.ProtectionStatus -eq 'On') { "Activado (Proteccion: $($vol.ProtectionStatus))" } else { "Inactivo (Proteccion: $($vol.ProtectionStatus))" }
        } catch { "No Disponible" }
    }    
    
    # -- Discos y Red --
    $diskData = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object {
        [PSCustomObject]@{
            Dispositivo = $_.DeviceID; Nombre = $_.VolumeName; Tipo = $_.FileSystem
            TamanoTotalGB = [math]::Round($_.Size / 1GB, 2); EspacioLibreGB = [math]::Round($_.FreeSpace / 1GB, 2)
            UsoPorc = if ($_.Size -gt 0) { [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2) } else { 0 }
        }
    }
    $networkData = Get-NetAdapter | Select-Object Name, ifIndex, InterfaceDescription, Status, MacAddress, LinkSpeed

    # -- OS Config y Procesos --
    $osConfigData = @{
        Hotfixes = Get-HotFix | Sort-Object -Property InstalledOn -Descending | Select-Object -First 15
        TopCPU = Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 5 Name, Id, CPU
        TopMemory = Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First 5 Name, Id, @{Name="Memoria_MB"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}}
    }

    # -- Software --
    $softwareData = Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
        Select-Object DisplayName, DisplayVersion, Publisher, @{
            Name = 'InstallDate'
            Expression = {
                if ($_.InstallDate -and $_.InstallDate -match '^\d{8}$') {
                    try { [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd') }
                    catch { $_.InstallDate }
                } else { $_.InstallDate }
            }
        } | Where-Object { $_.DisplayName } | Sort-Object DisplayName

    # -- Salud Discos Fisicos --
    $physicalDiskData = Get-PhysicalDisk | Select-Object FriendlyName, MediaType, SerialNumber, @{N='HealthStatus'; E={
        switch ($_.HealthStatus) {
            'Healthy'   { 'Saludable' }
            'Warning'   { 'Advertencia' }
            'Unhealthy' { 'No saludable' }
            default     { $_.HealthStatus }
        }
    }
}

    # -- Detalles RAM, Usuarios, Puertos --
    $ramDetails = Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object DeviceLocator, Manufacturer, PartNumber, Capacity, Speed
    $localUsers = Get-LocalUser | Select-Object Name, Enabled, LastLogon
    $adminUsers = Get-LocalGroupMember -Group "Administradores" | Select-Object Name, PrincipalSource
    $listeningPorts = Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess | Sort-Object LocalPort
    $powerPlan = if ((powercfg /getactivescheme) -match '\((.*?)\)') { $matches[1] } else { (powercfg /getactivescheme) }

    # -- Objeto final --
    return [PSCustomObject]@{
        System = $systemData; Hardware = $hardwareData; Security = $securityData; Disks = $diskData
        Network = $networkData; OSConfig = $osConfigData; Software = $softwareData
        PhysicalDisks = $physicalDiskData
        RAMDetails = $ramDetails
        LocalUsers = $localUsers
        AdminUsers = $adminUsers
        ListeningPorts = $listeningPorts
        PowerPlan = $powerPlan
        ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

# --- FUNCIoN AUXILIAR 2: Constructor del HTML Profesional ---
function Build-FullInventoryHtmlReport {
    param ([Parameter(Mandatory=$true)] $InventoryData)

    # --- Paleta de colores y CSS rediseñados ---
    $head = @"
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Inventario - Aegis Phoenix Suite</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    <style>
        :root { 
            --bg-color: #f4f7f9;
            --main-text-color: #2c3e50;
            --primary-color: #2980b9;
            --secondary-color: #34495e;
            --card-bg-color: #ffffff;
            --header-text-color: #ecf0f1;
            --border-color: #dfe6e9;
            --danger-color: #c0392b;
            --warning-color: #f39c12;
            --shadow: 0 5px 15px rgba(0,0,0,0.08);
        }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: var(--main-text-color); background-color: var(--bg-color); max-width: 1400px; margin: auto; padding: 20px; }
        .header { background: linear-gradient(135deg, var(--secondary-color) 0%, var(--primary-color) 100%); color: var(--header-text-color); padding: 30px; border-radius: 8px; margin-bottom: 30px; box-shadow: var(--shadow); }
        h1, h2 { margin: 0; font-weight: 600; }
        h1 { font-size: 2.8em; display: flex; align-items: center; } h1 i { margin-right: 15px; } /* Titulo mas grande */
        h2 { color: var(--secondary-color); border-bottom: 2px solid var(--border-color); padding-bottom: 10px; margin: 0 0 20px 0; font-size: 1.8em; display: flex; align-items: center; } h2 i { margin-right: 10px; color: var(--primary-color); }
        .timestamp { font-size: 1em; opacity: 0.9; margin-top: 5px; }
        .section { background-color: var(--card-bg-color); border-radius: 8px; padding: 25px; margin-bottom: 25px; box-shadow: var(--shadow); }
        .grid-container { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px; }
        .info-label { font-weight: 600; color: var(--primary-color); }
        table { width: 100%; border-collapse: collapse; font-size: 0.9em; margin-top: 15px; }
        th { background-color: var(--secondary-color); color: var(--header-text-color); text-align: left; padding: 12px 15px; font-weight: 600; }
        td { padding: 10px 15px; border-bottom: 1px solid var(--border-color); }
        tr:nth-child(even) { background-color: #fdfdfd; } tr:hover { background-color: #f1f5f8; }
        .progress-container { width: 100px; height: 10px; background-color: var(--border-color); border-radius: 5px; overflow: hidden; display: inline-block; margin-left: 10px; }
        .progress-bar { height: 100%; }
        .search-box input { width: 98%; padding: 10px 15px; border: 1px solid var(--border-color); border-radius: 5px; margin-bottom: 15px; font-size: 1em; }
        .footer { text-align: center; margin-top: 40px; color: #6c757d; font-size: 0.8em; }
		/* --- Estilos para la Barra de Navegacion --- */
        .navbar {
            background-color: var(--secondary-color);
            overflow: visible; /* Permitimos que las sombras se vean */
            position: sticky;
            top: 0;
            width: 100%;
            z-index: 1000;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            padding: 8px 5px; /* <-- Añadimos padding para espaciar los botones de la barra */
        }
        .navbar a {
            color: var(--header-text-color);
            background-color: var(--primary-color); /* <-- Color de fondo del boton (azul) */
            text-align: center;
            padding: 10px 15px; /* <-- Hacemos el padding un poco mas compacto */
            text-decoration: none;
            font-size: 0.9em;
            font-weight: 600; /* <-- Hacemos el texto mas grueso */
            border-radius: 5px; /* <-- ¡Esquinas redondeadas! */
            margin: 4px; /* <-- Espacio entre cada boton */
            box-shadow: 0 2px 4px rgba(0,0,0,0.2); /* <-- Sombra para dar profundidad */
            transition: all 0.2s ease-out; /* <-- Transicion suave para todo */
        }
        .navbar a:hover {
            background-color: var(--primary-color);
            color: #ffffff;
        }
    </style>
</head>
"@
  
    $body = "<body>"
	$body += @"
    <div class="navbar">
        <a href="#sistema">Sistema</a>
        <a href="#hardware">Hardware</a>
        <a href="#ram">RAM</a>
        <a href="#usuarios">Usuarios</a>
        <a href="#seguridad">Seguridad</a>
        <a href="#discos">Discos</a>
        <a href="#salud-discos">Salud Discos</a>
        <a href="#procesos">Procesos</a>
        <a href="#updates">Updates</a>
        <a href="#software">Software</a>
    </div>
"@
    $body += "<h1><i class='fas fa-shield-alt'></i>Aegis Phoenix Suite - Reporte de Inventario</h1>"
    $body += "<p class='timestamp'>Generado el: $($InventoryData.ReportDate) para el equipo $($InventoryData.System.Hostname)</p>"

    # Funcion interna para generar barras de progreso
    function Get-ProgressBarHtml($value) {
        $color = if ($value -gt 90) { 'var(--danger-color)' } elseif ($value -gt 75) { 'var(--warning-color)' } else { 'var(--primary-color)' }
        return "<div class='progress-container'><div class='progress-bar' style='width: $($value)%; background-color: $($color);'></div></div>"
    }

    # -- Secciones --
    $body += "<div class='section' id='sistema'><h2><i class='fas fa-desktop'></i>Sistema Operativo y CPU</h2><div class='grid-container'>"
    $body += "<div><span class='info-label'>Sistema:</span> $($InventoryData.System.WindowsVersion)</div>"
    $body += "<div><span class='info-label'>Procesador:</span> $($InventoryData.System.Procesador)</div>"
    $body += "<div><span class='info-label'>Nucleos:</span> $($InventoryData.System.Nucleos)</div>"
    $body += "<div><span class='info-label'>Tiempo de Actividad:</span> $($InventoryData.System.Uptime)</div>"
    $body += "<div><span class='info-label'>Memoria RAM Instalada:</span> $($InventoryData.System.MemoriaTotalGB) GB $($InventoryData.System.MemoriaEnUsoPorc)% Usado" + (Get-ProgressBarHtml($InventoryData.System.MemoriaEnUsoPorc)) + "</div>"
	$body += "<div><span class='info-label'>Capacidad Maxima Soportada (segun BIOS):</span> <strong>$($InventoryData.System.MemoriaMaxGB) GB</strong></div>"
    $body += "</div></div>"

    $body += "<div class='section' id='hardware'><h2><i class='fas fa-microchip'></i>Hardware Detallado</h2><div class='grid-container'>"
    $body += "<div><span class='info-label'>Placa Base:</span> $($InventoryData.Hardware.PlacaBase.Manufacturer) $($InventoryData.Hardware.PlacaBase.Product)</div>"
    $body += "<div><span class='info-label'>BIOS:</span> $($InventoryData.Hardware.BIOS)</div>"
        foreach ($gpu in $InventoryData.Hardware.GPU) {
        $body += "<div><span class='info-label'>GPU:</span> $($gpu.Name) ($($gpu.VRAM_GB) GB VRAM)</div>"
        $body += "<div><span class='info-label'>Driver de Video:</span> $($gpu.DriverVersion)</div>"
    }
    $body += "</div></div>"

    # --- MODULOS DE RAM ---
    $body += "<div class='section' id='ram'><h2><i class='fas fa-memory'></i>Modulos de Memoria RAM</h2><table id='ramTable'><thead><tr><th>Ranura (Slot)</th><th>Fabricante</th><th>No. de Serie</th><th>Capacidad (GB)</th><th>Velocidad (MHz)</th></tr></thead><tbody>"
        foreach ($ram in $InventoryData.RAMDetails) {
    $body += "<tr><td>$($ram.DeviceLocator)</td><td>$($ram.Manufacturer)</td><td>$($ram.PartNumber)</td><td>$([math]::Round($ram.Capacity / 1GB, 2))</td><td>$($ram.Speed)</td></tr>"
    }
    $body += "</tbody></table></div>"

    # --- CUENTAS DE USUARIO Y ADMINS ---
    $body += "<div class='section' id='usuarios'><h2><i class='fas fa-users-cog'></i>Cuentas de Usuario y Administradores</h2><div class='grid-container'>"
    $body += "<div><h3>Cuentas Locales</h3><div class='search-box'><input type='text' id='userSearch' onkeyup=`"searchTable('userSearch', 'userTable')`" placeholder='Buscar usuario...'></div><table id='userTable'><thead><tr><th>Nombre</th><th>Habilitado</th><th>Ultimo Inicio de Sesion</th></tr></thead><tbody>"
        foreach($user in $InventoryData.LocalUsers){ $body += "<tr><td>$($user.Name)</td><td>$($user.Enabled)</td><td>$($user.LastLogon)</td></tr>" }
    $body += "</tbody></table></div>"
    $body += "<div><h3>Miembros del Grupo de Administradores</h3><div class='search-box'><input type='text' id='adminSearch' onkeyup=`"searchTable('adminSearch', 'adminTable')`" placeholder='Buscar administrador...'></div><table id='adminTable'><thead><tr><th>Nombre</th><th>Origen</th></tr></thead><tbody>"
        foreach($admin in $InventoryData.AdminUsers){ $body += "<tr><td>$($admin.Name)</td><td>$($admin.PrincipalSource)</td></tr>" }
    $body += "</tbody></table></div></div></div>"

    # --- PLAN DE ENERGIA ---
    $body += "<div class='section' id='energia'><h2><i class='fas fa-bolt'></i>Plan de Energia Activo</h2><p>$($InventoryData.PowerPlan)</p></div>"

    # --- PUERTOS ABIERTOS ---
    $body += "<div class='section' id='puertos'><h2><i class='fas fa-network-wired'></i>Puertos de Red Abiertos (Escuchando)</h2><div class='search-box'><input type='text' id='portSearch' onkeyup=`"searchTable('portSearch', 'portTable')`" placeholder='Buscar por puerto o proceso...'></div><table id='portTable'><thead><tr><th>Direccion Local</th><th>Puerto</th><th>ID de Proceso</th></tr></thead><tbody>"
        foreach ($port in $InventoryData.ListeningPorts) {
    $body += "<tr><td>$($port.LocalAddress)</td><td>$($port.LocalPort)</td><td>$($port.OwningProcess)</td></tr>"
    }
    $body += "</tbody></table></div>"

    $body += "<div class='section' id='seguridad'><h2><i class='fas fa-lock'></i>Estado de Seguridad</h2><div class='grid-container'>"
    $avNames = if ($InventoryData.Security.Antivirus) { ($InventoryData.Security.Antivirus.displayName -join ', ') } else { 'No Detectado' }
    $body += "<div><span class='info-label'>Antivirus Registrado:</span> $avNames</div>"
    $firewallStatus = ($InventoryData.Security.Firewall | ForEach-Object { "$($_.Name): $(if($_.Enabled){'Activado'}else{'Desactivado'})" }) -join ' | '
    $body += "<div><span class='info-label'>Firewall:</span> $firewallStatus</div>"
    $body += "<div><span class='info-label'>Cifrado de Disco (BitLocker):</span> $($InventoryData.Security.BitLocker)</div>"
    $body += "</div></div>"

    $body += "<div class='section' id='discos'><h2><i class='fas fa-hdd'></i>Discos</h2><div class='search-box'><input type='text' id='disksSearch' onkeyup=`"searchTable('disksSearch', 'disksTable')`" placeholder='Buscar en discos...'></div><table id='disksTable'><thead><tr><th>Dispositivo</th><th>Tipo</th><th>Tamano (GB)</th><th>Libre (GB)</th><th>Uso</th></tr></thead><tbody>"
        foreach ($disk in $InventoryData.Disks) { $body += "<tr><td>$($disk.Dispositivo) ($($disk.Nombre))</td><td>$($disk.Tipo)</td><td>$($disk.TamanoTotalGB)</td><td>$($disk.EspacioLibreGB)</td><td>$($disk.UsoPorc)%" + (Get-ProgressBarHtml($disk.UsoPorc)) + "</td></tr>" }
    $body += "</tbody></table></div>"
	
	# ---salud de discos fisicos ---
    $body += "<div class='section' id='salud-discos'><h2><i class='fas fa-heartbeat'></i>Diagnostico de Salud de Discos (S.M.A.R.T.)</h2><div class='search-box'><input type='text' id='smartSearch' onkeyup=`"searchTable('smartSearch', 'smartTable')`" placeholder='Buscar por nombre o estado...'></div><table id='smartTable'><thead><tr><th>Nombre</th><th>Tipo</th><th>No. de Serie</th><th>Estado de Salud</th></tr></thead><tbody>"
    foreach ($pdisk in $InventoryData.PhysicalDisks) {
        $healthColor = switch ($pdisk.EstadoSalud) {
            'Saludable'   { 'var(--success-color)' }
            'Advertencia' { 'var(--warning-color)' }
            'No saludable' { 'var(--danger-color)' }
            default       { 'var(--main-text-color)' }
        }
        $body += "<tr><td>$($pdisk.FriendlyName)</td><td>$($pdisk.MediaType)</td><td>$($pdisk.SerialNumber)</td><td style='color: $healthColor;'><strong>$($pdisk.HealthStatus)</strong></td></tr>"
    }
    $body += "</tbody></table></div>"
    
    $body += "<div class='section' id='procesos'><h2><i class='fas fa-chart-line'></i>Procesos de Mayor Consumo</h2><div class='grid-container'>"
    $body += "<div><h3>Top 5 por CPU</h3><table><thead><tr><th>Nombre</th><th>CPU</th></tr></thead><tbody>"
    foreach($p in $InventoryData.OSConfig.TopCPU){ $body += "<tr><td>$($p.Name)</td><td>$($p.CPU)</td></tr>" }
    $body += "</tbody></table></div>"
    $body += "<div><h3>Top 5 por Memoria</h3><table><thead><tr><th>Nombre</th><th>Memoria (MB)</th></tr></thead><tbody>"
    foreach($p in $InventoryData.OSConfig.TopMemory){ $body += "<tr><td>$($p.Name)</td><td>$($p.Memoria_MB)</td></tr>" }
    $body += "</tbody></table></div></div></div>"
    
    $body += "<div class='section' id='updates'><h2><i class='fas fa-history'></i>Ultimas Actualizaciones Instaladas</h2><table><thead><tr><th>ID</th><th>Descripcion</th><th>Fecha</th></tr></thead><tbody>"
    foreach ($hotfix in $InventoryData.OSConfig.Hotfixes) {
        $body += "<tr><td>$($hotfix.HotFixID)</td><td>$($hotfix.Description)</td><td>$($hotfix.InstalledOn.ToString('yyyy-MM-dd'))</td></tr>"
    }
    $body += "</tbody></table></div>"

    # --- Instalacion al HTML ---
    $body += "<div class='section' id='software'><h2><i class='fas fa-box-open'></i>Software Instalado ($($InventoryData.Software.Count))</h2>"
    $body += "<div class='search-box'><input type='text' id='softwareSearch' onkeyup='searchSoftware()' placeholder='Buscar software por nombre...'></div>"
    $body += "<table id='softwareTable'><thead><tr><th>Nombre</th><th>Version</th><th>Editor</th><th>Fecha de Instalacion</th></tr></thead><tbody>"
    foreach ($app in $InventoryData.Software) {
        $body += "<tr><td>$($app.DisplayName)</td><td>$($app.DisplayVersion)</td><td>$($app.Publisher)</td><td>$($app.InstallDate)</td></tr>"
    }
    $body += "</tbody></table></div>"
    
    $body += @"
        <script>
            function searchSoftware() {
                const filter = document.getElementById('softwareSearch').value.toUpperCase();
                const rows = document.getElementById('softwareTable').getElementsByTagName('tbody')[0].rows;
                for (let i = 0; i < rows.length; i++) {
                    const name = rows[i].cells[0].textContent.toUpperCase();
                    if (name.indexOf(filter) > -1) { rows[i].style.display = ""; } else { rows[i].style.display = "none"; }
                }
            }
        </script>
        <div class="footer"><p>Aegis Phoenix Suite by SOFTMAXTER</p></div>
    </body>
"@
    return "<!DOCTYPE html><html lang='es'>$($head)$($body)</html>"
}

# --- FUNCIoN PRINCIPAL DEL MENu ---
function Show-InventoryMenu {
    Clear-Host
    Write-Host "--- Generador de Reportes de Inventario Profesional ---" -ForegroundColor Cyan
    Write-Host "Este modulo recopila una gran cantidad de datos y los exporta en varios formatos."
    Write-Host ""
	Write-Host "   [1] Archivo de Texto (.txt) - Completo y detallado."
    Write-Host "   [2] Pagina Web (.html)      - Reporte profesional e interactivo."
    Write-Host "   [3] Hojas de Calculo (.csv) - Multiples archivos para analisis de datos."

    $formatChoice = Read-Host "`nElige una opcion"
	Write-Log -LogLevel INFO -Message "INVENTORY: Usuario selecciono generar reporte en formato '$formatChoice'."
    $parentDir = Split-Path -Parent $PSScriptRoot
    $reportDir = Join-Path -Path $parentDir -ChildPath "Reportes"
    if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory -Force | Out-Null }
    
    $inventoryData = Get-SystemInventoryData
    $title = "Reporte de Inventario - Aegis Phoenix Suite - $($inventoryData.ReportDate)"
    $reportBaseName = "Reporte_Inventario_$($inventoryData.System.Hostname)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

    switch ($formatChoice) {
       '1' { # TXT
            $reportPath = Join-Path -Path $reportDir -ChildPath "$($reportBaseName).txt"
            $reportContent = @()
            
            $reportContent += "Reporte de Inventario - Aegis Phoenix Suite - $($inventoryData.ReportDate)"
            $reportContent += "================================================="
            
            # --- SECCIoN: SISTEMA Y CPU (Formato manual para mejor claridad) ---
            $reportContent += ""
            $reportContent += "=== SISTEMA OPERATIVO Y CPU ==="
			$reportContent += ""
            $reportContent += "WindowsVersion   : $($inventoryData.System.WindowsVersion)"
            $reportContent += "Hostname         : $($inventoryData.System.Hostname)"
            $reportContent += "Procesador       : $($inventoryData.System.Procesador)"
            $reportContent += "Nucleos          : $($inventoryData.System.Nucleos)"
            $reportContent += "MemoriaTotalGB   : $($inventoryData.System.MemoriaTotalGB)"
			$reportContent += "MemoriaMaxGB     : $($inventoryData.System.MemoriaMaxGB)"
            $reportContent += "MemoriaEnUsoPorc : $($inventoryData.System.MemoriaEnUsoPorc)"
            $reportContent += "Uptime           : $($inventoryData.System.Uptime)"
            
            # --- SECCIoN: HARDWARE (Formato manual) ---
            $reportContent += ""
            $reportContent += "=== HARDWARE DETALLADO ==="
			$reportContent += ""
            $reportContent += "Placa Base       : $($inventoryData.Hardware.PlacaBase.Manufacturer) $($inventoryData.Hardware.PlacaBase.Product)"
            $reportContent += "BIOS             : $($inventoryData.Hardware.BIOS)"
                foreach ($gpu in $inventoryData.Hardware.GPU) {
                $reportContent += "GPU              : $($gpu.Name) ($($gpu.VRAM_GB) GB VRAM)"
                $reportContent += "Driver de Video  : $($gpu.DriverVersion)"
            }

            $reportContent += ""
            $reportContent += "=== MODULOS DE MEMORIA RAM ==="
            $ramTable = $inventoryData.RAMDetails | ForEach-Object {
            [PSCustomObject]@{
                Ranura = $_.DeviceLocator
                Fabricante = $_.Manufacturer
                'No. de Serie' = $_.PartNumber
                'Capacidad (GB)' = [math]::Round($_.Capacity / 1GB, 2)
                'Velocidad (MHz)' = $_.Speed
                }
            }
            $reportContent += ($ramTable | Format-Table -Wrap | Out-String).TrimEnd()

            $reportContent += ""
            $reportContent += "=== CUENTAS DE USUARIO LOCALES ==="
            $reportContent += ($inventoryData.LocalUsers | Format-Table -Wrap | Out-String).TrimEnd()

            $reportContent += ""
            $reportContent += "=== MIEMBROS DEL GRUPO DE ADMINISTRADORES ==="
            $reportContent += ($inventoryData.AdminUsers | Format-Table -Wrap | Out-String).TrimEnd()

            $reportContent += ""
            $reportContent += "=== PLAN DE ENERGIA ACTIVO ==="
			$reportContent += ""
            $reportContent += $inventoryData.PowerPlan

            $reportContent += ""
            $reportContent += "=== PUERTOS DE RED ABIERTOS (ESCUCHANDO) ==="
            $reportContent += ($inventoryData.ListeningPorts | Format-Table -Wrap | Out-String).TrimEnd()

            # --- SECCIoN: SEGURIDAD
            $reportContent += ""
            $reportContent += "=== ESTADO DE SEGURIDAD ==="
			$reportContent += ""
            $reportContent += "Antivirus : $(if ($inventoryData.Security.Antivirus) { ($inventoryData.Security.Antivirus.displayName -join ', ') } else { 'No Detectado' })"
            $reportContent += "Firewall  : $(($inventoryData.Security.Firewall | ForEach-Object { "$($_.Name): $(if($_.Enabled){'Activado'}else{'Desactivado'})" }) -join ' | ')"
            $reportContent += "BitLocker : $($inventoryData.Security.BitLocker)"

            # --- SECCIoN: DISCOS
            $reportContent += ""
            $reportContent += "=== DISCOS ==="
            $reportContent += ($inventoryData.Disks | Format-Table | Out-String).TrimEnd()
			
			# --- Añadimos la seccion de salud de discos fisicos ---
            $reportContent += ""
            $reportContent += "=== DIAGNOSTICO DE SALUD DE DISCOS (S.M.A.R.T.) ==="
            $reportContent += ($inventoryData.PhysicalDisks | Format-Table | Out-String).TrimEnd()

            # --- SECCIoN: RED
            $reportContent += ""
            $reportContent += "=== RED ==="
            $reportContent += ($inventoryData.Network | Format-Table -Wrap | Out-String).TrimEnd()

            # --- SECCIONES: PROCESOS
            $reportContent += ""
            $reportContent += "=== PROCESOS DE MAYOR CONSUMO (CPU) ==="
            $reportContent += ($inventoryData.OSConfig.TopCPU | Format-Table | Out-String).TrimEnd()
            $reportContent += ""
            $reportContent += "=== PROCESOS DE MAYOR CONSUMO (MEMORIA) ==="
            $reportContent += ($inventoryData.OSConfig.TopMemory | Format-Table | Out-String).TrimEnd()

            # --- SECCIoN: ACTUALIZACIONES
            $reportContent += ""
            $reportContent += "=== ULTIMAS ACTUALIZACIONES INSTALADAS ==="
            $reportContent += ($inventoryData.OSConfig.Hotfixes | Format-Table -Wrap | Out-String).TrimEnd()

            # --- SECCIoN: SOFTWARE
            $reportContent += ""
            $reportContent += "=== SOFTWARE INSTALADO ($($inventoryData.Software.Count)) ==="
            foreach ($app in $inventoryData.Software) {
                $reportContent += "-------------------------------------------------"
                $reportContent += "Nombre    : $($app.DisplayName)"
                $reportContent += "Version   : $($app.DisplayVersion)"
                $reportContent += "Editor    : $($app.Publisher)"
                $reportContent += "Instalado : $($app.InstallDate)"
            }
            $reportContent | Out-File -FilePath $reportPath -Encoding UTF8            
        }
        '2' { # HTML
            $reportPath = Join-Path -Path $reportDir -ChildPath "$($reportBaseName).html"
            $htmlContent = Build-FullInventoryHtmlReport -InventoryData $inventoryData
            Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8
        }
        '3' { # CSV
            Write-Host "Generando multiples archivos CSV..." -ForegroundColor Yellow
            $utf8Bom = [byte[]](0xEF, 0xBB, 0xBF)

            # Exportar Software
            $csvContent = $inventoryData.Software |
                Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
                ConvertTo-Csv -NoTypeInformation | Out-String
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)
            $allBytes = $utf8Bom + $bytes
            [System.IO.File]::WriteAllBytes((Join-Path $reportDir "$($reportBaseName)_Software.csv"), $allBytes)

            # Exportar Red
            $csvContent = $inventoryData.Network |
                Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed |
                ConvertTo-Csv -NoTypeInformation | Out-String
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)
            $allBytes = $utf8Bom + $bytes
            [System.IO.File]::WriteAllBytes((Join-Path $reportDir "$($reportBaseName)_Red.csv"), $allBytes)

            # Exportar Discos
            $csvContent = $inventoryData.Disks |
                ConvertTo-Csv -NoTypeInformation | Out-String
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)
            $allBytes = $utf8Bom + $bytes
            [System.IO.File]::WriteAllBytes((Join-Path $reportDir "$($reportBaseName)_Discos.csv"), $allBytes)

            # Exportar Hotfixes
            $csvContent = $inventoryData.OSConfig.Hotfixes |
                Select-Object Description, HotFixID, InstalledBy, @{N='InstalledOn'; E={$_.InstalledOn.ToString('yyyy-MM-dd')}} |
                ConvertTo-Csv -NoTypeInformation | Out-String
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)
            $allBytes = $utf8Bom + $bytes
            [System.IO.File]::WriteAllBytes((Join-Path $reportDir "$($reportBaseName)_Hotfixes.csv"), $allBytes)
            $reportPath = $reportDir
        }
        default { Write-Warning "Opcion no valida."; return }
        }
    Write-Host "`n[OK] Reporte(s) generado(s) exitosamente en: '$reportPath'" -ForegroundColor Green
    if ($formatChoice -ne '3') { Start-Process $reportPath
	    } else {
		    Start-Process $reportDir
	}
    Read-Host "`nPresiona Enter para volver..."
}

function Show-DriverMenu {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Gestion de Drivers."

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
                $destPath = Select-PathDialog -DialogType 'Folder' -Title "Selecciona la carpeta para GUARDAR la copia de drivers"
                if (-not [string]::IsNullOrWhiteSpace($destPath)) {
                    Write-Host "`n[+] Exportando drivers a '$destPath'..." -ForegroundColor Yellow
                    Export-WindowsDriver -Online -Destination $destPath
                    Write-Host "[OK] Copia de seguridad completada." -ForegroundColor Green
					Write-Log -LogLevel ACTION -Message "Copia de seguridad de drivers completada en '$destPath'."
                } else {
                    Write-Warning "Operacion cancelada."
                }
            }
            '2' {
				Write-Log -LogLevel INFO -Message "DRIVERS: El usuario listo los drivers de terceros instalados."
                Write-Host "`n[+] Listando drivers no-Microsoft instalados..." -ForegroundColor Yellow
                Get-WindowsDriver -Online | Where-Object { $_.ProviderName -ne 'Microsoft' } | Format-Table ProviderName, ClassName, Date, Version -AutoSize
            }
            '3' {
                $sourcePath = Select-PathDialog -DialogType 'Folder' -Title "Selecciona la CARPETA con la copia de drivers"
                if (-not [string]::IsNullOrWhiteSpace($sourcePath)) {
                    if ($PSCmdlet.ShouldProcess("el sistema", "Restaurar todos los drivers desde '$sourcePath'")) {
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
                                pnputil.exe /add-driver $inf.FullName /install
                            }
                            Write-Host "`n[OK] Proceso de restauracion de drivers completado." -ForegroundColor Green
						    Write-Log -LogLevel ACTION -Message "Proceso de restauracion de drivers desde '$sourcePath' completado."
                        }
                    }
                } else {
                    Write-Warning "Operacion cancelada."
                }
            }
            'V' {
                continue
            }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
            }
        }

        if ($driverChoice -ne 'V') {
            Read-Host "`nPresiona Enter para continuar..."
        }
    } while ($driverChoice.ToUpper() -ne 'V')
}

# ===================================================================
# --- MoDULO DE REUBICACIoN DE CARPETAS DE USUARIO ---
# ===================================================================

function Move-UserProfileFolders {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Reubicacion de Carpetas de Usuario."

    $folderMappings = @{
        'Escritorio' = @{ RegValue = 'Desktop'; DefaultName = 'Desktop' }
        'Documentos' = @{ RegValue = 'Personal'; DefaultName = 'Documents' }
        'Descargas'  = @{ RegValue = '{374DE290-123F-4565-9164-39C4925E467B}'; DefaultName = 'Downloads' }
        'Musica'     = @{ RegValue = 'My Music'; DefaultName = 'Music' }
        'Imagenes'   = @{ RegValue = 'My Pictures'; DefaultName = 'Pictures' }
        'Videos'     = @{ RegValue = 'My Video'; DefaultName = 'Videos' }
    }
    $registryPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

    Write-Host "`n[+] Paso 1: Selecciona la carpeta RAIZ donde se crearan las nuevas carpetas de usuario." -ForegroundColor Yellow
    Write-Host "    (Ejemplo: Si seleccionas 'D:\MisDatos', se crearan 'D:\MisDatos\Escritorio', 'D:\MisDatos\Documentos', etc.)" -ForegroundColor Gray
    $newBasePath = Select-PathDialog -DialogType Folder -Title "Selecciona la NUEVA UBICACION BASE para tus carpetas"
    
    if ([string]::IsNullOrWhiteSpace($newBasePath)) {
        Write-Warning "Operacion cancelada. No se selecciono una ruta de destino."
        Start-Sleep -Seconds 2
        return
    }
    
    $currentUserProfilePath = $env:USERPROFILE
    if ($newBasePath.StartsWith($currentUserProfilePath, [System.StringComparison]::OrdinalIgnoreCase)) {
         Write-Error "La nueva ubicacion base no puede estar dentro de tu perfil de usuario actual ('$currentUserProfilePath')."
         Read-Host "`nOperacion abortada. Presiona Enter para volver..."
         return
    }

    $selectableFolders = $folderMappings.Keys | Sort-Object
    $folderItems = @()
    foreach ($folderName in $selectableFolders) {
        $folderItems += [PSCustomObject]@{
            Name     = $folderName
            Selected = $false
        }
    }

    $choice = ''
    while ($choice.ToUpper() -ne 'C' -and $choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "      Selecciona las Carpetas de Usuario a Reubicar    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Nueva Ubicacion Base: $newBasePath" -ForegroundColor Yellow
        Write-Host "Marca las carpetas que deseas mover a esta nueva ubicacion."
        Write-Host ""
        
        for ($i = 0; $i -lt $folderItems.Count; $i++) {
            $item = $folderItems[$i]
            $status = if ($item.Selected) { "[X]" } else { "[ ]" }
            $currentPath = (Get-ItemProperty -Path $registryPath -Name $folderMappings[$item.Name].RegValue -ErrorAction SilentlyContinue).($folderMappings[$item.Name].RegValue)
            $currentPathExpanded = try { [Environment]::ExpandEnvironmentVariables($currentPath) } catch { $currentPath }
            Write-Host ("   [{0}] {1} {2,-12} -> Actual: {3}" -f ($i + 1), $status, $item.Name, $currentPathExpanded)
        }
        
        $selectedCount = $folderItems.Where({$_.Selected}).Count
        if ($selectedCount -gt 0) {
            Write-Host ""
            Write-Host "   ($selectedCount carpeta(s) seleccionada(s))" -ForegroundColor Cyan
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] Marcar/Desmarcar        [T] Marcar Todas"
        Write-Host "   [C] Continuar con la Reubicacion [N] Desmarcar Todas"
        Write-Host ""
        Write-Host "   [V] Cancelar y Volver" -ForegroundColor Red
        Write-Host ""
        $choice = Read-Host "Selecciona una opcion"

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $folderItems.Count) {
            $index = [int]$choice - 1
            $folderItems[$index].Selected = -not $folderItems[$index].Selected
        } elseif ($choice.ToUpper() -eq 'T') { $folderItems.ForEach({$_.Selected = $true}) }
        elseif ($choice.ToUpper() -eq 'N') { $folderItems.ForEach({$_.Selected = $false}) }
        elseif ($choice.ToUpper() -notin @('C', 'V')) {
             Write-Warning "Opcion no valida." ; Start-Sleep -Seconds 1
        }
    }

    if ($choice.ToUpper() -eq 'V') {
        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    $foldersToProcess = $folderItems | Where-Object { $_.Selected }
    if ($foldersToProcess.Count -eq 0) {
        Write-Warning "No se selecciono ninguna carpeta para mover."
        Start-Sleep -Seconds 2
        return
    }

    Clear-Host
    Write-Host "--- RESUMEN DE LA REUBICACION ---" -ForegroundColor Cyan
    Write-Host "Nueva Ubicacion Base: $newBasePath"
    Write-Host "Se modificaran las siguientes carpetas:" -ForegroundColor Yellow
    
    $operations = @()
    foreach ($folder in $foldersToProcess) {
        $regValueName = $folderMappings[$folder.Name].RegValue
        $currentPathReg = (Get-ItemProperty -Path $registryPath -Name $regValueName -ErrorAction SilentlyContinue).($regValueName)
        $currentPathExpanded = try { [Environment]::ExpandEnvironmentVariables($currentPathReg) } catch { $currentPathReg }
        $newFolderName = $folderMappings[$folder.Name].DefaultName
        $newFullPath = Join-Path -Path $newBasePath -ChildPath $newFolderName

        Write-Host " - $($folder.Name)"
        Write-Host "     Ruta Actual Registrada: $currentPathExpanded" -ForegroundColor Gray
        Write-Host "     NUEVA Ruta a Registrar: $newFullPath" -ForegroundColor Green
        
        $operations += [PSCustomObject]@{
            Name = $folder.Name
            RegValueName = $regValueName
            CurrentPath = $currentPathExpanded
            NewPath = $newFullPath
        }
    }

    Write-Warning "`n¡ADVERTENCIA MUY IMPORTANTE!"
    Write-Warning "- Cierra TODAS las aplicaciones que puedan estar usando archivos de estas carpetas."
    Write-Warning "- Si eliges 'Mover y Registrar', el proceso puede tardar MUCHO tiempo."
    Write-Warning "- NO interrumpas el proceso una vez iniciado."

    Write-Host ""
    Write-Host "--- TIPO DE ACCION ---" -ForegroundColor Yellow
    Write-Host "   [M] Mover Archivos Y Actualizar Registro (Accion Completa, Lenta)"
    Write-Host "   [R] Solo Actualizar Registro (Rapido - ¡ASEGURATE de que los archivos ya estan en el destino" -ForegroundColor Red
    Write-Host "       o el destino esta vacio!)" -ForegroundColor Red
    Write-Host "   [N] Cancelar"
    
    $actionChoice = Read-Host "`nElige el tipo de accion a realizar"
    $actionType = ''

    switch ($actionChoice.ToUpper()) {
        'M' { $actionType = 'MoveAndRegister' }
        'R' { $actionType = 'RegisterOnly' }
        default {
            Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            return
        }
    }

    Write-Warning "`nConfirmacion Final:"
    $confirmation = Read-Host "¿Estas COMPLETAMENTE SEGURO de continuar con la accion '$actionType'? (Escribe 'SI' para confirmar)"
    if ($confirmation -ne 'SI') {
        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    Write-Host "`n[+] Iniciando proceso. NO CIERRES ESTA VENTANA..." -ForegroundColor Yellow
    Write-Log -LogLevel INFO -Message "REUBICACION: Iniciando proceso con accion '$actionType' para $($operations.Count) carpetas hacia '$newBasePath'."
    $globalSuccess = $true
    $explorerRestartNeeded = $false

    foreach ($op in $operations) {
        Write-Host "`n--- Procesando Carpeta: $($op.Name) ---" -ForegroundColor Cyan
        
        # 1. Crear directorio de destino (Siempre necesario)
        Write-Host "  [1/3] Asegurando directorio de destino '$($op.NewPath)'..." -ForegroundColor Gray
        $destinationDirCreated = $false
        try {
            if (-not (Test-Path $op.NewPath)) {
                New-Item -Path $op.NewPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                 Write-Host "  -> Directorio creado." -ForegroundColor Green
            } else {
                 Write-Host "  -> Directorio ya existe." -ForegroundColor Gray
            }
            $destinationDirCreated = $true
        } catch {
            Write-Error "  -> FALLO al crear el directorio de destino. Omitiendo carpeta '$($op.Name)'. Error: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "REUBICACION: Fallo al crear directorio '$($op.NewPath)'. Carpeta '$($op.Name)' omitida. Error: $($_.Exception.Message)"
            $globalSuccess = $false
            continue
        }

        # 2. Mover contenido (Solo si se eligio la accion completa)
        $robocopySucceeded = $true # Asumimos exito si no se mueve nada
        if ($actionType -eq 'MoveAndRegister') {
            Write-Host "  [2/3] Moviendo contenido desde '$($op.CurrentPath)'..." -ForegroundColor Gray
            Write-Warning "      (Esto puede tardar. Se abrira una ventana de Robocopy por cada carpeta)"
            
            $robocopyLogDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs"
            $robocopyLogFile = Join-Path $robocopyLogDir "Robocopy_Move_$($op.Name)_$(Get-Date -Format 'yyyyMMddHHmmss').log"
            $robocopyArgs = @(
                "`"$($op.CurrentPath)`"" # Origen
                "`"$($op.NewPath)`""    # Destino
                "/MOVE"                 # Mueve archivos Y directorios (los elimina del origen)
                "/E"                    # Copia subdirectorios, incluidos los vacios
                "/COPY:DAT"             # Copia Datos, Atributos, Timestamps
                "/DCOPY:T"              # Copia Timestamps de directorios
                "/R:2"                  # Numero de reintentos en caso de fallo
                "/W:5"                  # Tiempo de espera entre reintentos
                "/MT:8"                 # Usa 8 hilos para copiar (puede acelerar en discos rapidos)
                "/NJH"                  # No Job Header
                "/NJS"                  # No Job Summary
                "/NP"                   # No Progress
                "/TEE"                  # Muestra en consola Y en log
                "/LOG:`"$robocopyLogFile`"" # Guarda el log detallado
            )
            
            Write-Log -LogLevel ACTION -Message "REUBICACION: Iniciando Robocopy /MOVE para '$($op.Name)' de '$($op.CurrentPath)' a '$($op.NewPath)'."
            
            $processInfo = Start-Process "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -WindowStyle Minimized
            
            if ($processInfo.ExitCode -ge 8) {
                Write-Error "  -> FALLO Robocopy al mover '$($op.Name)' (Codigo de salida: $($processInfo.ExitCode))."
                Write-Error "     Los archivos pueden estar parcialmente movidos. Revisa el log: $robocopyLogFile"
                Write-Log -LogLevel ERROR -Message "REUBICACION: Robocopy fallo para '$($op.Name)' (Codigo: $($processInfo.ExitCode)). Log: $robocopyLogFile"
                $globalSuccess = $false
                $robocopySucceeded = $false 
                # NO continuamos con el cambio de registro si el movimiento fallo
                continue 
            } else {
                 Write-Host "  -> Movimiento completado (Codigo Robocopy: $($processInfo.ExitCode))." -ForegroundColor Green
                 Write-Log -LogLevel ACTION -Message "REUBICACION: Robocopy completado para '$($op.Name)' (Codigo: $($processInfo.ExitCode)). Log: $robocopyLogFile"
            }
        } else { # Si $actionType es 'RegisterOnly'
             Write-Host "  [2/3] Omitiendo movimiento masivo de archivos." -ForegroundColor Gray
             
             # --- MEJORA: COPIAR Y CONFIGURAR DESKTOP.INI ---
             Write-Host "      - Verificando y copiando 'desktop.ini' para mantener los iconos..." -ForegroundColor Gray
             
             $srcIni = Join-Path $op.CurrentPath "desktop.ini"
             $destIni = Join-Path $op.NewPath "desktop.ini"

             try {
                 if (Test-Path $srcIni -PathType Leaf) {
                     # Copiamos el archivo forzando la sobrescritura si existe
                     Copy-Item -Path $srcIni -Destination $destIni -Force -ErrorAction Stop
                     
                     # Aplicamos atributos de Oculto y Sistema al archivo (necesario para que Windows lo respete)
                     $fileItem = Get-Item $destIni -Force
                     $fileItem.Attributes = 'Hidden', 'System'
                     
                     # TRUCO CRITICO DE WINDOWS:
                     # Para que Windows lea el desktop.ini, la CARPETA contenedora debe ser 'ReadOnly' o 'System'.
                     # Esto no impide escribir en ella, es solo una bandera para el Explorador.
                     $folderItem = Get-Item $op.NewPath -Force
                     $folderItem.Attributes = 'ReadOnly'
                     
                     Write-Host "      [OK] Icono y nombre personalizado (desktop.ini) restaurados." -ForegroundColor Green
                 } else {
                     Write-Host "      [INFO] No se encontró 'desktop.ini' en el origen. La carpeta tendra icono generico." -ForegroundColor Gray
                 }
             } catch {
                 Write-Warning "      [AVISO] No se pudo copiar o configurar desktop.ini: $($_.Exception.Message)"
             }
        }

        # 3. Actualizar el Registro (Si la creacion del dir fue exitosa Y (Robocopy fue exitoso O se eligio 'Solo Registrar'))
        if ($destinationDirCreated -and $robocopySucceeded) {
            Write-Host "  [3/3] Actualizando la ruta en el Registro..." -ForegroundColor Gray
            try {
                Set-ItemProperty -Path $registryPath -Name $op.RegValueName -Value $op.NewPath -Type ExpandString -Force -ErrorAction Stop
                Write-Host "  -> Registro actualizado exitosamente." -ForegroundColor Green
                Write-Log -LogLevel ACTION -Message "REUBICACION: Registro actualizado para '$($op.Name)' a '$($op.NewPath)'."
                $explorerRestartNeeded = $true
            } catch {
                Write-Error "  -> FALLO CRITICO al actualizar el registro para '$($op.Name)'. Error: $($_.Exception.Message)"
                # Distinguir el mensaje de error segun la accion
                if ($actionType -eq 'MoveAndRegister') {
                    Write-Error "     La carpeta se movio, pero Windows aun apunta a la ubicacion antigua."
                } else {
                    Write-Error "     Windows no pudo ser actualizado para apuntar a la nueva ubicacion."
                }
                Write-Log -LogLevel ERROR -Message "REUBICACION CRITICO: Fallo al actualizar registro para '$($op.Name)' a '$($op.NewPath)'. Error: $($_.Exception.Message)"
                $globalSuccess = $false
            }
        } else {
             Write-Warning "  [3/3] Omitiendo actualizacion de registro debido a error previo en este paso."
        }
    }

    Write-Host "`n--- PROCESO DE REUBICACION FINALIZADO ---" -ForegroundColor Cyan
    if ($globalSuccess) {
        Write-Host "[EXITO] Todas las carpetas seleccionadas se han procesado." -ForegroundColor Green
        Write-Log -LogLevel INFO -Message "REUBICACION: Proceso finalizado con exito aparente para las carpetas seleccionadas (Accion: $actionType)."
    } else {
        Write-Error "[FALLO PARCIAL] Ocurrieron errores durante el proceso. Revisa los mensajes anteriores y los logs."
        Write-Log -LogLevel ERROR -Message "REUBICACION: Proceso finalizado con uno o mas errores (Accion: $actionType)."
    }

    if ($explorerRestartNeeded) {
        Write-Host "\nEs necesario reiniciar el Explorador de Windows (o cerrar sesion y volver a iniciar) para que los cambios surtan efecto." -ForegroundColor Yellow
        $restartChoice = Read-Host "¿Deseas reiniciar el Explorador ahora? (S/N)"
        if ($restartChoice.ToUpper() -eq 'S') {
            Invoke-ExplorerRestart
        }
    }

    Read-Host "`nPresiona Enter para volver al menu..."
}

function Show-AdminMenu {
    $adminChoice = ''
    do {
		Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Administracion de Sistema."
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "            Modulo de Administracion de Sistema        " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Limpiar Registros de Eventos de Windows"
        Write-Host "       (Elimina eventos de Aplicacion, Seguridad, Sistema, etc.)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Gestionar Tareas Programadas de Terceros"
        Write-Host "       (Activa o desactiva tareas que no son de Microsoft)" -ForegroundColor Gray
        Write-Host ""
		Write-Host "   [3] Reubicar Carpetas de Usuario (Escritorio, Documentos, etc.)" -ForegroundColor Yellow
        Write-Host "       (Mueve tus carpetas personales a otra unidad o ubicacion)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $adminChoice = Read-Host "Selecciona una opcion"
        
        switch ($adminChoice.ToUpper()) {
            '1' {
                if ((Read-Host "`nADVERTENCIA: Esto eliminara permanentemente los registros de eventos. ¿Estas seguro? (S/N)").ToUpper() -eq 'S') {
                    
                    $targetLogs = @("Application", "Security", "System", "Setup")
                    Write-Host ""

                    foreach ($logName in $targetLogs) {
                        $logExists = Get-WinEvent -ListLog $logName -ErrorAction SilentlyContinue

                        if ($logExists) {
                            Write-Host "[+] Intentando limpiar el registro '$logName'..." -ForegroundColor Gray
                            try {
                                $success = $false
                                if ($logName -eq 'Setup') {
                                    # 1. Ejecutamos wevtutil SIN el parametro /q para maxima compatibilidad.
                                    wevtutil.exe clear-log $logName
                                    
                                    # 2. VERIFICAMOS EL CoDIGO DE SALIDA. Si es 0, todo fue bien.
                                    if ($LASTEXITCODE -eq 0) {
                                        $success = $true
                                    } else {
                                        # 3. Si falla, creamos un error explicito para que el bloque 'catch' lo capture.
                                        throw "wevtutil.exe fallo con el codigo de salida $LASTEXITCODE."
                                    }
                                }
                                else {
                                    Clear-EventLog -LogName $logName -ErrorAction Stop
                                    $success = $true
                                }

                                # 4. El mensaje de exito SoLO se muestra si la variable $success es verdadera.
                                if ($success) {
                                    Write-Host "[OK] Registro '$logName' limpiado exitosamente." -ForegroundColor Green
                                    Write-Log -LogLevel ACTION -Message "Registro de eventos '$logName' limpiado por el usuario."
                                }
                            }
                            catch {
                                Write-Warning "No se pudo limpiar el registro '$logName'. Error: $($_.Exception.Message)"
                                Write-Log -LogLevel WARN -Message "Fallo al limpiar el registro '$logName'. Motivo: $($_.Exception.Message)"
                            }
                        }
                        else {
                            Write-Host "[INFO] Registro '$logName' no encontrado en este sistema. Omitido." -ForegroundColor Yellow
                        }
                    }
                }
            }
            '2' { Manage-ScheduledTasks }
			'3' { Move-UserProfileFolders }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
            }
        }
        if ($adminChoice.ToUpper() -ne 'V') {
            Read-Host "`nPresiona Enter para continuar..."
        }
    } while ($adminChoice.ToUpper() -ne 'V')
}

function Manage-ScheduledTasks {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
	
	Write-Log -LogLevel INFO -Message "Usuario entro al Gestor de Tareas Programadas de Terceros."

    function Get-ThirdPartyTasks {
        Write-Host "`n[+] Actualizando lista de tareas (usando filtro avanzado)..." -ForegroundColor Gray
        
        $tasks = Get-ScheduledTask | Where-Object {
            ($_.TaskPath -notlike '\Microsoft\*') -or 
            ($_.TaskPath -like '\Microsoft\*' -and $_.Author -notlike 'Microsoft*')
        }

        # Esto conserva el tipo de objeto original (CimInstance), lo que es crucial para que las acciones funcionen.
        $tasks | ForEach-Object {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Selected' -Value $false -Force
        }

        # Ahora devolvemos los objetos originales, pero con nuestra propiedad extra.
        # La logica de ordenacion se basa en propiedades que ya existen en el objeto original.
        return $tasks | Sort-Object @{Expression = {
            switch ($_.State) {
                'Ready'   { 0 }
                'Running' { 0 }
                'Disabled'{ 1 }
                default   { 2 }
            }
        }}, TaskName
    }

    # --- Bucle Principal de la Interfaz ---
    $displayTasks = Get-ThirdPartyTasks
    $choice = ''

    while ($choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "       Gestion de Tareas Programadas de Terceros       " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Escribe el numero para marcar/desmarcar una tarea."
        Write-Host ""

        if ($displayTasks.Count -eq 0) {
            Write-Host "[INFO] No se encontraron tareas programadas de terceros." -ForegroundColor Yellow
        }

        for ($i = 0; $i -lt $displayTasks.Count; $i++) {
            $task = $displayTasks[$i]
            $statusMarker = if ($task.Selected) { "[X]" } else { "[ ]" }
            $stateColor = if ($task.State -eq 'Ready' -or $task.State -eq 'Running') { "Green" } else { "Red" }
            
            # Usamos .TaskName en lugar de .Name para coincidir con la propiedad del objeto original.
            Write-Host ("   [{0,2}] {1} {2,-50}" -f ($i + 1), $statusMarker, $task.TaskName) -NoNewline
            Write-Host ("[{0}]" -f $task.State) -ForegroundColor $stateColor
        }
		
	    $selectedCount = $displayTasks.Where({$_.Selected}).Count
        if ($selectedCount -gt 0) {
			Write-Host ""
            Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
        }

        Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
        Write-Host "   [Numero] Marcar/Desmarcar"
        Write-Host "   [H] Habilitar Seleccionadas       [D] Deshabilitar Seleccionadas"
        Write-Host "   [T] Seleccionar Todas             [N] Deseleccionar Todas"
        Write-Host "   [R] Refrescar Lista"
        Write-Host ""
		Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        $choice = (Read-Host "`nSelecciona una opcion")

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $displayTasks.Count) {
            $index = [int]$choice - 1
            $displayTasks[$index].Selected = -not $displayTasks[$index].Selected
        }
        elseif ($choice.ToUpper() -eq 'T') { $displayTasks.ForEach({ $_.Selected = $true }) }
        elseif ($choice.ToUpper() -eq 'N') { $displayTasks.ForEach({ $_.Selected = $false }) }
        elseif ($choice.ToUpper() -eq 'R') { $displayTasks = Get-ThirdPartyTasks }
        elseif ($choice.ToUpper() -in @('D', 'H')) {
            $selectedTasks = $displayTasks | Where-Object { $_.Selected }
            
            if ($selectedTasks.Count -eq 0) {
                Write-Warning "No has seleccionado ninguna tarea."
                Start-Sleep -Seconds 2
                continue
            }

            foreach ($task in $selectedTasks) {
                $action = if ($choice.ToUpper() -eq 'D') { "Deshabilitar" } else { "Habilitar" }
                
                # Usamos .TaskName para el mensaje, que es la propiedad correcta del objeto original.
                if ($PSCmdlet.ShouldProcess($task.TaskName, $action)) {
                    try {
                        if ($choice.ToUpper() -eq 'D') {
                            $task | Disable-ScheduledTask -ErrorAction Stop
                        } else {
                            $task | Enable-ScheduledTask -ErrorAction Stop
                        }
						Write-Log -LogLevel ACTION -Message "TAREAS: Se aplico la accion '$action' a la tarea '$($task.TaskName)'."
                    } catch {
                        Write-Error "No se pudo cambiar el estado de la tarea '$($task.TaskName)'. Error: $($_.Exception.Message)"
						Write-Log -LogLevel ERROR -Message "TAREAS: Fallo al aplicar '$action' a '$($task.TaskName)'. Motivo: $_"
                    }
                }
            }

            Write-Host "`n[OK] Operacion completada. La lista se actualizara para reflejar los cambios reales." -ForegroundColor Green
            Read-Host "Presiona Enter para continuar..."
            
            $displayTasks = Get-ThirdPartyTasks
        }
    }
}

function Show-SoftwareMenu {
    $availableEngines = @('Winget', 'Chocolatey')
    $softwareChoice = ''
    
    do {
		Write-Log -LogLevel INFO -Message "Usuario entro al Gestor de Software Multi-Motor."
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "            GESTION DE SOFTWARE MULTI-MOTOR           " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host " Motor seleccionado: " -NoNewline
        Write-Host $script:SoftwareEngine -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [1] Buscar y APLICAR ACTUALIZACIONES (Recomendado)"
        Write-Host "   [2] Buscar e INSTALAR un software especifico"
        Write-Host "   [3] Instalar software en MASA desde un archivo .txt"
        Write-Host ""
        Write-Host "   [E] Cambiar motor de busqueda/instalacion"
        Write-Host ""
		Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
        Write-Host ""
        
        $softwareChoice = Read-Host "Selecciona una opcion"
        
        switch ($softwareChoice.ToUpper()) {
            '1' { Invoke-SoftwareUpdates }
            '2' { Invoke-SoftwareSearchAndInstall }
            '3' { Invoke-BatchInstallation }
            'E' {
                Clear-Host
                Write-Host "Selecciona el motor de software:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $availableEngines.Count; $i++) {
                    Write-Host "   [$($i+1)] $($availableEngines[$i])"
                }
                $engineChoice = Read-Host "`nElige una opcion (1-$($availableEngines.Count))"
                if ($engineChoice -match '^\d+$' -and [int]$engineChoice -le $availableEngines.Count) {
                    $script:SoftwareEngine = $availableEngines[[int]$engineChoice - 1]
					Write-Log -LogLevel INFO -Message "Cambiado el motor de software a '$script:SoftwareEngine'."
                    Write-Host "Motor cambiado a: $script:SoftwareEngine" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
            }
            'V' { continue }
            default {
                Write-Host "Opcion no valida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($softwareChoice.ToUpper() -ne 'V')
}

# --- ADAPTADOR 1: Obtener actualizaciones de Winget ---
function Get-AegisWingetUpdates {
    Write-Host "Buscando en Winget..." -ForegroundColor Gray
    $updates = @()
    try {
        # Forzamos codificación para estandarizar la salida
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        
        # Ejecutamos winget incluyendo paquetes desconocidos
        $output = winget upgrade --source winget --include-unknown --accept-source-agreements 2>&1
        
        # Filtramos líneas inútiles (encabezados, barras de progreso, líneas vacías)
        $lines = $output | Where-Object { 
            $_ -notmatch "^Nombre" -and 
            $_ -notmatch "^Name" -and 
            $_ -notmatch "^Id" -and 
            $_ -notmatch "^-" -and      # Líneas separadoras
            $_ -notmatch "No se encontraron" -and
            $_ -notmatch "No updates found" -and
            ![string]::IsNullOrWhiteSpace($_)
        }

        foreach ($line in $lines) {
            # Dividimos por 2 o más espacios consecutivos, que es más seguro que posiciones fijas
            $columns = $line -split "\s{2,}"
            
            # Winget suele devolver: Nombre | Id | Versión | Disponible
            if ($columns.Count -ge 3) {
                $updates += [PSCustomObject]@{
                    Name      = $columns[0].Trim()
                    Id        = $columns[1].Trim()
                    Version   = $columns[2].Trim()
                    Available = if ($columns.Count -ge 4) { $columns[3].Trim() } else { "Unknown" }
                    Engine    = 'Winget'
                }
            }
        }
    } catch {
        Write-Warning "Fallo al obtener actualizaciones de Winget: $($_.Exception.Message)"
    }
    return $updates
}

# --- ADAPTADOR 2: Obtener actualizaciones de Chocolatey ---
function Get-AegisChocoUpdates {
    Write-Host "Buscando en Chocolatey..." -ForegroundColor Gray
    $updates = @()
    try {
        $output = choco outdated -r
        $updates = $output | ForEach-Object {
            if ($_ -match "^(.*?)\|(.*?)\|(.*?)\|") {
                [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[1].Trim()
                    Version = $matches[2].Trim()
                    Available = $matches[3].Trim()
                    Engine = 'Chocolatey'
                }
            }
        }
    } catch {
        Write-Warning "Fallo al obtener actualizaciones de Chocolatey: $($_.Exception.Message)"
    }
    return $updates
}

# --- ADAPTADOR 3: Buscar paquetes en Winget ---
function Search-AegisWingetPackage {
    param([string]$SearchTerm)
    
    $results = @()
    try {
        $rawOutput = winget search $SearchTerm --source winget --accept-source-agreements 2>&1
        $lines = $rawOutput -split "`r?`n"
        $inTable = $false
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            if ($trimmedLine -match "^[-\\s]{20,}") {
                $inTable = $true
                continue
            }
            
            if ($inTable -and $trimmedLine -ne "" -and $trimmedLine -notmatch "^-") {
                $columns = $trimmedLine -split "\s{2,}"
                if ($columns.Count -ge 3) {
                    $results += [PSCustomObject]@{
                        Name = $columns[0].Trim()
                        Id = $columns[1].Trim()
                        Version = $columns[2].Trim()
                    }
                }
            }
        }
    } catch {
        Write-Warning "Fallo al buscar en Winget: $($_.Exception.Message)"
    }
    return $results
}

# --- ADAPTADOR 4: Buscar paquetes en Chocolatey ---
function Search-AegisChocoPackage {
     param([string]$SearchTerm)

    $results = @()
    try {
        $rawOutput = choco search $SearchTerm -r 2>&1
        $results = $rawOutput | ForEach-Object {
            if ($_ -match "^(.*?)\|(.*)$") {
                [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[1].Trim()
                    Version = $matches[2].Trim()
                }
            }
        }
    } catch {
         Write-Warning "Fallo al buscar en Chocolatey: $($_.Exception.Message)"
    }
    return $results
}

function Invoke-SoftwareUpdates {
    try {
        Write-Host "`nBuscando actualizaciones disponibles..." -ForegroundColor Yellow
        
        $allUpdates = @()
        $activeEngines = @()
        
        # Verificar que motores estan disponibles
        foreach ($engine in @('Winget', 'Chocolatey')) {
            $isEngineAvailable = Test-SoftwareEngine $engine
            
            if (-not $isEngineAvailable -and $engine -eq 'Chocolatey') {
                # Ofrecer instalar Chocolatey si no esta disponible
                $isEngineAvailable = Ensure-ChocolateyIsInstalled
            }
            
            if ($isEngineAvailable) {
                $activeEngines += $engine
            } else {
                Write-Host "Motor $engine no esta disponible." -ForegroundColor Yellow
                if ($engine -eq 'Winget') {
                    Write-Host "Nota: Winget debe instalarse manually desde Microsoft Store." -ForegroundColor Yellow
                }
            }
        }
		
		Write-Log -LogLevel INFO -Message "SOFTWARE: Iniciando busqueda de actualizaciones."

        # Si no hay motores disponibles, salir
        if ($activeEngines.Count -eq 0) {
            Write-Host "No hay motores de software disponibles para buscar actualizaciones." -ForegroundColor Red
            Read-Host "`nPresiona Enter para continuar"
            return
        }

        # La logica de parseo se ha movido a los adaptadores.
        foreach ($engine in $activeEngines) {
            switch ($engine) {
                'Winget'     { $allUpdates += Get-AegisWingetUpdates }
                'Chocolatey' { $allUpdates += Get-AegisChocoUpdates }
            }
        }

        if ($allUpdates.Count -eq 0) {
            Write-Host "No se encontraron actualizaciones pendientes." -ForegroundColor Green
            Read-Host "`nPresiona Enter para continuar"
            return
        }

        # Seleccion interactiva (Esta parte no cambia)
        $allUpdates | ForEach-Object { $_ | Add-Member -NotePropertyName 'Selected' -NotePropertyValue $false }
        
        $choice = ''
        while ($choice.ToUpper() -ne 'A' -and $choice.ToUpper() -ne 'V') {
            Clear-Host
            Write-Host "ACTUALIZACIONES DISPONIBLES:" -ForegroundColor Cyan
            Write-Host "Marca las actualizaciones que deseas instalar."
            
            for ($i = 0; $i -lt $allUpdates.Count; $i++) {
                $status = if ($allUpdates[$i].Selected) { "[X]" } else { "[ ]" }
                Write-Host "   [$($i+1)] $status $($allUpdates[$i].Name) (v$($allUpdates[$i].Version) -> v$($allUpdates[$i].Available)) - [$($allUpdates[$i].Engine)]" -ForegroundColor White
            }
			
			$selectedCount = $allUpdates.Where({$_.Selected}).Count
            if ($selectedCount -gt 0) {
				Write-Host ""
                Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
            }

            Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
			Write-Host ""
            Write-Host "   [Numero] Marcar/Desmarcar                       [T] Seleccionar Todas"
            Write-Host "   [A] Aplicar actualizaciones seleccionadas       [N] Deseleccionar Todas"
            Write-Host ""
            Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
			Write-Host ""
            
            $choice = Read-Host "`nSelecciona una opcion"

            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $allUpdates.Count) {
                $index = [int]$choice - 1
                $allUpdates[$index].Selected = -not $allUpdates[$index].Selected
            }
            elseif ($choice.ToUpper() -eq 'T') { $allUpdates.ForEach({$_.Selected = $true}) }
            elseif ($choice.ToUpper() -eq 'N') { $allUpdates.ForEach({$_.Selected = $false}) }
        }

        if ($choice.ToUpper() -eq 'A') {
            $selectedUpdates = $allUpdates | Where-Object { $_.Selected }
            
            if ($selectedUpdates.Count -eq 0) {
                Write-Host "No se seleccionaron actualizaciones." -ForegroundColor Yellow
                Read-Host "`nPresiona Enter para continuar"
                return
            }

            foreach ($update in $selectedUpdates) {
                Write-Host "Actualizando $($update.Name) con $($update.Engine)..." -ForegroundColor Yellow
				Write-Log -LogLevel ACTION -Message "SOFTWARE: Actualizando '$($update.Name)' ($($update.Id)) con $($update.Engine)."
                switch ($update.Engine) {
                    'Winget' {
                        winget upgrade --id $update.Id --silent --accept-package-agreements --accept-source-agreements
                    }
                    'Chocolatey' {
                        choco upgrade $update.Id -y
                    }
                }
            }

            Write-Host "`nActualizaciones completadas." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error durante la actualizacion: $($_.Exception.Message)" -ForegroundColor Red
		Write-Log -LogLevel ERROR -Message "SOFTWARE: Error durante la actualizacion: $($_.Exception.Message)"
    }
    
    Read-Host "`nPresiona Enter para continuar"
}

function Test-SoftwareEngine {
    param([string]$Engine)
    
    switch ($Engine) {
        'Winget' { 
            $wingetPath = Get-Command "winget" -ErrorAction SilentlyContinue
            return [bool]$wingetPath
        }
        'Chocolatey' { 
            # Verificar de multiples formas para asegurar deteccion
            $chocoPath = Get-Command "choco" -ErrorAction SilentlyContinue
            if (-not $chocoPath) {
                # Verificar tambien en la ruta comun de instalacion
                $commonChocoPath = "$env:ProgramData\chocolatey\bin\choco.exe"
                return (Test-Path $commonChocoPath)
            }
            return [bool]$chocoPath
        }
        default { return $false }
    }
}

function Ensure-ChocolateyIsInstalled {
    # Primero verificar si ya esta instalado
    if (Test-SoftwareEngine 'Chocolatey') { return $true }
    
    Write-Host "El gestor de paquetes 'Chocolatey' no esta instalado." -ForegroundColor Yellow
    
    if ($script:SoftwareEngine -eq 'Chocolatey') {
        $installChoice = Read-Host "¿Deseas instalarlo ahora? (S/N)"
        if ($installChoice -eq 'S' -or $installChoice -eq 's') {
            Write-Host "`n[+] Instalando Chocolatey..." -ForegroundColor Yellow
            try {
                # Forzar politica de ejecucion
                Set-ExecutionPolicy Bypass -Scope Process -Force
                
                # Configurar protocolo de seguridad
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                
                # Descargar e instalar
                iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                
                # Actualizar PATH inmediatamente
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                # Verificar instalacion
                Start-Sleep -Seconds 2  # Pequeña pausa para asegurar la instalacion
                
                if (Test-SoftwareEngine 'Chocolatey') {
                    Write-Host "`n[OK] Chocolatey instalado correctamente." -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "Chocolatey se instalo pero no se detecta. Intenta reiniciar la consola." -ForegroundColor Yellow
                    return $false
                }
            } catch {
                Write-Host "Fallo la instalacion de Chocolatey. Error: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
    }
    return $false
}

function Invoke-SoftwareSearchAndInstall {
    $searchTerm = Read-Host "Introduce el nombre del software a buscar"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { return }
	Write-Log -LogLevel INFO -Message "SOFTWARE: Iniciando busqueda de '$searchTerm' con el motor '$($script:SoftwareEngine)'."	

    try {
        Write-Host "Buscando '$searchTerm'..." -ForegroundColor Yellow
        
        # Verificar si el motor seleccionado esta disponible
        if ($script:SoftwareEngine -eq 'Chocolatey' -and -not (Ensure-ChocolateyIsInstalled)) {
            Write-Host "No se puede continuar sin Chocolatey." -ForegroundColor Red
            Read-Host "`nPresiona Enter para continuar"
            return
        }
        
        if (-not (Test-SoftwareEngine $script:SoftwareEngine)) {
            Write-Host "El motor $script:SoftwareEngine no esta disponible." -ForegroundColor Red
            Read-Host "`nPresiona Enter para continuar"
            return
        }
        
        $results = @()
        
        # --- INICIO DE LA REFACTORIZACION ---
        # La logica de parseo se ha movido a los adaptadores.
        switch ($script:SoftwareEngine) {
             'Winget' {
                $results = Search-AegisWingetPackage -SearchTerm $searchTerm
            }
            'Chocolatey' {
                $results = Search-AegisChocoPackage -SearchTerm $searchTerm
            }
        }
        # --- FIN DE LA REFACTORIZACION ---

        if ($results.Count -eq 0) {
            Write-Host "No se encontraron resultados." -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar"
            return
        }

        # Seleccion interactiva (Esta parte no cambia)
        $results | ForEach-Object { $_ | Add-Member -NotePropertyName 'Selected' -NotePropertyValue $false }
        
        $choice = ''
        while ($choice.ToUpper() -ne 'I' -and $choice.ToUpper() -ne 'V') {
            Clear-Host
            Write-Host "RESULTADOS DE BUSQUEDA:" -ForegroundColor Cyan
            Write-Host "Marca el software que deseas instalar."
            
            for ($i = 0; $i -lt $results.Count; $i++) {
                $status = if ($results[$i].Selected) { "[X]" } else { "[ ]" }
                Write-Host "   [$($i+1)] $status $($results[$i].Name) ($($results[$i].Version))" -ForegroundColor White
            }
			
			$selectedCount = $results.Where({$_.Selected}).Count
            if ($selectedCount -gt 0) {
				Write-Host ""
                Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
            }

            Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
			Write-Host ""
            Write-Host "   [Numero] Marcar/Desmarcar              [T] Seleccionar Todas"
            Write-Host "   [I] Instalar software seleccionado     [D] Deseleccionar Todas"
            Write-Host ""
            Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
			Write-Host ""
            
            $choice = Read-Host "`nSelecciona una opcion"

            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $results.Count) {
                $index = [int]$choice - 1
                $results[$index].Selected = -not $results[$index].Selected
            }
            elseif ($choice.ToUpper() -eq 'T') { $results.ForEach({$_.Selected = $true}) }
            elseif ($choice.ToUpper() -eq 'D') { $results.ForEach({$_.Selected = $false}) }
        }

        if ($choice.ToUpper() -eq 'I') {
            $selectedSoftware = $results | Where-Object { $_.Selected }
            
            if ($selectedSoftware.Count -eq 0) {
                Write-Host "No se selecciono software para instalar." -ForegroundColor Yellow
                Read-Host "`nPresiona Enter para continuar"
                return
            }

            foreach ($software in $selectedSoftware) {
                Install-Software -SoftwareId $software.Id -SoftwareName $software.Name
            }
        }
    }
    catch {
        Write-Host "Error durante la busqueda: $($_.Exception.Message)" -ForegroundColor Red
		Write-Log -LogLevel ERROR -Message "SOFTWARE: Error durante la busqueda: $($_.Exception.Message)"
        Read-Host "Presiona Enter para continuar"
    }
}

function Install-Software {
    param(
        [string]$SoftwareId,
        [string]$SoftwareName
    )

    try {
        Write-Host "Instalando $SoftwareName..." -ForegroundColor Yellow
		Write-Log -LogLevel ACTION -Message "SOFTWARE: Instalando '$SoftwareName' ($SoftwareId) con $($script:SoftwareEngine)."
        
        switch ($script:SoftwareEngine) {
            'Winget' {
                if ($SoftwareId -match "msstore$") {
                    Write-Host "Aplicacion de Microsoft Store detectada. No se puede instalar en modo silencioso." -ForegroundColor Yellow
                    winget install --id $SoftwareId --accept-package-agreements --accept-source-agreements
                } else {
                    winget install --id $SoftwareId --silent --accept-package-agreements --accept-source-agreements
                }
            }
            'Chocolatey' {
                choco install $SoftwareId -y
            }
        }
        
        Write-Host "¡$SoftwareName instalado correctamente!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error durante la instalacion: $($_.Exception.Message)" -ForegroundColor Red
		Write-Log -LogLevel ERROR -Message "SOFTWARE: Error instalando '$SoftwareName': $($_.Exception.Message)"
    }
    
    Read-Host "Presiona Enter para continuar"
}

function Invoke-BatchInstallation {
    $filePaths = Select-PathDialog -DialogType 'File' -Title "Selecciona el archivo .txt con la lista de software" -Filter "Archivos de texto (*.txt)|*.txt"
    
    # 1. Comprobamos primero si el usuario presiono "Cancelar" o no selecciono nada.
    if (-not $filePaths) {
        Write-Warning "No se selecciono un archivo. Operacion cancelada."
        Start-Sleep -Seconds 2
        return # Salimos de la funcion de forma segura
    }

    # 2. Para esta funcion, solo nos interesa el primer archivo seleccionado, incluso si el usuario selecciono varios.
    $filePath = $filePaths[0] 

    # El resto de la funcion continua sin cambios, ya que ahora sabemos que $filePath es una ruta valida.
    if ($script:SoftwareEngine -eq 'Chocolatey' -and -not (Ensure-ChocolateyIsInstalled)) {
        Write-Host "No se puede continuar sin Chocolatey." -ForegroundColor Red
        Read-Host "`nPresiona Enter para continuar"
        return
    }
    
    if (-not (Test-SoftwareEngine $script:SoftwareEngine)) {
        Write-Host "El motor $script:SoftwareEngine no esta disponible." -ForegroundColor Red
        Read-Host "`nPresiona Enter para continuar"
        return
    }

    $softwareList = Get-Content $filePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    
    if ($softwareList.Count -eq 0) {
        Write-Host "El archivo esta vacio." -ForegroundColor Yellow
        Read-Host "Presiona Enter para continuar"
        return
    }

    Clear-Host
    Write-Host "SOFTWARE A INSTALAR:" -ForegroundColor Cyan
    foreach ($software in $softwareList) {
        Write-Host "   - $software" -ForegroundColor White
    }

    $confirm = Read-Host "`n¿Continuar con la instalacion? (S/N)"
    if ($confirm -ne 'S' -and $confirm -ne 's') { return }
	Write-Log -LogLevel INFO -Message "SOFTWARE: Iniciando instalacion en masa desde '$filePath' con el motor '$($script:SoftwareEngine)'."

    foreach ($software in $softwareList) {
        Write-Host "Instalando $software..." -ForegroundColor Yellow
        Install-Software -SoftwareId $software -SoftwareName $software
    }
}

# Variable global para el motor de software
$script:SoftwareEngine = 'Winget'

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
function Set-TweakState {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Action
    )

    Write-Host " -> Aplicando '$Action' al ajuste '$($Tweak.Name)'..." -ForegroundColor Yellow
    Write-Log -LogLevel INFO -Message "Intentando aplicar '$Action' al ajuste '$($Tweak.Name)' en la categoria '$($Tweak.Category)'."
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
		Write-Log -LogLevel ACTION -Message "El ajuste '$($Tweak.Name)' se establecio a '$Action' exitosamente."
    } catch {
        Write-Error "No se pudo modificar el ajuste '$($Tweak.Name)'. Error: $($_.Exception.Message)"
		Write-Log -LogLevel ERROR -Message "Fallo al modificar '$($Tweak.Name)'. Motivo: $($_.Exception.Message)"
    }
}

function Show-TweakManagerMenu {
    $Category = $null
    Write-Log -LogLevel INFO -Message "Usuario entro al Gestor de Ajustes del Sistema (Tweaks)."
    
    [bool]$explorerRestartNeeded = $false

    # --- NUEVO: Cache de estados para evitar lag en el menu ---
    $tweakStateCache = @{}
    # ----------------------------------------------------------

    while ($true) {
        Clear-Host
        if ($null -eq $Category) {
            # --- MENU DE SELECCION DE CATEGORIA (Sin cambios) ---
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "           Gestor de Ajustes del Sistema (Tweaks)      " -ForegroundColor Cyan
            Write-Host "=======================================================" -ForegroundColor Cyan
            $categories = $script:SystemTweaks | Select-Object -ExpandProperty Category -Unique | Sort-Object
            
            for ($i = 0; $i -lt $categories.Count; $i++) { 
                Write-Host ("   [{0}] {1}" -f ($i + 1), $categories[$i]) 
            }
            
            Write-Host "`n   [V] Volver al menu anterior" -ForegroundColor Red
            $choice = Read-Host "`nSelecciona una categoria"

            if ($choice.ToUpper() -eq 'V') { return }
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $categories.Count) {
                $Category = $categories[[int]$choice - 1]
                Write-Log -LogLevel INFO -Message "TWEAKS: Usuario selecciono la categoria '$Category'."
                
                $tweaksInCategory = @($script:SystemTweaks | Where-Object { $_.Category -eq $Category })
                $tweaksInCategory | ForEach-Object { $_ | Add-Member -NotePropertyName 'Selected' -NotePropertyValue $false -Force }
                
                # --- OPTIMIZACION: Carga inicial de estados (Solo al entrar a la categoria) ---
                Write-Host "Cargando lista de los ajustes..." -ForegroundColor Gray
                $tweakStateCache.Clear()
                foreach ($tweak in $tweaksInCategory) {
                    # Guardamos el estado en el Hash usando el Nombre como clave
                    $tweakStateCache[$tweak.Name] = Get-TweakState -Tweak $tweak
                }
                # ------------------------------------------------------------------------------
            }
        }
        else {
            # --- MENU DE LISTADO DE TWEAKS (Optimizado) ---
            Write-Host "Gestor de Ajustes | Categoria: $Category" -ForegroundColor Cyan
            Write-Host "Marca los ajustes que deseas alternar (activar/desactivar)."
            Write-Host "------------------------------------------------"
            
            $consoleWidth = $Host.UI.RawUI.WindowSize.Width
            $descriptionIndent = 13

            for ($i = 0; $i -lt $tweaksInCategory.Count; $i++) {
                $tweak = $tweaksInCategory[$i]
                $status = if ($tweak.Selected) { "[X]" } else { "[ ]" }
                
                # --- USO DE CACHE (Lectura O(1) instantanea) ---
                # Ya no consultamos al registro/comando, leemos de la memoria
                $state = $tweakStateCache[$tweak.Name]
                # -----------------------------------------------
                
                $stateColor = if ($state -eq 'Enabled') { 'Green' } elseif ($state -eq 'Disabled') { 'Red' } else { 'Gray' }
                
                Write-Host ("   [{0,2}] {1} " -f ($i + 1), $status) -NoNewline
                Write-Host ("{0,-17}" -f "[$state]") -ForegroundColor $stateColor -NoNewline
                Write-Host $tweak.Name

                if (-not [string]::IsNullOrWhiteSpace($tweak.Description)) {
                    $wrappedDescription = Format-WrappedText -Text $tweak.Description -Indent $descriptionIndent -MaxWidth $consoleWidth
                    $wrappedDescription | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
                }
                Write-Host "" 
            }
            
            $selectedCount = $tweaksInCategory.Where({$_.Selected}).Count
            if ($selectedCount -gt 0) {
                Write-Host ""
                Write-Host "   ($selectedCount elemento(s) seleccionado(s))" -ForegroundColor Cyan
            }

            Write-Host "`n--- Acciones ---" -ForegroundColor Yellow
            Write-Host "   [Numero] Marcar/Desmarcar                [T] Marcar Todos"
            Write-Host "   [A] Aplicar cambios a los seleccionados  [N] Desmarcar Todos"
            Write-Host ""
            Write-Host "   [V] Volver a la seleccion de categoria" -ForegroundColor Red
            Write-Host ""
            
            $choice = Read-Host "`nElige una opcion"

            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $tweaksInCategory.Count) {
                $index = [int]$choice - 1
                $tweaksInCategory[$index].Selected = -not $tweaksInCategory[$index].Selected
            }
            elseif ($choice.ToUpper() -eq 'T') { $tweaksInCategory.ForEach({$_.Selected = $true}) }
            elseif ($choice.ToUpper() -eq 'N') { $tweaksInCategory.ForEach({$_.Selected = $false}) }
            elseif ($choice.ToUpper() -eq 'V') { $Category = $null; continue }
            elseif ($choice.ToUpper() -eq 'A') {
                $selectedTweaks = $tweaksInCategory | Where-Object { $_.Selected }
                if ($selectedTweaks.Count -eq 0) {
                    Write-Warning "No has seleccionado ningun ajuste."
                } else {
                    Write-Host "`n[+] Se aplicaran los siguientes cambios:" -ForegroundColor Cyan
                    foreach ($tweak in $selectedTweaks) {
                        # Aqui usamos la cache para determinar la accion necesaria
                        $currentState = $tweakStateCache[$tweak.Name]
                        if ($currentState -ne 'NotApplicable') {
                            $action = if ($currentState -eq 'Enabled') { 'Desactivar' } else { 'Activar' }
                            $actionColor = if ($action -eq 'Activar') { 'Green' } else { 'Red' }
                            Write-Host "    - " -NoNewline
                            Write-Host "[$action]" -ForegroundColor $actionColor -NoNewline
                            Write-Host " $($tweak.Name)"
                        }
                    }

                    $confirmation = Read-Host "`n¿Estas seguro de que deseas continuar? (S/N)"
                    if ($confirmation.ToUpper() -ne 'S') {
                        Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                        continue 
                    }

                    foreach ($tweakToToggle in $selectedTweaks) {
                        # Leemos estado actual desde Cache
                        $currentState = $tweakStateCache[$tweakToToggle.Name]
                        
                        if ($currentState -eq 'NotApplicable') {
                            Write-Warning "El ajuste '$($tweakToToggle.Name)' no es aplicable y se omitira."
                            continue
                        }
                        
                        # Determinamos la accion
                        $action = if ($currentState -eq 'Enabled') { 'Disable' } else { 'Enable' }
                        
                        # Ejecutamos el cambio real
                        Set-TweakState -Tweak $tweakToToggle -Action $action

                        # --- ACTUALIZACION DE CACHE POST-ACCION ---
                        # Invertimos el estado en la cache manualmente para evitar re-leer el registro
                        # Esto hace que la UI se sienta instantanea
                        $newState = if ($action -eq 'Enable') { 'Enabled' } else { 'Disabled' }
                        $tweakStateCache[$tweakToToggle.Name] = $newState
                        # ------------------------------------------

                        if ($tweakToToggle.RestartNeeded -eq 'Explorer') {
                            $explorerRestartNeeded = $true
                        }
                    }
                    Write-Host "`n[OK] Se han aplicado los cambios." -ForegroundColor Green
                }
                $tweaksInCategory.ForEach({$_.Selected = $false})

                if ($explorerRestartNeeded) {
                    $promptChoice = Read-Host "`n[?] Varios cambios requieren reiniciar el Explorador de Windows. ¿Deseas hacerlo ahora? (S/N)"
                    if ($promptChoice.ToUpper() -eq 'S') {
                        Invoke-ExplorerRestart
                    } else {
                        Write-Host "[INFO] Recuerda reiniciar la sesion para ver todos los cambios." -ForegroundColor Yellow
                    }
                    $explorerRestartNeeded = $false
                }
                Read-Host "`nPresiona Enter para continuar..."
            }
        }
    }
}

function Rebuild-SearchIndex {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Log -LogLevel INFO -Message "MANTENIMIENTO: Usuario inicio la reconstruccion del indice de busqueda."
    Write-Host "`n[+] Reconstruyendo el Indice de Busqueda de Windows..." -ForegroundColor Cyan
    Write-Warning "Esta operacion eliminara la base de datos de busqueda actual (.edb)."
    Write-Warning "El sistema tardara un tiempo en volver a indexar tus archivos (puede haber consumo de CPU)."

    if (-not ($PSCmdlet.ShouldProcess("Base de Datos de Busqueda", "Eliminar y Regenerar desde Cero"))) { 
        return 
    }

    try {
        # 1. Detener el servicio Windows Search
        Write-Host "   - Deteniendo servicio Windows Search (WSearch)..." -ForegroundColor Gray
        $service = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
        
        if ($service.Status -eq 'Running') {
            Stop-Service -Name "WSearch" -Force -ErrorAction Stop
        }

        # 2. Localizar la ruta real de la base de datos (No asumir ProgramData)
        Write-Host "   - Localizando ubicacion del indice..." -ForegroundColor Gray
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Search"
        $dataDir = (Get-ItemProperty -Path $regPath -Name "DataDirectory" -ErrorAction SilentlyContinue).DataDirectory

        if ([string]::IsNullOrWhiteSpace($dataDir)) {
            # Fallback seguro si el registro falla
            $dataDir = "$env:ProgramData\Microsoft\Search\Data"
        }

        # La carpeta critica es "Applications\Windows"
        $searchDbPath = Join-Path $dataDir "Applications\Windows"

        # 3. Eliminar la base de datos corrupta/vieja
        if (Test-Path $searchDbPath) {
            Write-Host "   - Purgando base de datos en: $searchDbPath" -ForegroundColor Yellow
            # Intentamos eliminar. Si falla por bloqueo, esperamos 2 segundos y reintentamos
            try {
                Remove-Item -Path $searchDbPath -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Host "     (Archivo bloqueado, reintentando en 2s...)" -ForegroundColor DarkGray
                Start-Sleep -Seconds 2
                Remove-Item -Path $searchDbPath -Recurse -Force -ErrorAction Stop
            }
            Write-Log -LogLevel ACTION -Message "MANTENIMIENTO: Base de datos de busqueda purgada exitosamente."
        } else {
            Write-Host "   - No se encontro base de datos previa (o ya estaba limpia)." -ForegroundColor Gray
        }

        # 4. Truco Pro: Resetear bandera de configuracion
        # Esto obliga a Windows a verificar las ubicaciones de indexado al arrancar
        Set-ItemProperty -Path $regPath -Name "SetupCompletedSuccessfully" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        # 5. Reiniciar el servicio (CON VALIDACION DE ESTADO)
        Write-Host "   - Reiniciando servicio Windows Search..." -ForegroundColor Gray
        
        # Refrescamos el objeto del servicio para ver su estado actual
        $svcFinal = Get-Service -Name "WSearch"
        
        # Si el usuario lo habia deshabilitado en el modulo de Servicios, lo reactivamos
        if ($svcFinal.StartType -eq 'Disabled') {
            Write-Warning "El servicio WSearch estaba deshabilitado. Reactivandolo temporalmente para reconstruir el indice..."
            Set-Service -Name "WSearch" -StartupType Automatic
            Write-Log -LogLevel WARN -Message "MANTENIMIENTO: Se reactivo WSearch (estaba Disabled) para reconstruccion."
        }
        
        Start-Service -Name "WSearch" -ErrorAction Stop

        Write-Host "`n[OK] Indice restablecido correctamente." -ForegroundColor Green
        Write-Host "      Windows comenzara a re-indexar en segundo plano inmediatamente." -ForegroundColor Cyan

    } catch {
        Write-Error "Fallo critico al reconstruir el indice: $($_.Exception.Message)"
        Write-Log -LogLevel ERROR -Message "MANTENIMIENTO: Fallo reconstruccion de indice. Error: $($_.Exception.Message)"
        
        # Intento de emergencia para levantar el servicio si quedo apagado
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    }
    
    Read-Host "`nPresiona Enter para continuar..."
}

# --- FUNCIONES DE MENU PRINCIPAL ---

function Show-OptimizationMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Optimizacion y Limpieza."
    $optimChoice = ''
	do { 
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "            Modulo de Optimizacion y Limpieza          " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Gestor de Servicios No Esenciales de Windows"
        Write-Host "       (Activa, desactiva o restaura servicios de forma segura)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Optimizar Servicios de Programas Instalados"
        Write-Host "       (Activa o desactiva servicios de tus aplicaciones)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Modulo de Limpieza Profunda"
        Write-Host "       (Libera espacio en disco eliminando archivos basura)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Eliminar Apps Preinstaladas"
        Write-Host "       (Detecta y te permite elegir que bloatware quitar)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Gestionar Programas de Inicio"
        Write-Host "       (Controla que aplicaciones arrancan con Windows)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------"
        Write-Host ""
        Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
        Write-Host ""
        
        $optimChoice = Read-Host "Selecciona una opcion"
        
        switch ($optimChoice.ToUpper()) {
            '1' { Manage-SystemServices }
            '2' { Manage-ThirdPartyServices }
            '3' { Show-CleaningMenu }
            '4' { Show-BloatwareMenu }
            '5' { Manage-StartupApps }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
                Read-Host 
            }
		} 
	} while ($optimChoice.ToUpper() -ne 'V')
}

function Show-MaintenanceMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Mantenimiento y Reparacion."
    $maintChoice = ''
	do { 
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Modulo de Mantenimiento y Reparacion        " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Verificar y Reparar Archivos del Sistema (SFC/DISM)"
        Write-Host "       (Soluciona errores de sistema, cuelgues y pantallas azules)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Limpiar Caches de Sistema (DNS, Tienda, etc.)"
        Write-Host "       (Resuelve problemas de conexion a internet y de la Tienda Windows)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Optimizar Unidades (Desfragmentar/TRIM)"
        Write-Host "       (Mejora la velocidad de lectura y la vida util de tus discos)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Generar Reporte de Salud del Sistema (Energia)"
        Write-Host "       (Diagnostica problemas de bateria y consumo de energia)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Purgar Memoria RAM en Cache (Standby List)" -ForegroundColor Yellow
        Write-Host "       (Libera la memoria 'En espera'. Para usos muy especificos)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [6] Diagnostico y Reparacion de Red"
        Write-Host "       (Soluciona problemas de conectividad a internet)" -ForegroundColor Gray
        Write-Host ""
		Write-Host "   [7] Reconstruir Indice de Busqueda (Search Index)" -ForegroundColor Cyan
        Write-Host "       (Soluciona busquedas lentas, incompletas o que no encuentran archivos)" -ForegroundColor Gray
		Write-Host ""
        Write-Host "-------------------------------------------------------"
        Write-Host ""
        Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
        Write-Host ""
        
        $maintChoice = Read-Host "Selecciona una opcion"
        
        switch ($maintChoice.ToUpper()) {
            '1' { Repair-SystemFiles }
            '2' { Clear-SystemCaches }
            '3' { Optimize-Drives }
            '4' { Generate-SystemReport }
            '5' { Clear-RAMCache }
            '6' { Show-NetworkDiagnosticsMenu }
            '7' { Rebuild-SearchIndex }
			'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        } 
    } while ($maintChoice.ToUpper() -ne 'V')
}

function Show-AdvancedMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Herramientas Avanzadas."
    $advChoice = ''
    do { 
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "                 Herramientas Avanzadas                " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Gestor de Ajustes del Sistema (Tweaks, Seguridad, UI, Privacidad)"
        Write-Host "       (Activa y desactiva individualmente ajustes para optimizar tu sistema)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Inventario y Reportes del Sistema"
        Write-Host "       (Genera un informe detallado del hardware y software de tu PC)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Gestion de Drivers (Backup/Listar)"
        Write-Host "       (Crea una copia de seguridad de tus drivers, esencial para reinstalar Windows)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Gestion de Software (Multi-Motor)"
        Write-Host "       (Actualiza e instala todas tus aplicaciones con Winget o Chocolatey)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Administracion de Sistema"
        Write-Host "       (Limpia logs, gestiona tareas y reubica carpetas de usuario)" -ForegroundColor Gray
		Write-Host ""
        Write-Host "   [6] Analizador Rapido de Registros de Eventos"
        Write-Host "       (Encuentra errores criticos del sistema y aplicaciones)" -ForegroundColor Gray
		Write-Host ""
        Write-Host "   [7] Herramienta de Respaldo de Datos de Usuario (Robocopy)"
        Write-Host "       (Crea copias de seguridad de tus archivos personales)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------"
        Write-Host ""
        Write-Host "   [V] Volver al menu principal" -ForegroundColor Red
		Write-Host ""
        
        $advChoice = Read-Host "Selecciona una opcion"
        
        switch ($advChoice.ToUpper()) {
            '1' { Show-TweakManagerMenu }
            '2' { Show-InventoryMenu }
            '3' { Show-DriverMenu }
            '4' { Show-SoftwareMenu }
            '5' { Show-AdminMenu }
			'6' { Show-EventLogAnalyzerMenu }
			'7' { Show-UserDataBackupMenu }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
                Read-Host
            }
        }
    } while ($advChoice.ToUpper() -ne 'V')
}

# --- BUCLE PRINCIPAL DEL SCRIPT ---
$mainChoice = ''
do {
    $headerInfo = "Usuario: $($env:USERNAME) | Equipo: $($env:COMPUTERNAME)"
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ("         Aegis Phoenix Suite v{0} by SOFTMAXTER" -f $script:Version) -ForegroundColor Cyan
    Write-Host ($headerInfo.PadLeft(55)) -ForegroundColor Gray
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
	Write-Host "   [L] Ver Registro de Actividad (Log)" -ForegroundColor Gray
	Write-Host ""
    Write-Host "   [S] Salir del script" -ForegroundColor Red
    Write-Host ""

    $mainChoice = Read-Host "Selecciona una opcion y presiona Enter"
	Write-Log -LogLevel INFO -Message "MAIN_MENU: Usuario selecciono la opcion '$($mainChoice.ToUpper())'."

    switch ($mainChoice.ToUpper()) {
        '1' { Create-RestorePoint }
        '2' { Show-OptimizationMenu }
        '3' { Show-MaintenanceMenu }
        '4' { Show-AdvancedMenu }
		'L' {
            $parentDir = Split-Path -Parent $PSScriptRoot
            $logFile = Join-Path -Path $parentDir -ChildPath "Logs\Registro.log"
            if (Test-Path $logFile) {
                Write-Host "`n[+] Abriendo archivo de registro..." -ForegroundColor Green
                Start-Process notepad.exe -ArgumentList $logFile
            } else {
                Write-Warning "El archivo de registro aun no ha sido creado. Realiza alguna accion primero."
                Read-Host "`nPresiona Enter para continuar..."
            }
        }
        'S' { Write-Host "`nGracias por usar Aegis Phoenix Suite by SOFTMAXTER!" }
            default {
                Write-Host "`n[ERROR] Opcion no valida. Por favor, intenta de nuevo." -ForegroundColor Red
                Read-Host "`nPresiona Enter para continuar..."
            }
        }

    } while ($mainChoice.ToUpper() -ne 'S')

Write-Log -LogLevel INFO -Message "Aegis Phoenix Suite cerrado por el usuario."
Write-Log -LogLevel INFO -Message "================================================="
