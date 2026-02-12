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
    4.9.1
#>

$script:Version = "4.9.1"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
            # Fallback: Comparacion de texto simple si el formato no es estandar
            if ($remoteVersionStr -ne $script:Version) { 
                $updateAvailable = $true 
            }
        }
    }
    catch {
        # Silencioso si no hay conexion, no es critico
        return
    }

    # --- Si hay una actualizacion, preguntamos al usuario ---
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
            # Guardar el script del actualizador con codificacion UTF8 limpia
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
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
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

    # CORRECCION AQUI: La propiedad correcta es .StartType, no .StartupType
    $originalStartupType = $vssService.StartType
    $originalStatus = $vssService.Status
    
    # Validacion de seguridad por si acaso
    if ($null -eq $originalStartupType) { $originalStartupType = "Manual" }

    $serviceNeedsChange = $false

    try {
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
        Read-Host "`nOcurrio un error. Presiona Enter para continuar..."
    } finally {
        # 4. Restauramos el estado original del servicio
        if ($serviceNeedsChange) {
            Write-Host "[INFO] Restaurando el estado original del servicio VSS..." -ForegroundColor Gray
            
            try {
                # Solo intentamos restaurar si tenemos un valor valido
                if ($null -ne $originalStartupType) {
                    Set-Service -Name VSS -StartupType $originalStartupType -ErrorAction SilentlyContinue
                }
                
                if ($originalStatus -eq 'Stopped' -and (Get-Service VSS).Status -eq 'Running') {
                    Stop-Service -Name VSS -ErrorAction SilentlyContinue
                }
                Write-Host "[OK] Estado del servicio VSS restaurado." -ForegroundColor Green
            } catch {
                Write-Warning "No se pudo restaurar el estado exacto del servicio VSS (StartType: $originalStartupType)."
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
            # Obtener todos los procesos del Explorador (puede haber mas de uno)
            $explorerProcesses = Get-Process -Name explorer -ErrorAction Stop
            
            # Detener los procesos
            $explorerProcesses | Stop-Process -Force
            Write-Host "   - Proceso(s) detenido(s)." -ForegroundColor Gray
            
            # CORRECCIoN: Esperar a que terminen uno por uno de forma segura
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
    # Verificar que el catalogo este cargado
    if ($null -eq $script:ServiceCatalog) {
        try { . "$PSScriptRoot\Catalogos\Servicios.ps1" } catch { 
            [System.Windows.Forms.MessageBox]::Show("No se pudo cargar el catalogo de servicios.", "Error", 0, 16); return 
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO (ESTILO OSCURO) ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Servicios"
    $form.Size = New-Object System.Drawing.Size(950, 700) # Ligeramente mas ancho para acomodar la busqueda
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR (FILTROS Y BuSQUEDA) ---
    $lblCat = New-Object System.Windows.Forms.Label
    $lblCat.Text = "Categoria:"
    $lblCat.Location = New-Object System.Drawing.Point(20, 23)
    $lblCat.AutoSize = $true
    $lblCat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblCat)

    $cmbCategory = New-Object System.Windows.Forms.ComboBox
    $cmbCategory.Location = New-Object System.Drawing.Point(100, 20)
    $cmbCategory.Width = 250
    $cmbCategory.DropDownStyle = "DropDownList"
    $cmbCategory.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $cmbCategory.ForeColor = [System.Drawing.Color]::White
    $cmbCategory.FlatStyle = "Flat"
    
    # Poblar categorias dinamicamente + "Todas"
    $cmbCategory.Items.Add("--- TODAS LAS CATEGORIAS ---") | Out-Null
    $categories = $script:ServiceCatalog | Select-Object -ExpandProperty Category -Unique | Sort-Object
    foreach ($cat in $categories) { $cmbCategory.Items.Add($cat) | Out-Null }
    $cmbCategory.SelectedIndex = 0
    $form.Controls.Add($cmbCategory)

    # -- NUEVO: CAJA DE BuSQUEDA --
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(370, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(430, 20)
    $txtSearch.Width = 250
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(700, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(100, 26)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW (TABLA CENTRAL) ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(890, 400)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion de Doble Bufer (Evita parpadeo)
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Servicio"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 200
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado Actual"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 120
    $grid.Columns.Add($colStatus) | Out-Null
    
    $colStartup = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStartup.HeaderText = "Inicio"
    $colStartup.Name = "Startup"
    $colStartup.ReadOnly = $true
    $colStartup.Width = 100
    $grid.Columns.Add($colStartup) | Out-Null

    $colDefault = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDefault.HeaderText = "Recomendado"
    $colDefault.Name = "Default"
    $colDefault.ReadOnly = $true
    $colDefault.Width = 120
    $grid.Columns.Add($colDefault) | Out-Null
    
    # Columna oculta para guardar el objeto completo
    $colCat = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCat.Name = "Category"
    $colCat.Visible = $false
    $grid.Columns.Add($colCat) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DESCRIPCION ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Descripcion del Servicio"
    $grpDesc.ForeColor = [System.Drawing.Color]::Silver
    $grpDesc.Location = New-Object System.Drawing.Point(20, 470)
    $grpDesc.Size = New-Object System.Drawing.Size(890, 80)
    $form.Controls.Add($grpDesc)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "Selecciona un servicio para ver su descripcion..."
    $lblDesc.Location = New-Object System.Drawing.Point(10, 20)
    $lblDesc.Size = New-Object System.Drawing.Size(870, 50)
    $lblDesc.ForeColor = [System.Drawing.Color]::White
    $grpDesc.Controls.Add($lblDesc)

    # --- 5. BOTONES DE ACCION ---
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR SELECCIONADOS"
    $btnDisable.Location = New-Object System.Drawing.Point(650, 560)
    $btnDisable.Size = New-Object System.Drawing.Size(260, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::Crimson
    $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "Restaurar / Habilitar (Default)"
    $btnRestore.Location = New-Object System.Drawing.Point(380, 560)
    $btnRestore.Size = New-Object System.Drawing.Size(260, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRestore.ForeColor = [System.Drawing.Color]::LightGreen
    $btnRestore.FlatStyle = "Flat"
    $form.Controls.Add($btnRestore)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 565)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # --- VARIABLES GLOBALES PARA LA GUI ---
    $script:ServiceCache = @{} # Para guardar descripcion y valores por defecto

    # --- FUNCION DE CARGA ---
    $LoadGrid = {
        # Optimizacion: SuspendLayout evita parpadeo y mejora rendimiento
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $script:ServiceCache.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        # 1. Obtener estado real de servicios (WMI)
        $liveServices = @{}
        try {
            Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | ForEach-Object { $liveServices[$_.Name] = $_ }
        } catch { Write-Warning "Error leyendo servicios WMI" }

        # 2. Filtrar por categoria
        $filterCat = $cmbCategory.SelectedItem
        $itemsToShow = if ($filterCat -eq "--- TODAS LAS CATEGORIAS ---") { 
            $script:ServiceCatalog 
        } else { 
            $script:ServiceCatalog | Where-Object { $_.Category -eq $filterCat } 
        }

        # 3. Filtrar por Texto de Busqueda (Nuevo)
        $searchText = $txtSearch.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            $itemsToShow = $itemsToShow | Where-Object { $_.Name -match $searchText }
        }

        # 4. Poblar Grid
        foreach ($item in $itemsToShow) {
            $svc = $liveServices[$item.Name]
            
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["Name"].Value = $item.Name
            $row.Cells["Category"].Value = $item.Category
            $row.Cells["Default"].Value = $item.DefaultStartupType

            # Guardar en cache para la descripcion y acciones
            $script:ServiceCache[$item.Name] = $item

            # Estado Visual
            if ($svc) {
                if ($svc.StartMode -eq 'Disabled') {
                    $row.Cells["Startup"].Value = "Deshabilitado"
                    $row.Cells["Status"].Value = "Desactivado"
                    
                    # Estilo: Solo la palabra "Desactivado" en Rojo, el resto Blanco
                    $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
                    $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White 
                } else {
                    $row.Cells["Startup"].Value = $svc.StartMode
                    if ($svc.State -eq 'Running') {
                        $row.Cells["Status"].Value = "Ejecutando"
                        $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                        $row.Cells["Name"].Style.Font = New-Object System.Drawing.Font($grid.Font, [System.Drawing.FontStyle]::Bold)
                    } else {
                        $row.Cells["Status"].Value = "Detenido"
                        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
                    }
                }
            } else {
                $row.Cells["Status"].Value = "No Instalado"
                $row.Cells["Startup"].Value = "-"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::DarkGray
            }
        }
        
        # Restaurar layout
        $grid.ResumeLayout()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $grid.ClearSelection()
    }

    # --- EVENTOS ---
    
    # Carga inicial y cambio de filtro
    $form.Add_Shown({ & $LoadGrid })
    $btnRefresh.Add_Click({ & $LoadGrid })
    $cmbCategory.Add_SelectedIndexChanged({ & $LoadGrid })
    
    # Evento de busqueda en tiempo real
    $txtSearch.Add_KeyUp({ & $LoadGrid })

    # Mostrar descripcion al seleccionar fila
    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            # Obtenemos el valor de la celda de forma segura
            $val = $grid.SelectedRows[0].Cells["Name"].Value
            $name = if ($val) { $val.ToString() } else { "" }

            # Verificamos que tenga texto y exista en cache
            if (-not [string]::IsNullOrEmpty($name) -and $script:ServiceCache.ContainsKey($name)) {
                $lblDesc.Text = $script:ServiceCache[$name].Description
            } else {
                $lblDesc.Text = "" 
            }
        }
    })

    # Boton Seleccionar Todo
    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Funcion helper para aplicar cambios
    $ApplyAction = {
        param($Mode) # 'Disable' o 'Restore'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $row.Cells["Name"].Value
            }
        }

        if ($targets.Count -eq 0) { 
            [System.Windows.Forms.MessageBox]::Show("No has seleccionado ningun servicio.", "Aviso", 0, 48)
            return 
        }

        $confirmMsg = if ($Mode -eq 'Disable') { 
            "¿Deshabilitar $($targets.Count) servicios? Esto detendra su ejecucion." 
        } else { 
            "¿Restaurar $($targets.Count) servicios a su estado recomendado?" 
        }

        if ([System.Windows.Forms.MessageBox]::Show($confirmMsg, "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        foreach ($svcName in $targets) {
            try {
                $config = $script:ServiceCache[$svcName]
                
                if ($Mode -eq 'Disable') {
                    Write-Log -LogLevel ACTION -Message "SERVICIOS GUI: Deshabilitando $svcName"
                    Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
                    $s = Get-Service -Name $svcName
                    if ($s.Status -eq 'Running') { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
                } 
                else {
                    # Restore
                    $targetType = $config.DefaultStartupType
                    Write-Log -LogLevel ACTION -Message "SERVICIOS GUI: Restaurando $svcName a $targetType"
                    Set-Service -Name $svcName -StartupType $targetType -ErrorAction Stop
                    if ($targetType -ne 'Disabled' -and $targetType -ne 'Manual') {
                        Start-Service -Name $svcName -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                Write-Log -LogLevel ERROR -Message "Fallo con servicio $svcName : $_"
            }
        }
        
        # Recargar para ver cambios
        & $LoadGrid
        [System.Windows.Forms.MessageBox]::Show("Operacion completada.", "Exito", 0, 64)
    }

    # --- EVENTO: BARRA ESPACIADORA PARA MARCAR/DESMARCAR ---
    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            # Evita que la barra espaciadora haga scroll hacia abajo
            $e.SuppressKeyPress = $true 
            
            # Recorre todas las filas seleccionadas (permite seleccion multiple con Shift/Ctrl)
            foreach ($row in $sender.SelectedRows) {
                # Invierte el valor actual (True -> False / False -> True)
                # Nota: Verificamos si la celda es de solo lectura (como en Bloatware protegido)
                if (-not $row.Cells["Check"].ReadOnly) {
                    $row.Cells["Check"].Value = -not ($row.Cells["Check"].Value)
                }
            }
        }
    })

    $btnDisable.Add_Click({ & $ApplyAction -Mode 'Disable' })
    $btnRestore.Add_Click({ & $ApplyAction -Mode 'Restore' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# =========================================================================================
# MODULO DE GESTION DE SERVICIOS DE TERCEROS
# =========================================================================================
function Manage-ThirdPartyServices {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- RUTAS Y VARIABLES GLOBALES DEL MODULO ---
    $parentDir = Split-Path -Parent $PSScriptRoot
    $backupDir = Join-Path -Path $parentDir -ChildPath "Backup"
    if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
    $backupFile = Join-Path -Path $backupDir -ChildPath "ThirdPartyServicesBackup.json"
    
    $script:BackupCache = @{}      # Almacena el estado original desde el JSON
    $script:LiveServiceCache = @{} # Diccionario para acceso rapido por nombre
    $script:CachedServiceList = @() # Lista para filtrado rapido sin re-consultar WMI

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Servicios de Terceros (Apps)"
    $form.Size = New-Object System.Drawing.Size(980, 700) # Un poco mas ancho para la busqueda
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR ---
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "Gestion Inteligente de Servicios"
    $lblInfo.Location = New-Object System.Drawing.Point(20, 15)
    $lblInfo.AutoSize = $true
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblInfo)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "Detecta servicios no-Windows y permite optimizarlos."
    $lblSub.Location = New-Object System.Drawing.Point(22, 40)
    $lblSub.AutoSize = $true
    $lblSub.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($lblSub)

    # -- BUSCADOR (NUEVO) --
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(400, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(460, 20)
    $txtSearch.Width = 220
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar Datos"
    $btnRefresh.Location = New-Object System.Drawing.Point(700, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(150, 28)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 70)
    $grid.Size = New-Object System.Drawing.Size(920, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion DoubleBuffered (Evita parpadeo al escribir)
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Nombre del Servicio"
    $colName.Name = "DisplayName"
    $colName.ReadOnly = $true
    $colName.Width = 300
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 100
    $grid.Columns.Add($colStatus) | Out-Null

    $colMode = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colMode.HeaderText = "Inicio"
    $colMode.Name = "StartMode"
    $colMode.ReadOnly = $true
    $colMode.Width = 100
    $grid.Columns.Add($colMode) | Out-Null

    $colBackup = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colBackup.HeaderText = "Backup"
    $colBackup.Name = "BackupState"
    $colBackup.ReadOnly = $true
    $colBackup.Width = 120
    $grid.Columns.Add($colBackup) | Out-Null
    
    # Columna oculta para el nombre real del servicio
    $colRealName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colRealName.Name = "ServiceName"
    $colRealName.Visible = $false
    $grid.Columns.Add($colRealName) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DESCRIPCION ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Detalles"
    $grpDesc.ForeColor = [System.Drawing.Color]::Silver
    $grpDesc.Location = New-Object System.Drawing.Point(20, 500)
    $grpDesc.Size = New-Object System.Drawing.Size(920, 60)
    $form.Controls.Add($grpDesc)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "Selecciona un servicio..."
    $lblDesc.Location = New-Object System.Drawing.Point(10, 20)
    $lblDesc.Size = New-Object System.Drawing.Size(900, 30)
    $lblDesc.ForeColor = [System.Drawing.Color]::White
    $grpDesc.Controls.Add($lblDesc)

    # --- 5. BOTONES DE ACCION ---
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR (Optimizar)"
    $btnDisable.Location = New-Object System.Drawing.Point(670, 580)
    $btnDisable.Size = New-Object System.Drawing.Size(270, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::Crimson
    $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "RESTAURAR A ESTADO ORIGINAL"
    $btnRestore.Location = New-Object System.Drawing.Point(380, 580)
    $btnRestore.Size = New-Object System.Drawing.Size(270, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::SeaGreen
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestore)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 585)
    $btnSelectAll.Size = New-Object System.Drawing.Size(100, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # --- LOGICA 1: RENDERIZADO (Filtrado Rapido) ---
    $RenderGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        
        $searchTerm = $txtSearch.Text.Trim()
        
        # Filtramos la lista en memoria (Rapido)
        $itemsToShow = if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            $script:CachedServiceList
        } else {
            $script:CachedServiceList | Where-Object { $_.DisplayName -match $searchTerm -or $_.Name -match $searchTerm }
        }

        foreach ($svc in $itemsToShow) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["DisplayName"].Value = $svc.DisplayName
            $row.Cells["ServiceName"].Value = $svc.Name
            
            # Estado Visual (Logica de Colores)
            if ($svc.StartMode -eq 'Disabled') {
                $row.Cells["StartMode"].Value = "Deshabilitado"
                $row.Cells["Status"].Value = "Inactivo"
                
                # Rojo solo para el texto de estado
                $row.Cells["StartMode"].Style.ForeColor = [System.Drawing.Color]::Salmon
            } else {
                $row.Cells["StartMode"].Value = $svc.StartMode
                # Asegurar blanco si no es disabled
                $row.Cells["StartMode"].Style.ForeColor = [System.Drawing.Color]::White

                if ($svc.State -eq 'Running') {
                    $row.Cells["Status"].Value = "Ejecutando"
                    $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                } else {
                    $row.Cells["Status"].Value = "Detenido"
                    $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::White
                }
            }

            # Estado Backup
            $bkp = $script:BackupCache[$svc.Name]
            if ($bkp) {
                $row.Cells["BackupState"].Value = $bkp.StartupType
                if ($bkp.StartupType -ne 'Disabled' -and $svc.StartMode -eq 'Disabled') {
                    $row.Cells["BackupState"].Style.ForeColor = [System.Drawing.Color]::Cyan
                }
            }
        }
        $grid.ResumeLayout()
        $grid.ClearSelection()
    }

    # --- LOGICA 2: CARGA DE DATOS (Lento - Solo al inicio/refrescar) ---
    $RefreshData = {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $script:LiveServiceCache.Clear()
        $script:CachedServiceList = @() # Limpiar lista
        
        # 1. Cargar Backup existente
        if (Test-Path $backupFile) {
            try {
                $json = Get-Content -Path $backupFile -Raw | ConvertFrom-Json
                foreach ($prop in $json.PSObject.Properties) {
                    $script:BackupCache[$prop.Name] = $prop.Value
                }
            } catch { }
        }

        # 2. Consultar WMI
        $services = Get-CimInstance -ClassName Win32_Service | Where-Object { 
            $_.PathName -and $_.PathName -notmatch '\\Windows\\' -and $_.PathName -notlike '*svchost.exe*' 
        } | Sort-Object DisplayName

        $backupUpdated = $false

        foreach ($svc in $services) {
            $script:LiveServiceCache[$svc.Name] = $svc
            $script:CachedServiceList += $svc # Guardar en lista simple
            
            # Actualizar Backup si es nuevo
            if (-not $script:BackupCache.ContainsKey($svc.Name)) {
                $script:BackupCache[$svc.Name] = @{
                    StartupType = $svc.StartMode
                    DisplayName = $svc.DisplayName
                    Description = $svc.Description
                }
                $backupUpdated = $true
            }
        }

        if ($backupUpdated) {
            $script:BackupCache | ConvertTo-Json -Depth 3 | Set-Content -Path $backupFile -Encoding UTF8
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        
        # Una vez cargados los datos, llamamos al renderizado
        & $RenderGrid
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $RefreshData })
    $btnRefresh.Add_Click({ & $RefreshData })
    
    # Evento de busqueda en tiempo real
    $txtSearch.Add_KeyUp({ & $RenderGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $val = $grid.SelectedRows[0].Cells["ServiceName"].Value
            $name = if ($val) { $val.ToString() } else { "" }
            
            if (-not [string]::IsNullOrEmpty($name) -and $script:LiveServiceCache.ContainsKey($name)) {
                $desc = $script:LiveServiceCache[$name].Description
                if ([string]::IsNullOrWhiteSpace($desc)) { $desc = "Sin descripcion disponible." }
                $lblDesc.Text = $desc
            }
        }
    })

    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Logica de Acciones
    $ApplyAction = {
        param($ActionType)

        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $row.Cells["ServiceName"].Value
            }
        }

        if ($targets.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No has marcado ningun servicio.", "Aviso", 0, 48)
            return
        }

        $msg = if ($ActionType -eq 'Disable') { "Deshabilitar" } else { "Restaurar" }
        if ([System.Windows.Forms.MessageBox]::Show("¿Seguro de $msg $($targets.Count) servicios?", "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        foreach ($svcName in $targets) {
            try {
                if ($ActionType -eq 'Disable') {
                    Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
                    $s = Get-Service -Name $svcName
                    if ($s.Status -eq 'Running') { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
                } 
                else {
                    # Restore logic
                    if ($script:BackupCache.ContainsKey($svcName)) {
                        $originalMode = $script:BackupCache[$svcName].StartupType
                        Set-Service -Name $svcName -StartupType $originalMode -ErrorAction Stop
                        if ($originalMode -ne 'Disabled') {
                            Start-Service -Name $svcName -ErrorAction SilentlyContinue
                        }
                    }
                }
            } catch {}
        }

        # Refrescamos datos completos para ver cambios reales
        & $RefreshData
        [System.Windows.Forms.MessageBox]::Show("Proceso completado.", "Exito", 0, 64)
    }

    $btnDisable.Add_Click({ & $ApplyAction -ActionType 'Disable' })
    $btnRestore.Add_Click({ & $ApplyAction -ActionType 'Restore' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
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
            Write-Log -LogLevel ERROR -Message "LIMPIEZA: Fallo critico al limpiar '$Path'. Motivo: $errorMsg"
        } catch {
            # Fallback por si Write-Log no esta disponible en este ambito
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

# --- FUNCIoN MEJORADA Y BLINDADA: Menu Principal de Limpieza ---
function Show-CleaningMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Limpieza de Sistema"
    $form.Size = New-Object System.Drawing.Size(900, 650)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. VARIABLES Y RUTAS ---
    $script:TempPaths = @(
        "$env:TEMP", "$env:windir\Temp", "$env:windir\Minidump", "$env:LOCALAPPDATA\CrashDumps",
        "$env:windir\Prefetch", "$env:windir\SoftwareDistribution\Download", "$env:windir\LiveKernelReports"
    )
    $script:CachePaths = @(
        "$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:windir\SoftwareDistribution\DeliveryOptimization"
    )

    # --- 3. UI SUPERIOR ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Limpieza Profunda de Disco"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "Analizar Espacio (Scan)"
    $btnScan.Location = New-Object System.Drawing.Point(700, 20)
    $btnScan.Size = New-Object System.Drawing.Size(160, 30)
    $btnScan.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnScan.ForeColor = [System.Drawing.Color]::White
    $btnScan.FlatStyle = "Flat"
    $form.Controls.Add($btnScan)

    # --- 4. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 70)
    $grid.Size = New-Object System.Drawing.Size(840, 350)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colCat = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCat.HeaderText = "Categoria"
    $colCat.Name = "Category"
    $colCat.ReadOnly = $true
    $colCat.Width = 150
    $grid.Columns.Add($colCat) | Out-Null

    $colDesc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDesc.HeaderText = "Descripcion"
    $colDesc.Name = "Desc"
    $colDesc.ReadOnly = $true
    $colDesc.Width = 350
    $grid.Columns.Add($colDesc) | Out-Null

    $colSize = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colSize.HeaderText = "Tamano Detectado"
    $colSize.Name = "Size"
    $colSize.ReadOnly = $true
    $colSize.Width = 120
    $grid.Columns.Add($colSize) | Out-Null

    $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colType.Name = "InternalType"
    $colType.Visible = $false
    $grid.Columns.Add($colType) | Out-Null

    $form.Controls.Add($grid)

    # --- 5. AGREGAR FILAS BASE ---
    $row1 = $grid.Rows.Add($false, "Archivos Temporales", "Temporales de Windows, Logs, Dumps de error, Prefetch.", "Pendiente...", "TEMP")
    $row2 = $grid.Rows.Add($false, "Caches del Sistema", "Cache de DirectX, NVIDIA, Miniaturas (Requiere reinicio de Explorer).", "Pendiente...", "CACHE")
    $row3 = $grid.Rows.Add($false, "Papelera de Reciclaje", "Archivos borrados por el usuario.", "Pendiente...", "BIN")
    $row4 = $grid.Rows.Add($false, "Limpieza Profunda (Admin)", "Windows.old, Updates viejos (DISM/Cleanmgr). Tarda mucho.", "N/A", "DEEP")
    
    # Colorear la fila DEEP para advertencia
    $grid.Rows[$row4].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Orange

    # --- 6. BARRA DE PROGRESO Y ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 440)
    $progressBar.Size = New-Object System.Drawing.Size(840, 20)
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Pulsa 'Analizar Espacio' para comenzar."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 470)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    # --- 7. BOTONES INFERIORES ---
    $btnClean = New-Object System.Windows.Forms.Button
    $btnClean.Text = "EJECUTAR LIMPIEZA SELECCIONADA"
    $btnClean.Location = New-Object System.Drawing.Point(560, 520)
    $btnClean.Size = New-Object System.Drawing.Size(300, 50)
    $btnClean.BackColor = [System.Drawing.Color]::Crimson
    $btnClean.ForeColor = [System.Drawing.Color]::White
    $btnClean.FlatStyle = "Flat"
    $btnClean.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnClean)

    $chkForce = New-Object System.Windows.Forms.CheckBox
    $chkForce.Text = "Cerrar navegadores (Chrome/Edge) automaticamente"
    $chkForce.Location = New-Object System.Drawing.Point(20, 520)
    $chkForce.AutoSize = $true
    $chkForce.Checked = $true
    $form.Controls.Add($chkForce)

    # --- LOGICA: SCAN ---
    $btnScan.Add_Click({
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = "Calculando tamanos... esto puede tardar un momento."
        [System.Windows.Forms.Application]::DoEvents()

        # 1. Temp
        $sizeTemp = 0
        try { $sizeTemp = Get-CleanableSize -Paths $script:TempPaths } catch {}
        $grid.Rows[0].Cells["Size"].Value = "$([math]::Round($sizeTemp / 1MB, 2)) MB"

        # 2. Cache
        $sizeCache = 0
        try { $sizeCache = Get-CleanableSize -Paths $script:CachePaths } catch {}
        $grid.Rows[1].Cells["Size"].Value = "$([math]::Round($sizeCache / 1MB, 2)) MB"

        # 3. Bin
        $sizeBin = 0
        try {
            $shell = New-Object -ComObject Shell.Application
            $binItems = $shell.NameSpace(0x0a).Items()
            foreach ($item in $binItems) { $sizeBin += [long]$item.Size }
        } catch {}
        $grid.Rows[2].Cells["Size"].Value = "$([math]::Round($sizeBin / 1MB, 2)) MB"

        $lblStatus.Text = "Analisis completado."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    })

    # --- LOGICA: CLEAN ---
    $btnClean.Add_Click({
        # Identificar qué se va a limpiar
        $tasks = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $tasks += $row.Cells["InternalType"].Value
            }
        }

        if ($tasks.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Selecciona al menos una categoria.", "Aviso", 0, 48)
            return
        }

        # Advertencia especial para DEEP CLEAN
        if ($tasks -contains "DEEP") {
            $warn = "Has seleccionado 'Limpieza Profunda'.\n\n- Esto borrara Windows.old (no podras volver atras).\n- Se ejecutara DISM y CleanMgr.\n- El proceso puede tardar mucho.\n\n¿Deseas continuar?"
            if ([System.Windows.Forms.MessageBox]::Show($warn, "Advertencia Critica", 4, 48) -ne 'Yes') { return }
        }

        # Confirmacion general
        if ([System.Windows.Forms.MessageBox]::Show("¿Iniciar proceso de limpieza?", "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnClean.Enabled = $false
        $progressBar.Value = 0
        $totalSteps = $tasks.Count + 1 # +1 por el cierre final
        $currentStep = 0
        $totalFreed = 0

        # Cerrar procesos si es necesario
        if ($tasks -contains "TEMP" -or $tasks -contains "CACHE") {
            if ($chkForce.Checked) {
                $lblStatus.Text = "Cerrando navegadores y explorador..."
                $procs = @("OneDrive", "Teams", "chrome", "firefox", "msedge")
                foreach ($p in $procs) { Stop-Process -Name $p -Force -ErrorAction SilentlyContinue }
            }
        }

        # Bucle de tareas
        foreach ($type in $tasks) {
            $currentStep++
            $progressVal = [int](($currentStep / $totalSteps) * 100)
            $progressBar.Value = $progressVal
            
            switch ($type) {
                "TEMP" {
                    $lblStatus.Text = "Limpiando archivos temporales..."
                    [System.Windows.Forms.Application]::DoEvents()
                    foreach ($path in $script:TempPaths) {
                        if (Test-Path $path) { 
                            $bytes = Remove-FilesSafely -Path $path
                            try { $totalFreed += [long]$bytes } catch {}
                        }
                    }
                }
                "CACHE" {
                    $lblStatus.Text = "Limpiando caches y reiniciando Explorer..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # Matar Explorer para limpiar miniaturas
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Sleep -Milliseconds 500
                    
                    foreach ($path in $script:CachePaths) {
                        if (Test-Path $path) { 
                            $bytes = Remove-FilesSafely -Path $path
                            try { $totalFreed += [long]$bytes } catch {}
                        }
                    }
                    
                    # Miniaturas
                    try {
                        $thumb = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                        if (Test-Path "$thumb\thumbcache_*.db") {
                            Remove-Item "$thumb\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                        }
                    } catch {}
                    
                    # Reiniciar Explorer inmediatamente
                    Start-Process "explorer.exe"
                }
                "BIN" {
                    $lblStatus.Text = "Vaciando Papelera de Reciclaje..."
                    [System.Windows.Forms.Application]::DoEvents()
                    try {
                        # Calculamos tamaño antes de borrar para sumar al total
                        $shell = New-Object -ComObject Shell.Application
                        $items = $shell.NameSpace(0x0a).Items()
                        foreach ($i in $items) { try { $totalFreed += [long]$i.Size } catch {} }
                        
                        Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop
                    } catch {}
                }
                "DEEP" {
                    $lblStatus.Text = "Ejecutando Limpieza Profunda (DISM/CleanMgr)..."
                    $lblStatus.ForeColor = [System.Drawing.Color]::Cyan
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    try {
                        # 1. DISM (Oculto, espera simple)
                        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /NoRestart" -Wait -WindowStyle Hidden
                        
                        # 2. Configurar Registro (Sageset dinamico)
                        $handlers = @("Temporary Files", "Recycle Bin", "Update Cleanup", "Windows Upgrade Log Files", "Previous Installations")
                        foreach ($h in $handlers) {
                            $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$h"
                            if (Test-Path $reg) { Set-ItemProperty -Path $reg -Name "StateFlags0099" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue }
                        }
                        
                        # 3. Ejecutar CleanMgr (MODO NATIVO ROBUSTO)
                        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:99" -Wait -WindowStyle Normal
                        
                        # 4. Windows.old (Limpieza manual final con mejora de variables de entorno)
                        $winOldPath = "$env:SystemDrive\Windows.old"
                        if (Test-Path $winOldPath) {
                            $lblStatus.Text = "Eliminando Windows.old (puede tardar)..."
                            [System.Windows.Forms.Application]::DoEvents()
                            & cmd.exe /c "takeown /F `"$winOldPath`" /R /D S && icacls `"$winOldPath`" /grant *S-1-5-32-544:F /T /C /Q && rd /s /q `"$winOldPath`"" 2>$null
                        }
                    } catch {
                        Write-Log -LogLevel ERROR -Message "Error en Deep Clean GUI: $_"
                    }
                }
            }
        }

        # Asegurar que Explorer vuelva si algo fallo
        if ((Get-Process -Name explorer -ErrorAction SilentlyContinue) -eq $null) {
            Start-Process "explorer.exe"
        }

        $progressBar.Value = 100
        $freedMB = [math]::Round($totalFreed / 1MB, 2)
        $lblStatus.Text = "Limpieza finalizada."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $btnClean.Enabled = $true
        
        $msg = "Proceso terminado."
        if ($totalFreed -gt 0) { $msg += "`n`nEspacio recuperado aprox: $freedMB MB" }
        [System.Windows.Forms.MessageBox]::Show($msg, "Exito", 0, 64)
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# ===================================================================
# --- MODULO DE GESTOR DE BLOATWARE ---
# ===================================================================
# --- FUNCION AUXILIAR: RECOLECTOR DE DATOS ---
function Get-RemovableApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft', 'ThirdParty_AllUsers', 'ThirdParty_CurrentUser')]
        [string]$Type
    )

    $apps = @()
    # Filtro base: Ignorar librerias de sistema (.NET, VCLibs) que rompen apps si se borran
    $baseFilter = { $_.IsFramework -eq $false -and $_.IsResourcePackage -eq $false -and $_.Name -notmatch "NET.Native|VCLibs|UI.Xaml" }

    # Cargar patrones desde variables globales o usar defaults seguros si fallan
    $recPattern = if ($script:RecommendedBloatwareList) { ($script:RecommendedBloatwareList | ForEach-Object { [System.Text.RegularExpressions.Regex]::Escape($_) }) -join '|' } else { "Solitaire|Bing|Cortana|Zune|Xbox" }
    $protPattern = if ($script:ProtectedAppList) { ($script:ProtectedAppList | ForEach-Object { [System.Text.RegularExpressions.Regex]::Escape($_) }) -join '|' } else { "Store|Calculator|Photos" }

    try {
        if ($Type -eq 'Microsoft') {
            # Apps firmadas por Microsoft
            $rawApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Publisher -like "*Microsoft*" -and $_.NonRemovable -eq $false -and (& $baseFilter) }
        }
        elseif ($Type -eq 'ThirdParty_AllUsers') {
            # Apps de terceros (Provisionadas en el sistema)
            $rawApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Publisher -notlike "*Microsoft*" -and $_.SignatureKind -eq 'System' -and (& $baseFilter) }
        }
        elseif ($Type -eq 'ThirdParty_CurrentUser') {
            # Apps de usuario actual (Store / Descargas)
            $rawApps = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Publisher -notlike "*Microsoft*" -and (& $baseFilter) }
        }

        foreach ($app in $rawApps) {
            $status = "Normal"
            if ($app.Name -match $recPattern) { $status = "Recommended" }
            if ($app.Name -match $protPattern) { $status = "Protected" }

            # Convertir tamaño si existe (algunas versiones de PS no lo traen)
            $sizeMB = "N/A"
            
            $apps += [PSCustomObject]@{
                Name              = $app.Name
                DisplayName       = if ($app.Name.Length -gt 50) { $app.Name.Substring(0,47) + "..." } else { $app.Name }
                PackageFullName   = $app.PackageFullName
                PackageFamilyName = $app.PackageFamilyName
                Publisher         = $app.Publisher
                Version           = $app.Version
                Status            = $status
                Obj               = $app
            }
        }
    } catch {
        Write-Warning "Error al listar apps: $_"
    }
    
    return $apps | Sort-Object @{Expression={$_.Status -eq 'Recommended'}; Descending=$true}, Name
}

function Show-BloatwareMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Aplicaciones (Bloatware)"
    $form.Size = New-Object System.Drawing.Size(1050, 780)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR (FILTROS) ---
    
    # FILA 1: Origen y Escaneo
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Fuente:"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 23)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    $cmbType = New-Object System.Windows.Forms.ComboBox
    $cmbType.Location = New-Object System.Drawing.Point(90, 20)
    $cmbType.Width = 300
    $cmbType.FlatStyle = "Flat"
    $cmbType.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $cmbType.ForeColor = [System.Drawing.Color]::White
    $cmbType.Items.Add("Bloatware Microsoft (Sistema)") | Out-Null
    $cmbType.Items.Add("Bloatware Terceros (Preinstalado)") | Out-Null
    $cmbType.Items.Add("Mis Apps (Usuario Actual)") | Out-Null
    $cmbType.SelectedIndex = 0
    $form.Controls.Add($cmbType)

    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "ESCANEAR"
    $btnScan.Location = New-Object System.Drawing.Point(410, 18)
    $btnScan.Size = New-Object System.Drawing.Size(120, 28)
    $btnScan.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnScan.ForeColor = [System.Drawing.Color]::White
    $btnScan.FlatStyle = "Flat"
    $btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnScan)

    # FILA 2: Filtros de Visualizacion (NUEVO)
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(20, 63)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(90, 60)
    $txtSearch.Width = 300
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    # Checkbox para mostrar/ocultar protegidos
    $chkShowProtected = New-Object System.Windows.Forms.CheckBox
    $chkShowProtected.Text = "Mostrar Apps Protegidas (Sistema)"
    $chkShowProtected.Location = New-Object System.Drawing.Point(410, 60)
    $chkShowProtected.Width = 250
    $chkShowProtected.AutoSize = $true
    $chkShowProtected.ForeColor = [System.Drawing.Color]::Silver
    $chkShowProtected.Checked = $false # Ocultos por defecto para seguridad
    $form.Controls.Add($chkShowProtected)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 100)
    $grid.Size = New-Object System.Drawing.Size(990, 450)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $true
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion grafica
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Nombre de la Aplicacion"
    $colName.Name = "DisplayName"
    $colName.ReadOnly = $true
    $colName.Width = 350
    $grid.Columns.Add($colName) | Out-Null
    
    $colVer = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colVer.HeaderText = "Version"
    $colVer.Name = "Version"
    $colVer.ReadOnly = $true
    $colVer.Width = 100
    $grid.Columns.Add($colVer) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Clasificacion"
    $colStatus.Width = 150
    $colStatus.Name = "StatusDesc"
    $colStatus.ReadOnly = $true
    $grid.Columns.Add($colStatus) | Out-Null

    # Columna Oculta
    $colObj = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colObj.Name = "RealObject"
    $colObj.Visible = $false
    $grid.Columns.Add($colObj) | Out-Null

    $form.Controls.Add($grid)

    # --- MENU CONTEXTUAL ---
    $ctxMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $itemGoogle = $ctxMenu.Items.Add("Buscar en Google (¿Que es esto?)")
    $itemGoogle.Add_Click({
        if ($grid.SelectedRows.Count -gt 0) {
            $appName = $grid.SelectedRows[0].Cells["DisplayName"].Value
            Start-Process "https://www.google.com/search?q=$appName app windows bloatware"
        }
    })
    $grid.ContextMenuStrip = $ctxMenu

    # --- 4. AREA DE ESTADO ---
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo. Selecciona 'Escanear' para comenzar."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 560)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    $chkDeepClean = New-Object System.Windows.Forms.CheckBox
    $chkDeepClean.Text = "Limpieza Profunda (Eliminar carpetas residuales en AppData)"
    $chkDeepClean.Location = New-Object System.Drawing.Point(20, 590)
    $chkDeepClean.AutoSize = $true
    $chkDeepClean.ForeColor = [System.Drawing.Color]::Silver
    $chkDeepClean.Checked = $true
    $form.Controls.Add($chkDeepClean)

    # --- 5. BOTONES DE ACCION ---
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 630)
    $btnSelectAll.Size = New-Object System.Drawing.Size(60, 40)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $btnSelectRec = New-Object System.Windows.Forms.Button
    $btnSelectRec.Text = "Marcar Recomendados"
    $btnSelectRec.Location = New-Object System.Drawing.Point(90, 630)
    $btnSelectRec.Size = New-Object System.Drawing.Size(160, 40)
    $btnSelectRec.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectRec.ForeColor = [System.Drawing.Color]::Orange
    $btnSelectRec.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectRec)

    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "Exportar Lista"
    $btnExport.Location = New-Object System.Drawing.Point(260, 630)
    $btnExport.Size = New-Object System.Drawing.Size(120, 40)
    $btnExport.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $btnExport.ForeColor = [System.Drawing.Color]::White
    $btnExport.FlatStyle = "Flat"
    $form.Controls.Add($btnExport)

    $btnRestoreStore = New-Object System.Windows.Forms.Button
    $btnRestoreStore.Text = "RESTAURAR TIENDA"
    $btnRestoreStore.Location = New-Object System.Drawing.Point(520, 630)
    $btnRestoreStore.Size = New-Object System.Drawing.Size(180, 40)
    $btnRestoreStore.BackColor = [System.Drawing.Color]::Teal
    $btnRestoreStore.ForeColor = [System.Drawing.Color]::White
    $btnRestoreStore.FlatStyle = "Flat"
    $btnRestoreStore.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestoreStore)

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = "ELIMINAR SELECCIONADOS"
    $btnRemove.Location = New-Object System.Drawing.Point(710, 630)
    $btnRemove.Size = New-Object System.Drawing.Size(300, 40)
    $btnRemove.BackColor = [System.Drawing.Color]::Crimson
    $btnRemove.ForeColor = [System.Drawing.Color]::White
    $btnRemove.FlatStyle = "Flat"
    $btnRemove.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnRemove.Enabled = $false
    $form.Controls.Add($btnRemove)

    $script:AppCache = @()

    # --- LOGICA: RENDERIZADO GRID ---
    $RenderGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        
        $term = $txtSearch.Text.Trim()
        $filtered = $script:AppCache

        # 1. Filtro de Texto
        if (-not [string]::IsNullOrWhiteSpace($term)) {
            $filtered = $filtered | Where-Object { $_.Name -match $term }
        }

        # 2. Filtro de Protegidos (NUEVO)
        if (-not $chkShowProtected.Checked) {
            $filtered = $filtered | Where-Object { $_.Status -ne 'Protected' }
        }

        foreach ($app in $filtered) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["DisplayName"].Value = $app.Name
            $row.Cells["Version"].Value = $app.Version
            $row.Cells["RealObject"].Value = $app 
            
            if ($app.Status -eq 'Protected') {
                $row.Cells["StatusDesc"].Value = "SISTEMA (Protegido)"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::LightGreen
                $row.Cells["Check"].ReadOnly = $true 
            }
            elseif ($app.Status -eq 'Recommended') {
                $row.Cells["StatusDesc"].Value = "BLOATWARE"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Orange
            }
            else {
                $row.Cells["StatusDesc"].Value = "Usuario / Opcional"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
            }
        }
        $grid.ResumeLayout()
        $grid.ClearSelection()
        
        $count = $filtered.Count
        $lblStatus.Text = "Aplicaciones listadas: $count"
        if ($count -gt 0) { $btnRemove.Enabled = $true }
    }

    $PerformScan = {
        $lblStatus.Text = "Escaneando aplicaciones... Por favor espera."
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnRemove.Enabled = $false
        [System.Windows.Forms.Application]::DoEvents()

        $type = switch($cmbType.SelectedIndex) {
            0 { 'Microsoft' }
            1 { 'ThirdParty_AllUsers' }
            2 { 'ThirdParty_CurrentUser' }
        }

        $script:AppCache = Get-RemovableApps -Type $type
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        
        & $RenderGrid
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $PerformScan })
    $btnScan.Add_Click({ & $PerformScan })
    $txtSearch.Add_KeyUp({ & $RenderGrid })
    # Nuevo evento para el checkbox
    $chkShowProtected.Add_CheckedChanged({ & $RenderGrid })

    $grid.Add_CellClick({ param($s,$e) if($e.RowIndex -ge 0 -and $e.ColumnIndex -ne 0 -and -not $grid.Rows[$e.RowIndex].Cells["Check"].ReadOnly){ $r=$grid.Rows[$e.RowIndex]; $r.Cells[0].Value = -not $r.Cells[0].Value } })
    $grid.Add_KeyDown({ param($s,$e) if($e.KeyCode -eq 'Space'){ $e.SuppressKeyPress=$true; foreach($r in $s.SelectedRows){ if(-not $r.Cells[0].ReadOnly){ $r.Cells[0].Value = -not $r.Cells[0].Value } } } })

    $btnSelectAll.Add_Click({ foreach($r in $grid.Rows){ if(-not $r.Cells[0].ReadOnly){ $r.Cells[0].Value = $true } } })
    $btnSelectRec.Add_Click({ foreach($r in $grid.Rows){ if($r.DefaultCellStyle.ForeColor -eq [System.Drawing.Color]::Orange){ $r.Cells[0].Value = $true } } })

    $btnExport.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = "Texto (*.txt)|*.txt"
        $sfd.FileName = "Lista_Apps_$(Get-Date -Format 'yyyyMMdd').txt"
        if ($sfd.ShowDialog() -eq 'OK') {
            $lines = $script:AppCache | Select-Object Name, Version, Publisher, Status
            $lines | Out-File $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Lista exportada.", "Exito", 0, 64)
        }
    })

    $btnRestoreStore.Add_Click({
        if ([System.Windows.Forms.MessageBox]::Show("Esto intentara descargar y registrar la Microsoft Store nuevamente.\nÚsalo si la borraste por error.\n\n¿Continuar?", "Restaurar Tienda", 'YesNo', 'Warning') -eq 'Yes') {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            $lblStatus.Text = "Restaurando Microsoft Store..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                Get-AppxPackage -AllUsers *WindowsStore* | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
                [System.Windows.Forms.MessageBox]::Show("Intento de restauracion completado.\nReinicia el PC y verifica.", "Info", 0, 64)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error al restaurar: $_", "Error", 0, 16)
            }
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $lblStatus.Text = "Listo."
        }
    })

    $btnRemove.Add_Click({
        $appsToRemove = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $appsToRemove += $row.Cells["RealObject"].Value.Obj
            }
        }

        if ($appsToRemove.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No hay apps seleccionadas.", "Aviso", 0, 48); return }

        if ([System.Windows.Forms.MessageBox]::Show("¿Eliminar $($appsToRemove.Count) aplicaciones?\n\nEsta accion no se puede deshacer facilmente.", "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnRemove.Enabled = $false
        $count = 0
        
        foreach ($app in $appsToRemove) {
            $count++
            $lblStatus.Text = "Eliminando ($count/$($appsToRemove.Count)): $($app.Name)"
            $lblStatus.ForeColor = [System.Drawing.Color]::Cyan
            [System.Windows.Forms.Application]::DoEvents()

            try {
                Write-Log -LogLevel ACTION -Message "BLOATWARE: Eliminando $($app.Name) ($($app.PackageFullName))"
                Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop
                
                $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app.Name }
                if ($prov) { Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue }

                if ($chkDeepClean.Checked) {
                    $pkgPath = "$env:LOCALAPPDATA\Packages\$($app.PackageFamilyName)"
                    if (Test-Path $pkgPath) { Remove-Item -Path $pkgPath -Recurse -Force -ErrorAction SilentlyContinue }
                }

                foreach ($row in $grid.Rows) {
                    if ($row.Cells["DisplayName"].Value -eq $app.Name) {
                        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
                        $row.Cells["StatusDesc"].Value = "ELIMINADO"
                        $row.Cells["Check"].Value = $false
                    }
                }

            } catch {
                Write-Log -LogLevel ERROR -Message "Fallo al eliminar $($app.Name): $_"
            }
        }

        $lblStatus.Text = "Proceso finalizado."
        $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $btnRemove.Enabled = $true
        
        [System.Windows.Forms.MessageBox]::Show("Operacion completada.", "Exito", 0, 64)
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# ===================================================================
# MODULO DE Gestor de Inicio
# ===================================================================
function Manage-StartupApps {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Inicio"
    $form.Size = New-Object System.Drawing.Size(1000, 750)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. FUNCIONES HELPER (BACKEND) ---
    
    # Obtiene el estado real basado en el byte de control de Windows
    $GetStartupStateSmart = {
        param($Hive, $Type, $Name)
        
        $approvedPath = "$($Hive):\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$Type"
        
        if (-not (Test-Path $approvedPath)) { return 'Enabled' }
        
        try {
            $bytes = (Get-ItemProperty -Path $approvedPath -Name $Name -ErrorAction SilentlyContinue).$Name
            if ($null -eq $bytes -or $bytes.Length -eq 0) { return 'Enabled' }
            
            # Logica binaria: Si el primer byte es impar, suele estar deshabilitado
            if ($bytes[0] % 2 -ne 0) { return 'Disabled' }
            return 'Enabled'
        } catch {
            return 'Enabled'
        }
    }

    # Establece el estado preservando metadatos
    $SetStartupStateSmart = {
        param($Item, $Enable)
        
        $hiveStr = if ($Item.RegBase -eq 'HKLM') { "HKLM:" } else { "HKCU:" }
        $subKey = if ($Item.InternalType -eq 'Folder') { "StartupFolder" } else { "Run" }
        $approvedKeyPath = "$hiveStr\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$subKey"
        
        if (-not (Test-Path $approvedKeyPath)) { New-Item -Path $approvedKeyPath -Force | Out-Null }

        try {
            $currentBytes = (Get-ItemProperty -Path $approvedKeyPath -Name $Item.Name -ErrorAction SilentlyContinue).($Item.Name)
            
            if ($null -eq $currentBytes -or $currentBytes.Length -lt 1) {
                $currentBytes = New-Object byte[] 12
            }

            # 0x02 = Habilitado, 0x03 = Deshabilitado
            if ($Enable) { $currentBytes[0] = 0x02 } else { $currentBytes[0] = 0x03 }

            Set-ItemProperty -Path $approvedKeyPath -Name $Item.Name -Value $currentBytes -Type Binary -Force -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }

    # Elimina la entrada permanentemente
    $DeleteStartupItem = {
        param($Item)
        try {
            if ($Item.InternalType -eq 'Task') {
                Unregister-ScheduledTask -TaskName $Item.Name -TaskPath $Item.RegPath -Confirm:$false -ErrorAction Stop
            }
            elseif ($Item.InternalType -eq 'Folder') {
                if (Test-Path $Item.Command) {
                    Remove-Item -Path $Item.Command -Force -ErrorAction Stop
                }
            }
            elseif ($Item.InternalType -eq 'Registry') {
                # 1. Borrar la clave Run original
                Remove-ItemProperty -Path $Item.RegPath -Name $Item.Name -Force -ErrorAction Stop
                
                # 2. Limpiar entrada huerfana en StartupApproved (Limpieza)
                $hiveStr = if ($Item.RegBase -eq 'HKLM') { "HKLM:" } else { "HKCU:" }
                $approvedKeyPath = "$hiveStr\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
                if (Test-Path $approvedKeyPath) {
                    Remove-ItemProperty -Path $approvedKeyPath -Name $Item.Name -ErrorAction SilentlyContinue
                }
            }
            return $true
        } catch {
            Write-Warning "Error eliminando: $_"
            return $false
        }
    }

    # --- 3. UI SUPERIOR (BUSQUEDA AÑADIDA) ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Programas de Inicio"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    # Label Busqueda
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(350, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    # TextBox Busqueda
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(410, 20)
    $txtSearch.Width = 250
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(830, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(130, 28)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 4. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(940, 430)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas (Sin acentos)
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Nombre"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 250
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 100
    $grid.Columns.Add($colStatus) | Out-Null

    $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colType.HeaderText = "Ubicacion / Origen"
    $colType.Name = "Type"
    $colType.ReadOnly = $true
    $colType.Width = 150
    $grid.Columns.Add($colType) | Out-Null

    $colCmd = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCmd.HeaderText = "Comando"
    $colCmd.Name = "Command"
    $colCmd.ReadOnly = $true
    $grid.Columns.Add($colCmd) | Out-Null

    $form.Controls.Add($grid)

    # --- 5. PANEL DE DETALLES ---
    $grpDet = New-Object System.Windows.Forms.GroupBox
    $grpDet.Text = "Detalle del Comando Completo"
    $grpDet.ForeColor = [System.Drawing.Color]::Silver
    $grpDet.Location = New-Object System.Drawing.Point(20, 500)
    $grpDet.Size = New-Object System.Drawing.Size(940, 70)
    $form.Controls.Add($grpDet)

    $txtCommand = New-Object System.Windows.Forms.TextBox
    $txtCommand.Location = New-Object System.Drawing.Point(15, 25)
    $txtCommand.Size = New-Object System.Drawing.Size(910, 30)
    $txtCommand.ReadOnly = $true
    $txtCommand.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtCommand.ForeColor = [System.Drawing.Color]::Yellow
    $txtCommand.BorderStyle = "FixedSingle"
    $grpDet.Controls.Add($txtCommand)

    # --- 6. BOTONES DE ACCION (AGREGADO ELIMINAR) ---
    
    # Boton Habilitar
    $btnEnable = New-Object System.Windows.Forms.Button
    $btnEnable.Text = "HABILITAR"
    $btnEnable.Location = New-Object System.Drawing.Point(280, 590)
    $btnEnable.Size = New-Object System.Drawing.Size(200, 40)
    $btnEnable.BackColor = [System.Drawing.Color]::SeaGreen
    $btnEnable.ForeColor = [System.Drawing.Color]::White
    $btnEnable.FlatStyle = "Flat"
    $btnEnable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnEnable)

    # Boton Deshabilitar
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR"
    $btnDisable.Location = New-Object System.Drawing.Point(500, 590)
    $btnDisable.Size = New-Object System.Drawing.Size(200, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::Orange # Naranja para precaucion
    $btnDisable.ForeColor = [System.Drawing.Color]::Black
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    # Boton Eliminar (Nuevo)
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR"
    $btnDelete.Location = New-Object System.Drawing.Point(720, 590)
    $btnDelete.Size = New-Object System.Drawing.Size(240, 40)
    $btnDelete.BackColor = [System.Drawing.Color]::Maroon # Rojo oscuro peligro
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 595)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # Cache global
    $script:StartupCache = @{} 
    $script:StartupRawList = @() # Lista cruda para filtrado rapido

    # --- LOGICA DE CARGA DE DATOS ---
    $LoadData = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $script:StartupCache.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        # 1. Obtener datos crudos (solo si la lista esta vacia o se pide refrescar)
        # Esto permite que la barra de busqueda use datos en memoria rapido
        if ($script:StartupRawList.Count -eq 0 -or $true) { # Forzamos recarga por seguridad
            $items = @()

            # A. Registro
            $regPaths = @(
                @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Base="HKCU"; Type="Run" },
                @{ P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Base="HKLM"; Type="Run" },
                @{ P="HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"; Base="HKLM"; Type="Run" }
            )
            foreach ($loc in $regPaths) {
                if (Test-Path $loc.P) {
                    Get-ItemProperty $loc.P -ErrorAction SilentlyContinue | ForEach-Object {
                        $_.PSObject.Properties | Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider','(Default)') } | ForEach-Object {
                            $statusCheck = & $GetStartupStateSmart -Hive $loc.Base -Type "Run" -Name $_.Name
                            $items += [PSCustomObject]@{
                                Name = $_.Name; Command = $_.Value; Origin = "Registro ($($loc.Base))"
                                InternalType = "Registry"; RegBase = $loc.Base; RegPath = $loc.P; Status = $statusCheck
                            }
                        }
                    }
                }
            }

            # B. Carpetas
            $folders = @(
                @{ P="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Base="HKCU" },
                @{ P="$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"; Base="HKLM" }
            )
            foreach ($loc in $folders) {
                if (Test-Path $loc.P) {
                    Get-ChildItem $loc.P -File -ErrorAction SilentlyContinue | ForEach-Object {
                        $statusCheck = & $GetStartupStateSmart -Hive $loc.Base -Type "StartupFolder" -Name $_.Name
                        $items += [PSCustomObject]@{
                            Name = $_.Name; Command = $_.FullName; Origin = "Carpeta ($($loc.Base))"
                            InternalType = "Folder"; RegBase = $loc.Base; RegPath = $loc.P; Status = $statusCheck
                        }
                    }
                }
            }

            # C. Tareas
            Get-ScheduledTask | Where-Object { ($_.Triggers.TriggerType -contains 'Logon') -and ($_.TaskPath -notlike "\Microsoft\*") } | ForEach-Object {
                $act = ($_.Actions | Select-Object -First 1)
                $cmd = "$($act.Execute) $($act.Arguments)"
                $items += [PSCustomObject]@{
                    Name = $_.TaskName; Command = $cmd; Origin = "Tarea Programada"
                    InternalType = "Task"; RegBase = ""; RegPath = $_.TaskPath
                    Status = if ($_.State -eq 'Disabled') { 'Disabled' } else { 'Enabled' }
                }
            }
            
            $script:StartupRawList = $items
        }

        # 2. Filtrar y Poblar
        $searchTerm = $txtSearch.Text.Trim()
        $filteredItems = $script:StartupRawList
        
        if (-not [string]::IsNullOrWhiteSpace($searchTerm)) {
            $filteredItems = $script:StartupRawList | Where-Object { 
                $_.Name -match $searchTerm -or $_.Command -match $searchTerm 
            }
        }

        foreach ($item in $filteredItems) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            $row.Tag = $item 

            $row.Cells["Name"].Value = $item.Name
            $row.Cells["Type"].Value = $item.Origin
            $row.Cells["Command"].Value = $item.Command
            
            if ($item.Status -eq 'Enabled') {
                $row.Cells["Status"].Value = "Habilitado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
            } else {
                $row.Cells["Status"].Value = "Deshabilitado"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
            }
        }
        
        $grid.ResumeLayout()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $grid.ClearSelection()
        $txtCommand.Text = ""
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $LoadData })
    $btnRefresh.Add_Click({ $script:StartupRawList = @(); & $LoadData })
    
    # Evento de Busqueda (Key Up)
    $txtSearch.Add_KeyUp({ & $LoadData })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $item = $grid.SelectedRows[0].Tag
            if ($item) { $txtCommand.Text = $item.Command }
        }
    })

    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            $e.SuppressKeyPress = $true 
            foreach ($row in $sender.SelectedRows) {
                if (-not $row.Cells["Check"].ReadOnly) {
                    $row.Cells["Check"].Value = -not ($row.Cells["Check"].Value)
                }
            }
        }
    })
    
    $grid.Add_CellClick({
        param($sender, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -eq 0) { 
             # Checkbox click handling
        }
    })

    $btnSelectAll.Add_Click({
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
    })

    # Logica de Accion (Enable / Disable / Delete)
    $ApplyChange = {
        param($Action) # 'Enable', 'Disable', 'Delete'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $row.Tag
            }
        }

        if ($targets.Count -eq 0) { return }

        # Advertencia especial para Eliminar
        if ($Action -eq 'Delete') {
            $msg = "¿Estas seguro de eliminar permanentemente $($targets.Count) elementos?`n`nEsta accion NO se puede deshacer."
            if ([System.Windows.Forms.MessageBox]::Show($msg, "Confirmacion de Eliminacion", 4, 48) -ne 'Yes') { return }
        }

        foreach ($item in $targets) {
            try {
                if ($Action -eq 'Delete') {
                    $res = & $DeleteStartupItem -Item $item
                }
                elseif ($item.InternalType -eq 'Task') {
                    if ($Action -eq 'Enable') { 
                        Enable-ScheduledTask -TaskName $item.Name -TaskPath $item.RegPath -ErrorAction Stop 
                    } else { 
                        Disable-ScheduledTask -TaskName $item.Name -TaskPath $item.RegPath -ErrorAction Stop 
                    }
                }
                else {
                    # Registro o Carpeta (StartupApproved)
                    $boolState = ($Action -eq 'Enable')
                    $res = & $SetStartupStateSmart -Item $item -Enable $boolState
                }
            } catch {
                # Log error silencioso o a consola
            }
        }
        $script:StartupRawList = @() # Forzar recarga completa
        & $LoadData
    }

    $btnEnable.Add_Click({ & $ApplyChange -Action 'Enable' })
    $btnDisable.Add_Click({ & $ApplyChange -Action 'Disable' })
    $btnDelete.Add_Click({ & $ApplyChange -Action 'Delete' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# ===================================================================
# MODULO DE Reparacion del sistema (SFC/DISM/CHKDSK)
# ===================================================================
function Repair-SystemFiles {
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "      Verificacion y Reparacion de Archivos de Sistema " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Esta utilidad ejecutara secuencialmente:" -ForegroundColor Yellow
    Write-Host "   1. DISM ScanHealth    (Diagnostico de imagen)"
    Write-Host "   2. DISM RestoreHealth (Reparacion de imagen - Si es necesario)"
    Write-Host "   3. SFC /Scannow       (Reparacion de archivos de sistema)"
    Write-Host "   4. CHKDSK             (Analisis de disco fisico - Opcional)"
    Write-Host ""
    Write-Host "   [TIEMPO ESTIMADO]: 15 a 45 minutos." -ForegroundColor Gray
    Write-Host "   [ADVERTENCIA]: El sistema puede ir lento durante el proceso." -ForegroundColor Red
    Write-Host ""
    Write-Host "   [C] CONTINUAR con la reparacion" -ForegroundColor Green
    Write-Host "   [V] VOLVER al menu anterior" -ForegroundColor Red
    Write-Host ""

    $choice = Read-Host "Elige una opcion"

    # --- 1. Salida Rapida (Logica de Inventory) ---
    if ($choice.ToUpper() -ne 'C') {
        return
    }

    # --- Inicio del proceso real ---
    Write-Log -LogLevel INFO -Message "Usuario confirmo inicio de la secuencia de reparacion (SFC/DISM/CHKDSK)."
    Write-Host "`n[+] Iniciando la secuencia de reparacion..." -ForegroundColor Cyan
    
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
        # Usamos try/catch por si el log esta bloqueado
        try {
            $sfcEntries = Get-Content $cbsLogPath -ErrorAction SilentlyContinue | Select-String -Pattern "\[SR\]"
            if ($sfcEntries -match "Repairing file|Fixed|Repaired|Reparando archivo|Reparado") {
                $repairsMade = $true
            }
        } catch {}
    }

    # --- PASO 4 (UNIVERSAL): CHKDSK PROFUNDO ---
    Write-Host "`n[+] PASO 4/4 (OPCIONAL): Analisis Profundo de Disco (CHKDSK /r /f /b /x)" -ForegroundColor Cyan
    Write-Host "    Este comando busca sectores fisicos defectuosos y re-evalua todo el disco." -ForegroundColor Gray
    Write-Warning "Esta operacion requiere reiniciar y puede tardar VARIAS HORAS."
    Write-Warning "Durante el analisis, NO podras usar el equipo."
    
    $chkdskChoice = Read-Host "`n¿Deseas programar este analisis profundo para el proximo reinicio? (S/N)"
    
    if ($chkdskChoice.ToUpper() -eq 'S') {
        try {
            Write-Host "Programando CHKDSK en unidad $env:SystemDrive..." -ForegroundColor Yellow
            
            # --- DETECCION INTELIGENTE DE IDIOMA ---
            $sysLang = (Get-UICulture).TwoLetterISOLanguageName.ToUpper()
            $yesKey = "Y" 

            switch ($sysLang) {
                "ES" { $yesKey = "S" } 
                "FR" { $yesKey = "O" } 
                "DE" { $yesKey = "J" } 
                "IT" { $yesKey = "S" } 
                "PT" { $yesKey = "S" } 
            }
            
            $result = cmd.exe /c "echo $yesKey | chkdsk $env:SystemDrive /f /r /b /x" 2>&1
            
            if ($LASTEXITCODE -eq 0 -or $result -match "se comprobar|checked the next time") {
                Write-Host "[OK] CHKDSK programado exitosamente ($sysLang detected -> '$yesKey')." -ForegroundColor Green
                Write-Log -LogLevel ACTION -Message "REPAIR: Se programo CHKDSK /f /r /b  /x para el proximo reinicio."
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
        
        Write-Host "[RECOMENDACION] $msg" -ForegroundColor Cyan
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

# ===================================================================
# MODULO DE Purgado de cache de RAM
# ===================================================================
function Clear-RAMCache {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    Write-Log -LogLevel INFO -Message "SISTEMA: Iniciando purgado de memoria Standby con verificacion."
    
    Write-Host "`n[+] Purgando la Memoria RAM en Cache (Standby List)..." -ForegroundColor Cyan
    Write-Warning "Esto vaciara la memoria 'En Espera' moviendola a 'Libre'."
    
    # 1. Comprobacion de Intencion
    if ((Read-Host "¿Confirmar operacion? (S/N)").ToUpper() -ne 'S') { return }

    # 2. Gestion de la Herramienta (Descarga Segura)
    $toolDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath "Tools"
    if (-not (Test-Path $toolDir)) { New-Item -Path $toolDir -ItemType Directory | Out-Null }
    $toolPath = Join-Path -Path $toolDir -ChildPath "EmptyStandbyList.exe"

    if (-not (Test-Path $toolPath)) {
        Write-Host "   - Herramienta no encontrada. Descargando..." -ForegroundColor Gray
        try {
            $url = "https://ia800303.us.archive.org/9/items/empty-standby-list/EmptyStandbyList.exe"
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            
            # Descarga con timeout para no congelar el script
            Invoke-WebRequest -Uri $url -OutFile $toolPath -UseBasicParsing -TimeoutSec 15
            
            # VALIDACION 1: Integridad basica (Tamaño > 0)
            $fileInfo = Get-Item $toolPath
            if ($fileInfo.Length -lt 10KB) { 
                throw "El archivo descargado parece corrupto (demasiado pequeño)." 
            }
            Write-Host "   [OK] Herramienta descargada y verificada." -ForegroundColor Green
        } catch {
            Write-Error "   [ERROR] No se pudo obtener la herramienta: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "RAM CLEAN: Fallo descarga de herramienta: $($_.Exception.Message)"
            if (Test-Path $toolPath) { Remove-Item $toolPath -Force } # Limpiar archivo corrupto
            return
        }
    }

    # 3. Medicion PREVIA (Snapshot)
    # Usamos Available MBytes como proxy, ya que vaciar la Standby List incrementa la memoria Libre/Disponible
    $ramBefore = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
    Write-Host "   - RAM Disponible Inicial: $([math]::Round($ramBefore / 1KB, 0)) MB" -ForegroundColor Gray

    # 4. Ejecucion Controlada
    if ($PSCmdlet.ShouldProcess("Memoria del Sistema", "Purgar lista de espera")) {
        try {
            $proc = Start-Process -FilePath $toolPath -ArgumentList "standbylist" -Verb RunAs -PassThru -WindowStyle Hidden -Wait
            
            # VALIDACION 2: Codigo de Salida
            if ($proc.ExitCode -ne 0) {
                throw "La herramienta devolvio el codigo de error $($proc.ExitCode)."
            }
            
            # Pequeña pausa para que el SO actualice los contadores
            Start-Sleep -Seconds 2 

            # 5. Medicion POSTERIOR y Calculo de Exito
            $ramAfter = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
            $freedKB = $ramAfter - $ramBefore
            
            # Normalizar (si sale negativo por uso del sistema, es 0)
            if ($freedKB -lt 0) { $freedKB = 0 }
            
            $freedMB = [math]::Round($freedKB / 1KB, 0)
            
            Write-Host "`n   [EXITO] Operacion finalizada." -ForegroundColor Green
            Write-Host "   -> Memoria Recuperada: " -NoNewline
            Write-Host "$freedMB MB" -ForegroundColor Yellow
            
            Write-Log -LogLevel ACTION -Message "RAM CLEAN: Se purgo la memoria Standby. Recuperados aprox: $freedMB MB."

        } catch {
            Write-Error "   [FALLO] Ocurrio un error al ejecutar el purgado: $($_.Exception.Message)"
            Write-Log -LogLevel ERROR -Message "RAM CLEAN: Error de ejecucion - $($_.Exception.Message)"
        }
    }
    
    Read-Host "`nPresiona Enter para volver..."
}

# ===================================================================
# MODULO DE limpieza de caches del sistema
# ===================================================================
function Clear-SystemCaches {
    Write-Log -LogLevel INFO -Message "CACHES: Usuario entro al menu de caches del sistema."

    while ($true) {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Centro de Mantenimiento de Caches           " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Limpiar Cache DNS (Resolucion de Nombres)"
        Write-Host "       (Soluciona 'No se puede acceder al sitio web')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Limpiar Cache ARP (Tablas de Ruta Local)"
        Write-Host "       (Soluciona conflictos de IP y problemas de LAN)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Reconstruir Cache de Iconos y Miniaturas"
        Write-Host "       (Repara iconos blancos o corruptos. Reinicia Explorer)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Limpiar Cache de la Tienda (Microsoft Store)"
        Write-Host "       (Soluciona errores de descarga/actualizacion de apps)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [5] Limpiar Cache de Fuentes (Font Cache)"
        Write-Host "       (Soluciona texto corrupto o fuentes que no cargan)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [6] Limpiar Cache de Certificados SSL (Cryptnet)"
        Write-Host "       (Soluciona errores de seguridad en navegadores)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "   [A] EJECUTAR TODO (Limpieza Completa)" -ForegroundColor Yellow
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "   Selecciona una opcion"
        
        if ($choice.ToUpper() -eq 'V') { return }

        # --- LOGICA DE SELECCION ---
        $tasks = @()
        switch ($choice.ToUpper()) {
            '1' { $tasks += "DNS" }
            '2' { $tasks += "ARP" }
            '3' { $tasks += "ICONS" }
            '4' { $tasks += "STORE" }
            '5' { $tasks += "FONTS" }
            '6' { $tasks += "SSL" }
            'A' { $tasks = @("DNS", "ARP", "SSL", "FONTS", "ICONS", "STORE") }
            default { continue }
        }

        # --- EJECUCION DE TAREAS CON COMPROBACIONES ---
        if ($tasks.Count -gt 0) {
            Write-Host "`n[+] Iniciando operaciones..." -ForegroundColor Yellow
            
            foreach ($task in $tasks) {
                Write-Host "   Processing: $task..." -ForegroundColor DarkGray
                try {
                    switch ($task) {
                        "DNS" {
                            Write-Host "   - Limpiando Cache DNS..." -NoNewline
                            $dnsSuccess = $false
                            
                            # Intento 1: Cmdlet Moderno
                            try {
                                Clear-DnsClientCache -ErrorAction Stop
                                $dnsSuccess = $true
                            } catch {
                                # Intento 2: Legacy
                                $null = ipconfig.exe /flushdns
                                if ($LASTEXITCODE -eq 0) { $dnsSuccess = $true }
                            }

                            if ($dnsSuccess) {
                                Write-Host " [OK]" -ForegroundColor Green
                                Write-Log -LogLevel ACTION -Message "CACHES: DNS limpiado exitosamente."
                            } else {
                                Write-Host " [FALLO]" -ForegroundColor Red
                                Write-Log -LogLevel ERROR -Message "CACHES: Fallo al limpiar DNS."
                            }
                        }

                        "ARP" {
                            Write-Host "   - Limpiando Tabla ARP..." -NoNewline
                            # Ejecucion y captura de error
                            $proc = Start-Process "netsh.exe" -ArgumentList "interface ip delete arpcache" -NoNewWindow -PassThru -Wait
                            
                            if ($proc.ExitCode -eq 0) {
                                Write-Host " [OK]" -ForegroundColor Green
                            } elseif ($proc.ExitCode -eq 1) {
                                Write-Host " [REQUIERE ELEVACION]" -ForegroundColor Red
                            } else {
                                Write-Host " [ERROR CODE: $($proc.ExitCode)]" -ForegroundColor Red
                            }
                        }

                        "SSL" {
                            Write-Host "   - Limpiando Cache SSL (Cryptnet)..." -NoNewline
                            $proc = Start-Process "certutil.exe" -ArgumentList "-urlcache * delete" -NoNewWindow -PassThru -Wait
                            
                            if ($proc.ExitCode -eq 0) {
                                Write-Host " [OK]" -ForegroundColor Green
                            } else {
                                Write-Host " [ADVERTENCIA]" -ForegroundColor Yellow
                                Write-Host "     (Es posible que la cache ya estuviera vacia)" -ForegroundColor Gray
                            }
                        }

                        "FONTS" {
                            Write-Host "`n   - Limpiando Cache de Fuentes..." -ForegroundColor Cyan
                            
                            $svcName = "FontCache"
                            $svc = Get-Service $svcName -ErrorAction SilentlyContinue
                            $wasRunning = ($svc.Status -eq 'Running')

                            # 1. Detener Servicio
                            if ($wasRunning) {
                                Write-Host "     * Deteniendo servicio de cache..." -ForegroundColor Gray
                                Stop-Service $svcName -Force -ErrorAction SilentlyContinue
                                Start-Sleep -Milliseconds 500
                            }
                            
                            # 2. Eliminar Archivos
                            $fontCachePath = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
                            if (Test-Path $fontCachePath) {
                                $files = Get-ChildItem "$fontCachePath\*.dat" -ErrorAction SilentlyContinue
                                if ($files) {
                                    Remove-Item "$fontCachePath\*.dat" -Force -ErrorAction SilentlyContinue
                                    if (!(Test-Path "$fontCachePath\*.dat")) {
                                        Write-Host "     * Archivos .dat eliminados." -ForegroundColor Green
                                    } else {
                                        Write-Host "     * Algunos archivos estaban bloqueados." -ForegroundColor Yellow
                                    }
                                } else {
                                    Write-Host "     * No se encontraron archivos de cache." -ForegroundColor Gray
                                }
                            }
                            
                            # 3. Reiniciar Servicio (solo si estaba corriendo)
                            if ($wasRunning) {
                                Start-Service $svcName -ErrorAction SilentlyContinue
                                Write-Host "     [OK] Servicio reiniciado." -ForegroundColor Green
                            }
                        }

                        "ICONS" {
                            Write-Host "`n   - Reconstruyendo Cache de Iconos..." -ForegroundColor Cyan
                            Write-Host "     * Reiniciando Explorador de Windows..." -ForegroundColor Yellow
                            
                            # Comprobación de seguridad antes de matar Explorer
                            try {
                                Stop-Process -Name "explorer" -Force -ErrorAction Stop
                                Start-Sleep -Milliseconds 500
                                
                                $iconPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                                $deletedCount = 0
                                
                                # Borrado selectivo
                                $items = Get-ChildItem -Path $iconPath -Filter "iconcache_*.db" -ErrorAction SilentlyContinue
                                $items += Get-ChildItem -Path $iconPath -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
                                
                                foreach ($item in $items) {
                                    try {
                                        Remove-Item $item.FullName -Force -ErrorAction Stop
                                        $deletedCount++
                                    } catch {}
                                }
                                Write-Host "     * Bases de datos purgadas: $deletedCount" -ForegroundColor Gray
                            } catch {
                                Write-Warning "     No se pudo detener el Explorador o acceder a los archivos."
                            } finally {
                                # Garantizar que Explorer vuelva
                                if (-not (Get-Process "explorer" -ErrorAction SilentlyContinue)) {
                                    Start-Process "explorer.exe"
                                    Write-Host "     [OK] Explorador reiniciado." -ForegroundColor Green
                                }
                            }
                        }

                        "STORE" {
                            Write-Host "`n   - Reseteando Microsoft Store (WSReset)..." -ForegroundColor Cyan
                            Write-Host "     (Se abrira una ventana externa, no la cierres...)" -ForegroundColor Gray
                            
                            try {
                                # Usamos Start-Process para monitorear
                                $p = Start-Process "wsreset.exe" -PassThru
                                
                                # Esperamos maximo 10 segundos para no congelar el script si wsreset se cuelga
                                $timeout = 0
                                while (-not $p.HasExited -and $timeout -lt 10) {
                                    Start-Sleep -Seconds 1
                                    $timeout++
                                }
                                
                                if ($p.HasExited) {
                                    Write-Host "     [OK] Comando finalizado." -ForegroundColor Green
                                } else {
                                    Write-Host "     [INFO] WSReset sigue ejecutandose en segundo plano." -ForegroundColor Yellow
                                }
                            } catch {
                                Write-Error "     Fallo al iniciar WSReset."
                            }
                        }
                    }
                } catch {
                    Write-Error "     [ERROR FATAL] Fallo en modulo $task : $($_.Exception.Message)"
                }
            }

            Write-Host "`n[FIN] Operaciones completadas." -ForegroundColor Green
            Read-Host "Presiona Enter para continuar..."
        }
    }
}

# ===================================================================
# MODULO DE Optimizacion de unidades
# ===================================================================
function Optimize-Drives {
    Write-Log -LogLevel INFO -Message "DISCOS: Usuario entro al menu de optimizacion avanzada."
    
    # --- CONFIGURACION DE LOGGING ---
    $parentDir = Split-Path -Parent $PSScriptRoot
    $logDir = Join-Path -Path $parentDir -ChildPath "Logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    
    $logFileName = "Optimizacion_Detallada_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
    $logFile = Join-Path -Path $logDir -ChildPath $logFileName

    # --- HELPER 1: Escribir en Log (Limpieza Null Bytes) ---
    function Write-LogFile {
        param([string]$Text, [bool]$IsHeader = $false)
        $cleanText = $Text -replace '\0', '' # Elimina bytes nulos que rompen logs
        if ($IsHeader) {
            $separator = "=" * 60
            "$separator`r`n$cleanText`r`n$separator" | Out-File -FilePath $logFile -Append -Encoding UTF8
        } else {
            $cleanText | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }

    # --- HELPER 2: Salida Dual ---
    function Write-Dual {
        param(
            [Parameter(Mandatory=$true)][string]$Message,
            [string]$Color = "White",
            [switch]$NoNewLine
        )
        if ($NoNewLine) { Write-Host $Message -NoNewline -ForegroundColor $Color }
        else { Write-Host $Message -ForegroundColor $Color }

        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-LogFile "[$timestamp] $Message"
    }

    # Header del Log
    $headerInfo = "REPORTE DE OPTIMIZACION DE ALMACENAMIENTO`r`n" +
                  "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n" +
                  "Equipo: $env:COMPUTERNAME | Usuario: $env:USERNAME`r`n" +
                  "Sistema: $((Get-CimInstance Win32_OperatingSystem).Caption)"
    Write-LogFile $headerInfo -IsHeader $true

    # --- FUNCIONES INTERNAS ---
    function Test-VolumeDirtyInternal {
        param($Letter)
        try {
            $v = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($Letter):'" -ErrorAction Stop
            return $v.VolumeDirty
        } catch { return $false }
    }

    function Get-MediaTypeInternal {
        param($Letter)
        try {
            $part = Get-Partition -DriveLetter $Letter -ErrorAction Stop
            $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop
            if ($disk.Model -match "Virtual|Storage Space" -or $disk.BusType -eq "FileBackedVirtual") { return "Virtual" }
            $pDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $disk.Number } | Select-Object -First 1
            if ($pDisk) { return $pDisk.MediaType }
        } catch {}
        return "Unknown"
    }

	# Estado Global TRIM
    $trimQuery = (fsutil behavior query DisableDeleteNotify) -join " "
    $isTrimEnabledGlobal = $trimQuery -match "DisableDeleteNotify = 0"
    $trimLabelGlobal = if ($isTrimEnabledGlobal) { "ON (Habilitado)" } else { "OFF (Deshabilitado)" }
    $trimColorGlobal = if ($isTrimEnabledGlobal) { "Green" } else { "Red" }

    # --- BUCLE PRINCIPAL ---
    while ($true) {
        $volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | Sort-Object DriveLetter

        if ($volumes.Count -eq 0) {
            Write-Warning "No se detectaron unidades fijas."
            return
        }

        # CONSTRUCCION DE INVENTARIO
        $driveList = @()
        foreach ($vol in $volumes) {
            $letter = $vol.DriveLetter
            $type = Get-MediaTypeInternal -Letter $letter
            $isDirty = Test-VolumeDirtyInternal -Letter $letter
            $integrityStr = if ($isDirty) { "CORRUPTO" } else { "Sano" }
            
            $totalGB = [math]::Round($vol.Size / 1GB, 2)
            $freeGB  = [math]::Round($vol.SizeRemaining / 1GB, 2)

            $trimStatus = "N/A"
            if ($type -eq 'SSD' -or $type -eq 'Virtual' -or $type -eq 'Tiered') {
                if ($isTrimEnabledGlobal) { $trimStatus = "Activo" } else { $trimStatus = "Inactivo" }
            } else { $trimStatus = "-" }

            $blStatus = "Desbloqueado"
            $bl = $null
            try {
                $bl = Get-BitLockerVolume -MountPoint "$($letter):" -ErrorAction SilentlyContinue
                if ($bl) {
                    if ($bl.ProtectionStatus -eq 'On' -and $bl.LockStatus -eq 'Locked') { $blStatus = "BLOQUEADO" }
                    elseif ($bl.ProtectionStatus -eq 'On') { $blStatus = "Cifrado" }
                }
            } catch {}

            $driveList += [PSCustomObject]@{
                Letter    = $letter
                Label     = if ($vol.FileSystemLabel) { $vol.FileSystemLabel } else { "Sin Etiqueta" }
                Total     = $totalGB
                Free      = $freeGB
                Type      = $type
                Integrity = $integrityStr
                BLStatus  = $blStatus
                IsDirty   = $isDirty
                IsLocked  = ($blStatus -eq "BLOQUEADO")
                Trim      = $trimStatus
            }
        }

        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "           Optimizacion de Almacenamiento              " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "   Estado Global TRIM (OS): $trimLabelGlobal" -ForegroundColor $trimColorGlobal
        Write-Host "   Archivo de Log: $logFileName" -ForegroundColor Gray
        Write-Host ""
        
        $fmt = "{0,-4} | {1,-3} | {2,-12} | {3,-8} | {4,-10} | {5,-10} | {6,-10} | {7,-8} | {8}"
        Write-Host ($fmt -f "Num", "Ltr", "Etiqueta", "Tipo", "Total (GB)", "Libre (GB)", "Integridad", "TRIM", "BitLocker") -ForegroundColor DarkGray
        Write-Host ("-" * 115) -ForegroundColor DarkGray

        for ($i = 0; $i -lt $driveList.Count; $i++) {
            $d = $driveList[$i]
            $rowColor = "White"
            if ($d.IsDirty) { $rowColor = "Red" }
            elseif ($d.IsLocked) { $rowColor = "Magenta" }
            elseif ($d.Type -eq 'SSD') { $rowColor = "Cyan" }
            elseif ($d.Type -eq 'Virtual') { $rowColor = "Green" }
            elseif ($d.Type -eq 'Tiered') { $rowColor = "Yellow" }

            Write-Host ($fmt -f "[$($i+1)]", $d.Letter, $d.Label.Substring(0, [math]::Min($d.Label.Length, 12)), $d.Type, $d.Total, $d.Free, $d.Integrity, $d.Trim, $d.BLStatus) -ForegroundColor $rowColor
        }
        
        Write-Host ""
        Write-Host "   [T] Optimizar TODAS (Lote Completo)" -ForegroundColor Green
        Write-Host "   [A] Analizar TODAS (Solo Diagnostico)" -ForegroundColor Yellow
        Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "   Selecciona una opcion (Numero de Unidad, T, A, V)"
        
        $targets = @()
        $analyzeOnly = $false
        
        if ($choice.ToUpper() -eq 'V') { return }
        elseif ($choice.ToUpper() -eq 'T') { $targets = $driveList }
        elseif ($choice.ToUpper() -eq 'A') { $analyzeOnly = $true; $targets = $driveList }
        elseif ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $driveList.Count) {
                $found = $driveList[$index]
                $targets = @($found)
                Write-Host ""
                Write-Host "   Has seleccionado la Unidad ($($found.Letter)):" -ForegroundColor Cyan
                Write-Host "   [1] OPTIMIZAR (Ejecutar ReTrim/Defrag)" -ForegroundColor Green
                Write-Host "   [2] ANALIZAR (Ver estado de fragmentacion)" -ForegroundColor Yellow
                $subChoice = Read-Host "   ¿Que deseas hacer?"
                if ($subChoice -eq '2') { $analyzeOnly = $true }
                elseif ($subChoice -ne '1') { continue }
            } else { continue }
        } else { continue }

        # --- EJECUCION ---
        foreach ($item in $targets) {
            Write-Dual "`n[+] Procesando Unidad $($item.Letter): ($($item.Type))..." -Color Yellow
            Write-LogFile "`r`n--- INICIO OPERACION: Unidad $($item.Letter) ($($item.Type)) ---"
            
            if ($item.IsLocked) { Write-Dual "   [OMITIDO] Unidad bloqueada por BitLocker." -Color Magenta; continue }
            if ($item.IsDirty) { Write-Dual "   [PELIGRO] Unidad corrupta. Ejecuta CHKDSK primero." -Color Red; continue }

            try {
                $params = @{ DriveLetter = $item.Letter; ErrorAction = "Stop"; Verbose = $true }
                $cmdOutputRaw = $null

                if ($analyzeOnly) {
                    Write-Dual "   - Iniciando Analisis..." -Color Cyan
                    $params.Add("Analyze", $true)
                    
                    # Captura Salida
                    $cmdOutputRaw = Optimize-Volume @params 4>&1 | Out-String
                    $cleanOutput = $cmdOutputRaw -replace '\0', '' -replace '\s+', ' '
                    
                    # --- PARSER BILINGÜE ---
                    $fragPercent = 0
                    if ($cleanOutput -match "(?:fragmentado|fragmented)\s*=\s*(\d+)%") { $fragPercent = [int]$matches[1] }
                    
                    $needsOpt = $false
                    if ($cleanOutput -match "(?:es necesario|you need to)") { $needsOpt = $true }
                    
                    $statusColor = if ($fragPercent -gt 10 -or $needsOpt) { "Yellow" } else { "Green" }
                    $statusText = if ($needsOpt) { "OPTIMIZACION RECOMENDADA" } else { "Correcto (No requiere accion)" }
                    
                    Write-Dual "   ------------------------------------------------" -Color DarkGray
                    Write-Dual "   [RESULTADO] Fragmentacion: $fragPercent%" -Color $statusColor
                    Write-Dual "   [ESTADO]    $statusText" -Color $statusColor
                    Write-Dual "   ------------------------------------------------" -Color DarkGray
                    Write-Dual "   [OK] Analisis finalizado." -Color Green

                } else {
                    # Logica de Optimizacion
                    if ($item.Type -eq 'SSD') {
                        if (-not $isTrimEnabledGlobal) {
                            Write-Dual "   [AUTO-FIX] Intentando activar TRIM (Registry)..." -Color Yellow
                            Start-Process "fsutil.exe" -ArgumentList "behavior set DisableDeleteNotify 0" -NoNewWindow -PassThru -Wait > $null
                            $isTrimEnabledGlobal = $true
                        }
                        Write-Dual "   - Ejecutando Retrim (Flash)..." -Color Cyan
                        $params.Add("ReTrim", $true)
                    } elseif ($item.Type -eq 'HDD') {
                        Write-Dual "   - Ejecutando Desfragmentacion..." -Color Cyan
                        $params.Add("Defrag", $true)
                    } elseif ($item.Type -eq 'Virtual') {
                        Write-Dual "   - Ejecutando Slab Consolidation..." -Color Cyan
                        $params.Add("SlabConsolidate", $true)
                    } elseif ($item.Type -eq 'Tiered') {
                        Write-Dual "   - Ejecutando Tier Optimization..." -Color Cyan
                        $params.Add("TierOptimize", $true)
                    } else {
                        Write-Dual "   - Ejecutando optimizacion estandar..." -Color Gray
                        $params.Add("Normal", $true)
                    }
                    
                    # EJECUCION Y CAPTURA
                    $cmdOutputRaw = Optimize-Volume @params 4>&1 | Out-String
                    
                    # --- PARSER DE RESULTADOS POST-OPTIMIZACION (NUEVO) ---
                    $cleanOptOutput = $cmdOutputRaw -replace '\0', '' -replace '\s+', ' '
                    
                    # Buscamos el reporte posterior (comun en HDDs)
                    $finalFrag = 0
                    $foundReport = $false
                    
                    # Regex para encontrar fragmentacion en el "Post Defragmentation Report" o al final
                    # Busca el ULTIMO porcentaje de fragmentacion mencionado
                    if ($cleanOptOutput -match "(?:Post Defragmentation Report|Informe de optimización posterior).*?(?:fragmentado|fragmented)\s*=\s*(\d+)%") {
                        $finalFrag = [int]$matches[1]
                        $foundReport = $true
                    } elseif ($cleanOptOutput -match "(?:fragmentado|fragmented)\s*=\s*(\d+)%") {
                        # Fallback: si no encuentra el encabezado, busca cualquier porcentaje
                        $finalFrag = [int]$matches[1]
                        $foundReport = $true
                    }

                    if ($item.Type -eq 'HDD' -and $foundReport) {
                        $col = if ($finalFrag -lt 5) { "Green" } else { "Yellow" }
                        Write-Dual "   ------------------------------------------------" -Color DarkGray
                        Write-Dual "   [REPORTE] Fragmentacion Final: $finalFrag%" -Color $col
                        Write-Dual "   ------------------------------------------------" -Color DarkGray
                    } elseif ($item.Type -eq 'SSD') {
                        # SSDs no suelen dar reporte de fragmentacion tras retrim
                        Write-Dual "   [REPORTE] Operacion TRIM completada exitosamente." -Color Green
                    } else {
                        Write-Dual "   [REPORTE] Optimizacion completada." -Color Green
                    }

                    Write-Dual "   [OK] Finalizado." -Color Green
                }

                if (-not [string]::IsNullOrWhiteSpace($cmdOutputRaw)) {
                    Write-LogFile "DETALLES TECNICOS DE WINDOWS:"
                    Write-LogFile "-----------------------------"
                    Write-LogFile $cmdOutputRaw
                    Write-LogFile "-----------------------------"
                }

            } catch {
                $errMsg = $_.Exception.Message
                if ($errMsg -match "not supported") {
                    Write-Dual "   [AVISO] Operacion no soportada por el hardware." -Color Yellow
                } else {
                    Write-Dual "   [ERROR] $errMsg" -Color Red
                }
            }
        }
        
        Write-Host ""
        Read-Host "Presiona Enter para continuar..."
    }
}

# ===================================================================
# MODULO DE DIAGNOSTICO DE ENERGIA
# ===================================================================
function Generate-SystemReport {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Activar estilos visuales
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Centro de Diagnostico de Energia"
    $form.Size = New-Object System.Drawing.Size(800, 550)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. ENCABEZADO ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Diagnosticos de Energia y Hardware"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.AutoSize = $true
    $lblTitle.ForeColor = [System.Drawing.Color]::Cyan
    $form.Controls.Add($lblTitle)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "Genera reportes detallados sobre la salud de la bateria, eficiencia y suspension."
    $lblSub.Location = New-Object System.Drawing.Point(25, 55)
    $lblSub.AutoSize = $true
    $lblSub.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($lblSub)

    # --- 3. CONTENEDOR DE OPCIONES ---
    $grpOptions = New-Object System.Windows.Forms.GroupBox
    $grpOptions.Text = "Selecciona un Reporte"
    $grpOptions.Location = New-Object System.Drawing.Point(20, 90)
    $grpOptions.Size = New-Object System.Drawing.Size(740, 280)
    $grpOptions.ForeColor = [System.Drawing.Color]::LightGray
    $form.Controls.Add($grpOptions)

    # -- OPCION A: ENERGY REPORT --
    $btnEnergy = New-Object System.Windows.Forms.Button
    $btnEnergy.Text = "Reporte de Eficiencia (Energy)"
    $btnEnergy.Location = New-Object System.Drawing.Point(30, 40)
    $btnEnergy.Size = New-Object System.Drawing.Size(250, 50)
    $btnEnergy.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnEnergy.ForeColor = [System.Drawing.Color]::White
    $btnEnergy.FlatStyle = "Flat"
    $btnEnergy.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $grpOptions.Controls.Add($btnEnergy)

    $lblEnergy = New-Object System.Windows.Forms.Label
    $lblEnergy.Text = "Analiza el comportamiento del sistema, busca errores de hardware USB y consumo excesivo."
    $lblEnergy.Location = New-Object System.Drawing.Point(300, 45)
    $lblEnergy.Size = New-Object System.Drawing.Size(400, 40)
    $grpOptions.Controls.Add($lblEnergy)

    # Selector de Duracion
    $lblDur = New-Object System.Windows.Forms.Label
    $lblDur.Text = "Duracion (seg):"
    $lblDur.Location = New-Object System.Drawing.Point(30, 100)
    $lblDur.AutoSize = $true
    $grpOptions.Controls.Add($lblDur)

    $numDuration = New-Object System.Windows.Forms.NumericUpDown
    $numDuration.Location = New-Object System.Drawing.Point(120, 98)
    $numDuration.Width = 60
    $numDuration.Minimum = 5
    $numDuration.Maximum = 300
    $numDuration.Value = 60
    $numDuration.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $numDuration.ForeColor = [System.Drawing.Color]::White
    $grpOptions.Controls.Add($numDuration)

    # -- OPCION B: BATTERY REPORT --
    $btnBattery = New-Object System.Windows.Forms.Button
    $btnBattery.Text = "Reporte de Bateria (Health)"
    $btnBattery.Location = New-Object System.Drawing.Point(30, 150)
    $btnBattery.Size = New-Object System.Drawing.Size(250, 50)
    $btnBattery.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnBattery.ForeColor = [System.Drawing.Color]::LightGreen
    $btnBattery.FlatStyle = "Flat"
    $btnBattery.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $grpOptions.Controls.Add($btnBattery)

    $lblBattery = New-Object System.Windows.Forms.Label
    $lblBattery.Text = "Historial de uso, capacidad real vs diseño y ciclos de carga."
    $lblBattery.Location = New-Object System.Drawing.Point(300, 155)
    $lblBattery.Size = New-Object System.Drawing.Size(400, 40)
    $grpOptions.Controls.Add($lblBattery)

    # -- OPCION C: SLEEP STUDY --
    $btnSleep = New-Object System.Windows.Forms.Button
    $btnSleep.Text = "Sleep Study (Suspension)"
    $btnSleep.Location = New-Object System.Drawing.Point(30, 210)
    $btnSleep.Size = New-Object System.Drawing.Size(250, 50)
    $btnSleep.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSleep.ForeColor = [System.Drawing.Color]::White
    $btnSleep.FlatStyle = "Flat"
    $btnSleep.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $grpOptions.Controls.Add($btnSleep)

    $lblSleep = New-Object System.Windows.Forms.Label
    $lblSleep.Text = "Diagnostica drenaje de bateria durante la suspension (Modern Standby)."
    $lblSleep.Location = New-Object System.Drawing.Point(300, 215)
    $lblSleep.Size = New-Object System.Drawing.Size(400, 40)
    $grpOptions.Controls.Add($lblSleep)

    # --- 4. BARRA DE ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 390)
    $progressBar.Size = New-Object System.Drawing.Size(740, 20)
    $progressBar.Style = "Blocks" # Estilo sólido para llenado real
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo para analizar."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 420)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    $btnOpenFolder = New-Object System.Windows.Forms.Button
    $btnOpenFolder.Text = "Abrir Carpeta"
    $btnOpenFolder.Location = New-Object System.Drawing.Point(560, 450)
    $btnOpenFolder.Size = New-Object System.Drawing.Size(200, 40)
    $btnOpenFolder.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $btnOpenFolder.ForeColor = [System.Drawing.Color]::White
    $btnOpenFolder.FlatStyle = "Flat"
    $form.Controls.Add($btnOpenFolder)

    # --- VARIABLES DE ESTADO Y SINCRONIZACION ---
    $script:ActiveProcess = $null
    $script:ActiveReportPath = ""
    $script:StartTime = $null
    $script:TargetDuration = 0 # Variable para guardar la duración total

    # --- 5. EL MONITOR ASINCRONO (TIMER DE CUENTA REGRESIVA) ---
    $monitorTimer = New-Object System.Windows.Forms.Timer
    $monitorTimer.Interval = 1000 # Actualizar cada segundo

    $monitorTimer.Add_Tick({
        # Calcular tiempo
        if ($script:StartTime) {
            $elapsed = (Get-Date) - $script:StartTime
            $secondsElapsed = [int]$elapsed.TotalSeconds
            
            # Calculo inverso: Cuantos segundos faltan
            $secondsRemaining = $script:TargetDuration - $secondsElapsed
            if ($secondsRemaining -lt 0) { $secondsRemaining = 0 }

            # Actualizar Barra (Se llena hacia arriba)
            if ($secondsElapsed -le $progressBar.Maximum) {
                $progressBar.Value = $secondsElapsed
            }

            # Actualizar Texto (Cuenta Regresiva)
            $lblStatus.Text = "Analizando... Quedan $secondsRemaining segundos."
        }

        # Verificar si el proceso sigue vivo
        if ($script:ActiveProcess -ne $null -and -not $script:ActiveProcess.HasExited) {
            return
        }

        # --- EL PROCESO TERMINO ---
        $monitorTimer.Stop()
        $progressBar.Value = $progressBar.Maximum # Llenar barra al 100%
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        
        # Reactivar botones
        $btnEnergy.Enabled = $true; $btnBattery.Enabled = $true; $btnSleep.Enabled = $true

        # Analizar resultados
        if ($script:ActiveProcess.ExitCode -eq 0 -and (Test-Path $script:ActiveReportPath)) {
            $lblStatus.Text = "Reporte generado con exito."
            $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
            
            if ([System.Windows.Forms.MessageBox]::Show("Reporte generado exitosamente.`n`n¿Deseas abrirlo ahora?", "Completado", 'YesNo', 'Information') -eq 'Yes') {
                Start-Process $script:ActiveReportPath
            }
        } else {
            $lblStatus.Text = "Fallo al generar el reporte."
            $lblStatus.ForeColor = [System.Drawing.Color]::Salmon
            [System.Windows.Forms.MessageBox]::Show("El comando fallo.`nAsegurate de ejecutar como Administrador.`nCodigo: $($script:ActiveProcess.ExitCode)", "Error", 0, 16)
        }
    })

    # --- LOGICA DE INICIO ---
    $StartAnalysis = {
        param($Type)
        
        # Preparar Directorios
        $parentDir = Split-Path -Parent $PSScriptRoot
        $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
        if (-not (Test-Path $diagDir)) { New-Item -Path $diagDir -ItemType Directory | Out-Null }
        
        $date = Get-Date -Format 'yyyy-MM-dd_HH-mm'
        $cmdArgs = ""
        $duration = 0
        
        switch ($Type) {
            'Energy' {
                $duration = [int]$numDuration.Value
                $lblStatus.Text = "Iniciando analisis de ENERGIA ($duration seg)..."
                $script:ActiveReportPath = Join-Path $diagDir "Energy_Report_$date.html"
                $cmdArgs = "/energy /output `"$script:ActiveReportPath`" /duration $duration"
            }
            'Battery' {
                $duration = 5 # Estimado visual
                $lblStatus.Text = "Generando reporte de BATERIA..."
                $script:ActiveReportPath = Join-Path $diagDir "Battery_Report_$date.html"
                $cmdArgs = "/batteryreport /output `"$script:ActiveReportPath`""
            }
            'Sleep' {
                $duration = 5 # Estimado visual
                $lblStatus.Text = "Analizando SUSPENSION..."
                $script:ActiveReportPath = Join-Path $diagDir "Sleep_Study_$date.html"
                $cmdArgs = "/sleepstudy /output `"$script:ActiveReportPath`""
            }
        }

        # Configurar UI
        $btnEnergy.Enabled = $false; $btnBattery.Enabled = $false; $btnSleep.Enabled = $false
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
        
        # Configurar Barra
        $progressBar.Style = "Blocks"
        $progressBar.Minimum = 0
        $progressBar.Maximum = $duration
        $progressBar.Value = 0
        
        # Guardar duración objetivo para la cuenta regresiva
        $script:TargetDuration = $duration
        
        # Iniciar
        try {
            $script:StartTime = Get-Date
            $script:ActiveProcess = Start-Process "powercfg.exe" -ArgumentList $cmdArgs -WindowStyle Hidden -PassThru
            $monitorTimer.Start()
        } catch {
            $lblStatus.Text = "Error al iniciar proceso: $_"
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $btnEnergy.Enabled = $true; $btnBattery.Enabled = $true; $btnSleep.Enabled = $true
        }
    }

    # --- EVENTOS ---
    $btnEnergy.Add_Click({ & $StartAnalysis -Type 'Energy' })
    $btnBattery.Add_Click({ & $StartAnalysis -Type 'Battery' })
    $btnSleep.Add_Click({ & $StartAnalysis -Type 'Sleep' })
    
    $btnOpenFolder.Add_Click({
        $parentDir = Split-Path -Parent $PSScriptRoot
        $diagDir = Join-Path -Path $parentDir -ChildPath "Diagnosticos"
        if (Test-Path $diagDir) { Start-Process $diagDir }
    })

    # Limpieza al cerrar
    $form.Add_FormClosing({ $monitorTimer.Stop() })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# ===================================================================
# --- MoDULO DE DIAGNoSTICO Y REPARACION DE RED ---
# ===================================================================
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

    # --- FUNCION: EJECUCION ASINCRONA ROBUSTA ---
    $RunAsyncProcess = {
        param($Exe, $CmdArgs, $Title, $ClearConsole = $true)
        
        if ($ClearConsole) { $consoleBox.Clear() }
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        & $LogToBox -Msg "EJECUTANDO: $Title" -IsHeader $true -Color "Cyan"
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = $Exe
            $pinfo.Arguments = $CmdArgs
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError = $true
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true
            
            # CRITICO: Usar codificacion OEM para leer correctamente tildes y caracteres de consola
            $oemEncoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
            $pinfo.StandardOutputEncoding = $oemEncoding
            $pinfo.StandardErrorEncoding = $oemEncoding

            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null

            while (-not $p.HasExited) {
                $line = $p.StandardOutput.ReadLine()
                if ($null -ne $line) {
                    $c = "White"
                    if ($line -match "error|fallo|failed|unreachable|agotado|timed out") { $c = "Salmon" }
                    if ($line -match "reply|respuesta|ms") { $c = "LightGreen" }
                    if ($line -match "tracing|trazando|haciendo ping") { $c = "Yellow" }
                    
                    # Logica especial para ipconfig
                    if ($line -match "IPv4") { $c = "Cyan" }

                    $consoleBox.SelectionStart = $consoleBox.TextLength
                    $consoleBox.SelectionLength = 0
                    $consoleBox.SelectionColor = [System.Drawing.Color]::FromName($c)
                    $consoleBox.AppendText("$line`r`n")
                    $consoleBox.ScrollToCaret()
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
            
            # Leer remanente
            $rest = $p.StandardOutput.ReadToEnd(); if ($rest) { $consoleBox.AppendText("$rest`r`n") }
            $err = $p.StandardError.ReadToEnd()
            if (-not [string]::IsNullOrWhiteSpace($err)) {
                if ($err -notmatch "Non-authoritative") { # Ignorar advertencia comun de nslookup
                    & $LogToBox -Msg "STDERR: $err" -Color "Salmon"
                }
            }

        } catch {
            & $LogToBox -Msg "Error critico al ejecutar proceso: $_" -Color "Red"
        }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        & $LogToBox -Msg "Fin del proceso." -Color "Gray"
    }

    # --- FUNCION: DIAGNOSTICO INTELIGENTE (.NET) ---
    $RunSmartDiag = {
        $consoleBox.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        & $LogToBox -Msg "INICIANDO DIAGNOSTICO INTELIGENTE" -IsHeader $true -Color "Cyan"
        
        $pingSender = New-Object System.Net.NetworkInformation.Ping
        $success = $true

        # 1. Gateway
        & $LogToBox -Msg "PASO 1: Verificando Puerta de Enlace (Router Local)..." -Color "Yellow" -IsBold $true
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
        if ($gateway) {
            try {
                $reply = $pingSender.Send($gateway, 1000)
                if ($reply.Status -eq 'Success') {
                    & $LogToBox -Msg "   [OK] Router accesible en $gateway (Latencia: $($reply.RoundtripTime) ms)" -Color "LightGreen"
                } else {
                    & $LogToBox -Msg "   [FALLO] No se recibe respuesta del Router ($gateway)." -Color "Red"
                    & $LogToBox -Msg "   -> Posible problema de cable o Wi-Fi local." -Color "Salmon"
                    $success = $false
                }
            } catch {
                & $LogToBox -Msg "   [ERROR] No se pudo hacer ping al Gateway." -Color "Red"
            }
        } else {
            & $LogToBox -Msg "   [FALLO] No se detecta Puerta de Enlace. ¿Estas conectado?" -Color "Red"
            $success = $false
        }

        # 2. Internet (IP)
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 500
        & $LogToBox -Msg "`r`nPASO 2: Verificando Salida a Internet (Ping 8.8.8.8)..." -Color "Yellow" -IsBold $true
        try {
            $reply = $pingSender.Send("8.8.8.8", 2000)
            if ($reply.Status -eq 'Success') {
                & $LogToBox -Msg "   [OK] Conexion a Internet confirmada (Latencia: $($reply.RoundtripTime) ms)" -Color "LightGreen"
            } else {
                & $LogToBox -Msg "   [FALLO] El Router responde, pero no hay Internet." -Color "Red"
                & $LogToBox -Msg "   -> Problema de tu proveedor (ISP) o del modem." -Color "Salmon"
                $success = $false
            }
        } catch {
             & $LogToBox -Msg "   [ERROR] Fallo general de ping." -Color "Red"
             $success = $false
        }

        # 3. DNS
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 500
        & $LogToBox -Msg "`r`nPASO 3: Verificando Resolucion de Nombres (DNS)..." -Color "Yellow" -IsBold $true
        try {
            $dns = [System.Net.Dns]::GetHostAddresses("google.com")
            if ($dns) {
                & $LogToBox -Msg "   [OK] DNS funciona correctamente ($($dns[0].IPAddressToString))" -Color "LightGreen"
            }
        } catch {
            & $LogToBox -Msg "   [FALLO] Internet funciona, pero el DNS falla." -Color "Red"
            & $LogToBox -Msg "   -> Recomendacion: Usa 'Limpiar Cache DNS' o cambia tus DNS a 8.8.8.8/1.1.1.1" -Color "Orange"
            $success = $false
        }

        if ($success) {
            & $LogToBox -Msg "`r`n[CONCLUSION] Tu red parece funcionar correctamente." -Color "Cyan" -IsBold $true
        } else {
            & $LogToBox -Msg "`r`n[CONCLUSION] Se detectaron problemas. Revisa los pasos en rojo." -Color "Salmon" -IsBold $true
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }

    # --- EVENTOS ---
    $btnSmartDiag.Add_Click({ & $RunSmartDiag })
    $btnIpConfig.Add_Click({ & $RunAsyncProcess -Exe "ipconfig.exe" -CmdArgs "/all" -Title "Configuracion IP" })
    $btnTrace.Add_Click({ & $RunAsyncProcess -Exe "tracert.exe" -CmdArgs "-d 8.8.8.8" -Title "Traza de Ruta" })
    $btnNslookup.Add_Click({ & $RunAsyncProcess -Exe "nslookup.exe" -CmdArgs "google.com" -Title "Prueba DNS" })
    $btnArp.Add_Click({ & $RunAsyncProcess -Exe "arp.exe" -CmdArgs "-a" -Title "Tabla ARP" })

    $btnFlush.Add_Click({ & $RunAsyncProcess -Exe "ipconfig.exe" -CmdArgs "/flushdns" -Title "Limpieza de Cache DNS" })
    $btnRenew.Add_Click({ 
        if ([System.Windows.Forms.MessageBox]::Show("Esto desconectara momentaneamente la red. ¿Seguir?", "Confirmar", 'YesNo') -eq 'Yes') {
            & $RunAsyncProcess -Exe "cmd.exe" -CmdArgs "/c ipconfig /release && ipconfig /renew" -Title "Renovacion de IP" 
        }
    })

    $btnReset.Add_Click({
        if ([System.Windows.Forms.MessageBox]::Show("ADVERTENCIA: Esto reiniciara Winsock y la pila TCP/IP.\nEs necesario REINICIAR el PC despues.\n\n¿Continuar?", "Reset Critico", 'YesNo', 'Warning') -eq 'Yes') {
            & $RunAsyncProcess -Exe "cmd.exe" -CmdArgs "/c netsh winsock reset && netsh int ip reset" -Title "Reset Completo de Red"
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

    # --- TAREA DE FONDO: IP PUBLICA Y ESTADO ---
    $form.Add_Shown({
        & $LogToBox -Msg "Bienvenido. Selecciona una opcion para comenzar." -Color "Gray"

        # Check simple inicial
        $ping = New-Object System.Net.NetworkInformation.Ping
        try {
            if (($ping.Send("8.8.8.8", 1000)).Status -eq 'Success') {
                $lblConnStatus.Text = "CONECTADO"
                $lblConnStatus.ForeColor = [System.Drawing.Color]::LightGreen

                # Intentar obtener IP Publica (Async dummy via job logic simplificada visualmente)
                try {
                    $web = Invoke-RestMethod -Uri "http://ip-api.com/json" -TimeoutSec 3 -ErrorAction Stop
                    $lblPublicIP.Text = "IP: $($web.query) ($($web.isp))"
                } catch {
                    $lblPublicIP.Text = "IP Pub: (No disponible)"
                }
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

# ===================================================================
# --- MoDULO DE Gestor de Claves Wi-Fi ---
# ===================================================================
function Show-WifiManager {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Claves Wi-Fi"
    $form.Size = New-Object System.Drawing.Size(980, 700)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Redes Wi-Fi Guardadas"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(380, 23)
    $lblSearch.AutoSize = $true
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(430, 20)
    $txtSearch.Width = 250
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(700, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(100, 26)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(920, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $true
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion grafica
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "SSID (Nombre de Red)"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 250
    $grid.Columns.Add($colName) | Out-Null

    $colAuth = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAuth.HeaderText = "Autenticacion"
    $colAuth.Name = "Auth"
    $colAuth.ReadOnly = $true
    $colAuth.Width = 150
    $grid.Columns.Add($colAuth) | Out-Null

    $colPass = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPass.HeaderText = "Contrasena (Clave)"
    $colPass.Name = "Password"
    $colPass.ReadOnly = $true
    $colPass.Width = 250
    $grid.Columns.Add($colPass) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. BARRA DE ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 490)
    $progressBar.Size = New-Object System.Drawing.Size(920, 20)
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 520)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    # --- 5. BOTONES DE ACCION ---
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 560)
    $btnSelectAll.Size = New-Object System.Drawing.Size(100, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # Boton EXPORTAR
    $btnBackup = New-Object System.Windows.Forms.Button
    $btnBackup.Text = "EXPORTAR (Backup)"
    $btnBackup.Location = New-Object System.Drawing.Point(140, 550)
    $btnBackup.Size = New-Object System.Drawing.Size(260, 50)
    $btnBackup.BackColor = [System.Drawing.Color]::SeaGreen
    $btnBackup.ForeColor = [System.Drawing.Color]::White
    $btnBackup.FlatStyle = "Flat"
    $btnBackup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnBackup)

    # Boton RESTAURAR
    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "RESTAURAR XML"
    $btnRestore.Location = New-Object System.Drawing.Point(410, 550)
    $btnRestore.Size = New-Object System.Drawing.Size(260, 50)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestore)

    # Boton ELIMINAR (Nuevo)
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR SELECCIONADOS"
    $btnDelete.Location = New-Object System.Drawing.Point(680, 550)
    $btnDelete.Size = New-Object System.Drawing.Size(260, 50)
    $btnDelete.BackColor = [System.Drawing.Color]::Crimson
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    # --- VARIABLES Y CACHE ---
    $script:WifiCache = @{}

    # --- LOGICA: ESCANEAR Y LEER PASSWORDS ---
    $ScanWifi = {
        $grid.Rows.Clear()
        $script:WifiCache.Clear()
        $lblStatus.Text = "Recuperando perfiles Wi-Fi y desencriptando claves..."
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        [System.Windows.Forms.Application]::DoEvents()

        $tempDir = Join-Path $env:TEMP "AegisWifiTemp"
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

        try {
            $proc = Start-Process -FilePath "netsh.exe" -ArgumentList "wlan export profile key=clear folder=`"$tempDir`"" -WindowStyle Hidden -PassThru -Wait
            
            $xmlFiles = Get-ChildItem -Path $tempDir -Filter "*.xml"
            foreach ($file in $xmlFiles) {
                try {
                    [xml]$xmlContent = Get-Content $file.FullName
                    $ssid = $xmlContent.WLANProfile.name
                    $auth = $xmlContent.WLANProfile.MSM.security.authEncryption.authentication
                    $pass = $xmlContent.WLANProfile.MSM.security.sharedKey.keyMaterial
                    if ([string]::IsNullOrWhiteSpace($pass)) { $pass = "(Sin clave / Enterprise)" }

                    $script:WifiCache[$ssid] = [PSCustomObject]@{
                        Name = $ssid
                        Auth = $auth
                        Password = $pass
                    }
                } catch {}
            }
        } catch {
            $lblStatus.Text = "Error al leer perfiles Wi-Fi."
        } finally {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Poblar Grid
        $searchText = $txtSearch.Text.Trim()
        foreach ($key in $script:WifiCache.Keys) {
            $item = $script:WifiCache[$key]
            if ([string]::IsNullOrWhiteSpace($searchText) -or $item.Name -match $searchText) {
                $rowId = $grid.Rows.Add()
                $row = $grid.Rows[$rowId]
                $row.Cells["Name"].Value = $item.Name
                $row.Cells["Auth"].Value = $item.Auth
                $row.Cells["Password"].Value = $item.Password
                
                if ($item.Password -ne "(Sin clave / Enterprise)") {
                    $row.Cells["Password"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                } else {
                    $row.Cells["Password"].Style.ForeColor = [System.Drawing.Color]::Silver
                }
            }
        }

        $lblStatus.Text = "Se encontraron $($grid.Rows.Count) redes Wi-Fi."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $grid.ClearSelection()
    }

    # --- EVENTOS ---
    
    $form.Add_Shown({ & $ScanWifi })
    $btnRefresh.Add_Click({ & $ScanWifi })
    $txtSearch.Add_KeyUp({ & $ScanWifi })

    # Evento: Clic en celda
    $grid.Add_CellClick({
        param($sender, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -ne 0) {
            $row = $grid.Rows[$e.RowIndex]
            $val = $row.Cells["Check"].Value
            if ($val -eq $null) { $val = $false }
            $row.Cells["Check"].Value = -not $val
        }
    })

    # Evento: Barra Espaciadora
    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            $e.SuppressKeyPress = $true 
            foreach ($row in $sender.SelectedRows) {
                $curr = $row.Cells["Check"].Value
                if ($curr -eq $null) { $curr = $false }
                $row.Cells["Check"].Value = -not $curr
            }
        }
    })

    $btnSelectAll.Add_Click({
        foreach ($row in $grid.Rows) { 
            $curr = $row.Cells["Check"].Value
            if ($curr -eq $null) { $curr = $false }
            $row.Cells["Check"].Value = -not $curr 
        }
    })

    # 3. BACKUP (EXPORTAR)
    $btnBackup.Add_Click({
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) { $targets += $row.Cells["Name"].Value }
        }

        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona al menos una red.", "Aviso", 0, 48); return }

        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Carpeta destino para el backup"
        if ($dialog.ShowDialog() -ne 'OK') { return }
        $destPath = $dialog.SelectedPath

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0
        $progressBar.Maximum = $targets.Count
        $count = 0

        foreach ($ssid in $targets) {
            $count++
            $lblStatus.Text = "Exportando ($count/$($targets.Count)): $ssid..."
            $progressBar.Value = $count
            [System.Windows.Forms.Application]::DoEvents()
            $cmd = "netsh wlan export profile name=`"$ssid`" key=clear folder=`"$destPath`""
            Start-Process "cmd.exe" -ArgumentList "/c $cmd" -WindowStyle Hidden -Wait
        }

        $lblStatus.Text = "Proceso finalizado."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("Backup completado en: $destPath", "Exito", 0, 64)
    })

    # 4. RESTORE (IMPORTAR)
    $btnRestore.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = "Selecciona archivos XML Wi-Fi"
        $dialog.Filter = "Archivos XML (*.xml)|*.xml"
        $dialog.Multiselect = $true
        if ($dialog.ShowDialog() -ne 'OK') { return }
        $files = $dialog.FileNames

        if ($files.Count -eq 0) { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0
        $progressBar.Maximum = $files.Count
        $count = 0
        
        foreach ($file in $files) {
            $count++
            $fName = [System.IO.Path]::GetFileName($file)
            $lblStatus.Text = "Importando: $fName..."
            $progressBar.Value = $count
            [System.Windows.Forms.Application]::DoEvents()
            $cmd = "netsh wlan add profile filename=`"$file`" user=all"
            Start-Process "cmd.exe" -ArgumentList "/c $cmd" -WindowStyle Hidden -Wait
        }

        $lblStatus.Text = "Restauracion completada."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("Importados $($files.Count) perfiles.", "Exito", 0, 64)
        & $ScanWifi
    })

    # 5. ELIMINAR
    $btnDelete.Add_Click({
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) { $targets += $row.Cells["Name"].Value }
        }

        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona una red para eliminar.", "Aviso", 0, 48); return }

        if ([System.Windows.Forms.MessageBox]::Show("¿Eliminar $($targets.Count) redes Wi-Fi del sistema?\n\nEsta accion olvidara las contrasenas y no se conectara automaticamente.", "Confirmar Eliminacion", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0
        $progressBar.Maximum = $targets.Count
        $count = 0

        foreach ($ssid in $targets) {
            $count++
            $lblStatus.Text = "Eliminando: $ssid..."
            $progressBar.Value = $count
            [System.Windows.Forms.Application]::DoEvents()
            
            # Comando de borrado nativo
            $cmd = "netsh wlan delete profile name=`"$ssid`""
            Start-Process "cmd.exe" -ArgumentList "/c $cmd" -WindowStyle Hidden -Wait
        }

        $lblStatus.Text = "Eliminacion completada."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("Redes eliminadas.", "Exito", 0, 64)
        
        # Recargar lista
        & $ScanWifi
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
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
                    # Si $event.Message es $null, usamos un marcador de posicion
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
=== RESULTADOS DEL ANALISIS DE EVENTOS ===
Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Sistema: $($env:COMPUTERNAME)
Numero total de eventos: $($Events.Count)
============================================================

"@
    
    $index = 1
    foreach ($event in $Events) {
        $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        $source = $event.ProviderName
        $id = $event.Id
        $level = switch ($event.Level) {
            1 { "CRiTICO" }
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
    
    # Exportar a CSV (para analisis de datos)
    $eventsForCsv = $Events | Select-Object @{
        Name = "FechaHora"
        Expression = { $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") }
    }, @{
        Name = "Nivel"
        Expression = { 
            switch ($_.Level) {
                1 { "CRiTICO" }
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
    Write-Host "   - CSV (analisis): $csvPath"
    
    $openChoice = Read-Host "`n¿Deseas abrir la carpeta con los resultados? (S/N)"
    if ($openChoice.ToUpper() -eq 'S') {
        Start-Process $diagDir
    }
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
        $friendlyEdition = "Edicion Desconocida"
        $fullBuildString = "Build Desconocida"
        $osArch = "Arquitectura Desconocida"

        # Intentamos obtener arquitectura de forma segura
        try { 
            $osArch = (Get-ComputerInfo -ErrorAction Stop).OsArchitecture 
        } catch { 
            $osArch = $env:PROCESSOR_ARCHITECTURE 
        }

        # Validacion de datos del registro
        if ($winVerInfo) {
            $buildNumber = 0
            if ($winVerInfo.CurrentBuildNumber) { 
                $buildNumber = [int]$winVerInfo.CurrentBuildNumber 
            }
            
            $ubrNumber = if ($winVerInfo.UBR) { $winVerInfo.UBR } else { "0" }
            $fullBuildString = "$buildNumber.$ubrNumber"
            
            # Logica de nombre base
            $baseProductName = "Windows 10"
            if ($buildNumber -ge 22000) { $baseProductName = "Windows 11" }

            # Logica de Edicion
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
        # Fallback de emergencia en caso de error critico
        Write-Warning "No se pudo detectar la version detallada de Windows. Usando informacion basica."
        return "Windows Detectado (Error al leer version detallada)"
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
    Write-Host ""
    Write-Host "   [V] Volver al menu anterior" -ForegroundColor Red
    Write-Host ""

    $formatChoice = Read-Host "Elige una opcion"

    if ($formatChoice.ToUpper() -eq 'V') {
        return
    }
	
    if ($formatChoice -notin @('1','2','3')) {
        Write-Warning "Opcion no valida."
        Start-Sleep -Seconds 1
        return
    }

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
            
            # --- SECCION: SISTEMA Y CPU ---
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
            
            # --- SECCION: HARDWARE ---
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

            # --- SECCION: SEGURIDAD
            $reportContent += ""
            $reportContent += "=== ESTADO DE SEGURIDAD ==="
            $reportContent += ""
            $reportContent += "Antivirus : $(if ($inventoryData.Security.Antivirus) { ($inventoryData.Security.Antivirus.displayName -join ', ') } else { 'No Detectado' })"
            $reportContent += "Firewall  : $(($inventoryData.Security.Firewall | ForEach-Object { "$($_.Name): $(if($_.Enabled){'Activado'}else{'Desactivado'})" }) -join ' | ')"
            $reportContent += "BitLocker : $($inventoryData.Security.BitLocker)"

            # --- SECCION: DISCOS
            $reportContent += ""
            $reportContent += "=== DISCOS ==="
            $reportContent += ($inventoryData.Disks | Format-Table | Out-String).TrimEnd()
            
            # --- SECCION: SALUD DISCOS
            $reportContent += ""
            $reportContent += "=== DIAGNOSTICO DE SALUD DE DISCOS (S.M.A.R.T.) ==="
            $reportContent += ($inventoryData.PhysicalDisks | Format-Table | Out-String).TrimEnd()

            # --- SECCION: RED
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

            # --- SECCION: ACTUALIZACIONES
            $reportContent += ""
            $reportContent += "=== ULTIMAS ACTUALIZACIONES INSTALADAS ==="
            $reportContent += ($inventoryData.OSConfig.Hotfixes | Format-Table -Wrap | Out-String).TrimEnd()

            # --- SECCION: SOFTWARE
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
    }

    Write-Host "`n[OK] Reporte(s) generado(s) exitosamente en: '$reportPath'" -ForegroundColor Green
    if ($formatChoice -ne '3') { 
        Start-Process $reportPath
    } else {
        Start-Process $reportDir
    }
    Read-Host "`nPresiona Enter para volver..."
}

# ===================================================================
# --- MODULO DE GESTION DE DRIVERS ---
# ===================================================================
function Show-DriverMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Administrador de Controladores (Drivers)"
    $form.Size = New-Object System.Drawing.Size(1050, 750)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR (FILTROS) ---
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "Repositorio de Drivers (Driver Store)"
    $lblInfo.Location = New-Object System.Drawing.Point(20, 15)
    $lblInfo.AutoSize = $true
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblInfo)

    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Filtrar:"
    $lblSearch.Location = New-Object System.Drawing.Point(350, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(410, 20)
    $txtSearch.Width = 300
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $chkShowMS = New-Object System.Windows.Forms.CheckBox
    $chkShowMS.Text = "Mostrar Microsoft"
    $chkShowMS.Location = New-Object System.Drawing.Point(730, 20)
    $chkShowMS.AutoSize = $true
    $chkShowMS.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($chkShowMS)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(880, 15)
    $btnRefresh.Size = New-Object System.Drawing.Size(130, 30)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(990, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $true
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion grafica
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colInf = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colInf.HeaderText = "Archivo INF"
    $colInf.Name = "InfName"
    $colInf.Width = 100
    $colInf.ReadOnly = $true
    $grid.Columns.Add($colInf) | Out-Null

    $colProv = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colProv.HeaderText = "Fabricante (Provider)"
    $colProv.Name = "Provider"
    $colProv.Width = 200
    $colProv.ReadOnly = $true
    $grid.Columns.Add($colProv) | Out-Null

    $colClass = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colClass.HeaderText = "Clase de Dispositivo"
    $colClass.Name = "Class"
    $colClass.Width = 150
    $colClass.ReadOnly = $true
    $grid.Columns.Add($colClass) | Out-Null

    $colVer = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colVer.HeaderText = "Version"
    $colVer.Name = "Version"
    $colVer.Width = 100
    $colVer.ReadOnly = $true
    $grid.Columns.Add($colVer) | Out-Null

    $colDate = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDate.HeaderText = "Fecha"
    $colDate.Name = "Date"
    $colDate.Width = 100
    $colDate.ReadOnly = $true
    $grid.Columns.Add($colDate) | Out-Null

    # Columna oculta para ID objeto
    $colObj = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colObj.Name = "ObjID"
    $colObj.Visible = $false
    $grid.Columns.Add($colObj) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DETALLES ---
    $grpDet = New-Object System.Windows.Forms.GroupBox
    $grpDet.Text = "Informacion Detallada"
    $grpDet.ForeColor = [System.Drawing.Color]::Silver
    $grpDet.Location = New-Object System.Drawing.Point(20, 490)
    $grpDet.Size = New-Object System.Drawing.Size(990, 70)
    $form.Controls.Add($grpDet)

    $lblDetailPath = New-Object System.Windows.Forms.Label
    $lblDetailPath.Text = "Selecciona un driver para ver detalles..."
    $lblDetailPath.Location = New-Object System.Drawing.Point(15, 25)
    $lblDetailPath.AutoSize = $true
    $lblDetailPath.ForeColor = [System.Drawing.Color]::Cyan
    $grpDet.Controls.Add($lblDetailPath)

    # --- 5. BARRA DE ESTADO ---
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 570)
    $progressBar.Size = New-Object System.Drawing.Size(990, 10)
    $form.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Listo."
    $lblStatus.Location = New-Object System.Drawing.Point(20, 590)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    $form.Controls.Add($lblStatus)

    # --- 6. BOTONES DE ACCION ---
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 620)
    $btnSelectAll.Size = New-Object System.Drawing.Size(60, 40)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $btnBackup = New-Object System.Windows.Forms.Button
    $btnBackup.Text = "EXPORTAR (Backup)"
    $btnBackup.Location = New-Object System.Drawing.Point(90, 620)
    $btnBackup.Size = New-Object System.Drawing.Size(250, 40)
    $btnBackup.BackColor = [System.Drawing.Color]::SeaGreen
    $btnBackup.ForeColor = [System.Drawing.Color]::White
    $btnBackup.FlatStyle = "Flat"
    $btnBackup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnBackup)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "INSTALAR (Restaurar)"
    $btnRestore.Location = New-Object System.Drawing.Point(350, 620)
    $btnRestore.Size = New-Object System.Drawing.Size(250, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRestore)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR (Limpiar)"
    $btnDelete.Location = New-Object System.Drawing.Point(610, 620)
    $btnDelete.Size = New-Object System.Drawing.Size(200, 40)
    $btnDelete.BackColor = [System.Drawing.Color]::Maroon
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    # Checkbox para Forzar Instalacion
    $chkForce = New-Object System.Windows.Forms.CheckBox
    $chkForce.Text = "Forzar accion (/force)"
    $chkForce.Location = New-Object System.Drawing.Point(830, 620)
    $chkForce.Width = 150
    $chkForce.ForeColor = [System.Drawing.Color]::Salmon
    $form.Controls.Add($chkForce)

    # --- VARIABLES Y CACHE ---
    $script:DriverCache = @()

    # --- LOGICA: RENDERIZAR GRID (Rapido) ---
    $RenderGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        
        $searchTerm = $txtSearch.Text.Trim()
        
        $filtered = $script:DriverCache
        
        # Filtro de Busqueda
        if (-not [string]::IsNullOrWhiteSpace($searchTerm)) {
            $filtered = $filtered | Where-Object { 
                $_.ProviderName -match $searchTerm -or 
                $_.ClassName -match $searchTerm -or 
                $_.Driver -match $searchTerm 
            }
        }

        # Filtro de Microsoft
        if (-not $chkShowMS.Checked) {
            $filtered = $filtered | Where-Object { $_.ProviderName -notmatch "^Microsoft" }
        }

        foreach ($d in $filtered) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["InfName"].Value = $d.Driver
            $row.Cells["Provider"].Value = $d.ProviderName
            $row.Cells["Class"].Value = $d.ClassName
            $row.Cells["Version"].Value = $d.Version
            $row.Cells["Date"].Value = try { $d.Date.ToString("yyyy-MM-dd") } catch { $d.Date }
            
            # Guardamos el objeto real en una columna oculta o en el Tag para uso posterior
            $row.Tag = $d 

            # Colorear Microsoft en gris si se muestran
            if ($d.ProviderName -match "^Microsoft") {
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
            }
        }
        $grid.ResumeLayout()
        $grid.ClearSelection()
    }

    # --- LOGICA: ESCANEAR SISTEMA (Lento) ---
    $ScanDrivers = {
        $lblStatus.Text = "Escaneando Driver Store... (Esto puede tardar)"
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $script:DriverCache = @(Get-WindowsDriver -Online -ErrorAction Stop)
            $lblStatus.Text = "Drivers cargados: $($script:DriverCache.Count)"
            $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
        } catch {
            $lblStatus.Text = "Error al leer drivers: $_"
            $lblStatus.ForeColor = [System.Drawing.Color]::Salmon
            $script:DriverCache = @()
        }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        & $RenderGrid
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $ScanDrivers })
    $btnRefresh.Add_Click({ & $ScanDrivers })
    $txtSearch.Add_KeyUp({ & $RenderGrid })
    $chkShowMS.Add_CheckedChanged({ & $RenderGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $d = $grid.SelectedRows[0].Tag
            $lblDetailPath.Text = "Origen: $($d.OriginalFileName) | Firmado por: $($d.SignerName)"
        }
    })

    # Evento de checkbox en celda y Barra Espaciadora
    $grid.Add_CellClick({ param($s,$e) if($e.RowIndex -ge 0 -and $e.ColumnIndex -ne 0){ $r=$grid.Rows[$e.RowIndex]; $r.Cells[0].Value = -not $r.Cells[0].Value } })
    $grid.Add_KeyDown({ param($s,$e) if($e.KeyCode -eq 'Space'){ $e.SuppressKeyPress=$true; foreach($r in $s.SelectedRows){ $r.Cells[0].Value = -not $r.Cells[0].Value } } })
    $btnSelectAll.Add_Click({ foreach($r in $grid.Rows){ $r.Cells[0].Value = -not $r.Cells[0].Value } })

    # --- ACCION: BACKUP ---
    $btnBackup.Add_Click({
        $targets = @($grid.Rows | Where-Object { $_.Cells[0].Value } | ForEach-Object { $_.Cells["InfName"].Value })
        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona drivers.", "Aviso", 0, 48); return }

        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog; $dlg.Description = "Carpeta de destino"
        if ($dlg.ShowDialog() -ne 'OK') { return }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0; $progressBar.Maximum = $targets.Count; $cnt = 0; $errs = 0

        foreach ($inf in $targets) {
            $cnt++; $progressBar.Value = $cnt
            $lblStatus.Text = "Exportando $inf..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                $p = Start-Process "pnputil.exe" -ArgumentList "/export-driver `"$inf`" `"$($dlg.SelectedPath)`"" -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -ne 0) { $errs++ }
            } catch { $errs++ }
        }
        
        $lblStatus.Text = "Backup finalizado."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("Backup completado. Errores: $errs", "Info", 0, 64)
    })

    # --- ACCION: DELETE (NUEVO) ---
    $btnDelete.Add_Click({
        $targets = @($grid.Rows | Where-Object { $_.Cells[0].Value } | ForEach-Object { $_.Cells["InfName"].Value })
        if ($targets.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Selecciona drivers para eliminar.", "Aviso", 0, 48); return }

        if ([System.Windows.Forms.MessageBox]::Show("PELIGRO: Vas a eliminar $($targets.Count) drivers del almacén del sistema.`n`nSi eliminas un driver en uso, el dispositivo dejará de funcionar.`n¿Estás seguro?", "Confirmar Eliminación", 4, 48) -ne 'Yes') { return }

        if ($chkForce.Checked) {
             if ([System.Windows.Forms.MessageBox]::Show("HAS MARCADO 'FORZAR'.`nEsto eliminará el driver incluso si está en uso.`n¿Confirmación final?", "PELIGRO EXTREMO", 4, 16) -ne 'Yes') { return }
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0; $progressBar.Maximum = $targets.Count; $cnt = 0; $errs = 0
        $argsBase = "/delete-driver"
        if ($chkForce.Checked) { $argsBase += " /force" }

        foreach ($inf in $targets) {
            $cnt++; $progressBar.Value = $cnt
            $lblStatus.Text = "Eliminando $inf..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                $p = Start-Process "pnputil.exe" -ArgumentList "$argsBase `"$inf`"" -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -ne 0) { $errs++ }
            } catch { $errs++ }
        }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("Eliminación completada. Errores (Archivos en uso): $errs", "Info", 0, 64)
        & $ScanDrivers # Recargar lista
    })

    # --- ACCION: RESTORE ---
    $btnRestore.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = "Selecciona archivos .INF"; $dlg.Filter = "Drivers (*.inf)|*.inf"; $dlg.Multiselect = $true
        if ($dlg.ShowDialog() -ne 'OK') { return }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $progressBar.Value = 0; $progressBar.Maximum = $dlg.FileNames.Count; $cnt = 0; $errs = 0
        
        $argsBase = "/add-driver /install"
        if ($chkForce.Checked) { $argsBase += " /force" }

        foreach ($file in $dlg.FileNames) {
            $cnt++; $progressBar.Value = $cnt
            $fname = [System.IO.Path]::GetFileName($file)
            $lblStatus.Text = "Instalando $fname..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                $p = Start-Process "pnputil.exe" -ArgumentList "$argsBase `"$file`"" -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -ne 0) { $errs++ }
            } catch { $errs++ }
        }
        
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("Instalación completada. Errores: $errs", "Info", 0, 64)
        & $ScanDrivers
    })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
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
            $dialog.Multiselect = $true 
            if ($dialog.ShowDialog() -eq 'OK') {
                return $dialog.FileNames 
            }
        }
    } catch {
        Write-Error "No se pudo mostrar el dialogo. Error: $($_.Exception.Message)"
    }
    
    return $null 
}

