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
    4.7.0
#>

$script:Version = "4.7.0"

# --- INICIO DEL MODULO DE AUTO-ACTUALIZACION ---

function Invoke-FullRepoUpdater {
    # --- CONFIGURACION ---
    $repoUser = "SOFTMAXTER"; $repoName = "Aegis-Phoenix-Suite"; $repoBranch = "main"
    $versionUrl = "https://raw.githubusercontent.com/$repoUser/$repoName/$repoBranch/version.txt"
    $zipUrl = "https://github.com/$repoUser/$repoName/archive/refs/heads/$repoBranch.zip"
    
    try {
        # Se intenta la operacion de red con un timeout corto para no retrasar el script si no hay conexion.
        $remoteVersionStr = (Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -Headers @{"Cache-Control"="no-cache"}).Content.Trim()

        if ([System.Version]$remoteVersionStr -gt [System.Version]$script:Version) {
            # Solo si se encuentra una actualizacion, se le notifica al usuario.
            Write-Host "¡Nueva version encontrada! Local: v$($script:Version) | Remota: v$remoteVersionStr" -ForegroundColor Green
            $confirmation = Read-Host "¿Deseas descargar e instalar la actualizacion ahora? (S/N)"
            if ($confirmation.ToUpper() -eq 'S') {
                Write-Warning "El actualizador se ejecutara en una nueva ventana. NO LA CIERRES."
                $tempDir = Join-Path $env:TEMP "AegisUpdater"
                if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
                New-Item -Path $tempDir -ItemType Directory | Out-Null
                $updaterScriptPath = Join-Path $tempDir "updater.ps1"
                $installPath = (Split-Path -Path $PSScriptRoot -Parent)
                $batchPath = Join-Path $installPath "Run.bat"

                $updaterScriptContent = @"
`$ErrorActionPreference = 'Stop'
`$Host.UI.RawUI.WindowTitle = 'PROCESO DE ACTUALIZACION DE AEGIS - NO CERRAR'
try {
    `$tempDir_updater = "$tempDir"
    `$tempZip_updater = Join-Path "`$tempDir_updater" "update.zip"
    `$tempExtract_updater = Join-Path "`$tempDir_updater" "extracted"

    Write-Host "[PASO 1/5] Descargando la nueva version..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "$zipUrl" -OutFile "`$tempZip_updater"

    Write-Host "[PASO 2/5] Descomprimiendo archivos..." -ForegroundColor Yellow
    Expand-Archive -Path "`$tempZip_updater" -DestinationPath "`$tempExtract_updater" -Force
    `$updateSourcePath = (Get-ChildItem -Path "`$tempExtract_updater" -Directory).FullName

    Write-Host "[PASO 3/5] Eliminando archivos antiguos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 4
    `$itemsToRemove = Get-ChildItem -Path "$installPath" -Exclude "Logs", "Backup", "Reportes", "Diagnosticos", "Tools"
    if (`$null -ne `$itemsToRemove) { Remove-Item -Path `$itemsToRemove.FullName -Recurse -Force }

    Write-Host "[PASO 4/5] Instalando nuevos archivos..." -ForegroundColor Yellow
    Move-Item -Path "`$updateSourcePath\*" -Destination "$installPath" -Force
    Get-ChildItem -Path "$installPath" -Recurse | Unblock-File

    Write-Host "[PASO 5/5] ¡Actualizacion completada! Reiniciando la suite en 5 segundos..." -ForegroundColor Green
    Start-Sleep -Seconds 5
    
    Remove-Item -Path "`$tempDir_updater" -Recurse -Force
    Start-Process -FilePath "$batchPath"
}
catch {
    Write-Error "¡LA ACTUALIZACION HA FALLADO!"
    Write-Error `$_
    Read-Host "El proceso ha fallado. Presiona Enter para cerrar esta ventana."
}
"@
                Set-Content -Path $updaterScriptPath -Value $updaterScriptContent -Encoding utf8
                $launchArgs = "/c start `"PROCESO DE ACTUALIZACION DE AEGIS`" powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$updaterScriptPath`""
                Start-Process cmd.exe -ArgumentList $launchArgs -WindowStyle Hidden
                exit
            } else {
				Write-Host "Actualizacion omitida por el usuario." -ForegroundColor Yellow; Start-Sleep -Seconds 1
        	}
        } 
    }
    catch {
		
        return
    }
}

# Ejecutar el actualizador DESPUES de definir la version
Invoke-FullRepoUpdater

# --- CARGA DE CATALOGOS EXTERNOS ---
Write-Host "Cargando catalogos..."
try {
    . "$PSScriptRoot\Catalogos\Ajustes.ps1"
    . "$PSScriptRoot\Catalogos\Servicios.ps1"
}
catch {
    Write-Error "Error critico: No se pudieron cargar los archivos de catalogo."
    Write-Error "Asegurate de que 'Ajustes.ps1' y 'Servicios.ps1' existen en la subcarpeta 'Catalogos'."
    Read-Host "Presiona Enter para salir."
    exit
}

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

    # --- NUEVO: Anadimos una pausa final antes de volver al menu ---
    Read-Host "`nProceso finalizado. Presiona Enter para volver al menu principal..."
}

function Invoke-ExplorerRestart {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Host "`n[+] Reiniciando el Explorador de Windows para aplicar los cambios visuales..." -ForegroundColor Yellow
    Write-Log -LogLevel ACTION -Message "Reiniciando el Explorador de Windows a peticion del usuario."

    if ($PSCmdlet.ShouldProcess("explorer.exe", "Reiniciar")) {
        try {
            # Obtener todos los procesos del Explorador (puede haber mas de uno)
            $explorerProcesses = Get-Process -Name explorer -ErrorAction Stop
            
            # Detener los procesos
            $explorerProcesses | Stop-Process -Force
            Write-Host "   - Proceso(s) detenido(s)." -ForegroundColor Gray
            
            # Esperar a que terminen
            $explorerProcesses.WaitForExit()
            
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

function Manage-SystemServices {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    Write-Log -LogLevel INFO -Message "Usuario entro al Gestor de Servicios de Windows."

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
        
        # Obtenemos el ancho de la consola para que el texto se ajuste dinamicamente.
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        # Definimos la sangria para las descripciones.
        $descriptionIndent = 13
        foreach ($category in $categories) {
            Write-Host "--- Categoria: $category ---" -ForegroundColor Yellow
            $servicesInCategory = $fullServiceList | Where-Object { $_.Definition.Category -eq $category }

            foreach ($serviceItem in $servicesInCategory) {
                $itemIndex++
                $serviceDef = $serviceItem.Definition
                $checkbox = if ($serviceItem.Selected) { "[X]" } else { "[ ]" }
                $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($serviceDef.Name)'" -ErrorAction SilentlyContinue
                
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
                
                # Se imprime la linea principal del servicio
                Write-Host ("   [{0,2}] {1} " -f $itemIndex, $checkbox) -NoNewline
                Write-Host ("{0,-25}" -f $statusText) -ForegroundColor $statusColor -NoNewline
                Write-Host $serviceDef.Name -ForegroundColor White
                
                # Usamos la nueva funcion para formatear e imprimir la descripcion.
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
		
        # El resto de la funcion (menu y logica de acciones) permanece igual...
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

    # Definir la ruta del archivo de respaldo
    $parentDir = Split-Path -Parent $PSScriptRoot
    $backupDir = Join-Path -Path $parentDir -ChildPath "Backup"
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    $backupFile = Join-Path -Path $backupDir -ChildPath "ThirdPartyServicesBackup.json"

    # Funcion para obtener servicios de terceros
    function Get-ThirdPartyServices {
        $thirdPartyServices = @()
        $allServices = Get-CimInstance -ClassName Win32_Service
        
        foreach ($service in $allServices) {
            if ($service.PathName -and $service.PathName -notmatch '\\Windows\\' -and $service.PathName -notlike '*svchost.exe*') {
                $thirdPartyServices += $service
            }
        }
        return $thirdPartyServices | Sort-Object DisplayName
    }

    # Funcion para actualizar el backup con servicios nuevos
    function Update-ServicesBackup {
        param(
            [hashtable]$CurrentStates,
            [string]$BackupPath
        )
        
        $updated = $false
        $currentServices = Get-ThirdPartyServices
        
        foreach ($service in $currentServices) {
            if (-not $CurrentStates.ContainsKey($service.Name)) {
                # Servicio nuevo detectado, agregar al backup
                $CurrentStates[$service.Name] = @{
                    StartupType = $service.StartMode
                    DisplayName = $service.DisplayName
                    Description = $service.Description
                    AddedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                Write-Host "Servicio nuevo agregado al backup: $($service.DisplayName)" -ForegroundColor Yellow
                $updated = $true
            }
        }
        
        if ($updated) {
            try {
                $CurrentStates | ConvertTo-Json -Depth 3 | Set-Content -Path $BackupPath -Encoding UTF8 -ErrorAction Stop
                Write-Host "Backup actualizado con servicios nuevos." -ForegroundColor Green
            } catch {
                Write-Host "Error al actualizar el backup: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        return $CurrentStates
    }

    # Cargar o crear el backup de estados originales
    $originalStates = @{} # Inicializar como hashtable vacia por defecto

    if (Test-Path $backupFile) {
        Write-Host "Cargando estados originales desde el archivo de respaldo..." -ForegroundColor Gray
        try {
            $fileContent = Get-Content -Path $backupFile -Raw -ErrorAction Stop
            
            if ([string]::IsNullOrWhiteSpace($fileContent)) {
                throw [System.IO.InvalidDataException]::new("El archivo de respaldo esta vacio o no contiene datos validos.")
            }
            
            $jsonObject = $fileContent | ConvertFrom-Json -ErrorAction Stop
            
            # Convertir el objeto PSCustomObject a Hashtable manualmente
            foreach ($property in $jsonObject.PSObject.Properties) {
                $originalStates[$property.Name] = @{
                    StartupType = $property.Value.StartupType
                    DisplayName = $property.Value.DisplayName
                    Description = $property.Value.Description
                    AddedDate = $property.Value.AddedDate
                }
            }
            
            Write-Host "Respaldo cargado correctamente desde: $backupFile" -ForegroundColor Green
            $originalStates = Update-ServicesBackup -CurrentStates $originalStates -BackupPath $backupFile
        }
        catch [System.Text.Json.JsonException], [System.ArgumentException] {
            Write-Error "El archivo de respaldo '$backupFile' parece estar corrupto (JSON no valido)."
            Write-Log -LogLevel ERROR -Message "Fallo al cargar el respaldo: Archivo JSON corrupto. Error: $($_.Exception.Message)"
            # (Aqui iria la logica para recrear el respaldo)
        }
        catch [System.IO.InvalidDataException] {
            Write-Error "El archivo de respaldo '$backupFile' esta vacio."
            Write-Log -LogLevel ERROR -Message "Fallo al cargar el respaldo: Archivo vacio. Error: $($_.Exception.Message)"
            # (Aqui iria la logica para recrear el respaldo)
        }
        catch [System.IO.IOException] {
            Write-Error "No se pudo leer el archivo de respaldo '$backupFile'. Verifique los permisos o si otro programa lo esta usando."
            Write-Log -LogLevel ERROR -Message "Fallo al cargar el respaldo: Error de I/O. Error: $($_.Exception.Message)"
            Read-Host "Presiona Enter para continuar sin usar el respaldo..."
            # Se mantiene la hashtable vacia
        }
        catch {
            Write-Error "Ocurrio un error inesperado al cargar el archivo de respaldo."
            Write-Log -LogLevel ERROR -Message "Fallo al cargar el respaldo: Error inesperado. Error: $($_.Exception.Message)"
            # (Aqui iria la logica para recrear el respaldo como fallback)
        }
    } 

    # Si despues de todo, la tabla esta vacia, es porque no existia o fallo la carga. La creamos.
    if ($originalStates.Keys.Count -eq 0) {
        Write-Host "Creando respaldo de estados originales de servicios de terceros..." -ForegroundColor Gray
        $services = Get-ThirdPartyServices
        foreach ($service in $services) {
            $originalStates[$service.Name] = @{
                StartupType = $service.StartMode
                DisplayName = $service.DisplayName
                Description = $service.Description
                AddedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        try {
            $originalStates | ConvertTo-Json -Depth 3 | Set-Content -Path $backupFile -Encoding UTF8 -ErrorAction Stop
            Write-Host "Respaldo guardado en: $backupFile" -ForegroundColor Green
        } catch {
            Write-Error "Error al guardar el respaldo: $($_.Exception.Message)"
        }
    }

    # Obtener la lista actual de servicios para mostrar
    $rawServices = Get-ThirdPartyServices
    $displayItems = @()
    foreach ($service in $rawServices) {
        $displayItems += [PSCustomObject]@{
            ServiceObject = $service
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
            $service = $item.ServiceObject
            $checkbox = if ($item.Selected) { "[X]" } else { "[ ]" }
            $liveService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction SilentlyContinue
            
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

            # Indicador de servicio en backup (usando texto en lugar de simbolos Unicode)
            $backupIndicator = if ($item.InBackup) { " [BACKUP] " } else { " [NO BK] " }
            $backupColor = if ($item.InBackup) { "Green" } else { "Red" }
            
            Write-Host ("   [{0,2}] {1} " -f $itemIndex, $checkbox) -NoNewline
            Write-Host ("{0,-25}" -f $statusText) -ForegroundColor $statusColor -NoNewline
            Write-Host "$backupIndicator" -NoNewline -ForegroundColor $backupColor
            Write-Host $service.DisplayName -ForegroundColor White

            if (-not [string]::IsNullOrWhiteSpace($service.Description)) {
                $wrappedDescription = Format-WrappedText -Text $service.Description -Indent $descriptionIndent -MaxWidth $consoleWidth
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
        Write-Host "   [U] Actualizar backup con servicios nuevos"
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
                # Actualizar backup manualmente
                $originalStates = Update-ServicesBackup -CurrentStates $originalStates -BackupPath $backupFile
                
                # Actualizar indicadores de backup en la lista
                foreach ($item in $displayItems) {
                    $item.InBackup = $originalStates.ContainsKey($item.ServiceObject.Name)
                }
                
                Read-Host "Presiona Enter para continuar..."
            }
            elseif ($choice.ToUpper() -in @('D', 'H', 'R')) {
                $selectedItems = $displayItems | Where-Object { $_.Selected }
                if ($selectedItems.Count -eq 0) {
                    Write-Warning "No has seleccionado ningun servicio."
                    Start-Sleep -Seconds 2
                    continue
                }

                foreach ($itemAction in $selectedItems) {
                    $selectedService = $itemAction.ServiceObject
                    $actionDescription = ""
                    switch ($choice.ToUpper()) {
                        'D' { $actionDescription = "Deshabilitar" }
                        'H' { $actionDescription = "Habilitar" }
                        'R' { 
                            if (-not $itemAction.InBackup) {
                                Write-Host "El servicio '$($selectedService.DisplayName)' no tiene un estado original guardado." -ForegroundColor Red
                                $addToBackup = Read-Host "¿Deseas agregarlo al backup ahora? (S/N)"
                                if ($addToBackup.ToUpper() -eq 'S') {
                                    $originalStates[$selectedService.Name] = @{
                                        StartupType = $selectedService.StartMode
                                        DisplayName = $selectedService.DisplayName
                                        Description = $selectedService.Description
                                        AddedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                                    }
                                    $originalStates | ConvertTo-Json -Depth 3 | Set-Content -Path $backupFile
                                    $itemAction.InBackup = $true
                                    Write-Host "Servicio agregado al backup." -ForegroundColor Green
                                } else {
                                    Write-Host "No se puede restaurar un servicio sin backup." -ForegroundColor Red
                                    continue
                                }
                            }
                            $actionDescription = "Restaurar a estado original ($($originalStates[$selectedService.Name].StartupType))" 
                        }
                    }
                    
                    if ($PSCmdlet.ShouldProcess($selectedService.DisplayName, $actionDescription)) {
                        $newStartupType = ''
                        if ($choice.ToUpper() -eq 'D') { $newStartupType = 'Disabled' }
                        if ($choice.ToUpper() -eq 'H') { $newStartupType = 'Manual' }
                        if ($choice.ToUpper() -eq 'R') { $newStartupType = $originalStates[$selectedService.Name].StartupType }

                        Set-Service -Name $selectedService.Name -StartupType $newStartupType -ErrorAction Stop
                        
                        $isRunningNow = (Get-Service -Name $selectedService.Name).Status -eq 'Running'
                        if ($newStartupType -eq 'Disabled' -and $isRunningNow) {
                            Stop-Service -Name $selectedService.Name -Force -ErrorAction SilentlyContinue
                        } elseif ($newStartupType -ne 'Disabled' -and -not $isRunningNow) {
                            Start-Service -Name $selectedService.Name -ErrorAction SilentlyContinue
                        }
                        Write-Log -LogLevel ACTION -Message "Servicio de Aplicacion '$($selectedService.DisplayName)' modificado via accion '$actionDescription'."
                    }
                }

                Write-Host "`n[OK] Accion completada para los servicios seleccionados." -ForegroundColor Green
                $displayItems.ForEach({$_.Selected = $false})
                Read-Host "Presiona Enter para continuar..."
            }
            elseif ($choice.ToUpper() -ne 'V') {
                Write-Warning "Opcion no valida."
                Start-Sleep -Seconds 2
            }
        } catch {
            Write-Error "Error: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "Error en Manage-ThirdPartyServices: $($_.Exception.Message)"
            Read-Host "Presiona Enter para continuar..."
        }
    }
}

# =================================================================================
# --- INICIO DEL MoDULO DE LIMPIEZA ---
# =================================================================================

# --- FUNCIoN AUXILIAR 1: Calcula el tamaño recuperable de forma silenciosa ---
function Get-CleanableSize {
    param([string[]]$Paths)
    $totalSize = 0
    foreach ($path in $Paths) {
        if (Test-Path $path) {
            $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue -File
            if ($null -ne $items) {
                $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                $totalSize += $size
            }
        }
    }
    return $totalSize # Devuelve el tamaño en bytes
}

# --- FUNCIoN AUXILIAR 2: Limpieza Avanzada de Componentes del Sistema ---
# (Esta funcion no necesita cambios)
function Invoke-AdvancedSystemClean {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
	Write-Log -LogLevel INFO -Message "Usuario inicio la Limpieza Avanzada de Componentes de Windows."
    Write-Host "`n[+] Iniciando Limpieza Avanzada de Componentes del Sistema..." -ForegroundColor Cyan
	Write-Log -LogLevel ACTION -Message "Iniciando Limpieza Avanzada del Sistema."; Invoke-AdvancedSystemClean
    Write-Warning "Esta operacion eliminara archivos de instalaciones anteriores de Windows (Windows.old) y restos de actualizaciones."
    Write-Warning "Despues de esta limpieza, NO podras volver a la version anterior de Windows."
    if ((Read-Host "¿Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') {
		Write-Log -LogLevel WARN -Message "Usuario cancelo la Limpieza Avanzada de Componentes."
        Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
        return
    }
    if ($PSCmdlet.ShouldProcess("Componentes del Sistema", "Limpieza Profunda via cleanmgr.exe")) {
        try {
            Write-Host "[+] Configurando el Liberador de Espacio en Disco para una limpieza maxima..." -ForegroundColor Yellow
            $sagesetNum = 65535
            $handlers = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            foreach ($handler in $handlers) {
                try {
                    Set-ItemProperty -Path $handler.PSPath -Name "StateFlags0000" -Value 2 -Type DWord -Force
                } catch {}
            }
            Write-Host "[+] Ejecutando el Liberador de Espacio en Disco. Por favor, espera..." -ForegroundColor Yellow
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:$sagesetNum" -Wait -Verb RunAs
            Write-Host "`n[OK] Limpieza avanzada completada." -ForegroundColor Green
        } catch {
            Write-Error "Ocurrio un error durante la limpieza avanzada: $($_.Exception.Message)"
			Write-Log -LogLevel ERROR -Message "Error en Invoke-AdvancedSystemClean: $($_.Exception.Message)"
        }
    }
}

# --- FUNCIoN DE MENu PRINCIPAL ---
function Show-CleaningMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Limpieza."
    # Funcion auxiliar para medir y limpiar rutas de forma segura.
    function Invoke-SafeClean {
        param(
            [string[]]$Paths,
            [string]$Description
        )
        $totalSize = Get-CleanableSize -Paths $Paths
        if ($totalSize -gt 0) {
            $sizeInMB = [math]::Round($totalSize / 1MB, 2)
            Write-Host "[INFO] Se pueden liberar aproximadamente $($sizeInMB) MB en '$Description'." -ForegroundColor Cyan
            if ((Read-Host "¿Deseas continuar? (S/N)").ToUpper() -eq 'S') {
                Write-Host "[+] Limpiando..."
                foreach ($path in $Paths) {
                    if (Test-Path $path) {
                        try {
                            Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        } catch {
                            Write-Warning "No se pudo limpiar por completo '$path'. Puede que algunos archivos esten en uso."
                        }
                    }
                }
                Write-Host "[OK] Limpieza de '$Description' completada." -ForegroundColor Green
				Write-Log -LogLevel ACTION -Message "Limpieza de '$Description' completada. Se liberaron $($sizeInMB) MB."
                return $totalSize
            }
        } else {
            Write-Host "[OK] No se encontraron archivos para limpiar en '$Description'." -ForegroundColor Green
        }
        return 0
    }

    $cleanChoice = ''
    do {
        # --- Calculo de datos en CADA iteracion del bucle ---
        Write-Host "Refrescando datos, por favor espera..." -ForegroundColor Gray
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
        
        $sizeTempBytes = Get-CleanableSize -Paths $tempPaths
        $sizeCachesBytes = Get-CleanableSize -Paths $cachePaths
        
        # --- LoGICA MEJORADA PARA LA PAPELERA DE RECICLAJE ---
        $recycleBinSize = 0
        $recycleBinItemCount = 0
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBinItems = $shell.NameSpace(10).Items()
            $recycleBinItemCount = $recycleBinItems.Count
            foreach ($item in $recycleBinItems) {
                $recycleBinSize += $item.Size
            }
        } catch {
             # Si falla el COM, los valores se quedan en 0, lo que es seguro.
        }
        
        # Convertimos a MB para la visualizacion
        $sizeTempMB = [math]::Round($sizeTempBytes / 1MB, 2)
        $sizeCachesMB = [math]::Round($sizeCachesBytes / 1MB, 2)
        $sizeBinMB = [math]::Round($recycleBinSize / 1MB, 2)
        
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "               Modulo de Limpieza Profunda             " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Selecciona el tipo de limpieza que deseas ejecutar."
        Write-Host ""
        Write-Host "--- Limpieza Rapida (Archivos de Usuario) ---" -ForegroundColor Yellow
        Write-Host ""
		Write-Host "   [1] Limpieza Estandar (Temporales y Dumps de Errores)" -NoNewline; Write-Host " ($($sizeTempMB) MB)" -ForegroundColor Cyan
        Write-Host ""
		Write-Host "   [2] Limpieza de Caches (Sistema, Drivers y Miniaturas)" -NoNewline; Write-Host " ($($sizeCachesMB) MB)" -ForegroundColor Cyan
        Write-Host ""
		Write-Host "   [3] Vaciar Papelera de Reciclaje" -NoNewline; Write-Host " ($($sizeBinMB) MB)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "--- Limpieza Profunda (Archivos de Sistema) ---" -ForegroundColor Yellow
        Write-Host ""
		Write-Host "   [4] Limpieza de Componentes de Windows (Windows.old, etc.)" -ForegroundColor Red
        Write-Host ""
        Write-Host "   [T] TODO (Ejecutar todas las limpiezas rapidas [1-3])"
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
		$cleanChoice = Read-Host "`nSelecciona una opcion"
		
		Write-Log -LogLevel INFO -Message "Usuario selecciono la opcion de limpieza '$($cleanChoice.ToUpper())'"

        $totalFreed = 0
        switch ($cleanChoice.ToUpper()) {
			
            '1' { 
                $freed = Invoke-SafeClean -Paths $tempPaths -Description "Archivos Temporales y Dumps de Errores"
				Write-Log -LogLevel ACTION -Message "Iniciando Limpieza Segura."; Invoke-SafeClean
                $totalFreed += $freed
            }
            '2' {
                $freed = Invoke-SafeClean -Paths $cachePaths -Description "Caches de Sistema y Drivers"
				Write-Log -LogLevel ACTION -Message "Iniciando Limpieza Profunda."; Invoke-DeepClean
                $totalFreed += $freed
                # Limpieza de miniaturas no devuelve tamaño, pero se ejecuta
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue; try { Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction Stop; Write-Host "[OK] Cache de miniaturas limpiada." -ForegroundColor Green } catch { Write-Warning "No se pudo limpiar la cache de miniaturas." } finally { Start-Process "explorer" }
            }
            '3' {
                if ($recycleBinItemCount -gt 0) {
                    Write-Host "[+] Vaciando la Papelera de Reciclaje..."
                    Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1 # Pequeña pausa
                    $totalFreed += $recycleBinSize 
                    Write-Host "[OK] Operacion de vaciado completada." -ForegroundColor Green
					Write-Log -LogLevel ACTION -Message "Papelera de Reciclaje vaciada exitosamente."
                } else {
                    Write-Host "[OK] La Papelera de Reciclaje ya estaba vacia." -ForegroundColor Green
                }
            }
            '4' { Invoke-AdvancedSystemClean }
            'T' {
                $totalFreed += Invoke-SafeClean -Paths $tempPaths -Description "Archivos Temporales y Dumps de Errores"
                $totalFreed += Invoke-SafeClean -Paths $cachePaths -Description "Caches de Sistema y Drivers"
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue; try { Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction Stop;
				Write-Host "[OK] Cache de miniaturas limpiada." -ForegroundColor Green
				} catch {
					Write-Warning "No se pudo limpiar la cache de miniaturas."
					Write-Log -LogLevel ERROR -Message "Fallo la limpieza de cache de miniaturas: $($_.Exception.Message)"
					} finally {
						Start-Process "explorer"
						}
                if ($recycleBinItemCount -gt 0) {
                    Write-Host "[+] Vaciando la Papelera de Reciclaje..."
                    Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
                    $totalFreed += $recycleBinSize
                    Write-Host "[OK] Operacion de vaciado completada." -ForegroundColor Green
                } else { Write-Host "[OK] La Papelera de Reciclaje ya estaba vacia." -ForegroundColor Green }
            }
            'V' { continue }
            default { Write-Warning "Opcion no valida." }
        }

        if ($totalFreed -gt 0) {
            $freedMB = [math]::Round($totalFreed / 1MB, 2)
            Write-Host "`n[EXITO] ¡Se han liberado aproximadamente $freedMB MB!" -ForegroundColor Magenta
        }

        if ($cleanChoice.ToUpper() -ne 'V') { Read-Host "`nPresiona Enter para continuar..." }
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
                
                try {
                    Write-Log -LogLevel ACTION -Message "INICIO: Se aplico la accion '$action' al programa '$($item.Name)'."
                    # --- LoGICA DE ACCIoN 100% NATIVA ---
                    switch ($item.Type) {
                        'Registry' {
                            Set-StartupApprovedStatus -ItemName $item.Name -BaseKeyPath $item.BaseKey -ItemType $item.ItemType -Action $action -ErrorAction Stop
                        }
                        'Folder' {
                            Set-StartupApprovedStatus -ItemName $item.Name -BaseKeyPath $item.BaseKey -ItemType $item.ItemType -Action $action -ErrorAction Stop
                        }
                        'Task' {
                             if ($action -eq 'Disable') {
                                Disable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction Stop
                            } else {
                                Enable-ScheduledTask -TaskPath $item.Path -TaskName $item.Name -ErrorAction Stop
                            }
                        }
                    }
                }
                catch {
                    Write-Log -LogLevel ERROR -Message "INICIO: Fallo al aplicar '$action' a '$($item.Name)'. Motivo: $($_.Exception.Message)"
                }
            }
			Write-Host "`n[OK] Se modificaron $($selectedItems.Count) programas." -ForegroundColor Green
            $startupItems.ForEach({$_.Selected = $false})
            Write-Host "`n[OK] Accion completada. Refrescando lista..." -ForegroundColor Green
            Start-Sleep -Seconds 2
            $startupItems = Get-AllStartupItems
        }
    }
}

function Repair-SystemFiles {
    Write-Log -LogLevel INFO -Message "Usuario inicio la secuencia de reparacion del sistema (SFC/DISM)."
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
        Write-Host "`n[+] PASO 2/3: No se detecto corrupcion en la imagen de Windows. Omitiendo reparacion." -ForegroundColor Green
    }

    # --- PASO 2: Reparar Archivos del Sistema con SFC ---
    Write-Host "`n[+] PASO 3/3: Ejecutando SFC para verificar los archivos del sistema..." -ForegroundColor Yellow
    sfc.exe /scannow

    if ($LASTEXITCODE -ne 0) {
		Write-Log -LogLevel WARN -Message "SFC: Scannow finalizo con un codigo de error ($LASTEXITCODE)."
        Write-Warning "SFC encontro un error o no pudo reparar todos los archivos."
    } else {
        Write-Host "[OK] SFC ha completado su operacion." -ForegroundColor Green
		Write-Log -LogLevel ACTION -Message "REPAIR/SFC: Se encontraron y repararon archivos de sistema corruptos."
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
	Write-Log -LogLevel INFO -Message "Usuario inicio la limpieza de caches del sistema (DNS, Tienda)."
    try {
        ipconfig /flushdns | Out-Null
        Write-Host "[OK] Cache DNS limpiada." -ForegroundColor Green
		Write-Log -LogLevel ACTION -Message "Cache DNS limpiada."
    }
    catch {
		Write-Warning "Error limpiando DNS: $_"
		Write-Log -LogLevel ERROR -Message "Error limpiando DNS: $_"
	}

    try {
        Start-Process "wsreset.exe" -ArgumentList "-q" -Wait -NoNewWindow
        Write-Host "[OK] Cache de Tienda Windows limpiada." -ForegroundColor Green
		Write-Log -LogLevel ACTION -Message "Cache de Tienda Windows limpiada."
    }
    catch {
		Write-Warning "Error en wsreset: $_"
		Write-Log -LogLevel ERROR -Message "Error en wsreset: $_"
	}
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
	$parentDir = Split-Path -Parent $PSScriptRoot;
	$diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos";
	if (-not (Test-Path $diagDir))
	{
		New-Item -Path $diagDir -ItemType Directory | Out-Null };
		$reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Salud_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').html";
		Write-Log -LogLevel INFO -Message "Generando reporte de energia del sistema.";
		powercfg /energy /output $reportPath /duration 60;
		if (Test-Path $reportPath)
		{
			Write-Host "[OK] Reporte generado en: '$reportPath'" -ForegroundColor Green;
			Start-Process $reportPath
	} else {
     	Write-Error "No se pudo generar el reporte."
    };
		
	Read-Host "`nPresiona Enter para volver..."
}

# ===================================================================
# --- INICIO DEL MoDULO DE DIAGNoSTICO Y REPARACIoN DE RED (REFACTORIZADO) ---
# ===================================================================

# --- Funciones de Accion (Herramientas del modulo) ---

function Invoke-ShowIpConfig {
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "`n[+] Mostrando configuracion de red detallada (ipconfig /all)..." -ForegroundColor Cyan
        ipconfig.exe /all
    }
    catch {
        Write-Error "No se pudo obtener la configuracion de red. Error: $($_.Exception.Message)"
    }
}

function Invoke-PingTest {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n[+] Realizando prueba de conectividad a Internet (8.8.8.8)..." -ForegroundColor Cyan
        Test-NetConnection -ComputerName "8.8.8.8" -WarningAction SilentlyContinue
    }
    catch {
    Write-Error "La prueba de conexion fallo. Error: $($_.Exception.Message)"
    }
}

function Invoke-DnsResolutionTest {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n[+] Realizando prueba de resolucion de nombres de dominio (google.com)..." -ForegroundColor Cyan
        Resolve-DnsName -Name "google.com" -ErrorAction Stop | Format-Table
    }
    catch {
        Write-Error "No se pudo resolver el nombre de dominio. Error: $($_.Exception.Message)"
    }
}

function Invoke-TraceRoute {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n[+] Trazando la ruta de red hacia 8.8.8.8 (puede tardar un momento)..." -ForegroundColor Cyan
        Test-NetConnection -ComputerName "8.8.8.8" -TraceRoute -WarningAction Stop
    }
    catch {
        Write-Error "El trazado de ruta fallo. Error: $($_.Exception.Message)"
    }
}

function Invoke-FlushDnsCache {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n[+] Limpiando la cache de resolucion de DNS..." -ForegroundColor Cyan
        Clear-DnsClientCache
        Write-Host "[OK] Cache de DNS limpiada exitosamente." -ForegroundColor Green
    }
    catch {
        Write-Error "No se pudo limpiar la cache de DNS. Error: $($_.Exception.Message)"
    }
}

function Invoke-RenewIpAddress {
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "`n[+] Liberando y renovando la direccion IP..." -ForegroundColor Cyan
        Write-Host " - Liberando IP actual (ipconfig /release)..." -ForegroundColor Gray
        ipconfig.exe /release | Out-Null
        Write-Host " - Solicitando nueva IP (ipconfig /renew)..." -ForegroundColor Gray
        ipconfig.exe /renew | Out-Null
        Write-Host "[OK] Proceso de renovacion de IP completado." -ForegroundColor Green
    }
    catch {
        Write-Error "No se pudo renovar la direccion IP. Error: $($_.Exception.Message)"
    }
}

function Invoke-ResetNetworkStacks {
    [CmdletBinding()]
    param()
    
    try {
        Write-Warning "¡ADVERTENCIA! Esta accion requiere reiniciar el equipo para completarse."
        Write-Host "`n[+] Restableciendo la Pila de Red (Winsock y TCP/IP)..." -ForegroundColor Red
        Write-Host " - Restableciendo el catalogo de Winsock..." -ForegroundColor Gray
        netsh.exe winsock reset | Out-Null
        Write-Host " - Restableciendo la pila TCP/IP..." -ForegroundColor Gray
        netsh.exe int ip reset | Out-Null
        Write-Host "[OK] Pila de red restablecida. Por favor, reinicia tu equipo para aplicar los cambios." -ForegroundColor Green
    }
    catch {
        Write-Error "No se pudo restablecer la pila de red. Error: $($_.Exception.Message)"
    }
}

# --- Funcion Principal del Menu (Controlador del modulo) ---

function Show-NetworkDiagnosticsMenu {
    # Menu definido como un array de objetos para mayor flexibilidad y mantenibilidad.
    $menuItems = @(
        [PSCustomObject]@{
            Text   = "Ver configuracion IP detallada (ipconfig /all)"
            Type   = "Diagnostico"
            Action = { Invoke-ShowIpConfig }
            NeedsConfirmation = $false
        },
        [PSCustomObject]@{
            Text   = "Probar conectividad a Internet (ping)"
            Type   = "Diagnostico"
            Action = { Invoke-PingTest }
            NeedsConfirmation = $false
        },
        [PSCustomObject]@{
            Text   = "Probar resolucion de DNS (nslookup)"
            Type   = "Diagnostico"
            Action = { Invoke-DnsResolutionTest }
            NeedsConfirmation = $false
        },
        [PSCustomObject]@{
            Text   = "Trazar ruta de red (tracert)"
            Type   = "Diagnostico"
            Action = { Invoke-TraceRoute }
            NeedsConfirmation = $false
        },
        [PSCustomObject]@{
            Text   = "Limpiar cache de DNS"
            Type   = "Reparacion"
            Action = { Invoke-FlushDnsCache }
            NeedsConfirmation = $true
        },
        [PSCustomObject]@{
            Text   = "Renovar concesion de IP"
            Type   = "Reparacion"
            Action = { Invoke-RenewIpAddress }
            NeedsConfirmation = $true
        },
        [PSCustomObject]@{
            Text   = "Restablecer la Pila de Red (Requiere Reinicio)"
            Type   = "Reparacion"
            Action = { Invoke-ResetNetworkStacks }
            NeedsConfirmation = $true
        }
    )

    $netChoice = ''
    do {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "      Modulo de Diagnostico y Reparacion de Red        " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        
        $isConnected = Test-NetConnection -ComputerName "1.1.1.1" -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Host "Estado de la Conexion: " -NoNewline
        if ($isConnected) {
            Write-Host "CONECTADO A INTERNET" -ForegroundColor Green
        } else {
            Write-Host "SIN CONEXIoN A INTERNET" -ForegroundColor Red
        }
        Write-Host ""

        # Generacion dinamica del menu
        $itemIndex = 1
        $menuItems | Group-Object -Property Type | ForEach-Object {
            $categoryColor = if ($_.Name -eq "Reparacion") { "Red" } else { "Yellow" }
            Write-Host "--- Acciones de $($_.Name) ---" -ForegroundColor $categoryColor
            foreach ($item in $_.Group) {
                Write-Host "   [$itemIndex] $($item.Text)"
                $itemIndex++
            }
            Write-Host ""
        }
        
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $rawChoice = Read-Host "Selecciona una opcion"

        if ($rawChoice.ToUpper() -eq 'V') { continue }

        if (($rawChoice -match '^\d+$') -and ([int]$rawChoice -ge 1 -and [int]$rawChoice -le $menuItems.Count)) {
            $selectedOption = $menuItems[[int]$rawChoice - 1]
            $proceed = $true

            if ($selectedOption.NeedsConfirmation) {
                $confirm = Read-Host "`n¿Estas seguro de que deseas ejecutar '$($selectedOption.Text)'? (S/N)"
                if ($confirm.ToUpper() -ne 'S') {
                    $proceed = $false
                    Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
                }
            }

            if ($proceed) {
				Write-Log -LogLevel INFO -Message "NETWORK: Ejecutando la acción '$($selectedOption.Text)'."
                # Invocar el bloque de accion asociado a la opcion del menu
                & $selectedOption.Action
            }

            Read-Host "`nPresiona Enter para continuar..."
        }
        else {
            Write-Warning "Opcion no valida."
            Start-Sleep -Seconds 2
        }
        
    } while ($rawChoice.ToUpper() -ne 'V')
}

# ===================================================================
# --- INICIO DEL MODULO DE ANALIZADOR DE REGISTROS DE EVENTOS ---
# ===================================================================

# --- Funcion auxiliar principal para obtener eventos ---

function Generate-EventTable {
        param($Title, $Icon, $Events)
        $eventCount = if ($null -ne $Events) { @($Events).Count } else { 0 }
        
        $safeTitle = $Title -replace '[^a-zA-Z0-9]', ''
        $tableId = "table-$safeTitle"
        $inputId = "search-$safeTitle"

        $html = "<div class='section'><h2><i class='fas fa-$Icon'></i>$Title ($eventCount)</h2>"
        # Añadimos el buscador
        $html += "<div class='search-box'><input type='text' id='$inputId' onkeyup=`"searchTable('$inputId', '$tableId')`" placeholder='Buscar en esta seccion...'></div>"
        
        if ($eventCount -gt 0) {
            $html += "<table id='$tableId'><thead><tr><th>Fecha y Hora</th><th>Origen</th><th>Mensaje (Primera Linea)</th></tr></thead><tbody>"
            foreach ($event in $Events) {
                $message = [System.Web.HttpUtility]::HtmlEncode(($event.Message -split "[`r`n]")[0])
                $html += "<tr><td>$($event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))</td><td>$($event.ProviderName)</td><td>$message</td></tr>"
            }
            $html += "</tbody></table>"
        } else {
            $html += "<p>No se encontraron eventos recientes en esta categoria.</p>"
        }
        $html += "</div>"
        return $html
}

function Get-EventLogReportData {
    [CmdletBinding()]
    param(
        [int]$MaxEventsPerCategory = 30
    )

    Write-Host "`n[+] Recopilando los ultimos $MaxEventsPerCategory eventos importantes. Esto puede tardar un momento..." -ForegroundColor Yellow

    # Categoria 1: Errores Criticos del Sistema (Nivel 1)
    $criticalEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1} -MaxEvents $MaxEventsPerCategory -ErrorAction SilentlyContinue

    # Categoria 2: Errores del Sistema (Nivel 2)
    $systemErrorEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents $MaxEventsPerCategory -ErrorAction SilentlyContinue

    # Categoria 3: Errores de Aplicaciones (Nivel 2)
    $appErrorEvents = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2} -MaxEvents $MaxEventsPerCategory -ErrorAction SilentlyContinue

    # Categoria 4: Auditorias de Seguridad Fallidas
    $auditFailEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; Keywords=4503599627370496} -MaxEvents $MaxEventsPerCategory -ErrorAction SilentlyContinue

    # Devolvemos un solo objeto con todas las colecciones de eventos
    return [PSCustomObject]@{
        CriticalSystemEvents   = $criticalEvents
        SystemErrorEvents      = $systemErrorEvents
        ApplicationErrorEvents = $appErrorEvents
        FailedSecurityAudits   = $auditFailEvents
        ReportDate             = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Hostname               = $env:COMPUTERNAME
    }
}

function Build-EventLogHtmlReport {
    param ([Parameter(Mandatory=$true)] $EventData)

    Add-Type -AssemblyName System.Web

    # --- CSS (sin cambios) ---
    $head = @"
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Analisis de Eventos - Aegis Phoenix Suite</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    <style>
        :root { --bg-color: #f4f7f9; --main-text-color: #2c3e50; --primary-color: #c0392b; --secondary-color: #34495e; --card-bg-color: #ffffff; --header-text-color: #ecf0f1; --border-color: #dfe6e9; --shadow: 0 5px 15px rgba(0,0,0,0.08); }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: var(--main-text-color); background-color: var(--bg-color); max-width: 1400px; margin: auto; padding: 20px; }
        .header { background: linear-gradient(135deg, var(--secondary-color) 0%, var(--primary-color) 100%); color: var(--header-text-color); padding: 30px; border-radius: 8px; margin-bottom: 30px; box-shadow: var(--shadow); }
        h1, h2 { margin: 0; font-weight: 600; } h1 { font-size: 2.8em; display: flex; align-items: center; } h1 i { margin-right: 15px; }
        h2 { color: var(--secondary-color); border-bottom: 2px solid var(--border-color); padding-bottom: 10px; margin: 0 0 20px 0; font-size: 1.8em; display: flex; align-items: center; } h2 i { margin-right: 10px; color: var(--primary-color); }
        .timestamp { font-size: 1em; opacity: 0.9; margin-top: 5px; } .section { background-color: var(--card-bg-color); border-radius: 8px; padding: 25px; margin-bottom: 25px; box-shadow: var(--shadow); }
        table { width: 100%; border-collapse: collapse; font-size: 0.9em; margin-top: 15px; } th { background-color: var(--secondary-color); color: var(--header-text-color); text-align: left; padding: 12px 15px; font-weight: 600; }
        td { padding: 10px 15px; border-bottom: 1px solid var(--border-color); } tr:nth-child(even) { background-color: #fdfdfd; } tr:hover { background-color: #f1f5f8; }
        .search-box input { width: 98%; padding: 10px 15px; border: 1px solid var(--border-color); border-radius: 5px; margin-bottom: 15px; font-size: 1em; } /* Estilo del buscador */
        .footer { text-align: center; margin-top: 40px; color: #6c757d; font-size: 0.8em; }
    </style>
</head>
"@
    
    $body = "<body>"
    $body += "<h1><i class='fas fa-shield-alt'></i>Aegis Phoenix Suite - Reporte de Analisis de Eventos</h1>"
    $body += "<p class='timestamp'>Generado el: $($EventData.ReportDate) para el equipo $($EventData.Hostname)</p>"
    $body += Generate-EventTable -Title "Errores Criticos del Sistema" -Icon "bomb" -Events $EventData.CriticalSystemEvents
    $body += Generate-EventTable -Title "Errores del Sistema" -Icon "times-circle" -Events $EventData.SystemErrorEvents
    $body += Generate-EventTable -Title "Errores de Aplicaciones" -Icon "cogs" -Events $EventData.ApplicationErrorEvents
    $body += Generate-EventTable -Title "Auditorias de Seguridad Fallidas" -Icon "user-secret" -Events $EventData.FailedSecurityAudits
    
    $body += @"
        <script>
            function searchTable(inputId, tableId) {
                const filter = document.getElementById(inputId).value.toUpperCase();
                const table = document.getElementById(tableId);
                const rows = table.getElementsByTagName('tbody')[0].rows;
                for (let i = 0; i < rows.length; i++) {
                    const cells = rows[i].getElementsByTagName('td');
                    let found = false;
                    for (let j = 0; j < cells.length; j++) {
                        if (cells[j] && cells[j].textContent.toUpperCase().indexOf(filter) > -1) {
                            found = true;
                            break;
                        }
                    }
                    rows[i].style.display = found ? "" : "none";
                }
            }
        </script>
        <div class="footer"><p>Aegis Phoenix Suite by SOFTMAXTER</p></div>
    </body>
"@
    
    return "<!DOCTYPE html><html lang='es'>$($head)$($body)</html>"
}

function Show-EventLogAnalyzerMenu {
    $logChoice = ''
    do {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "         Analizador Rapido de Registros de Eventos     " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Generar reporte HTML completo (ultimos eventos)"
        Write-Host "   [2] Buscar eventos por un origen especifico y generar reporte"
        Write-Host ""
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $logChoice = Read-Host "Selecciona una opcion"
        
        $parentDir = Split-Path -Parent $PSScriptRoot
        $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
        if (-not (Test-Path $diagDir)) { New-Item -Path $diagDir -ItemType Directory | Out-Null }
        
        switch ($logChoice.ToUpper()) {
            '1' {
				Write-Log -LogLevel INFO -Message "EVENTLOG: Usuario selecciono 'Generar reporte HTML completo'."
                $eventData = Get-EventLogReportData
                $htmlContent = Build-EventLogHtmlReport -EventData $eventData
                $reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Eventos_Completo_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').html"
                Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8
                
                Write-Host "`n[OK] Reporte completo generado en: '$reportPath'" -ForegroundColor Green
                Start-Process $reportPath
                Read-Host "`nPresiona Enter para continuar..."
            }
            '2' {
				Write-Log -LogLevel INFO -Message "EVENTLOG: Usuario seleccionó 'Buscar eventos por origen'."
                $providerName = Read-Host "Introduce la palabra clave del origen a buscar (ej. Office, Disk, nvlddmkm)"
                if ([string]::IsNullOrWhiteSpace($providerName)) {
                    Write-Warning "La palabra clave no puede estar vacia." ; Start-Sleep -Seconds 2; continue
                }
                $maxEvents = Read-Host "Introduce el numero maximo de eventos a buscar (ej. 100)"
                if (-not ($maxEvents -match '^\d+$') -or [int]$maxEvents -le 0) { $maxEvents = 100 }

                Write-Host "`n[+] Buscando eventos que contengan '$providerName' en los registros de Sistema y Aplicacion..." -ForegroundColor Yellow
                
                $searchTerm = "*$providerName*"
                $systemEvents = Get-WinEvent -LogName 'System' -MaxEvents 5000 -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -like $searchTerm }
                $appEvents = Get-WinEvent -LogName 'Application' -MaxEvents 5000 -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -like $searchTerm }
                
                $searchedEvents = ($systemEvents + $appEvents) | Sort-Object TimeCreated -Descending | Select-Object -First ([int]$maxEvents)
                
                if ($searchedEvents.Count -eq 0) {
                    Write-Host "`n[INFO] No se encontraron eventos que coincidan con la busqueda '$providerName'." -ForegroundColor Yellow
                    Read-Host "`nPresiona Enter para continuar..."
                    continue
                }
                Add-Type -AssemblyName System.Web
                $head = (Get-Content (Join-Path $PSScriptRoot 'AegisPhoenixSuite.ps1') -Raw) -match '(?s)<head>.*?</head>' | ForEach-Object { $matches[0] }
                $js = (Get-Content (Join-Path $PSScriptRoot 'AegisPhoenixSuite.ps1') -Raw) -match '(?s)<script>.*?</script>' | ForEach-Object { $matches[0] }
                
                $body = "<body><h1><i class='fas fa-shield-alt'></i>Aegis Phoenix Suite - Busqueda de Eventos</h1>"
                $body += "<p class='timestamp'>Resultados para la busqueda '$providerName' el $(Get-Date -Format 'yyyy-MM-dd HH-mm:ss')</p>"
                $body += Generate-EventTable -Title "Resultados de Busqueda para '$providerName'" -Icon "search" -Events $searchedEvents
                $body += $js
                $body += "<div class='footer'><p>Aegis Phoenix Suite by SOFTMAXTER</p></div></body>"
                $htmlContent = "<!DOCTYPE html><html lang='es'>$head$body</html>"

                $reportPath = Join-Path -Path $diagDir -ChildPath "Reporte_Busqueda_Eventos_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').html"
                Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8

                Write-Host "`n[OK] Reporte de busqueda generado en: '$reportPath'" -ForegroundColor Green
                Start-Process $reportPath
                Read-Host "`nPresiona Enter para continuar..."
            }
            'V' { continue }
            default { Write-Warning "Opcion no valida." ; Start-Sleep -Seconds 2 }
        }
    } while ($logChoice.ToUpper() -ne 'V')
}

# ===================================================================
# --- INICIO DEL MODULO DE RESPALDO DE DATOS DE USUARIO (ROBOCOPY) ---
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
        $sourcePaths = @(
            [System.Environment]::GetFolderPath('Desktop')
			[System.Environment]::GetFolderPath('MyDocuments')
            [System.Environment]::GetFolderPath('MyPictures')
            [System.Environment]::GetFolderPath('MyMusic')
            [System.Environment]::GetFolderPath('MyVideos')
        ) | Where-Object { Test-Path $_ }
    }
    
    # 2. Solicitamos y validamos el destino
    Write-Host "`n[+] Por favor, selecciona la carpeta de destino para el respaldo..." -ForegroundColor Yellow
    $destinationPath = Select-PathDialog -DialogType 'Folder' -Title "Paso 2: Elige la Carpeta de Destino del Respaldo"
    
    if ([string]::IsNullOrWhiteSpace($destinationPath)) {
        Write-Warning "No se selecciono una carpeta de destino. Operacion cancelada." ; Start-Sleep -Seconds 2; return
    }

    # Comprobacion inteligente de Origen vs. Destino
    $sourceDriveLetter = (Get-Item -Path $sourcePaths[0]).PSDrive.Name
    $destinationDriveLetter = (Get-Item -Path $destinationPath).PSDrive.Name
    if ($sourceDriveLetter.ToUpper() -eq $destinationDriveLetter.ToUpper()) {
        Write-Warning "El destino esta en la misma unidad que el origen (Unidad $($sourceDriveLetter.ToUpper()):)."
        Write-Warning "Un respaldo en el mismo disco no protege contra fallos del disco fisico."
        if ((Read-Host "Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') {
            Write-Host "[INFO] Operacion cancelada." -ForegroundColor Yellow; Start-Sleep -Seconds 2; return
        }
    }
    
    # Calculamos el espacio requerido
    Write-Host "`n[+] Calculando espacio requerido para el respaldo. Esto puede tardar..." -ForegroundColor Yellow
    $sourceTotalSize = 0
    try {
        if ($backupType -eq 'Files') {
            $sourceTotalSize = ($sourcePaths | Get-Item | Measure-Object -Property Length -Sum).Sum
        } else {
            foreach ($folder in $sourcePaths) {
                $sourceTotalSize += (Get-ChildItem -Path $folder -Recurse -Force -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
            }
        }
    } catch {
        Write-Warning "No se pudo calcular el tamano total. Error: $($_.Exception.Message)"
    }
    
    $destinationFreeSpace = (Get-Volume -DriveLetter $destinationDriveLetter).SizeRemaining
    $sourceTotalSizeGB = [math]::Round($sourceTotalSize / 1GB, 2)
    $destinationFreeSpaceGB = [math]::Round($destinationFreeSpace / 1GB, 2)
    Write-Host "Espacio requerido estimado: $sourceTotalSizeGB GB"
    Write-Host "Espacio disponible en el destino ($($destinationDriveLetter.ToUpper()):): $destinationFreeSpaceGB GB"

    if ($sourceTotalSize -gt $destinationFreeSpace) {
        Write-Error "No hay suficiente espacio en el disco de destino para completar el respaldo."
        Read-Host "`nOperacion abortada. Presiona Enter para volver al menu..."
        return
    }

    # 3. Configuramos Robocopy
    $logDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    $logFile = Join-Path $logDir "Respaldo_Robocopy_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
    $baseRoboCopyArgs = @("/COPY:DAT", "/R:3", "/W:5", "/XJ", "/NP", "/TEE")

    # 4. Mostramos el resumen y pedimos confirmacion final
    Clear-Host
    $modeDescription = if ($Mode -eq 'Mirror') { "Sincronizacion Completa (Modo Espejo)" } else { "Respaldo Simple (Anadir/Actualizar)" }
    Write-Host "--- RESUMEN DE LA OPERACION DE RESPALDO ---" -ForegroundColor Cyan
    Write-Host "Modo: $modeDescription"
    Write-Host "Destino: $destinationPath"
    if ($backupType -eq 'Files') {
        Write-Host "Archivos de Origen:"
    } else {
        Write-Host "Carpetas de Origen:"
    }
    $sourcePaths | ForEach-Object { Write-Host " - $_" }
    if ($Mode -eq 'Mirror') {
        Write-Warning "El Modo Espejo eliminara cualquier archivo en el destino que no exista en el origen."
    }
    Write-Host "Se generara un registro detallado en: $logFile"
    Write-Log -LogLevel INFO -Message "BACKUP: Resumen de la operación. Modo: '$Mode'. Origen: $($sourcePaths -join ', '). Destino: '$destinationPath'."
	
    if ((Read-Host "`nEstas listo para iniciar el respaldo? (S/N)").ToUpper() -ne 'S') {
        Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow; Start-Sleep -Seconds 2; return
    }

    # 5. Ejecutamos el respaldo
    $logArg = "/LOG+:`"$logFile`""

    if ($backupType -eq 'Files') {
        Write-Host "`n[+] Respaldando $($sourcePaths.Count) archivo(s) hacia '$destinationPath'..." -ForegroundColor Yellow
        $baseFileArgs = $baseRoboCopyArgs
        $filesByDirectory = $sourcePaths | Get-Item | Group-Object -Property DirectoryName
        foreach ($group in $filesByDirectory) {
            $sourceDir = $group.Name
            $fileNames = $group.Group | ForEach-Object { "`"$($_.Name)`"" }
            Write-Host " - Procesando lote desde '$sourceDir'..." -ForegroundColor Gray
            $currentArgs = @("`"$sourceDir`"", "`"$destinationPath`"") + $fileNames + $baseFileArgs + $logArg
            Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow
        }
    } else {
        $folderArgs = $baseRoboCopyArgs + "/E"
        if ($Mode -eq 'Mirror') {
            $folderArgs = $baseRoboCopyArgs + "/MIR"
        }
        foreach ($sourceFolder in $sourcePaths) {
            $folderName = Split-Path $sourceFolder -Leaf
            $destinationFolder = Join-Path $destinationPath $folderName
            Write-Host "`n[+] Respaldando '$folderName' hacia '$destinationFolder'..." -ForegroundColor Yellow
            $currentArgs = @("`"$sourceFolder`"", "`"$destinationFolder`"") + $folderArgs + $logArg
            Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow
        }
    }

    Write-Host "`n[EXITO] Operacion de respaldo completada." -ForegroundColor Green
    Write-Host "Se ha guardado un registro detallado en '$logFile'"
    if ((Read-Host "Deseas abrir el archivo de registro ahora? (S/N)").ToUpper() -eq 'S') {
        Start-Process "notepad.exe" -ArgumentList $logFile
    }
    Read-Host "`nPresiona Enter para volver al menu..."
}


# --- FUNCION 3: INTERFAZ DE USUARIO DEL MODULO DE RESPALDO ---
function Show-UserDataBackupMenu {
    # Funcion interna para no repetir el menu de seleccion de modo
    function Get-BackupMode {
        Write-Host ""
        Write-Host "--- Elige un modo de respaldo ---" -ForegroundColor Yellow
        Write-Host "   [1] Simple (Anadir y Actualizar)"
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
# --- INICIO DEL MoDULO DE INVENTARIO PROFESIONAL ---
# ===================================================================

function Get-DetailedWindowsVersion {
    # Obtenemos los datos clave del registro en una sola llamada para mayor eficiencia
    $winVerInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

    $buildNumber = [int]$winVerInfo.CurrentBuildNumber
	$ubrNumber = $winVerInfo.UBR
    $fullBuildString = "$buildNumber.$ubrNumber"  
    $editionId = $winVerInfo.EditionID

    # Determinar el nombre base (Windows 10 o 11) segun el numero de compilacion
    $baseProductName = "Windows 10" # Valor por defecto
    if ($buildNumber -ge 22000) {
        $baseProductName = "Windows 11"
    }

    # Traducir el EditionID a un nombre mas amigable, como en tu ejemplo
    $friendlyEdition = switch ($editionId) {
        "Core"                  { "Home" }
        "CoreSingleLanguage"    { "Home Single Language" }
        "Professional"          { "Pro" }
        "ProfessionalWorkstation" { "Pro for Workstations" }
        "ProfessionalEducation" { "Pro Education" }
        "Enterprise"            { "Enterprise" }
        "EnterpriseS"           { "Enterprise LTSC" }
        "Education"             { "Education" }
        default                 { $editionId }
    }

    # Devolvemos la cadena de texto combinada y detallada
    return "$baseProductName $friendlyEdition (Build: $fullBuildString)"
}

# --- FUNCIoN AUXILIAR 1: Recopilador de Datos Exhaustivo ---
function Get-SystemInventoryData {
    Write-Host "`n[+] Recopilando informacion exhaustiva del sistema. Esto puede tardar un momento..." -ForegroundColor Yellow
    
    # -- Sistema y Rendimiento --
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $csInfo = Get-ComputerInfo
    $uptime = (Get-Date) - $osInfo.LastBootUpTime
	$physicalCores = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
    $systemData = @{
        WindowsVersion = Get-DetailedWindowsVersion
        Hostname = $csInfo.CsName
        Procesador = ($csInfo.CsProcessors | Select-Object -First 1).Name
        Nucleos = "fisicos $physicalCores logicos $($csInfo.CsNumberOfLogicalProcessors)"
        MemoriaTotalGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        MemoriaEnUsoPorc = [math]::Round((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100, 2)
        Uptime = "$($uptime.Days) dias, $($uptime.Hours) horas, $($uptime.Minutes) minutos"
    }

    # -- Hardware Detallado --
    $tempTxtPath = Join-Path $env:TEMP "dxdiag.txt"
    $gpuInfo = try {
        # Preparamos el registro para que DxDiag no muestre ventanas emergentes
        $dxdiagRegPath = "HKCU:\Software\Microsoft\DxDiag"
        if (-not (Test-Path $dxdiagRegPath)) { New-Item -Path $dxdiagRegPath -Force | Out-Null }
        Set-ItemProperty -Path $dxdiagRegPath -Name "bOnceRun" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        
        # Eliminamos cualquier reporte anterior
        if (Test-Path $tempTxtPath) { Remove-Item $tempTxtPath -Force }

        # Ejecutamos DxDiag para generar el .txt y esperamos a que finalice
        Start-Process "dxdiag.exe" -ArgumentList "/t $tempTxtPath" -Wait -WindowStyle Hidden
        
        if (Test-Path $tempTxtPath) {
            $dxdiagContent = Get-Content $tempTxtPath

            # Extraemos los valores del archivo de texto
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

            # Devolvemos el objeto con la informacion completa. Esta es la salida si todo va bien.
            [PSCustomObject]@{
                Name          = $cardName
                DriverVersion = $driverVersion
                VRAM_GB       = $vram_gb
            }
        } else {
            # Si el archivo no se crea, lanzamos un error para activar el bloque 'catch'.
            throw "El archivo DxDiag.txt no se pudo crear."
        }
    } catch {
        # MeTODO DE RESPALDO: WMI Antiguo
        # ---------------------------------
        # Esto solo se ejecutara si el bloque 'try' (DxDiag) falla por cualquier motivo.
        Write-Warning "El metodo principal con DxDiag.txt fallo. Usando WMI como ultimo recurso (la VRAM puede ser imprecisa). Error: $($_.Exception.Message)"
        
        Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1 | ForEach-Object {
            [PSCustomObject]@{
                Name          = $_.Name
                DriverVersion = $_.DriverVersion
                VRAM_GB       = [math]::Round($_.AdapterRAM / 1GB, 2)
            }
        }
    } finally {
        # LIMPIEZA: Nos aseguramos de borrar el archivo temporal sin importar el resultado.
        if (Test-Path $tempTxtPath) {
            Remove-Item $tempTxtPath -Force
        }
    }

    # -- Asignacion final al objeto de Hardware --
    $hardwareData = @{
        PlacaBase = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object Manufacturer, Product, SerialNumber
        BIOS      = "Ver. $((Get-CimInstance -ClassName Win32_BIOS).SMBIOSBIOSVersion) Tipo de Arranque. ($(if (Test-Path "$env:windir\Boot\EFI") { 'UEFI' } else { 'Legacy' }))"
        GPU       = $gpuInfo 
    }

    # -- Estado de Seguridad --
    $antivirusStatus = try {
        $avProducts = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)
        if ($avProducts.Count -gt 0) {
            $avNames = $avProducts | ForEach-Object { $_.displayName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if ($avNames) { $avNames -join ', ' } else { "Registrado, pero sin nombre" }
        } else { "No Detectado" }
    } catch { "No Detectado (Error al consultar)" }

    $firewallStatus = try {
        $profileStrings = @()
        foreach ($profile in (Get-NetFirewallProfile -ErrorAction Stop)) {
            $status = if ($profile.Enabled) { "Activado" } else { "Desactivado" }
            $profileStrings += "$($profile.Name): $status"
        }
        $profileStrings -join ' | '
    } catch { "No se pudo obtener el estado" }

    $bitlockerStatus = try {
        $vol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
        if ($vol.ProtectionStatus -eq 'On') {
            "Activado (Proteccion: $($vol.ProtectionStatus))"
        } else {
            "Inactivo (Proteccion: $($vol.ProtectionStatus))"
        }
    } catch { "No Disponible" }

    $securityData = @{
        Antivirus = try { @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop) } catch { @() };
        Firewall = try { @(Get-NetFirewallProfile -ErrorAction Stop) } catch { @() };
        
        BitLocker = try {
            $vol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
            if ($vol.ProtectionStatus -eq 'On') {
                "Activado (Proteccion: $($vol.ProtectionStatus))"
            } else {
                "Inactivo (Proteccion: $($vol.ProtectionStatus))"
            }
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
        } | 
        Where-Object { $_.DisplayName } | 
        Sort-Object DisplayName

    # --- NUEVO: Recopilamos el estado de salud de los discos físicos ---
    $physicalDiskData = Get-PhysicalDisk | Select-Object FriendlyName, MediaType, SerialNumber, @{N='EstadoSalud'; E={
    switch ($_.HealthStatus) {
        'Healthy'   { 'Saludable' }
        'Warning'   { 'Advertencia' }
        'Unhealthy' { 'No saludable' }
        default     { $_.HealthStatus } # Si hay un estado desconocido, muestra el original en ingles
        }
    }
}

    # -- Objeto final --
    return [PSCustomObject]@{
        System = $systemData; Hardware = $hardwareData; Security = $securityData; Disks = $diskData
        Network = $networkData; OSConfig = $osConfigData; Software = $softwareData
		PhysicalDisks = $physicalDiskData
        ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

# --- FUNCIoN AUXILIAR 2: Constructor del HTML Profesional ---
function Build-FullInventoryHtmlReport {
    param ([Parameter(Mandatory=$true)] $InventoryData)

    # --- INICIO: Paleta de colores y CSS rediseñados ---
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
        h1 { font-size: 2.8em; display: flex; align-items: center; } h1 i { margin-right: 15px; } /* Título mas grande */
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
    </style>
</head>
"@
    # --- FIN: Paleta de colores y CSS rediseñados ---
    
    $body = "<body>"
    $body += "<h1><i class='fas fa-shield-alt'></i>Aegis Phoenix Suite - Reporte de Inventario</h1>"
    $body += "<p class='timestamp'>Generado el: $($InventoryData.ReportDate) para el equipo $($InventoryData.System.Hostname)</p>"

    # Funcion interna para generar barras de progreso
    function Get-ProgressBarHtml($value) {
        $color = if ($value -gt 90) { 'var(--danger-color)' } elseif ($value -gt 75) { 'var(--warning-color)' } else { 'var(--primary-color)' }
        return "<div class='progress-container'><div class='progress-bar' style='width: $($value)%; background-color: $($color);'></div></div>"
    }

    # -- Secciones --
    $body += "<div class='section'><h2><i class='fas fa-desktop'></i>Sistema Operativo y CPU</h2><div class='grid-container'>"
    $body += "<div><span class='info-label'>Sistema:</span> $($InventoryData.System.WindowsVersion)</div>"
    $body += "<div><span class='info-label'>Procesador:</span> $($InventoryData.System.Procesador)</div>"
    $body += "<div><span class='info-label'>Nucleos:</span> $($InventoryData.System.Nucleos)</div>"
    $body += "<div><span class='info-label'>Tiempo de Actividad:</span> $($InventoryData.System.Uptime)</div>"
    $body += "<div><span class='info-label'>Memoria RAM:</span> $($InventoryData.System.MemoriaTotalGB) GB $($InventoryData.System.MemoriaEnUsoPorc)% Usado" + (Get-ProgressBarHtml($InventoryData.System.MemoriaEnUsoPorc)) + "</div>"
    $body += "</div></div>"

    $body += "<div class='section'><h2><i class='fas fa-microchip'></i>Hardware Detallado</h2><div class='grid-container'>"
    $body += "<div><span class='info-label'>Placa Base:</span> $($InventoryData.Hardware.PlacaBase.Manufacturer) $($InventoryData.Hardware.PlacaBase.Product)</div>"
    $body += "<div><span class='info-label'>BIOS:</span> $($InventoryData.Hardware.BIOS)</div>"
        foreach ($gpu in $InventoryData.Hardware.GPU) {
        $body += "<div><span class='info-label'>GPU:</span> $($gpu.Name) ($($gpu.VRAM_GB) GB VRAM)</div>"
        $body += "<div><span class='info-label'>Driver de Video:</span> $($gpu.DriverVersion)</div>"
    }
    $body += "</div></div>"

    $body += "<div class='section'><h2><i class='fas fa-lock'></i>Estado de Seguridad</h2><div class='grid-container'>"
    $avNames = if ($InventoryData.Security.Antivirus) { ($InventoryData.Security.Antivirus.displayName -join ', ') } else { 'No Detectado' }
    $body += "<div><span class='info-label'>Antivirus Registrado:</span> $avNames</div>"
    $firewallStatus = ($InventoryData.Security.Firewall | ForEach-Object { "$($_.Name): $(if($_.Enabled){'Activado'}else{'Desactivado'})" }) -join ' | '
    $body += "<div><span class='info-label'>Firewall:</span> $firewallStatus</div>"
    $body += "<div><span class='info-label'>Cifrado de Disco (BitLocker):</span> $($InventoryData.Security.BitLocker)</div>"
    $body += "</div></div>"

    $body += "<div class='section'><h2><i class='fas fa-hdd'></i>Discos</h2><table><thead><tr><th>Dispositivo</th><th>Tamano (GB)</th><th>Libre (GB)</th><th>Uso</th></tr></thead><tbody>"
    foreach ($disk in $InventoryData.Disks) {
        $body += "<tr><td>$($disk.Dispositivo) ($($disk.Nombre))</td><td>$($disk.TamanoTotalGB)</td><td>$($disk.EspacioLibreGB)</td><td>$($disk.UsoPorc)%" + (Get-ProgressBarHtml($disk.UsoPorc)) + "</td></tr>"
    }
    $body += "</tbody></table></div>"
	
	# --- NUEVO: Añadimos la tabla de salud de discos físicos ---
    $body += "<div class='section'><h2><i class='fas fa-heartbeat'></i>Diagnostico de Salud de Discos (S.M.A.R.T.)</h2><table><thead><tr><th>Nombre</th><th>Tipo</th><th>No. de Serie</th><th>Estado de Salud</th></tr></thead><tbody>"
    foreach ($pdisk in $InventoryData.PhysicalDisks) {
        $body += "<tr><td>$($pdisk.FriendlyName)</td><td>$($pdisk.MediaType)</td><td>$($pdisk.SerialNumber)</td><td>$($pdisk.EstadoSalud)</td></tr>"
    }
    $body += "</tbody></table></div>"

    $body += "<div class='section'><h2><i class='fas fa-network-wired'></i>Red</h2><table><thead><tr><th>Nombre</th><th>Descripcion</th><th>Estado</th><th>MAC</th></tr></thead><tbody>"
    foreach ($adapter in $InventoryData.Network) {
        $body += "<tr><td>$($adapter.Name)</td><td>$($adapter.InterfaceDescription)</td><td>$($adapter.Status)</td><td>$($adapter.MacAddress)</td></tr>"
    }
    $body += "</tbody></table></div>"
    
    $body += "<div class='section'><h2><i class='fas fa-chart-line'></i>Procesos de Mayor Consumo</h2><div class='grid-container'>"
    $body += "<div><h3>Top 5 por CPU</h3><table><thead><tr><th>Nombre</th><th>CPU</th></tr></thead><tbody>"
    foreach($p in $InventoryData.OSConfig.TopCPU){ $body += "<tr><td>$($p.Name)</td><td>$($p.CPU)</td></tr>" }
    $body += "</tbody></table></div>"
    $body += "<div><h3>Top 5 por Memoria</h3><table><thead><tr><th>Nombre</th><th>Memoria (MB)</th></tr></thead><tbody>"
    foreach($p in $InventoryData.OSConfig.TopMemory){ $body += "<tr><td>$($p.Name)</td><td>$($p.Memoria_MB)</td></tr>" }
    $body += "</tbody></table></div></div></div>"
    
    $body += "<div class='section'><h2><i class='fas fa-history'></i>Ultimas 15 Actualizaciones Instaladas</h2><table><thead><tr><th>ID</th><th>Descripcion</th><th>Fecha</th></tr></thead><tbody>"
    foreach ($hotfix in $InventoryData.OSConfig.Hotfixes) {
        $body += "<tr><td>$($hotfix.HotFixID)</td><td>$($hotfix.Description)</td><td>$($hotfix.InstalledOn.ToString('yyyy-MM-dd'))</td></tr>"
    }
    $body += "</tbody></table></div>"

    # --- INICIO: Añadida columna de Fecha de Instalacion al HTML ---
    $body += "<div class='section'><h2><i class='fas fa-box-open'></i>Software Instalado ($($InventoryData.Software.Count))</h2>"
    $body += "<div class='search-box'><input type='text' id='softwareSearch' onkeyup='searchSoftware()' placeholder='Buscar software por nombre...'></div>"
    $body += "<table id='softwareTable'><thead><tr><th>Nombre</th><th>Version</th><th>Editor</th><th>Fecha de Instalacion</th></tr></thead><tbody>"
    foreach ($app in $InventoryData.Software) {
        $body += "<tr><td>$($app.DisplayName)</td><td>$($app.DisplayVersion)</td><td>$($app.Publisher)</td><td>$($app.InstallDate)</td></tr>"
    }
    $body += "</tbody></table></div>"
    # --- FIN: Añadida columna de Fecha de Instalacion al HTML ---
    
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
            $reportContent += "WindowsVersion   : $($inventoryData.System.WindowsVersion)"
            $reportContent += "Hostname         : $($inventoryData.System.Hostname)"
            $reportContent += "Procesador       : $($inventoryData.System.Procesador)"
            $reportContent += "Nucleos          : $($inventoryData.System.Nucleos)"
            $reportContent += "MemoriaTotalGB   : $($inventoryData.System.MemoriaTotalGB)"
            $reportContent += "MemoriaEnUsoPorc : $($inventoryData.System.MemoriaEnUsoPorc)"
            $reportContent += "Uptime           : $($inventoryData.System.Uptime)"
            
            # --- SECCIoN: HARDWARE (Formato manual) ---
            $reportContent += ""
            $reportContent += "=== HARDWARE DETALLADO ==="
            $reportContent += "Placa Base       : $($inventoryData.Hardware.PlacaBase.Manufacturer) $($inventoryData.Hardware.PlacaBase.Product)"
            $reportContent += "BIOS             : $($inventoryData.Hardware.BIOS)"
                foreach ($gpu in $inventoryData.Hardware.GPU) {
                $reportContent += "GPU              : $($gpu.Name) ($($gpu.VRAM_GB) GB VRAM)"
                $reportContent += "Driver de Video  : $($gpu.DriverVersion)"
            }

            # --- SECCIoN: SEGURIDAD
            $reportContent += ""
            $reportContent += "=== ESTADO DE SEGURIDAD ==="
            $reportContent += "Antivirus : $(if ($inventoryData.Security.Antivirus) { ($inventoryData.Security.Antivirus.displayName -join ', ') } else { 'No Detectado' })"
            $reportContent += "Firewall  : $(($inventoryData.Security.Firewall | ForEach-Object { "$($_.Name): $(if($_.Enabled){'Activado'}else{'Desactivado'})" }) -join ' | ')"
            $reportContent += "BitLocker : $($inventoryData.Security.BitLocker)"

            # --- SECCIoN: DISCOS
            $reportContent += ""
            $reportContent += "=== DISCOS ==="
            $reportContent += ($inventoryData.Disks | Format-Table | Out-String).TrimEnd()
			
			# --- NUEVO: Añadimos la seccion de salud de discos físicos ---
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
                    Write-Host "Nota: Winget debe instalarse manualmente desde Microsoft Store." -ForegroundColor Yellow
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

        # Buscar actualizaciones en los motores activos
        foreach ($engine in $activeEngines) {
            Write-Host "Buscando en $engine..." -ForegroundColor Gray
            $updates = @()
            
            switch ($engine) {
                'Winget' {
                    $output = winget upgrade --source winget --include-unknown --accept-source-agreements 2>&1
                    $lines = $output -split "`r?`n"
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
                                $updates += [PSCustomObject]@{
                                    Name = $columns[0].Trim()
                                    Id = $columns[1].Trim()
                                    Version = $columns[2].Trim()
                                    Available = if ($columns.Count -ge 4) { $columns[3].Trim() } else { "Unknown" }
                                    Engine = 'Winget'
                                }
                            }
                        }
                    }
                }
                'Chocolatey' {
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
                }
            }
            
            $allUpdates += $updates
        }

        if ($allUpdates.Count -eq 0) {
            Write-Host "No se encontraron actualizaciones pendientes." -ForegroundColor Green
            Read-Host "`nPresiona Enter para continuar"
            return
        }

        # Seleccion interactiva
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
        switch ($script:SoftwareEngine) {
             'Winget' {
                # Ejecutar winget y capturar salida
                $rawOutput = winget search $searchTerm --source winget --accept-source-agreements 2>&1
                
                # Procesar la salida linea por linea
                $lines = $rawOutput -split "`r?`n"
                $inTable = $false
                
                foreach ($line in $lines) {
                    $trimmedLine = $line.Trim()
                    
                    # Detectar el inicio de la tabla (linea con muchos guiones)
                    if ($trimmedLine -match "^[-\\s]{20,}") {
                        $inTable = $true
                        continue
                    }
                    
                    # Si estamos en la tabla y la linea tiene contenido
                    if ($inTable -and $trimmedLine -ne "" -and $trimmedLine -notmatch "^-") {
                        # Dividir por multiples espacios
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
            }
            'Chocolatey' {
                $rawOutput = choco search $searchTerm -r 2>&1
                $results = $rawOutput | ForEach-Object {
                    if ($_ -match "^(.*?)\|(.*)$") {
                        [PSCustomObject]@{
                            Name = $matches[1].Trim()
                            Id = $matches[1].Trim()
                            Version = $matches[2].Trim()
                        }
                    }
                }
            }
        }

        if ($results.Count -eq 0) {
            Write-Host "No se encontraron resultados." -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar"
            return
        }

        # Seleccion interactiva
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

    while ($true) {
        Clear-Host
        if ($null -eq $Category) {
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
            }
        }
        else {
            Write-Host "Gestor de Ajustes | Categoria: $Category" -ForegroundColor Cyan
            Write-Host "Marca los ajustes que deseas alternar (activar/desactivar)."
            Write-Host "------------------------------------------------"
            
            $consoleWidth = $Host.UI.RawUI.WindowSize.Width
            $descriptionIndent = 13

            for ($i = 0; $i -lt $tweaksInCategory.Count; $i++) {
                $tweak = $tweaksInCategory[$i]
                $status = if ($tweak.Selected) { "[X]" } else { "[ ]" }
                $state = Get-TweakState -Tweak $tweak
                $stateColor = if ($state -eq 'Enabled') { 'Green' } elseif ($state -eq 'Disabled') { 'Red' } else { 'Gray' }
                
                Write-Host ("   [{0,2}] {1} " -f ($i + 1), $status) -NoNewline
                Write-Host ("{0,-15}" -f "[$state]") -ForegroundColor $stateColor -NoNewline
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
                        $currentState = Get-TweakState -Tweak $tweak
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
                        continue # Vuelve al inicio del bucle sin aplicar cambios
                    }

                    foreach ($tweakToToggle in $selectedTweaks) {
                        $currentState = Get-TweakState -Tweak $tweakToToggle
                        if ($currentState -eq 'NotApplicable') {
                            Write-Warning "El ajuste '$($tweakToToggle.Name)' no es aplicable y se omitira."
                            continue
                        }
                        $action = if ($currentState -eq 'Enabled') { 'Disable' } else { 'Enable' }
                        Set-TweakState -Tweak $tweakToToggle -Action $action

                        # Si el ajuste requiere reiniciar explorer, activamos la bandera
                        if ($tweakToToggle.RestartNeeded -eq 'Explorer') {
                            $explorerRestartNeeded = $true
                        }
                    }
                    Write-Host "`n[OK] Se han aplicado los cambios." -ForegroundColor Green
                }
                $tweaksInCategory.ForEach({$_.Selected = $false})

                # Comprobar la bandera y preguntar al usuario
                if ($explorerRestartNeeded) {
                    $promptChoice = Read-Host "`n[?] Varios cambios requieren reiniciar el Explorador de Windows para ser visibles. ¿Deseas hacerlo ahora? (S/N)"
                    if ($promptChoice.ToUpper() -eq 'S') {
                        Invoke-ExplorerRestart # Llamamos a nuestra nueva funcion
                    } else {
                        Write-Host "[INFO] Recuerda reiniciar la sesion o el equipo para ver todos los cambios." -ForegroundColor Yellow
                    }
                    # Restablecer la bandera para la siguiente ronda de cambios
                    $explorerRestartNeeded = $false
                }

                Read-Host "`nPresiona Enter para continuar..."
            }
        }
    }
}

# --- FUNCIONES DE MENU PRINCIPAL ---

function Show-OptimizationMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Optimizacion y Limpieza."
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
	Write-Host "   [4] Eliminar Apps Preinstaladas";
	Write-Host "       (Detecta y te permite elegir que bloatware quitar)" -ForegroundColor Gray;
	Write-Host "";
	Write-Host "   [5] Gestionar Programas de Inicio";
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
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Mantenimiento y Reparacion."
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
    Write-Host "   [5] Purgar Memoria RAM en Cache (Standby List)" -ForegroundColor Yellow
    Write-Host "       (Libera la memoria 'En espera'. Para usos muy especificos)" -ForegroundColor Gray
	Write-Host ""
    Write-Host "   [6] Diagnostico y Reparacion de Red"
    Write-Host "       (Soluciona problemas de conectividad a internet)" -ForegroundColor Gray
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
		'5' { Clear-RAMCache }
		'6' { Show-NetworkDiagnosticsMenu }
		'V' { continue };
		default {
			Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red;
			Read-Host }
			} 
	} while ($maintChoice.ToUpper() -ne 'V')
}

function Show-AdvancedMenu {
	Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Herramientas Avanzadas."
    $advChoice = ''; do { 
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
        Write-Host "       (Limpia registros de eventos y gestiona tareas programadas)" -ForegroundColor Gray
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
        
        # MODIFICADO: El switch ahora apunta a la nueva funcion Show-TweakManagerMenu.
        switch ($advChoice.ToUpper()) {
            '1' { Show-TweakManagerMenu }
            '2' { Show-InventoryMenu }
            '3' { Show-DriverMenu }
            '4' { Show-SoftwareMenu }
            '5' { Show-AdminMenu }
			'6' { Show-EventLogAnalyzerMenu }
			'7' { Show-UserDataBackupMenu }
            'V' { continue }
            default { Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red; Read-Host }
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
	Write-Log -LogLevel INFO -Message "MAIN_MENU: Usuario seleccionó la opción '$($mainChoice.ToUpper())'."

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
            Write-Warning "El archivo de registro aún no ha sido creado. Realiza alguna acción primero."
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
