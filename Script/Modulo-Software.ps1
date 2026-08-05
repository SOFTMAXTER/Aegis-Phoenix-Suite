# =================================================================
#  Modulo-Software
#
#  CONTENIDO   : Show-SoftwareMenu
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                      : registro de eventos en el log de la suite
#    - Invoke-AegisNativeProcess      : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - New-AegisOperationJournal      : abre una bitacora de auditoria para una operacion
#    - Complete-AegisOperationJournal : cierra y guarda la bitacora de una operacion
#    - $script:SoftwareEngine         : motor de gestion de software seleccionado (Winget/Chocolatey)
#
#  CARGA       : . "$PSScriptRoot\Modulo-Software.ps1"
#
#  NO modificar las firmas de funcion; el nucleo las invoca por nombre.
#
# ==============================================================================
# Copyright (C) 2026 SOFTMAXTER
#
# DUAL LICENSING NOTICE:
# This software is dual-licensed. By default, Aegis Phoenix Suite is 
# distributed under the GNU General Public License v3.0 (GPLv3).
# 
# 1. OPEN SOURCE (GPLv3):
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details: <https://www.gnu.org/licenses/>.
#
# 2. COMMERCIAL LICENSE:
# If you wish to integrate this software into a proprietary/commercial product, 
# distribute it without revealing your source code, or require commercial 
# support, you must obtain a commercial license from the original author.
#
# Please contact softmaxter@hotmail.com for commercial licensing inquiries.
# ==============================================================================

function Assert-AegisPackageIdentifier {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$PackageId)

    $candidate = $PackageId.Trim()
    if ($candidate -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{0,255}$') {
        throw "Identificador de paquete no valido: '$PackageId'."
    }
    return $candidate
}

function Get-AegisSoftwareEngineExecutable {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateSet('Winget','Chocolatey')][string]$Engine)

    $commandName = if ($Engine -eq 'Winget') { 'winget.exe' } else { 'choco.exe' }
    $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and $command.Source) { return [string]$command.Source }
    if ($Engine -eq 'Chocolatey') {
        $commonPath = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
        if (Test-Path -LiteralPath $commonPath -PathType Leaf) { return $commonPath }
    }
    return $null
}

function ConvertFrom-AegisWingetTable {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Text)

    $lines = @($Text -split "`r?`n")
    $separatorIndex = -1
    $columnStarts = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $matches = [regex]::Matches($lines[$i], '-{2,}')
        if ($matches.Count -ge 3) {
            $separatorIndex = $i
            $columnStarts = @($matches | ForEach-Object { $_.Index })
            break
        }
    }
    if ($separatorIndex -lt 0) { return @() }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @($lines | Select-Object -Skip ($separatorIndex + 1))) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $columns = [System.Collections.Generic.List[string]]::new()
        for ($columnIndex = 0; $columnIndex -lt $columnStarts.Count; $columnIndex++) {
            $start = $columnStarts[$columnIndex]
            if ($start -ge $line.Length) { $columns.Add(''); continue }
            $length = if ($columnIndex -lt ($columnStarts.Count - 1)) {
                [math]::Min($line.Length - $start, $columnStarts[$columnIndex + 1] - $start)
            } else {
                $line.Length - $start
            }
            $columns.Add($line.Substring($start, $length).Trim())
        }
        if ($columns.Count -ge 3 -and $columns[1] -match '^[A-Za-z0-9][A-Za-z0-9._+-]{0,255}$') {
            $rows.Add([PSCustomObject]@{
                Name = $columns[0]
                Id = $columns[1]
                Version = $columns[2]
                Extra = if ($columns.Count -ge 4) { $columns[3] } else { '' }
                Source = if ($columns.Count -ge 5) { $columns[$columns.Count - 1] } else { '' }
            })
        }
    }
    return $rows.ToArray()
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
                if ($engineChoice -match '^\d+$' -and [int]$engineChoice -ge 1 -and [int]$engineChoice -le $availableEngines.Count) {
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
        $enginePath = Get-AegisSoftwareEngineExecutable -Engine Winget
        if (-not $enginePath) { throw 'Winget no esta disponible.' }
        $processResult = Invoke-AegisNativeProcess -FilePath $enginePath -ArgumentList @(
            'upgrade','--source','winget','--include-unknown','--accept-source-agreements'
        ) -TimeoutSeconds 180 -ValidExitCodes @(0)
        foreach ($row in @(ConvertFrom-AegisWingetTable -Text $processResult.StdOut)) {
            $updates += [PSCustomObject]@{
                Name      = $row.Name
                Id        = $row.Id
                Version   = $row.Version
                Available = if ($row.Extra) { $row.Extra } else { 'Unknown' }
                Source    = if ($row.Source) { $row.Source } else { 'winget' }
                Engine    = 'Winget'
            }
        }
    } catch {
        throw "Fallo al obtener actualizaciones de Winget: $($_.Exception.Message)"
    }
    return $updates
}