function Invoke-BackupRobocopyVerification {
    [CmdletBinding()]
    param($logFile, $baseRoboCopyArgs, $backupType, $sourcePaths, $destinationPath, $Mode)

    Write-Host "`n[+] Iniciando comprobacion de integridad (RAPIDA /L)..." -ForegroundColor Yellow
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
            Write-Host "`n[+] Verificando '$folderName'..." -ForegroundColor Gray
            $currentArgs = @("`"$sourceFolder`"", "`"$destinationFolder`"") + $folderArgs + $logArg
            Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow
        }
    }
    Write-Host "[OK] Verificacion finalizada. Revisa el log." -ForegroundColor Green
}

function Invoke-BackupHashVerification {
    [CmdletBinding()]
    param($sourcePaths, $destinationPath, $backupType, $logFile)
    
    Write-Host "`n[+] Iniciando comprobacion profunda por Hash (SHA256)..." -ForegroundColor Yellow
    
    $sourceFiles = @()
    if ($backupType -eq 'Files') {
        $sourceFiles = $sourcePaths | Get-Item
    } else {
        $sourcePaths | ForEach-Object { $sourceFiles += Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue }
    }

    if ($sourceFiles.Count -eq 0) { Write-Warning "Sin archivos para verificar."; return }

    $totalFiles = $sourceFiles.Count
    $checkedFiles = 0; $mismatchedFiles = 0; $missingFiles = 0
    $details = [System.Collections.Generic.List[string]]::new()

    foreach ($sourceFile in $sourceFiles) {
        $checkedFiles++
        # Progreso en la misma linea para no saturar
        if ($checkedFiles % 5 -eq 0) { 
            Write-Progress -Activity "Calculando Hash (SHA256)" -Status "Archivo $checkedFiles de $totalFiles" -PercentComplete (($checkedFiles / $totalFiles) * 100)
        }
        
        $destinationFile = ""
        if ($backupType -eq 'Folders') {
             $baseSourceFolder = ($sourcePaths | Where-Object { $sourceFile.FullName.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object Length -Descending | Select-Object -First 1)
             if ($baseSourceFolder) {
                 $relativePath = $sourceFile.FullName.Substring($baseSourceFolder.Length)
                 $destinationFile = Join-Path (Join-Path $destinationPath (Split-Path $baseSourceFolder -Leaf)) $relativePath
             }
        } else { $destinationFile = Join-Path $destinationPath $sourceFile.Name }
        
        if (Test-Path $destinationFile) {
            try {
                $h1 = (Get-FileHash $sourceFile.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                $h2 = (Get-FileHash $destinationFile -Algorithm SHA256 -ErrorAction Stop).Hash
                
                if ($h1 -ne $h2) { 
                    $mismatchedFiles++
                    Write-Host "`n[!] DISCREPANCIA: $($sourceFile.Name)" -ForegroundColor Red
                    $details.Add("DIFF: $($sourceFile.FullName)") 
                }
            } catch { 
                # Ignorar desktop.ini bloqueados, es normal
                if ($sourceFile.Name -ne "desktop.ini") {
                    $details.Add("ERROR LEER: $($sourceFile.Name)") 
                }
            }
        } else { 
            $missingFiles++
            Write-Host "`n[!] FALTANTE: $($sourceFile.Name)" -ForegroundColor Red
            $details.Add("FALTANTE: $destinationFile") 
        }
    }
    Write-Progress -Activity "Calculando Hash (SHA256)" -Completed
    
    $logTxt = "`r`n--- RESUMEN HASH ---`r`nTotal: $totalFiles | Diferentes: $mismatchedFiles | Faltan: $missingFiles`r`n"
    if ($details.Count -gt 0) { $logTxt += ($details | Out-String) }
    $logTxt | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    if ($mismatchedFiles -eq 0 -and $missingFiles -eq 0) { 
        Write-Host "[OK] Integridad Hash Correcta." -ForegroundColor Green 
    } else { 
        # Lanzamos una excepcion controlada para que el modulo principal sepa que fallo
        throw "HASH_FAILURE" 
    }
}

function Invoke-UserDataBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Copy', 'Mirror', 'Move')] # <--- AGREGADO 'Move'
        [string]$Mode,

        [string[]]$CustomSourcePath
    )

    # 1. Determinamos el origen
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
        
        # Obtener ruta real de Descargas
		$regPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
        
        # Helper para leer registro de forma segura
        function Get-UserFolder { param($Name, $Guid, $Default) 
            try {
                $val = (Get-ItemProperty -Path $regPath -Name $Guid -ErrorAction SilentlyContinue).$Guid
                if (-not $val) { $val = (Get-ItemProperty -Path $regPath -Name $Name -ErrorAction SilentlyContinue).$Name }
                if ($val) { return [System.Environment]::ExpandEnvironmentVariables($val) }
                return [System.Environment]::GetFolderPath($Default)
            } catch { return [System.Environment]::GetFolderPath($Default) }
        }

        # Candidatos para el menu Checkbox
        $candidates = @(
            [PSCustomObject]@{ Id=1; Name="Escritorio"; Path=(Get-UserFolder -Name 'Desktop' -Default 'Desktop'); Selected=$true },
            [PSCustomObject]@{ Id=2; Name="Documentos"; Path=(Get-UserFolder -Name 'Personal' -Default 'MyDocuments'); Selected=$true },
            [PSCustomObject]@{ Id=3; Name="Imagenes";   Path=(Get-UserFolder -Name 'My Pictures' -Default 'MyPictures'); Selected=$true },
            [PSCustomObject]@{ Id=4; Name="Musica";     Path=(Get-UserFolder -Name 'My Music' -Default 'MyMusic'); Selected=$true },
            [PSCustomObject]@{ Id=5; Name="Videos";     Path=(Get-UserFolder -Name 'My Video' -Default 'MyVideos'); Selected=$true },
            [PSCustomObject]@{ Id=6; Name="Descargas";  Path=(Get-UserFolder -Guid '{374DE290-123F-4565-9164-39C4925E467B}' -Default 'UserProfile') + "\Downloads"; Selected=$true }
        )

        # --- MENU INTERACTIVO CHECKBOX (CLI) ---
        $selectionDone = $false
        do {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "   SELECCION DE CARPETAS A RESPALDAR      " -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host " Marca o desmarca las carpetas usando su numero."
            Write-Host ""

            foreach ($item in $candidates) {
                if ($item.Selected) { Write-Host "   [$($item.Id)] [X] $($item.Name)" -ForegroundColor Green }
                else { Write-Host "   [$($item.Id)] [ ] $($item.Name)" -ForegroundColor Gray }
            }
            Write-Host ""
            Write-Host "   [C] CONTINUAR con la seleccion actual" -ForegroundColor Yellow
            Write-Host "   [X] CANCELAR operacion" -ForegroundColor Red
            Write-Host ""
            
            $inputKey = Read-Host " Elige una opcion"
            
            if ($inputKey.ToUpper() -eq 'C') { $selectionDone = $true }
            elseif ($inputKey.ToUpper() -eq 'X') { Write-Host "Cancelado."; Start-Sleep -Seconds 1; return }
            else {
                if ($inputKey -match '^\d+$') {
                    $id = [int]$inputKey
                    $target = $candidates | Where-Object { $_.Id -eq $id }
                    if ($target) { $target.Selected = -not $target.Selected }
                }
            }
        } until ($selectionDone)

        $sourcePaths = $candidates | Where-Object { $_.Selected -eq $true -and (Test-Path $_.Path) } | Select-Object -ExpandProperty Path

        if ($sourcePaths.Count -eq 0) {
            Write-Warning "No seleccionaste ninguna carpeta. Volviendo..."
            Start-Sleep -Seconds 2
            return
        }
    }
    
    # 2. Solicitamos destino
    Write-Host "`n[+] Por favor, selecciona la carpeta de destino para el respaldo..." -ForegroundColor Yellow
    $destinationPath = Select-PathDialog -DialogType 'Folder' -Title "Paso 2: Elige la Carpeta de Destino"
    
    if ([string]::IsNullOrWhiteSpace($destinationPath)) {
        Write-Warning "No se selecciono destino. Cancelado." ; Start-Sleep -Seconds 2; return
    }

    # --- VALIDACIONES ---
    # A) Validar Bucle Infinito
	$destFull = (Get-Item -Path $destinationPath).FullName.TrimEnd('\')
    foreach ($src in $sourcePaths) {
        if ($backupType -eq 'Folders') {
            $srcFull = (Get-Item -Path $src).FullName.TrimEnd('\')
            if ($destFull.StartsWith($srcFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Error "`n[ERROR CRITICO] El destino esta DENTRO del origen."
                Write-Error "Esto causaria un bucle infinito que llenaria el disco."
                Read-Host "Operacion abortada. Presiona Enter..."; return
            }
        }
    }

    # B) Validar Unidad Idéntica
    try {
        $srcDrive = Split-Path $sourcePaths[0] -Qualifier -ErrorAction SilentlyContinue
        $destDrive = Split-Path $destinationPath -Qualifier -ErrorAction SilentlyContinue
        
        if ($srcDrive -and $destDrive -and ($srcDrive -eq $destDrive)) {
            Write-Warning "AVISO: Origen y Destino estan en la misma unidad fisica ($srcDrive)."
            if ((Read-Host "¿Estas seguro de que deseas continuar? (S/N)").ToUpper() -ne 'S') { return }
        }
    } catch {}
    
    # 3. Calculo de espacio
	Clear-Host
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
    } catch { Write-Warning "Calculo aproximado." }
    
    $destDriveLetter = Split-Path $destinationPath -Qualifier
    $driveInfo = Get-Volume | Where-Object { ($_.DriveLetter + ":") -eq $destDriveLetter }
    $destinationFreeSpace = if ($driveInfo) { $driveInfo.SizeRemaining } else { [long]::MaxValue }

    if ($sourceTotalSize -gt $destinationFreeSpace) {
        $neededGB = [math]::Round($sourceTotalSize / 1GB, 2)
        $freeGB = [math]::Round($destinationFreeSpace / 1GB, 2)
        Write-Host "`n[ERROR] ESPACIO INSUFICIENTE: Requieres ~$neededGB GB pero solo tienes $freeGB GB libres." -ForegroundColor Red
        Read-Host "Operacion abortada. Presiona Enter..."
        return
    }

    # 4. Configurar Robocopy
	$logDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    $logFile = Join-Path $logDir "Respaldo_Robocopy_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

    $baseRoboCopyArgs = @("/COPY:DAT", "/R:2", "/W:3", "/XJ", "/NP", "/TEE", "/B", "/J", "/MT:8")
    $excludeDirs = @("/XD", "`"$destinationPath`"", "System Volume Info", "`$RECYCLE.BIN", "AppData\Local\Temp")

    # --- ACTUALIZACIoN DE DESCRIPCIoN DE MODO ---
    $modeDescription = switch ($Mode) {
        'Mirror' { "Sincronizacion (ESPEJO - Borra en destino)" }
        'Move'   { "Mover (CORTAR y PEGAR - Borra en origen)" }
        default  { "Respaldo Incremental (Copia)" }
    }
    
    Write-Host "--- RESUMEN DE RESPALDO ---" -ForegroundColor Cyan
    Write-Host "Modo: $modeDescription"
    Write-Host "Destino: $destinationPath"
    Write-Host "Origen(es):"
    $sourcePaths | ForEach-Object { Write-Host " - $_" }

	if ($Mode -eq 'Move') {
        Write-Host "`n[ADVERTENCIA EXTREMA] Se selecciono MOVER." -ForegroundColor Red
        Write-Host "Los archivos se borraran del origen una vez copiados al destino."
        Write-Host "Asegurate de que el destino sea correcto."
    }

    Write-Host ""
    Write-Host "   [S] Iniciar Operacion"
    Write-Host "   [V] Iniciar + Verificacion Rapida (/L)"
    Write-Host "   [H] Iniciar + Verificacion Hash (LENTO)" -ForegroundColor Yellow
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

    # 6. Ejecucion
    $logArg = "/LOG+:`"$logFile`""
    Write-Log -LogLevel ACTION -Message "BACKUP: Iniciando ($Mode) en $destinationPath"

    if ($backupType -eq 'Files') {
        $filesByDirectory = $sourcePaths | Get-Item | Group-Object -Property DirectoryName
        
        # --- LoGICA MOVER ARCHIVOS ---
        $currentFileArgs = $baseRoboCopyArgs
        if ($Mode -eq 'Move') { $currentFileArgs += "/MOV" } # /MOV mueve archivos

        foreach ($group in $filesByDirectory) {
            $sourceDir = $group.Name
            $fileNames = $group.Group | ForEach-Object { "`"$($_.Name)`"" }
            $currentArgs = @("`"$sourceDir`"", "`"$destinationPath`"") + $fileNames + $currentFileArgs + $logArg
            Write-Host "Procesando archivos desde: $sourceDir" -ForegroundColor Gray
            Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow
        }
    } else {
        # --- LoGICA MOVER CARPETAS ---
        $folderArgs = $baseRoboCopyArgs
        if ($Mode -eq 'Mirror') { 
            $folderArgs += "/MIR" 
        } 
        elseif ($Mode -eq 'Move') { 
            $folderArgs += "/MOVE" # Mueve carpeta y contenido
            $folderArgs += "/E"    # Asegura subcarpetas vacias
        } 
        else { 
            $folderArgs += "/E" 
        }
        $folderArgs += $excludeDirs

        foreach ($sourceFolder in $sourcePaths) {
            $folderName = Split-Path $sourceFolder -Leaf
            $destinationFolder = Join-Path $destinationPath $folderName
            
            Write-Host "`n[ROBOCOPY] Procesando: $folderName" -ForegroundColor Cyan
            $currentArgs = @("`"$sourceFolder`"", "`"$destinationFolder`"") + $folderArgs + $logArg
            
            $proc = Start-Process "robocopy.exe" -ArgumentList $currentArgs -Wait -NoNewWindow -PassThru
            
            if ($proc.ExitCode -ge 8) {
                Write-Host "   [!] Errores detectados (Cod: $($proc.ExitCode))." -ForegroundColor Red
            } else {
                Write-Host "   -> Completado." -ForegroundColor Green
            }
        }
    }

    Write-Host "`n[FIN] Operacion finalizada." -ForegroundColor Green
    
    # 7. Verificaciones
    switch ($verificationType) {
        'Fast' {
            Invoke-BackupRobocopyVerification -logFile $logFile -baseRoboCopyArgs $baseRoboCopyArgs -backupType $backupType -sourcePaths $sourcePaths -destinationPath $destinationPath -Mode $Mode
        }
        'Deep' {
            Invoke-BackupHashVerification -sourcePaths $sourcePaths -destinationPath $destinationPath -backupType $backupType -logFile $logFile
        }
    }
    
    Write-Host "Log: $logFile"
    Read-Host "Presiona Enter para volver..."
}

# --- FUNCION: INTERFAZ DE USUARIO DEL MODULO DE RESPALDO ---
function Show-UserDataBackupMenu {
    # Funcion interna para no repetir el menu de seleccion de modo
    function Get-BackupMode {
        Write-Host ""
        Write-Host "--- Elige un modo de respaldo ---" -ForegroundColor Yellow
        Write-Host "   [1] Simple (Copiar y Actualizar)"
        Write-Host "       Copia archivos nuevos o modificados. No borra nada en el destino." -ForegroundColor Gray
        Write-Host "   [2] Sincronizacion (Espejo)"
        Write-Host "       Hace que el destino sea identico al origen. Borra archivos EXTRAS en el destino." -ForegroundColor Red
        Write-Host "   [3] Mover (Cortar y Pegar)"
        Write-Host "       Mueve los archivos al destino y los BORRA del origen. Libera espacio." -ForegroundColor Cyan
        
        $modeChoice = Read-Host "`nSelecciona el modo"
        
        switch ($modeChoice) {
            '1' { return 'Copy' }
            '2' { return 'Mirror' }
            '3' { return 'Move' }
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
# --- MoDULO DE REUBICACIoN DE CARPETAS DE USUARIO ---
# ===================================================================
function Move-UserProfileFolders {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    Write-Log -LogLevel INFO -Message "Usuario entro al Modulo de Reubicacion de Carpetas de Usuario."

    # --- UTILIDAD PARA MANTENER LA CONSOLA VISIBLE (MEJORADO) ---
    if (-not ([System.Management.Automation.PSTypeName]'Win32ConsoleUtils').Type) {
        try {
            Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32ConsoleUtils {
                [DllImport("kernel32.dll")]
                public static extern IntPtr GetConsoleWindow();
                
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                
                [DllImport("user32.dll")]
                public static extern bool SetForegroundWindow(IntPtr hWnd);

                [DllImport("user32.dll", SetLastError = true)]
                public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

                // Constantes para SetWindowPos
                public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
                public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
                public const uint SWP_NOSIZE = 0x0001;
                public const uint SWP_NOMOVE = 0x0002;
                public const uint SWP_SHOWWINDOW = 0x0040;
                
                // Constante para ShowWindow
                public const int SW_RESTORE = 9;
            }
"@ -ErrorAction Stop
        } catch { 
            # Ignorar si el tipo ya existe
        }
    }

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

    # --- MENU DE SELECCION ---
    $choice = ''
    while ($choice.ToUpper() -ne 'C' -and $choice.ToUpper() -ne 'V') {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "      Selecciona las Carpetas de Usuario a Reubicar    " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Nueva Ubicacion Base: $newBasePath" -ForegroundColor Yellow
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

    # --- CALCULO DE ESPACIO AUTOMATICO ---
    Clear-Host
	Write-Host "`n[+] Calculando espacio necesario..." -ForegroundColor Yellow
    $totalRequiredBytes = 0
    foreach ($folder in $foldersToProcess) {
        $regVal = $folderMappings[$folder.Name].RegValue
        $pathRaw = (Get-ItemProperty -Path $registryPath -Name $regVal -ErrorAction SilentlyContinue).($regVal)
        $pathExpanded = try { [Environment]::ExpandEnvironmentVariables($pathRaw) } catch { $pathRaw }
        try {
            $size = (Get-ChildItem -Path $pathExpanded -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $totalRequiredBytes += $size
        } catch {}
    }

    try {
        $destDrive = Split-Path $newBasePath -Qualifier
        $volumeInfo = Get-Volume | Where-Object { ($_.DriveLetter + ":") -eq $destDrive }
        $freeSpaceBytes = $volumeInfo.SizeRemaining
    } catch { $freeSpaceBytes = [long]::MaxValue }

    $reqGB = [math]::Round($totalRequiredBytes / 1GB, 2)
    $freeGB = [math]::Round($freeSpaceBytes / 1GB, 2)

    if ($totalRequiredBytes -gt $freeSpaceBytes) {
        Write-Host "`n[ERROR CRITICO] ESPACIO INSUFICIENTE EN DESTINO" -ForegroundColor Red
        Write-Host "Se requieren: ~$reqGB GB | Disponibles: ~$freeGB GB" -ForegroundColor White
        Read-Host "Operacion abortada. Presiona Enter..."
        return
    } else {
        Write-Host "`n[OK] Espacio suficiente verificado." -ForegroundColor Green
        Write-Host "Requerido: $reqGB GB | Disponible: $freeGB GB" -ForegroundColor Gray
    }

    # --- MENU DE ACCION ---
	Write-Host "`n--- TIPO DE ACCION ---" -ForegroundColor Cyan
    Write-Host "   [1] Mover Archivos Y Actualizar Registro (Recomendado)"
    Write-Host "   [2] Solo Actualizar Registro (Si ya moviste archivos manualmente)"
    
    $actionInput = Read-Host "`nElige opcion (1/2)"
    if ($actionInput -ne '1' -and $actionInput -ne '2') { return }
    $actionType = if ($actionInput -eq '1') { 'MoveAndRegister' } else { 'RegisterOnly' }

    $verificationMode = 'None'
    if ($actionType -eq 'MoveAndRegister') {
        Write-Host "`n--- NIVEL DE VERIFICACION ---" -ForegroundColor Yellow
        Write-Host "   [N] Ninguna (Mover directo - Mas rapido)"
        Write-Host "   [S] Simulacion (/L) - Ver que pasara antes de mover"
        Write-Host "   [H] Verificacion Hash (LENTO - Copia -> Verifica -> Borra origen)"
        
        $verifyInput = Read-Host "`nElige opcion"
        switch ($verifyInput.ToUpper()) {
            'S' { $verificationMode = 'Simulation' }
            'H' { $verificationMode = 'Hash' }
            default { $verificationMode = 'None' }
        }
    }

    if ($verificationMode -eq 'Simulation') {
        Write-Host "`n[SIMULACION] Ejecutando Robocopy /L para previsualizar..." -ForegroundColor Cyan
        foreach ($folder in $foldersToProcess) {
            $regName = $folderMappings[$folder.Name].RegValue
            $currentPath = (Get-ItemProperty -Path $registryPath -Name $regName -ErrorAction SilentlyContinue).($regName)
            $src = try { [Environment]::ExpandEnvironmentVariables($currentPath) } catch { $currentPath }
            $dest = Join-Path $newBasePath $folderMappings[$folder.Name].DefaultName
            
            Start-Process "robocopy.exe" -ArgumentList "`"$src`" `"$dest`" /L /E /NP /NJH /NJS" -Wait -PassThru -NoNewWindow
        }
        Write-Host "`nSimulacion completada. Revisa la salida arriba." -ForegroundColor Yellow
        if ((Read-Host "¿Deseas proceder con el movimiento REAL? (S/N)").ToUpper() -ne 'S') { return }
        $verificationMode = 'None' 
    }

    Write-Host ""
	Write-Warning "Cerrando aplicaciones y explorador..."
    $confirmation = Read-Host "¿Confirmar inicio? (SI/NO)"
    if ($confirmation -ne 'SI') { return }

    # --- [SEGURIDAD] CERRAR EXPLORER Y FORZAR VISIBILIDAD ---
    Write-Host "Cerrando el Explorador de Windows..." -ForegroundColor Yellow
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    
    # Esperamos un momento para que el sistema reaccione al cierre
    Start-Sleep -Seconds 1
    
    # --- [FIX CRiTICO] FORZAR LA CONSOLA AL FRENTE (TOPMOST) ---
    try {
        $hWnd = [Win32ConsoleUtils]::GetConsoleWindow()
        if ($hWnd -ne [IntPtr]::Zero) {
            # 1. Asegurar que no esté minimizada
            [Win32ConsoleUtils]::ShowWindow($hWnd, [Win32ConsoleUtils]::SW_RESTORE) 
            
            # 2. Forzar "Siempre visible" (TopMost) para que no se pierda tras el fondo
            # HWND_TOPMOST (-1) coloca la ventana sobre todas las demas no-topmost
            [Win32ConsoleUtils]::SetWindowPos($hWnd, [Win32ConsoleUtils]::HWND_TOPMOST, 0, 0, 0, 0, ([Win32ConsoleUtils]::SWP_NOMOVE -bor [Win32ConsoleUtils]::SWP_NOSIZE -bor [Win32ConsoleUtils]::SWP_SHOWWINDOW)) | Out-Null
            
            # 3. Dar foco
            [Win32ConsoleUtils]::SetForegroundWindow($hWnd) | Out-Null
            
        }
    } catch {
    }

    $globalSuccess = $true
    
    foreach ($op in $foldersToProcess) {
        $regName = $folderMappings[$op.Name].RegValue
        $rawPath = (Get-ItemProperty -Path $registryPath -Name $regName -ErrorAction SilentlyContinue).($regName)
        $srcPath = [Environment]::ExpandEnvironmentVariables($rawPath)
        
        # Validacion de existencia de origen
        if (-not (Test-Path $srcPath)) {
            Write-Warning "   [OMITIDO] La carpeta de origen no existe en disco: $srcPath"
            continue
        }

        $destPath = Join-Path $newBasePath $folderMappings[$op.Name].DefaultName

        Write-Host "`nProcesando: $($op.Name)..." -ForegroundColor Cyan

        # 1. Crear Directorio
        if (-not (Test-Path $destPath)) { New-Item -Path $destPath -ItemType Directory -Force | Out-Null }

        # 2. Mover/Copiar
        $filesMoved = $true
        if ($actionType -eq 'MoveAndRegister') {
            $logDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs"
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
            $logFile = Join-Path $logDir "Move_$($op.Name).log"

            if ($verificationMode -eq 'Hash') {
                # MODO SEGURO: Copiar -> Verificar -> Borrar
                Write-Host "   [HASH] Copiando archivos (Modo Seguro)..." -ForegroundColor Yellow
                $args = @("`"$srcPath`"", "`"$destPath`"", "/MOVE", "/E", "/COPY:DAT", "/DCOPY:T", "/MT:8", "/J", "/R:2", "/W:2", "/NP", "/LOG:`"$logFile`"")
                Start-Process "robocopy.exe" -ArgumentList $args -Wait -WindowStyle Hidden
                
                # Verificar Hash Manualmente (adaptado para renombres)
                Write-Host "   [HASH] Verificando integridad..." -ForegroundColor Yellow
                $hashError = $false
                
                try {
                    $sourceFiles = Get-ChildItem -Path $srcPath -Recurse -File -Force -ErrorAction SilentlyContinue
                    $totalCheck = $sourceFiles.Count
                    $currentCheck = 0
                    
                    foreach ($file in $sourceFiles) {
                        $currentCheck++
                        if ($currentCheck % 50 -eq 0) { Write-Progress -Activity "Verificando Hash" -Status "$currentCheck / $totalCheck" -PercentComplete (($currentCheck / $totalCheck) * 100) }
                        
                        $relativePath = $file.FullName.Substring($srcPath.Length)
                        $targetFile = Join-Path $destPath $relativePath
                        
                        if (Test-Path $targetFile) {
                            $h1 = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
                            $h2 = (Get-FileHash $targetFile -Algorithm SHA256).Hash
                            if ($h1 -ne $h2) { $hashError = $true; Write-Warning "Hash incorrecto: $($file.Name)"; break }
                        } else {
                            $hashError = $true; Write-Warning "Falta en destino: $($file.Name)"; break
                        }
                    }
                    Write-Progress -Activity "Verificando Hash" -Completed
                } catch {
                    $hashError = $true
                    Write-Warning "Error leyendo archivos para hash."
                }
                
                if (-not $hashError) {
                    Write-Host "   [HASH] Integridad OK. Eliminando origen..." -ForegroundColor Green
                    Remove-Item -Path "$srcPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Host "   [ALERTA] INTEGRIDAD FALLIDA. No se actualizara el registro." -ForegroundColor Red
                    $filesMoved = $false
                    $globalSuccess = $false
                }
            } else {
                # MODO ESTANDAR: Mover directo (/MOVE)
                Write-Host "   [MOVE] Moviendo archivos..." -ForegroundColor Gray
				$args = @("`"$srcPath`"", "`"$destPath`"", "/MOVE", "/E", "/COPY:DAT", "/DCOPY:T", "/MT:8", "/J", "/R:2", "/W:2", "/NP", "/LOG:`"$logFile`"")
                $p = Start-Process "robocopy.exe" -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
                if ($p.ExitCode -ge 8) { 
                    Write-Error "   Error Robocopy (Cod $($p.ExitCode))."
                    $filesMoved = $false
                    $globalSuccess = $false
                }
            }
        } else {
            # Solo registro: copiar desktop.ini
            $ini = Join-Path $srcPath "desktop.ini"
            if (Test-Path $ini) { Copy-Item $ini (Join-Path $destPath "desktop.ini") -Force -ErrorAction SilentlyContinue }
        }

        # 3. Registro
        if ($filesMoved) {
            try {
                Set-ItemProperty -Path $registryPath -Name $regName -Value $destPath -Type ExpandString -Force
                Write-Host "   Registro actualizado." -ForegroundColor Green
                
                # --- MAGIA DE ICONOS ---
                $srcIni = Join-Path $srcPath "desktop.ini"
                $destIni = Join-Path $destPath "desktop.ini"
                if ((Test-Path $srcIni) -and (-not (Test-Path $destIni))) {
                    Copy-Item $srcIni $destIni -Force -ErrorAction SilentlyContinue
                }
                
                if (Test-Path $destIni) { (Get-Item $destIni -Force).Attributes = 'Hidden', 'System' }
                # CRITICO: La carpeta contenedora debe ser ReadOnly
                (Get-Item $destPath -Force).Attributes = 'ReadOnly'
                
                Write-Log -LogLevel ACTION -Message "Registro actualizado para $($op.Name) -> $destPath"
            } catch {
                Write-Error "   Error actualizando registro: $_"
            }
        }
    }

    # --- [SEGURIDAD] RESTAURAR EXPLORER ---
    Write-Host "`nRestaurando escritorio..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Invoke-ExplorerRestart

    Read-Host "`nPresiona Enter para volver..."
}

# ===================================================================
# MODULO DE Gestion de Tareas Programadas de Terceros
# ===================================================================
function Show-ScheduledTasks {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. CONFIGURACION DEL FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Tareas Programadas de Terceros"
    $form.Size = New-Object System.Drawing.Size(980, 700)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL SUPERIOR ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Tareas Programadas (No Microsoft)"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(380, 23)
    $lblSearch.AutoSize = $true
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(430, 20)
    $txtSearch.Width = 250
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(700, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(100, 26)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(920, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    # Optimizacion de buffer
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Nombre de Tarea"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 250
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 100
    $grid.Columns.Add($colStatus) | Out-Null

    $colAuth = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAuth.HeaderText = "Autor"
    $colAuth.Name = "Author"
    $colAuth.ReadOnly = $true
    $colAuth.Width = 150
    $grid.Columns.Add($colAuth) | Out-Null

    $colPath = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPath.HeaderText = "Ruta Interna (TaskPath)"
    $colPath.Name = "Path"
    $colPath.ReadOnly = $true
    $colPath.Width = 200
    $grid.Columns.Add($colPath) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DE DETALLES ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Detalles de Ejecucion"
    $grpDesc.ForeColor = [System.Drawing.Color]::LightGray
    $grpDesc.Location = New-Object System.Drawing.Point(20, 490)
    $grpDesc.Size = New-Object System.Drawing.Size(920, 80)
    $form.Controls.Add($grpDesc)

    $txtDetails = New-Object System.Windows.Forms.TextBox
    $txtDetails.Location = New-Object System.Drawing.Point(15, 30)
    $txtDetails.Size = New-Object System.Drawing.Size(890, 40)
    $txtDetails.ReadOnly = $true
    $txtDetails.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtDetails.ForeColor = [System.Drawing.Color]::Yellow
    $txtDetails.BorderStyle = "FixedSingle"
    $grpDesc.Controls.Add($txtDetails)

    # --- 5. BOTONES DE ACCION (Reorganizados para caber 3) ---
    
    # Boton Marcar Todo
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 595)
    $btnSelectAll.Size = New-Object System.Drawing.Size(100, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    # Boton HABILITAR
    $btnEnable = New-Object System.Windows.Forms.Button
    $btnEnable.Text = "HABILITAR"
    $btnEnable.Location = New-Object System.Drawing.Point(280, 590)
    $btnEnable.Size = New-Object System.Drawing.Size(200, 40)
    $btnEnable.BackColor = [System.Drawing.Color]::SeaGreen
    $btnEnable.ForeColor = [System.Drawing.Color]::White
    $btnEnable.FlatStyle = "Flat"
    $btnEnable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnEnable)

    # Boton DESHABILITAR
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "DESHABILITAR"
    $btnDisable.Location = New-Object System.Drawing.Point(500, 590)
    $btnDisable.Size = New-Object System.Drawing.Size(200, 40)
    $btnDisable.BackColor = [System.Drawing.Color]::OrangeRed
    $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDisable)

    # Boton ELIMINAR (Nuevo)
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "ELIMINAR TAREA"
    $btnDelete.Location = New-Object System.Drawing.Point(720, 590)
    $btnDelete.Size = New-Object System.Drawing.Size(220, 40)
    $btnDelete.BackColor = [System.Drawing.Color]::Maroon # Rojo oscuro para peligro
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnDelete)

    # --- VARIABLES Y CACHE ---
    $script:TaskCache = @{}

    # --- LOGICA DE CARGA ---
    $LoadGrid = {
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $script:TaskCache.Clear()
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        # Filtro Inteligente
        $allTasks = Get-ScheduledTask | Where-Object {
            ($_.TaskPath -notlike '\Microsoft\*') -or 
            ($_.TaskPath -like '\Microsoft\*' -and $_.Author -notlike 'Microsoft*')
        }

        # Filtro de Busqueda
        $searchText = $txtSearch.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            $allTasks = $allTasks | Where-Object { $_.TaskName -match $searchText }
        }

        foreach ($task in $allTasks) {
            $taskId = "$($task.TaskPath)|$($task.TaskName)"
            $script:TaskCache[$taskId] = $task

            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            $row.Cells["Name"].Value = $task.TaskName
            $row.Cells["Name"].Tag = $taskId 
            
            $row.Cells["Author"].Value = $task.Author
            $row.Cells["Path"].Value = $task.TaskPath

            if ($task.State -eq 'Disabled') {
                $row.Cells["Status"].Value = "Deshabilitado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
            } else {
                $row.Cells["Status"].Value = "Habilitado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                if ($task.State -eq 'Running') {
                    $row.Cells["Status"].Value = "Ejecutando"
                }
            }
        }
        
        $grid.ResumeLayout()
        $grid.ClearSelection()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $txtDetails.Text = ""
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $LoadGrid })
    $btnRefresh.Add_Click({ & $LoadGrid })
    $txtSearch.Add_KeyUp({ & $LoadGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $taskId = $grid.SelectedRows[0].Cells["Name"].Tag
            
            if ($null -ne $taskId -and $script:TaskCache.ContainsKey($taskId)) {
                $t = $script:TaskCache[$taskId]
                $action = ($t.Actions | Select-Object -First 1)
                if ($action) {
                    $txtDetails.Text = "Ejecuta: $($action.Execute) $($action.Arguments)"
                } else {
                    $txtDetails.Text = "No hay acciones definidas."
                }
            }
        }
    })

    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Logica General (Habilitar/Deshabilitar/Eliminar)
    $Apply = {
        param($Mode) # 'Enable', 'Disable', 'Delete'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $script:TaskCache[$row.Cells["Name"].Tag]
            }
        }

        if ($targets.Count -eq 0) { return }

        # Configurar mensajes y advertencias segun accion
        $verb = ""
        $icon = [System.Windows.Forms.MessageBoxIcon]::Question
        
        switch ($Mode) {
            'Enable'  { $verb = "HABILITAR" }
            'Disable' { $verb = "DESHABILITAR" }
            'Delete'  { 
                $verb = "ELIMINAR PERMANENTEMENTE" 
                $icon = [System.Windows.Forms.MessageBoxIcon]::Warning
            }
        }

        $msg = "¿Estas seguro de $verb $($targets.Count) tareas seleccionadas?"
        if ($Mode -eq 'Delete') {
            $msg += "`n`n¡Esta accion NO se puede deshacer!"
        }

        if ([System.Windows.Forms.MessageBox]::Show($msg, "Confirmar Accion", 4, $icon) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        foreach ($t in $targets) {
            try {
                if ($Mode -eq 'Enable') { 
                    Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop 
                } 
                elseif ($Mode -eq 'Disable') { 
                    Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop 
                }
                elseif ($Mode -eq 'Delete') {
                    # Logica de eliminacion
                    Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false -ErrorAction Stop
                }
                
                Write-Log -LogLevel ACTION -Message "TASKS GUI: $verb $($t.TaskName)"
            } catch {
                Write-Log -LogLevel ERROR -Message "Error con tarea $($t.TaskName): $_"
            }
        }

        & $LoadGrid
        [System.Windows.Forms.MessageBox]::Show("Proceso completado.", "Exito", 0, 64)
    }

    # --- EVENTO: BARRA ESPACIADORA PARA MARCAR/DESMARCAR ---
    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            # Evita que la barra espaciadora haga scroll hacia abajo
            $e.SuppressKeyPress = $true 
            
            # Recorre todas las filas seleccionadas (permite seleccion multiple con Shift/Ctrl)
            foreach ($row in $sender.SelectedRows) {
                # Invierte el valor actual (True -> False / False -> True)
                # Nota: Verificamos si la celda es de solo lectura (como en Bloatware protegido)
                if (-not $row.Cells["Check"].ReadOnly) {
                    $row.Cells["Check"].Value = -not ($row.Cells["Check"].Value)
                }
            }
        }
    })

    # Asignar eventos a botones
    $btnEnable.Add_Click({ & $Apply -Mode 'Enable' })
    $btnDisable.Add_Click({ & $Apply -Mode 'Disable' })
    $btnDelete.Add_Click({ & $Apply -Mode 'Delete' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# ===================================================================
# MODULO DE Gestor de Software Multi-Motor."
# ===================================================================
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
        # Forzamos codificacion para estandarizar la salida
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        
        # Ejecutamos winget incluyendo paquetes desconocidos
        $output = winget upgrade --source winget --include-unknown --accept-source-agreements 2>&1
        
        # Filtramos lineas inutiles (encabezados, barras de progreso, lineas vacias)
        $lines = $output | Where-Object { 
            $_ -notmatch "^Nombre" -and 
            $_ -notmatch "^Name" -and 
            $_ -notmatch "^Id" -and 
            $_ -notmatch "^-" -and      # Lineas separadoras
            $_ -notmatch "No se encontraron" -and
            $_ -notmatch "No updates found" -and
            ![string]::IsNullOrWhiteSpace($_)
        }

        foreach ($line in $lines) {
            # Dividimos por 2 o mas espacios consecutivos, que es mas seguro que posiciones fijas
            $columns = $line -split "\s{2,}"
            
            # Winget suele devolver: Nombre | Id | Version | Disponible
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
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   BUSQUEDA DE SOFTWARE ($($script:SoftwareEngine))" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Escribe el nombre del programa (ej: chrome, vlc)" -ForegroundColor Gray
    Write-Host "O escribe 'V' para volver atras." -ForegroundColor Yellow
    Write-Host ""

    $searchTerm = Read-Host "Nombre del software"
    
    # Salida rapida explicita
    if ([string]::IsNullOrWhiteSpace($searchTerm) -or $searchTerm.ToUpper() -eq 'V') { return }
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
    # Validar Catalogo
    if ($null -eq $script:SystemTweaks) {
        try { . "$PSScriptRoot\Catalogos\Ajustes.ps1" } catch { 
            [System.Windows.Forms.MessageBox]::Show("Error cargando catalogo.", "Error", 0, 16); return 
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- 1. FORMULARIO ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aegis Phoenix - Gestor de Ajustes"
    $form.Size = New-Object System.Drawing.Size(980, 720)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White

    # --- 2. PANEL DE FILTROS ---
    $lblCat = New-Object System.Windows.Forms.Label
    $lblCat.Text = "Categoria:"
    $lblCat.Location = New-Object System.Drawing.Point(20, 23)
    $lblCat.AutoSize = $true
    $lblCat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblCat)

    $cmbCategory = New-Object System.Windows.Forms.ComboBox
    $cmbCategory.Location = New-Object System.Drawing.Point(100, 20)
    $cmbCategory.Width = 250
    $cmbCategory.DropDownStyle = "DropDownList"
    $cmbCategory.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $cmbCategory.ForeColor = [System.Drawing.Color]::White
    $cmbCategory.FlatStyle = "Flat"
    $cmbCategory.Items.Add("--- TODAS LAS CATEGORIAS ---") | Out-Null
    
    # Carga rapida de categorias
    $script:SystemTweaks | Select-Object -ExpandProperty Category -Unique | Sort-Object | ForEach-Object { 
        $cmbCategory.Items.Add($_) | Out-Null 
    }
    $cmbCategory.SelectedIndex = 0
    $form.Controls.Add($cmbCategory)

    # -- OPTIMIZACIoN: CAJA DE BuSQUEDA --
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Buscar:"
    $lblSearch.Location = New-Object System.Drawing.Point(370, 23)
    $lblSearch.AutoSize = $true
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblSearch)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(430, 20)
    $txtSearch.Width = 250
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $txtSearch.ForeColor = [System.Drawing.Color]::Yellow
    $txtSearch.BorderStyle = "FixedSingle"
    $form.Controls.Add($txtSearch)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refrescar"
    $btnRefresh.Location = New-Object System.Drawing.Point(700, 18)
    $btnRefresh.Size = New-Object System.Drawing.Size(100, 26)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $form.Controls.Add($btnRefresh)

    # --- 3. DATAGRIDVIEW OPTIMIZADO ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(20, 60)
    $grid.Size = New-Object System.Drawing.Size(920, 420)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $grid.BorderStyle = "None"
    $grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = "Fill"
    
    # -- OPTIMIZACIoN: DOBLE BuFER PARA EVITAR PARPADEO --
    $type = $grid.GetType()
    $prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $prop.SetValue($grid, $true, $null)

    # Estilos
    $defaultStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $defaultStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $defaultStyle.ForeColor = [System.Drawing.Color]::White
    $defaultStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $defaultStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle = $defaultStyle
    $grid.ColumnHeadersDefaultCellStyle = $defaultStyle
    $grid.EnableHeadersVisualStyles = $false

    # Columnas
    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.HeaderText = "X"
    $colCheck.Width = 30
    $colCheck.Name = "Check"
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Ajuste"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.Width = 350
    $grid.Columns.Add($colName) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Estado"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.Width = 100
    $grid.Columns.Add($colStatus) | Out-Null

    $colReboot = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colReboot.HeaderText = "Requiere"
    $colReboot.Name = "Reboot"
    $colReboot.ReadOnly = $true
    $colReboot.Width = 120
    $grid.Columns.Add($colReboot) | Out-Null

    $colCat = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCat.HeaderText = "Categoria"
    $colCat.Name = "Category"
    $colCat.ReadOnly = $true
    $colCat.Width = 150
    $grid.Columns.Add($colCat) | Out-Null

    $form.Controls.Add($grid)

    # --- 4. PANEL DESCRIPCION ---
    $grpDesc = New-Object System.Windows.Forms.GroupBox
    $grpDesc.Text = "Detalles"
    $grpDesc.ForeColor = [System.Drawing.Color]::LightGray
    $grpDesc.Location = New-Object System.Drawing.Point(20, 490)
    $grpDesc.Size = New-Object System.Drawing.Size(920, 80)
    $form.Controls.Add($grpDesc)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "Selecciona un ajuste..."
    $lblDesc.Location = New-Object System.Drawing.Point(10, 20)
    $lblDesc.Size = New-Object System.Drawing.Size(900, 50)
    $lblDesc.ForeColor = [System.Drawing.Color]::White
    $grpDesc.Controls.Add($lblDesc)

    # --- 5. BOTONES ---
    $btnEnable = New-Object System.Windows.Forms.Button
    $btnEnable.Text = "ACTIVAR / OPTIMIZAR"
    $btnEnable.Location = New-Object System.Drawing.Point(680, 590)
    $btnEnable.Size = New-Object System.Drawing.Size(260, 40)
    $btnEnable.BackColor = [System.Drawing.Color]::SeaGreen
    $btnEnable.ForeColor = [System.Drawing.Color]::White
    $btnEnable.FlatStyle = "Flat"
    $btnEnable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnEnable)

    $btnRestore = New-Object System.Windows.Forms.Button
    $btnRestore.Text = "RESTAURAR (Default)"
    $btnRestore.Location = New-Object System.Drawing.Point(400, 590)
    $btnRestore.Size = New-Object System.Drawing.Size(260, 40)
    $btnRestore.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnRestore.ForeColor = [System.Drawing.Color]::White
    $btnRestore.FlatStyle = "Flat"
    $form.Controls.Add($btnRestore)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todo"
    $btnSelectAll.Location = New-Object System.Drawing.Point(20, 595)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $form.Controls.Add($btnSelectAll)

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Location = New-Object System.Drawing.Point(20, 640)
    $lblInfo.AutoSize = $true
    $lblInfo.ForeColor = [System.Drawing.Color]::Orange
    $form.Controls.Add($lblInfo)

    # --- VARIABLES Y CACHE ---
    $script:TweakCache = @{}

    # --- LOGICA DE CARGA (OPTIMIZADA) ---
    $LoadGrid = {
        # 1. OPTIMIZACIoN DE RENDIMIENTO: SuspendLayout evita repintado por cada fila
        $grid.SuspendLayout()
        $grid.Rows.Clear()
        $script:TweakCache.Clear()
        
        # Filtro de Categoria
        $cat = $cmbCategory.SelectedItem
        $items = if ($cat -eq "--- TODAS LAS CATEGORIAS ---") { $script:SystemTweaks } 
                 else { $script:SystemTweaks | Where-Object { $_.Category -eq $cat } }

        # Filtro de Busqueda (Texto)
        $searchText = $txtSearch.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            $items = $items | Where-Object { $_.Name -match $searchText }
        }

        foreach ($tweak in $items) {
            $rowId = $grid.Rows.Add()
            $row = $grid.Rows[$rowId]
            
            # Guardamos referencia en Cache (acceso O(1))
            $script:TweakCache[$tweak.Name] = $tweak

            $row.Cells["Name"].Value = $tweak.Name
            $row.Cells["Category"].Value = $tweak.Category
            
            $rebootTxt = switch($tweak.RestartNeeded) {
                "Reboot"   { "Reiniciar PC" }
                "Explorer" { "Reiniciar Explorer" }
                "Session"  { "Cerrar Sesion" }
                default    { "-" }
            }
            $row.Cells["Reboot"].Value = $rebootTxt

            # Obtener Estado
            $state = Get-TweakState -Tweak $tweak
            
            if ($state -eq 'Enabled') {
                $row.Cells["Status"].Value = "Activado"
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::LightGreen
                $row.Cells["Name"].Style.Font = New-Object System.Drawing.Font($grid.Font, [System.Drawing.FontStyle]::Bold)
            } 
            elseif ($state -eq 'Disabled') {
                $row.Cells["Status"].Value = "Desactivado"
                # Estilo solicitado: Rojo suave solo en el texto de estado
                $row.Cells["Status"].Style.ForeColor = [System.Drawing.Color]::Salmon
            }
            else {
                $row.Cells["Status"].Value = "N/A"
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Silver
            }
        }
        
        # 2. Restaurar pintado (Renderiza todo de golpe)
        $grid.ResumeLayout()
        $grid.ClearSelection()
    }

    # --- EVENTOS ---
    $form.Add_Shown({ & $LoadGrid })
    $btnRefresh.Add_Click({ & $LoadGrid })
    $cmbCategory.Add_SelectedIndexChanged({ & $LoadGrid })
    
    # Evento de busqueda en tiempo real (mientras escribes)
    $txtSearch.Add_KeyUp({ & $LoadGrid })

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            # 1. Obtener nombre del ajuste seleccionado
            $val = $grid.SelectedRows[0].Cells["Name"].Value
            $name = if ($val) { $val.ToString() } else { "" }
            
            # 2. Buscar en la caché y actualizar la etiqueta directamente
            if (-not [string]::IsNullOrEmpty($name) -and $script:TweakCache.ContainsKey($name)) {
                $desc = $script:TweakCache[$name].Description
                
                # Asignacion directa en lugar de Invoke
                # Si la descripcion esta vacia, mostramos un mensaje por defecto
                if (-not [string]::IsNullOrWhiteSpace($desc)) {
                    $lblDesc.Text = $desc
                } else {
                    $lblDesc.Text = "Sin descripcion disponible para este ajuste."
                }
            }
        }
    })

    $btnSelectAll.Add_Click({
        $grid.SuspendLayout()
        foreach ($row in $grid.Rows) { $row.Cells["Check"].Value = $true }
        $grid.ResumeLayout()
    })

    # Logica de Aplicacion
    $Apply = {
        param($Mode) # 'Enable' o 'Disable'
        
        $targets = @()
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Check"].Value -eq $true) {
                $targets += $script:TweakCache[$row.Cells["Name"].Value]
            }
        }

        if ($targets.Count -eq 0) { return }

        $actionTxt = if ($Mode -eq 'Enable') { "ACTIVAR" } else { "RESTAURAR" }
        if ([System.Windows.Forms.MessageBox]::Show("¿$actionTxt $($targets.Count) ajustes?", "Confirmar", 4, 32) -ne 'Yes') { return }

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $needRestart = $false
        $needExplorer = $false

        foreach ($t in $targets) {
            try {
                Set-TweakState -Tweak $t -Action $Mode
                if ($t.RestartNeeded -eq 'Reboot') { $needRestart = $true }
                if ($t.RestartNeeded -eq 'Explorer') { $needExplorer = $true }
            } catch {}
        }

        & $LoadGrid
        $form.Cursor = [System.Windows.Forms.Cursors]::Default

        if ($needExplorer -and -not $needRestart) {
            if ([System.Windows.Forms.MessageBox]::Show("Se requiere reiniciar el Explorador. ¿Hacerlo ahora?", "Aviso", 4, 32) -eq 'Yes') {

                $grid.ShowCellToolTips = $false
                [System.Windows.Forms.Application]::DoEvents() 

                try {
                    Invoke-ExplorerRestart
            } finally {
                    $grid.ShowCellToolTips = $true
                }
            }
        }
        if ($needRestart) {
            [System.Windows.Forms.MessageBox]::Show("Algunos cambios requieren reiniciar el PC para surtir efecto.", "Reinicio Requerido", 0, 48)
        }
    }

    # --- EVENTO: BARRA ESPACIADORA PARA MARCAR/DESMARCAR ---
    $grid.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Space') {
            # Evita que la barra espaciadora haga scroll hacia abajo
            $e.SuppressKeyPress = $true 
            
            # Recorre todas las filas seleccionadas (permite seleccion multiple con Shift/Ctrl)
            foreach ($row in $sender.SelectedRows) {
                # Invierte el valor actual (True -> False / False -> True)
                # Nota: Verificamos si la celda es de solo lectura (como en Bloatware protegido)
                if (-not $row.Cells["Check"].ReadOnly) {
                    $row.Cells["Check"].Value = -not ($row.Cells["Check"].Value)
                }
            }
        }
    })
	
    $btnEnable.Add_Click({ & $Apply -Mode 'Enable' })
    $btnRestore.Add_Click({ & $Apply -Mode 'Disable' })

    $form.ShowDialog() | Out-Null
    $form.Dispose()
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

# ===================================================================
# MODULO DE Limpieza Profunda de Navegadores
# ===================================================================
function Clean-BrowserCaches {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Log -LogLevel INFO -Message "MANTENIMIENTO: Inicio de limpieza robusta de navegadores."
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "            Limpieza Profunda de Navegadores           " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [!] ADVERTENCIA: Se cerraran forzosamente los navegadores." -ForegroundColor Yellow
    Write-Host "   [i] Se verificara que los archivos no esten bloqueados." -ForegroundColor Gray
    Write-Host ""
    
    if ((Read-Host "¿Deseas continuar? (S/N)").ToUpper() -ne 'S') { return }

    # Definición expandida de objetivos
    $browsers = @(
        @{ Name="Google Chrome"; Process="chrome"; Path="$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache*" },
        @{ Name="Google Chrome (GPU)"; Process="chrome"; Path="$env:LOCALAPPDATA\Google\Chrome\User Data\*\GPUCache*" },
        @{ Name="Microsoft Edge"; Process="msedge"; Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache*" },
        @{ Name="Microsoft Edge (GPU)"; Process="msedge"; Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\GPUCache*" },
        @{ Name="Brave Browser"; Process="brave"; Path="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Cache*" },
        @{ Name="Opera Stable"; Process="opera"; Path="$env:LOCALAPPDATA\Opera Software\Opera Stable\Cache*" },
        @{ Name="Opera GX"; Process="opera_gx"; Path="$env:LOCALAPPDATA\Opera Software\Opera GX Stable\Cache*" },
        @{ Name="Mozilla Firefox"; Process="firefox"; Path="$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2*" }
    )

    $globalFreed = 0

    foreach ($b in $browsers) {
        Write-Host "`n[+] Analizando: $($b.Name)..." -ForegroundColor Cyan
        
        # --- FASE 1: GESTION DE PROCESOS (DETERMINISTA) ---
        $proc = Get-Process -Name $b.Process -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "   - Cerrando $($b.Process) (Intento suave)..." -ForegroundColor Gray
            $proc | Stop-Process -ErrorAction SilentlyContinue
            
            # Espera inteligente (Polling): Esperar hasta 10 segundos a que muera
            $timeout = 0
            while ((Get-Process -Name $b.Process -ErrorAction SilentlyContinue) -and $timeout -lt 20) {
                Start-Sleep -Milliseconds 500
                $timeout++
                Write-Host "." -NoNewline -ForegroundColor DarkGray
            }
            
            # Kill forzoso si sigue vivo
            if (Get-Process -Name $b.Process -ErrorAction SilentlyContinue) {
                Write-Host "`n   - Proceso atascado. Forzando cierre..." -ForegroundColor Red
                Stop-Process -Name $b.Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1 # Tiempo extra para liberar I/O handles
            } else {
                Write-Host "`n   - Proceso finalizado correctamente." -ForegroundColor Green
            }
        }

        # --- FASE 2: LIMPIEZA CON VALIDACION DE BLOQUEOS ---
        $targetFolders = Get-Item -Path $b.Path -ErrorAction SilentlyContinue
        
        if ($targetFolders) {
            foreach ($folder in $targetFolders) {
                $folderSizeBefore = 0
                try {
                    $folderSizeBefore = (Get-ChildItem -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                } catch {}

                if ($folderSizeBefore -gt 0) {
                    Write-Host "   - Limpiando: $($folder.FullName)" -ForegroundColor Gray
                    
                    # Intentamos borrar el contenido. Si falla, reintentamos una vez más.
                    try {
                        Remove-Item -Path "$($folder.FullName)\*" -Recurse -Force -ErrorAction Stop
                    } catch {
                        Write-Warning "     Archivos bloqueados. Reintentando en 2 segundos..."
                        Start-Sleep -Seconds 2
                        try {
                            Remove-Item -Path "$($folder.FullName)\*" -Recurse -Force -ErrorAction SilentlyContinue
                        } catch {
                            Write-Log -LogLevel ERROR -Message "BROWSER CLEAN: No se pudo limpiar totalmente $($folder.FullName)"
                        }
                    }

                    # Calculamos el resultado REAL
                    $folderSizeAfter = 0
                    try {
                        $folderSizeAfter = (Get-ChildItem -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    } catch {}

                    $freed = $folderSizeBefore - $folderSizeAfter
                    if ($freed -lt 0) { $freed = 0 } # Evitar negativos raros
                    
                    $globalFreed += $freed
                    $freedMB = [math]::Round($freed / 1MB, 2)
                    
                    if ($freed -gt 0) {
                        Write-Host "     [OK] Liberado: $freedMB MB" -ForegroundColor Green
                    } else {
                        Write-Host "     [INFO] Ya estaba limpio o bloqueado." -ForegroundColor DarkGray
                    }
                }
            }
        }
    }

    $totalFreedMB = [math]::Round($globalFreed / 1MB, 2)
    Write-Host "`n-------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "   RESUMEN FINAL DE LIMPIEZA" -ForegroundColor Cyan
    if ($totalFreedMB -gt 0) {
        Write-Host "   Espacio Real Recuperado: $totalFreedMB MB" -ForegroundColor Green
        Write-Log -LogLevel ACTION -Message "BROWSER CLEAN: Limpieza masiva completada. Recuperados $totalFreedMB MB."
    } else {
        Write-Host "   No se requeria limpieza." -ForegroundColor White
    }
    Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
    
    Read-Host "Presiona Enter para volver..."
}

# --- FUNCIONES DE MENU PRINCIPAL ---
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
		Write-Host "   [4] Gestor de Claves Wi-Fi (Ver/Backup/Restore)" -ForegroundColor Cyan
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
            '2' { Show-ScheduledTasks }
			'3' { Move-UserProfileFolders }
			'4' { Show-WifiManager }
            'V' { continue }
            default {
                Write-Host "[ERROR] Opcion no valida." -ForegroundColor Red
            }
        }
    } while ($adminChoice.ToUpper() -ne 'V')
}

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
		Write-Host "   [8] Limpieza Profunda de Cache de Navegadores" -ForegroundColor Yellow
        Write-Host "       (Chrome, Edge, Firefox, Brave, Opera)" -ForegroundColor Gray
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
			'8' { Clean-BrowserCaches }
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
        Write-Host "   [3] Gestion de Drivers (Backup/Listar/Eliminar)"
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