# --- ADAPTADOR 2: Obtener actualizaciones de Chocolatey ---

function Get-AegisChocoUpdates {
    Write-Host "Buscando en Chocolatey..." -ForegroundColor Gray
    $updates = @()
    try {
        $enginePath = Get-AegisSoftwareEngineExecutable -Engine Chocolatey
        if (-not $enginePath) { throw 'Chocolatey no esta disponible.' }
        $processResult = Invoke-AegisNativeProcess -FilePath $enginePath -ArgumentList @('outdated','--limit-output') -TimeoutSeconds 180 -ValidExitCodes @(0,2)
        $updates = $processResult.StdOut -split "`r?`n" | ForEach-Object {
            if ($_ -match "^(.*?)\|(.*?)\|(.*?)\|") {
                [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[1].Trim()
                    Version = $matches[2].Trim()
                    Available = $matches[3].Trim()
                    Source = 'chocolatey'
                    Engine = 'Chocolatey'
                }
            }
        }
    } catch {
        throw "Fallo al obtener actualizaciones de Chocolatey: $($_.Exception.Message)"
    }
    return $updates
}

# --- ADAPTADOR 3: Buscar paquetes en Winget ---

function Search-AegisWingetPackage {
    param([string]$SearchTerm)
    
    $results = @()
    try {
        $enginePath = Get-AegisSoftwareEngineExecutable -Engine Winget
        if (-not $enginePath) { throw 'Winget no esta disponible.' }
        $processResult = Invoke-AegisNativeProcess -FilePath $enginePath -ArgumentList @(
            'search',$SearchTerm,'--source','winget','--accept-source-agreements'
        ) -TimeoutSeconds 180 -ValidExitCodes @(0)
        foreach ($row in @(ConvertFrom-AegisWingetTable -Text $processResult.StdOut | Select-Object -First 100)) {
            $results += [PSCustomObject]@{
                Name = $row.Name
                Id = $row.Id
                Version = $row.Version
                Source = if ($row.Source) { $row.Source } else { 'winget' }
            }
        }
    } catch {
        throw "Fallo al buscar en Winget: $($_.Exception.Message)"
    }
    return $results
}

# --- ADAPTADOR 4: Buscar paquetes en Chocolatey ---

function Search-AegisChocoPackage {
     param([string]$SearchTerm)

    $results = @()
    try {
        $enginePath = Get-AegisSoftwareEngineExecutable -Engine Chocolatey
        if (-not $enginePath) { throw 'Chocolatey no esta disponible.' }
        $processResult = Invoke-AegisNativeProcess -FilePath $enginePath -ArgumentList @('search',$SearchTerm,'--limit-output') -TimeoutSeconds 180 -ValidExitCodes @(0)
        $results = $processResult.StdOut -split "`r?`n" | ForEach-Object {
            if ($_ -match "^(.*?)\|(.*)$") {
                [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[1].Trim()
                    Version = $matches[2].Trim()
                    Source = 'chocolatey'
                }
            }
        }
    } catch {
         throw "Fallo al buscar en Chocolatey: $($_.Exception.Message)"
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
        $queryErrors = 0
        foreach ($engine in $activeEngines) {
            try {
                switch ($engine) {
                    'Winget'     { $allUpdates += Get-AegisWingetUpdates }
                    'Chocolatey' { $allUpdates += Get-AegisChocoUpdates }
                }
            } catch {
                $queryErrors++
                Write-Host $_.Exception.Message -ForegroundColor Red
                Write-Log -LogLevel ERROR -Message "SOFTWARE: Consulta $engine fallida: $($_.Exception.Message)"
            }
        }

        if ($allUpdates.Count -eq 0) {
            if ($queryErrors -gt 0) {
                Write-Host "No fue posible completar la consulta de actualizaciones ($queryErrors motores con error)." -ForegroundColor Red
            } else {
                Write-Host "No se encontraron actualizaciones pendientes." -ForegroundColor Green
            }
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

            $successCount = 0
            $errorCount = 0
            $journal = New-AegisOperationJournal -Module 'Software' -Action 'UpgradePackages' -Targets @($selectedUpdates | ForEach-Object {
                [ordered]@{ Id=$_.Id; Name=$_.Name; Engine=$_.Engine; From=$_.Version; To=$_.Available; Source=$_.Source }
            })
            $journalResults = [System.Collections.Generic.List[object]]::new()
            foreach ($update in $selectedUpdates) {
                Write-Host "Actualizando $($update.Name) con $($update.Engine)..." -ForegroundColor Yellow
				Write-Log -LogLevel ACTION -Message "SOFTWARE: Actualizando '$($update.Name)' ($($update.Id)) con $($update.Engine)."
                try {
                    switch ($update.Engine) {
                        'Winget' {
                            $packageId = Assert-AegisPackageIdentifier -PackageId $update.Id
                            $source = if ($update.Source -in @('winget','msstore')) { [string]$update.Source } else { 'winget' }
                            $processResult = Invoke-AegisNativeProcess -FilePath (Get-AegisSoftwareEngineExecutable -Engine Winget) -ArgumentList @(
                                'upgrade','--id',$packageId,'--exact','--source',$source,'--silent','--accept-package-agreements','--accept-source-agreements'
                            ) -TimeoutSeconds 7200 -ValidExitCodes @(0)
                        }
                        'Chocolatey' {
                            $packageId = Assert-AegisPackageIdentifier -PackageId $update.Id
                            $processResult = Invoke-AegisNativeProcess -FilePath (Get-AegisSoftwareEngineExecutable -Engine Chocolatey) -ArgumentList @('upgrade',$packageId,'-y','--no-progress') -TimeoutSeconds 7200 -ValidExitCodes @(0,1641,3010)
                        }
                    }
                    $successCount++
                    $journalResults.Add([ordered]@{ Id=$update.Id; Engine=$update.Engine; Status='Completed'; ExitCode=$processResult.ExitCode })
                } catch {
                    $errorCount++
                    $journalResults.Add([ordered]@{ Id=$update.Id; Engine=$update.Engine; Status='Failed'; Error=$_.Exception.Message })
                    Write-Host "Fallo al actualizar $($update.Name): $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log -LogLevel ERROR -Message "SOFTWARE: Fallo actualizando '$($update.Name)': $($_.Exception.Message)"
                }
            }

            $journalStatus = if ($errorCount -eq 0) { 'Completed' } elseif ($successCount -gt 0) { 'Partial' } else { 'Failed' }
            [void](Complete-AegisOperationJournal -Journal $journal -Status $journalStatus -Results @($journalResults))

            Write-Host "`nResultado: $successCount actualizaciones correctas, $errorCount errores." -ForegroundColor $(if ($errorCount -eq 0) { 'Green' } else { 'Yellow' })
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
    
    if ($Engine -notin @('Winget','Chocolatey')) { return $false }
    return -not [string]::IsNullOrWhiteSpace((Get-AegisSoftwareEngineExecutable -Engine $Engine))
}

function Ensure-ChocolateyIsInstalled {
    # Primero verificar si ya esta instalado
    if (Test-SoftwareEngine 'Chocolatey') { return $true }
    
    Write-Host "El gestor de paquetes 'Chocolatey' no esta instalado." -ForegroundColor Yellow
    
    if ($script:SoftwareEngine -eq 'Chocolatey') {
        Write-Warning "Por seguridad, Aegis no descargara ni ejecutara automaticamente un script remoto de instalacion."
        $installChoice = Read-Host "Deseas abrir la pagina oficial de instalacion de Chocolatey? (S/N)"
        if ($installChoice -eq 'S' -or $installChoice -eq 's') {
            try {
                Start-Process 'https://chocolatey.org/install'
                Write-Host "Completa la instalacion siguiendo la documentacion oficial y vuelve a abrir Aegis." -ForegroundColor Yellow
            } catch {
                Write-Host "No se pudo abrir la pagina oficial: $($_.Exception.Message)" -ForegroundColor Red
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
    $searchTerm = $searchTerm.Trim()
    if ($searchTerm.Length -gt 100 -or $searchTerm -match '[\x00-\x1F]') {
        Write-Host 'El termino de busqueda no es valido o es demasiado largo.' -ForegroundColor Red
        Read-Host 'Presiona Enter para continuar'
        return
    }
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
                Install-Software -SoftwareId $software.Id -SoftwareName $software.Name -Source $software.Source
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
        [string]$SoftwareName,
        [string]$Source,
        [switch]$NoPause
    )

    $success = $false
    $journal = $null
    try {
        $SoftwareId = Assert-AegisPackageIdentifier -PackageId $SoftwareId
        $journal = New-AegisOperationJournal -Module 'Software' -Action 'InstallPackage' -Targets @(
            [ordered]@{ Id=$SoftwareId; Name=$SoftwareName; Engine=$script:SoftwareEngine; Source=$Source }
        )
        Write-Host "Instalando $SoftwareName..." -ForegroundColor Yellow
		Write-Log -LogLevel ACTION -Message "SOFTWARE: Instalando '$SoftwareName' ($SoftwareId) con $($script:SoftwareEngine)."
        
        switch ($script:SoftwareEngine) {
            'Winget' {
                $resolvedSource = if ($Source -in @('winget','msstore')) { $Source } else { 'winget' }
                if ($resolvedSource -eq 'msstore') {
                    Write-Host "Aplicacion de Microsoft Store detectada. No se puede instalar en modo silencioso." -ForegroundColor Yellow
                    $processResult = Invoke-AegisNativeProcess -FilePath (Get-AegisSoftwareEngineExecutable -Engine Winget) -ArgumentList @(
                        'install','--id',$SoftwareId,'--exact','--source',$resolvedSource,'--accept-package-agreements','--accept-source-agreements'
                    ) -TimeoutSeconds 7200 -ValidExitCodes @(0)
                } else {
                    $processResult = Invoke-AegisNativeProcess -FilePath (Get-AegisSoftwareEngineExecutable -Engine Winget) -ArgumentList @(
                        'install','--id',$SoftwareId,'--exact','--source',$resolvedSource,'--silent','--accept-package-agreements','--accept-source-agreements'
                    ) -TimeoutSeconds 7200 -ValidExitCodes @(0)
                }
            }
            'Chocolatey' {
                $processResult = Invoke-AegisNativeProcess -FilePath (Get-AegisSoftwareEngineExecutable -Engine Chocolatey) -ArgumentList @('install',$SoftwareId,'-y','--no-progress') -TimeoutSeconds 7200 -ValidExitCodes @(0,1641,3010)
            }
            default { throw "Motor de software no compatible: $($script:SoftwareEngine)" }
        }
        $success = $true
        [void](Complete-AegisOperationJournal -Journal $journal -Status 'Completed' -Results @(
            [ordered]@{ Status='Installed'; ExitCode=$processResult.ExitCode }
        ))
        Write-Host "¡$SoftwareName instalado correctamente!" -ForegroundColor Green
    }
    catch {
        if ($journal) {
            [void](Complete-AegisOperationJournal -Journal $journal -Status 'Failed' -Results @(
                [ordered]@{ Status='Failed'; Error=$_.Exception.Message }
            ))
        }
        Write-Host "Error durante la instalacion: $($_.Exception.Message)" -ForegroundColor Red
		Write-Log -LogLevel ERROR -Message "SOFTWARE: Error instalando '$SoftwareName': $($_.Exception.Message)"
    }
    
    if (-not $NoPause) { Read-Host "Presiona Enter para continuar" }
    return $success
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

    try {
        $listFile = Get-Item -LiteralPath $filePath -ErrorAction Stop
        if ($listFile.Length -gt 1MB) { throw 'El archivo supera el limite de 1 MB.' }
        $softwareList = @(Get-Content -LiteralPath $filePath -ErrorAction Stop | ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith('#') } |
            Select-Object -Unique)
        if ($softwareList.Count -gt 500) { throw 'La lista supera el limite de 500 paquetes.' }
        $softwareList = @($softwareList | ForEach-Object { Assert-AegisPackageIdentifier -PackageId $_ })
    } catch {
        Write-Host "Lista de instalacion no valida: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host 'Presiona Enter para continuar'
        return
    }
    
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

    $confirm = Read-Host "`nContinuar con la instalacion? (S/N)"
    if ($confirm -ne 'S' -and $confirm -ne 's') { return }
	Write-Log -LogLevel INFO -Message "SOFTWARE: Iniciando instalacion en masa desde '$filePath' con el motor '$($script:SoftwareEngine)'."

    $successCount = 0
    $errorCount = 0
    foreach ($software in $softwareList) {
        Write-Host "Instalando $software..." -ForegroundColor Yellow
        if (Install-Software -SoftwareId $software -SoftwareName $software -Source $(if ($script:SoftwareEngine -eq 'Winget') { 'winget' } else { 'chocolatey' }) -NoPause) { $successCount++ } else { $errorCount++ }
    }
    Write-Host "`nLote finalizado: $successCount correctos, $errorCount errores." -ForegroundColor $(if ($errorCount -eq 0) { 'Green' } else { 'Yellow' })
}