# ===================================================================
# --- BUCLE PRINCIPAL (MOTOR DE INTERFAZ DE USUARIO) ---
# ===================================================================
function Invoke-MainMenuLoop {
    # Variable de estado para mensajes de retroalimentacion (Feedback Loop)
    $statusMessage = ""
    $statusColor = "Gray"
    
    # --- PRE-CALCULO DE INFORMACION ---
    $cachedSystemInfo = try {
        $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        
        # 1. Determinar Nombre Comercial (El registro miente en Win11 por compatibilidad)
        $build = [int]$reg.CurrentBuild
        $osName = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }
        
        # 2. Limpiar Edición
        $edition = $reg.EditionID `
            -replace "Professional", "Pro" `
            -replace "Core", "Home" `
            -replace "Enterprise", "Ent" `
            -replace "Education", "Edu" `
            -replace "Server", "Srv" `
            -replace "Workstation", "Wrk" `
            -replace "SingleLanguage", "SL" `
            -replace "CountrySpecific", "CS" `
            -replace "Essentials", "Ess" `
            -replace "Ultimate", "Ult" `
            -replace "Starter", "Strt" `
            -replace "Cloud", "SE" `
            -replace "IoT", "IoT"
        
        # 3. Versión de Visualización (23H2, 22H2, etc.)
        $displayVer = if ($reg.DisplayVersion) { $reg.DisplayVersion } else { $reg.ReleaseId }
        
        # 4. Arquitectura (Desde variable de entorno = 0ms)
        $arch = $env:PROCESSOR_ARCHITECTURE -replace "AMD64", "x64" -replace "x86", "x32"
        
        # String Final
        "$osName $edition $displayVer ($arch) - Build $build.$($reg.UBR)"
    } catch { 
        "Windows (Detectando...)" 
    }
    
    # Bucle infinito controlado
    while ($true) {
        Clear-Host
        
        # --- ENCABEZADO UNIFICADO ---
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        $line = "=" * $consoleWidth
        
        Write-Host $line -ForegroundColor Cyan
        
        # Titulo centrado
        $title = "Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER"
        $padding = [math]::Max(0, [int](($consoleWidth - $title.Length) / 2))
        Write-Host (" " * $padding + $title) -ForegroundColor Cyan
        
        # Metadata L1: Usuario y Equipo
        $metaInfo1 = "Usuario: $env:USERNAME | Equipo: $env:COMPUTERNAME | Privilegios: Admin"
        $paddingMeta1 = [math]::Max(0, [int](($consoleWidth - $metaInfo1.Length) / 2))
        Write-Host (" " * $paddingMeta1 + $metaInfo1) -ForegroundColor Gray

        # Metadata L2: Sistema Exacto (Cacheado)
        $paddingMeta2 = [math]::Max(0, [int](($consoleWidth - $cachedSystemInfo.Length) / 2))
        Write-Host (" " * $paddingMeta2 + $cachedSystemInfo) -ForegroundColor Gray
        
        Write-Host $line -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Crear Punto de Restauracion" -ForegroundColor White
        Write-Host "       (Snapshot de seguridad del sistema)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "--- MODULOS OPERATIVOS ---" -ForegroundColor Cyan
        Write-Host "   [2] Optimizacion y Limpieza" -ForegroundColor Green
        Write-Host "       (Servicios, Bloatware, Disco, Inicio)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Mantenimiento y Reparacion" -ForegroundColor Green
        Write-Host "       (SFC, DISM, Red, Caches, Drivers)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Herramientas Avanzadas" -ForegroundColor Yellow
        Write-Host "       (Ajustes/Tweaks, Inventario, Software)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "   [L] Ver Logs   [H] Ayuda/Info   [S] Salir" -ForegroundColor Gray
        Write-Host ""

        # --- AREA DE MENSAJES DE ESTADO (FEEDBACK) ---
        if (-not [string]::IsNullOrWhiteSpace($statusMessage)) {
            Write-Host "   ESTADO: $statusMessage" -ForegroundColor $statusColor
            $statusMessage = ""
            $statusColor = "Gray"
        } else {
            Write-Host ""
        }
        
        # --- CAPTURA DE ENTRADA ---
        $selection = Read-Host "   > Selecciona una opcion"
        
        # --- VALIDACIoN Y LOGICA ---
        switch ($selection.Trim().ToUpper()) {
            '1' { 
                Create-RestorePoint 
                $statusMessage = "Ultima accion: Punto de restauracion finalizado."; $statusColor = "Green"
            }
            '2' { 
                Show-OptimizationMenu 
                $statusMessage = "Regresando del menu de Optimizacion."; $statusColor = "Cyan"
            }
            '3' { 
                Show-MaintenanceMenu 
                $statusMessage = "Regresando del menu de Mantenimiento."; $statusColor = "Cyan"
            }
            '4' { 
                Show-AdvancedMenu 
                $statusMessage = "Regresando del menu Avanzado."; $statusColor = "Cyan"
            }
            'L' {
                $logFile = Join-Path (Split-Path -Parent $PSScriptRoot) "Logs\Registro.log"
                if (Test-Path $logFile) {
                    Start-Process notepad.exe -ArgumentList $logFile
                    $statusMessage = "Abriendo logs..."; $statusColor = "Green"
                } else {
                    $statusMessage = "Error: El archivo de log aun no existe."; $statusColor = "Red"
                }
            }
            'H' {
               $msg = "Aegis Phoenix Suite v$($script:Version)`n" +
                      "Desarrollado por SOFTMAXTER`n`n" +
                      "Email: softmaxter@hotmail.com`n" +
                      "Blog: softmaxter.blogspot.com`n`n" +
                      "Una suite integral para el mantenimiento proactivo de sistemas Windows."
               
               [System.Windows.Forms.MessageBox]::Show($msg, "Acerca de", 0, 64)
            }
            'S' { 
                Write-Host "`n   Cerrando sesion y limpiando variables temporales..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                return # Rompe el bucle y la funcion
            }
            default {
                if ([string]::IsNullOrWhiteSpace($selection)) {
                    $statusMessage = "Por favor, escribe una opcion."; $statusColor = "Yellow"
                } else {
                    $statusMessage = "Opcion '$selection' no reconocida. Intenta de nuevo."; $statusColor = "Red"
                    [System.Console]::Beep(500, 200) 
                }
            }
        }
        
        # Registro de telemetria interna
        if (-not [string]::IsNullOrWhiteSpace($selection)) {
            Write-Log -LogLevel INFO -Message "MAIN_MENU: Input usuario: '$selection'"
        }
    }
}

# --- PUNTO DE ENTRADA (ENTRY POINT) ---
try {
    # Configurar titulo de consola
    $Host.UI.RawUI.WindowTitle = "Aegis Phoenix Suite v$($script:Version) by SOFTMAXTER"
    
    # Iniciar el bucle principal
    Invoke-MainMenuLoop
    
    Write-Log -LogLevel INFO -Message "Sesion finalizada correctamente."
}
catch {
    Write-Log -LogLevel ERROR -Message "CRASH FATAL EN MENU PRINCIPAL: $_"
    Write-Error "Ocurrio un error inesperado en el nucleo del script."
    Write-Error $_
    Read-Host "Presiona Enter para salir..."
}
