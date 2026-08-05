# =================================================================
#  Modulo-Inventario
#
#  CONTENIDO   : Show-InventoryMenu
#  DEPENDENCIAS DEL NUCLEO (heredadas via dot-source):
#    - Write-Log                 : registro de eventos en el log de la suite
#    - Invoke-AegisNativeProcess : ejecucion controlada de procesos nativos (wevtutil, dism, robocopy, etc.)
#    - Test-AegisCapability      : verifica disponibilidad de un comando/capacidad del sistema
#    - ConvertTo-AegisHtmlSafe   : escapa texto para insertarlo de forma segura en HTML
#    - Read-AegisSafeXml         : carga y valida contenido XML de forma segura
#
#  CARGA       : . "$PSScriptRoot\Modulo-Inventario.ps1"
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
    $osInfo = try { Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } catch {
        Write-Warning "No se pudo leer Win32_OperatingSystem: $($_.Exception.Message)"
        [PSCustomObject]@{ LastBootUpTime = Get-Date; TotalVisibleMemorySize = 0; FreePhysicalMemory = 0 }
    }
    $csInfo = try { Get-ComputerInfo -ErrorAction Stop } catch {
        Write-Warning "No se pudo leer Get-ComputerInfo: $($_.Exception.Message)"
        [PSCustomObject]@{
            CsName = $env:COMPUTERNAME
            CsProcessors = @([PSCustomObject]@{ Name = $env:PROCESSOR_IDENTIFIER })
            CsNumberOfLogicalProcessors = [int]$env:NUMBER_OF_PROCESSORS
        }
    }
    $uptime = (Get-Date) - $osInfo.LastBootUpTime
    $physicalCores = try { (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Measure-Object -Property NumberOfCores -Sum).Sum } catch { "No disponible" }
    
    # --- NUEVO: Calculo de RAM Maxima Soportada ---
    $maxRamInfo = try { Get-CimInstance -ClassName Win32_PhysicalMemoryArray -ErrorAction Stop | Measure-Object -Property MaxCapacity -Sum } catch { $null }
    $maxRamGB = if ($maxRamInfo.Sum -gt 0) { 
        [math]::Round($maxRamInfo.Sum / 1024 / 1024, 0) # Convertir KB a GB
    } else { "Desconocido" }
    # ---------------------------------------------

    # Windows PowerShell 5.1 no acepta un bloque try/catch directamente como
    # valor de una clave dentro de un literal hash. Calculamos primero cada
    # valor tolerante a errores y despues construimos la tabla.
    $memoriaTotalGB = try {
        [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB, 2)
    } catch {
        "No disponible"
    }

    $systemData = @{
        WindowsVersion = Get-DetailedWindowsVersion
        Hostname = $csInfo.CsName
        Procesador = ($csInfo.CsProcessors | Select-Object -First 1).Name
        Nucleos = "$physicalCores fisicos. $($csInfo.CsNumberOfLogicalProcessors) logicos."
        MemoriaTotalGB = $memoriaTotalGB
        MemoriaMaxGB   = $maxRamGB  # <--- Agregado aqui
        MemoriaEnUsoPorc = if ($osInfo.TotalVisibleMemorySize -gt 0) { [math]::Round((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100, 2) } else { "No disponible" }
        Uptime = "$($uptime.Days) dias, $($uptime.Hours) horas, $($uptime.Minutes) minutos"
    }

    # -- Hardware Detallado --
    # Win32_VideoController.AdapterRAM es UInt32 y puede truncar la VRAM de
    # tarjetas con mas de 4 GB. Se prioriza el controlador NVIDIA y despues el
    # valor QWORD de 64 bits publicado por el controlador en el registro.
    $convertVideoMemoryToBytes = {
        param($Value)

        if ($null -eq $Value) { return [uint64]0 }
        try {
            if ($Value -is [byte[]]) {
                if ($Value.Length -ge 8) { return [BitConverter]::ToUInt64($Value, 0) }
                if ($Value.Length -ge 4) { return [uint64][BitConverter]::ToUInt32($Value, 0) }
                return [uint64]0
            }
            if ($Value -is [int32] -and $Value -lt 0) {
                return [uint64][BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$Value), 0)
            }
            return [uint64]$Value
        } catch {
            return [uint64]0
        }
    }

    $normalizeGpuName = {
        param([string]$Name)
        if ([string]::IsNullOrWhiteSpace($Name)) { return "" }
        return [regex]::Replace($Name.ToLowerInvariant(), '[^a-z0-9]', '')
    }

    # NVIDIA-SMI informa la memoria fisica total en MiB sin el limite UInt32.
    $nvidiaMemory = @()
    try {
        $nvidiaSmiCommand = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        $nvidiaSmiPath = if ($nvidiaSmiCommand) { $nvidiaSmiCommand.Source } else { $null }
        if ([string]::IsNullOrWhiteSpace($nvidiaSmiPath)) {
            $defaultNvidiaSmi = Join-Path $env:ProgramFiles "NVIDIA Corporation\NVSMI\nvidia-smi.exe"
            if (Test-Path -LiteralPath $defaultNvidiaSmi -PathType Leaf) { $nvidiaSmiPath = $defaultNvidiaSmi }
        }

        if (-not [string]::IsNullOrWhiteSpace($nvidiaSmiPath)) {
            $nvidiaResult = Invoke-AegisNativeProcess -FilePath $nvidiaSmiPath -ArgumentList @(
                '--query-gpu=name,memory.total','--format=csv,noheader,nounits'
            ) -TimeoutSeconds 30 -ValidExitCodes @(0)
            if ($nvidiaResult.Succeeded) {
                $nvidiaMemory = @($nvidiaResult.StdOut -split "`r?`n" | ForEach-Object {
                    $line = ([string]$_).Trim()
                    $separator = $line.LastIndexOf(',')
                    if ($separator -gt 0) {
                        $gpuName = $line.Substring(0, $separator).Trim()
                        $memoryText = $line.Substring($separator + 1).Trim()
                        [double]$memoryMiB = 0
                        if ([double]::TryParse($memoryText, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$memoryMiB) -and $memoryMiB -gt 0) {
                            [PSCustomObject]@{
                                Name  = $gpuName
                                Bytes = [uint64][math]::Round($memoryMiB * 1MB)
                            }
                        }
                    }
                })
            }
        }
    } catch {
        $nvidiaMemory = @()
    }

    # DXDiag ofrece una fuente neutral para AMD, Intel y NVIDIA. Se utiliza
    # antes del registro y se descarta el XML temporal inmediatamente.
    $dxdiagMemory = @()
    $parseDxDiagMemory = {
        param([string]$Text)
        if ([string]::IsNullOrWhiteSpace($Text)) { return [uint64]0 }
        $match = [regex]::Match($Text, '(?<value>[0-9]+(?:[\.,][0-9]+)?)\s*(?<unit>GB|GiB|MB|MiB)', 'IgnoreCase')
        if (-not $match.Success) { return [uint64]0 }
        [double]$numericValue = 0
        $normalizedValue = $match.Groups['value'].Value.Replace(',', '.')
        if (-not [double]::TryParse($normalizedValue, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$numericValue)) { return [uint64]0 }
        if ($match.Groups['unit'].Value -match '^G') { return [uint64][math]::Round($numericValue * 1GB) }
        return [uint64][math]::Round($numericValue * 1MB)
    }
    $dxdiagPath = Join-Path ([System.IO.Path]::GetTempPath()) ("AegisDxDiag_" + [guid]::NewGuid().ToString('N') + '.xml')
    try {
        if (Test-AegisCapability -Command 'dxdiag.exe') {
            $dxdiagResult = Invoke-AegisNativeProcess -FilePath 'dxdiag.exe' -ArgumentList @('/whql:off', '/x', $dxdiagPath) -TimeoutSeconds 90 -NoThrow
            if ($dxdiagResult.Succeeded -and (Test-Path -LiteralPath $dxdiagPath)) {
                $dxdiagXml = Read-AegisSafeXml -Path $dxdiagPath -MaxCharacters 10485760
                $dxdiagMemory = @($dxdiagXml.DxDiag.DisplayDevices.DisplayDevice | ForEach-Object {
                    # DisplayMemory suele ser dedicada + compartida y por eso
                    # sobrestima la VRAM. DedicatedMemory es la magnitud correcta.
                    [uint64]$bytes = & $parseDxDiagMemory ([string]$_.DedicatedMemory)
                    $source = 'DXDiag DedicatedMemory'
                    if ($bytes -eq 0) {
                        [uint64]$displayBytes = & $parseDxDiagMemory ([string]$_.DisplayMemory)
                        [uint64]$sharedBytes = & $parseDxDiagMemory ([string]$_.SharedMemory)
                        if ($displayBytes -gt $sharedBytes) {
                            $bytes = $displayBytes - $sharedBytes
                            $source = 'DXDiag DisplayMemory - SharedMemory'
                        }
                    }
                    if ($bytes -gt 0 -and $bytes -le 256GB) {
                        [PSCustomObject]@{ Name=[string]$_.CardName; Bytes=$bytes; Source=$source }
                    }
                })
            }
        }
    } catch {
        Write-Log -LogLevel WARN -Message "INVENTORY: DXDiag no pudo proporcionar VRAM: $($_.Exception.Message)"
    } finally {
        if (Test-Path -LiteralPath $dxdiagPath) { Remove-Item -LiteralPath $dxdiagPath -Force -ErrorAction SilentlyContinue }
    }

    # Reunir valores de memoria publicados por los controladores de pantalla.
    $gpuRegistryEntries = New-Object System.Collections.Generic.List[object]
    $addGpuRegistryEntry = {
        param($RegistryKey)

        try {
            $properties = Get-ItemProperty -LiteralPath $RegistryKey.PSPath -ErrorAction Stop
            $memoryBytes = [uint64]0
            $memorySource = $null

            $qwordProperty = $properties.PSObject.Properties['HardwareInformation.qwMemorySize']
            if ($qwordProperty) {
                $memoryBytes = & $convertVideoMemoryToBytes $qwordProperty.Value
                if ($memoryBytes -gt 0) { $memorySource = 'Registro QWORD (64 bits)' }
            }

            if ($memoryBytes -eq 0) {
                $dwordProperty = $properties.PSObject.Properties['HardwareInformation.MemorySize']
                if ($dwordProperty) {
                    $memoryBytes = & $convertVideoMemoryToBytes $dwordProperty.Value
                    if ($memoryBytes -gt 0) { $memorySource = 'Registro DWORD (limitado)' }
                }
            }

            # Ignorar valores imposibles o claves que no informan memoria.
            if ($memoryBytes -gt 0 -and $memoryBytes -le 256GB) {
                $driverNameProperty = $properties.PSObject.Properties['DriverDesc']
                $adapterNameProperty = $properties.PSObject.Properties['HardwareInformation.AdapterString']
                $matchingIdProperty = $properties.PSObject.Properties['MatchingDeviceId']
                $registryName = if ($adapterNameProperty -and $adapterNameProperty.Value) {
                    [string]$adapterNameProperty.Value
                } elseif ($driverNameProperty -and $driverNameProperty.Value) {
                    [string]$driverNameProperty.Value
                } else {
                    ""
                }

                $gpuRegistryEntries.Add([PSCustomObject]@{
                    Name       = $registryName
                    MatchingId = if ($matchingIdProperty) { [string]$matchingIdProperty.Value } else { "" }
                    Bytes      = $memoryBytes
                    Source     = $memorySource
                }) | Out-Null
            }
        } catch {
            # Algunos subdispositivos no permiten leer todas sus propiedades.
        }
    }

    $displayClassRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    if (Test-Path -LiteralPath $displayClassRoot) {
        @(Get-ChildItem -LiteralPath $displayClassRoot -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^\d{4}$' }) | ForEach-Object {
                & $addGpuRegistryEntry $_
            }
    }

    $videoControlRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Video'
    if (Test-Path -LiteralPath $videoControlRoot) {
        @(Get-ChildItem -LiteralPath $videoControlRoot -ErrorAction SilentlyContinue) | ForEach-Object {
            @(Get-ChildItem -LiteralPath $_.PSPath -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -match '^\d{4}$' }) | ForEach-Object {
                    & $addGpuRegistryEntry $_
                }
        }
    }

    $gpuInfo = try {
        $gpuControllers = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop)
        @($gpuControllers | ForEach-Object {
            $controller = $_
            $controllerName = [string]$controller.Name
            $normalizedControllerName = & $normalizeGpuName $controllerName
            [uint64]$vramBytes = 0
            $vramSource = "No disponible"

            # Primera opcion: valor exacto del controlador NVIDIA.
            $nvidiaMatch = @($nvidiaMemory | Where-Object {
                $normalizedNvidiaName = & $normalizeGpuName ([string]$_.Name)
                -not [string]::IsNullOrWhiteSpace($normalizedNvidiaName) -and
                -not [string]::IsNullOrWhiteSpace($normalizedControllerName) -and
                ($normalizedNvidiaName -eq $normalizedControllerName -or
                 $normalizedNvidiaName.Contains($normalizedControllerName) -or
                 $normalizedControllerName.Contains($normalizedNvidiaName))
            } | Select-Object -First 1)
            if ($nvidiaMatch.Count -gt 0) {
                $vramBytes = [uint64]$nvidiaMatch[0].Bytes
                $vramSource = "NVIDIA-SMI"
            }

            # Segunda opcion: DXDiag, neutral entre fabricantes.
            if ($vramBytes -eq 0) {
                $dxdiagMatch = @($dxdiagMemory | Where-Object {
                    $normalizedDxName = & $normalizeGpuName ([string]$_.Name)
                    -not [string]::IsNullOrWhiteSpace($normalizedDxName) -and
                    -not [string]::IsNullOrWhiteSpace($normalizedControllerName) -and
                    ($normalizedDxName -eq $normalizedControllerName -or
                     $normalizedDxName.Contains($normalizedControllerName) -or
                     $normalizedControllerName.Contains($normalizedDxName))
                } | Select-Object -First 1)
                if ($dxdiagMatch.Count -gt 0) {
                    $vramBytes = [uint64]$dxdiagMatch[0].Bytes
                    $vramSource = [string]$dxdiagMatch[0].Source
                }
            }

            # Tercera opcion: QWORD del registro, relacionado por PNP o nombre.
            if ($vramBytes -eq 0) {
                $controllerPnpId = ([string]$controller.PNPDeviceID).ToLowerInvariant()
                $registryMatches = @($gpuRegistryEntries | ForEach-Object {
                    $entry = $_
                    $score = 0
                    $entryMatchingId = ([string]$entry.MatchingId).ToLowerInvariant()
                    $normalizedEntryName = & $normalizeGpuName ([string]$entry.Name)
                    if (-not [string]::IsNullOrWhiteSpace($entryMatchingId) -and $controllerPnpId.StartsWith($entryMatchingId)) {
                        $score = 100
                    } elseif (-not [string]::IsNullOrWhiteSpace($normalizedEntryName) -and
                              -not [string]::IsNullOrWhiteSpace($normalizedControllerName) -and
                              ($normalizedEntryName -eq $normalizedControllerName -or
                               $normalizedEntryName.Contains($normalizedControllerName) -or
                               $normalizedControllerName.Contains($normalizedEntryName))) {
                        $score = 50
                    }
                    if ($score -gt 0) {
                        [PSCustomObject]@{ Score = $score; Entry = $entry }
                    }
                } | Sort-Object @{Expression='Score'; Descending=$true}, @{Expression={$_.Entry.Bytes}; Descending=$true})

                if ($registryMatches.Count -gt 0) {
                    $vramBytes = [uint64]$registryMatches[0].Entry.Bytes
                    $vramSource = [string]$registryMatches[0].Entry.Source
                }
            }

            # Ultimo recurso. Este campo puede truncarse por encima de 4 GB.
            if ($vramBytes -eq 0 -and $controller.AdapterRAM) {
                $vramBytes = & $convertVideoMemoryToBytes $controller.AdapterRAM
                if ($vramBytes -gt 0) { $vramSource = "CIM AdapterRAM (limitado a 32 bits)" }
            }

            $vramGB = if ($vramBytes -gt 0) { [math]::Round($vramBytes / 1GB, 2) } else { $null }
            $isVirtualAdapter = ([string]$controller.PNPDeviceID -match '^(?i:ROOT|SWD|RDP|UMB)\\') -or
                ($controllerName -match '(?i)remote|virtual|mirror|indirect display')
            $isReliableVram = $vramSource -in @(
                'NVIDIA-SMI', 'DXDiag DedicatedMemory',
                'DXDiag DisplayMemory - SharedMemory', 'Registro QWORD (64 bits)'
            )
            [PSCustomObject]@{
                Name          = $controllerName
                DriverVersion = $controller.DriverVersion
                PNPDeviceID   = $controller.PNPDeviceID
                IsPhysicalAdapter = -not $isVirtualAdapter
                VRAM_Bytes    = $vramBytes
                VRAM_GB       = $vramGB
                VRAM_Display  = if ($null -ne $vramGB) { "$vramGB GB" } else { "No disponible" }
                VRAM_Source   = $vramSource
                VRAM_Reliable = $isReliableVram
            }
        })
    } catch {
        Write-Warning "No se pudo consultar la informacion de video: $($_.Exception.Message)"
        @()
    }

    # Win32_VideoController puede repetir el mismo adaptador (por ejemplo, por
    # sesiones remotas o capas del controlador). Se conserva una sola entrada
    # por PNP y, ante duplicados, la que tenga la mejor lectura de VRAM.
    $gpuInfo = @($gpuInfo |
        Group-Object {
            if (-not [string]::IsNullOrWhiteSpace([string]$_.PNPDeviceID)) {
                ([string]$_.PNPDeviceID).ToUpperInvariant()
            } else {
                'NAME:' + (& $normalizeGpuName ([string]$_.Name))
            }
        } |
        ForEach-Object {
            $_.Group | Sort-Object @{Expression='VRAM_Reliable'; Descending=$true}, @{Expression='VRAM_Bytes'; Descending=$true} | Select-Object -First 1
        })

    $physicalGpuInfo = @($gpuInfo | Where-Object { $_.IsPhysicalAdapter })
    $unknownReliableVram = @($physicalGpuInfo | Where-Object { -not $_.VRAM_Reliable -or $_.VRAM_Bytes -le 0 })
    [uint64]$totalVramBytes = 0
    foreach ($gpuAdapter in $physicalGpuInfo) {
        if ($gpuAdapter.VRAM_Bytes -gt 0) { $totalVramBytes += [uint64]$gpuAdapter.VRAM_Bytes }
    }
    $totalVramDisplay = if ($physicalGpuInfo.Count -gt 0 -and $unknownReliableVram.Count -eq 0 -and $totalVramBytes -gt 0) {
        "$([math]::Round($totalVramBytes / 1GB, 2)) GB"
    } elseif ($unknownReliableVram.Count -gt 0) {
        "No disponible: faltan datos fiables para $($unknownReliableVram.Count) adaptador(es)"
    } else {
        "No disponible"
    }
    if ($unknownReliableVram.Count -gt 0) { $totalVramBytes = 0 }

    $placaBase = try {
        @(Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop |
            Select-Object Manufacturer, Product, SerialNumber)
    } catch {
        @()
    }
    $biosInfo = try {
        $biosVersion = (Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SMBIOSBIOSVersion
        $firmwareType = if (Test-Path "$env:windir\Boot\EFI") { 'UEFI' } else { 'Legacy' }
        "Ver. $biosVersion Tipo de Arranque. ($firmwareType)"
    } catch {
        "No disponible"
    }

    # -- Asignacion final al objeto de Hardware --
    $hardwareData = @{
        PlacaBase = $placaBase
        BIOS      = $biosInfo
        GPU       = $gpuInfo
        VRAMTotalBytes   = $totalVramBytes
        VRAMTotalDisplay = $totalVramDisplay
    }

    # -- Estado de Seguridad --
    $antivirusInfo = try {
        @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)
    } catch {
        @()
    }
    $firewallInfo = try {
        @(Get-NetFirewallProfile -ErrorAction Stop)
    } catch {
        @()
    }
    $bitLockerInfo = try {
        $vol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
        if ($vol.ProtectionStatus -eq 'On') {
            "Activado (Proteccion: $($vol.ProtectionStatus))"
        } else {
            "Inactivo (Proteccion: $($vol.ProtectionStatus))"
        }
    } catch {
        "No Disponible"
    }

    $securityData = @{
        Antivirus = $antivirusInfo
        Firewall  = $firewallInfo
        BitLocker = $bitLockerInfo
    }    
    
    # -- Discos y Red --
    $diskData = try { @(Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 } | ForEach-Object {
        [PSCustomObject]@{
            Dispositivo = $_.DeviceID; Nombre = $_.VolumeName; Tipo = $_.FileSystem
            TamanoTotalGB = [math]::Round($_.Size / 1GB, 2); EspacioLibreGB = [math]::Round($_.FreeSpace / 1GB, 2)
            UsoPorc = if ($_.Size -gt 0) { [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2) } else { 0 }
        }
    }) } catch { Write-Warning "No se pudieron leer discos logicos: $($_.Exception.Message)"; @() }
    $networkData = try { @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, ifIndex, InterfaceDescription, Status, MacAddress, LinkSpeed) } catch { @() }

    # -- OS Config y Procesos --
    $hotfixes = try {
        @(Get-HotFix -ErrorAction Stop | Sort-Object -Property InstalledOn -Descending | Select-Object -First 15)
    } catch {
        @()
    }
    $topCPU = try {
        @(Get-Process -ErrorAction Stop | Sort-Object -Property CPU -Descending | Select-Object -First 5 Name, Id, CPU)
    } catch {
        @()
    }
    $topMemory = try {
        @(Get-Process -ErrorAction Stop |
            Sort-Object -Property WorkingSet -Descending |
            Select-Object -First 5 Name, Id, @{Name="Memoria_MB"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}})
    } catch {
        @()
    }

    $osConfigData = @{
        Hotfixes  = $hotfixes
        TopCPU    = $topCPU
        TopMemory = $topMemory
    }

    # -- Software --
    $uninstallPaths = @(
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $classicSoftware = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
        Select-Object DisplayName, DisplayVersion, Publisher, @{
            Name = 'InstallDate'
            Expression = {
                if ($_.InstallDate -and $_.InstallDate -match '^\d{8}$') {
                    try { [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd') }
                    catch { $_.InstallDate }
                } else { $_.InstallDate }
            }
        }, @{N='Source';E={'Registry'}} | Where-Object { $_.DisplayName }
    $appxSoftware = try {
        @(Get-AppxPackage -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{ DisplayName=$_.Name; DisplayVersion=$_.Version; Publisher=$_.Publisher; InstallDate=$null; Source='AppX' }
        })
    } catch { @() }
    $softwareData = @($classicSoftware) + @($appxSoftware) |
        Group-Object { "$($_.DisplayName)|$($_.DisplayVersion)|$($_.Publisher)" } |
        ForEach-Object { $_.Group | Select-Object -First 1 } | Sort-Object DisplayName

    # -- Salud Discos Fisicos --
    $physicalDiskData = try { @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
        $physicalDisk = $_
        $healthText = switch ($physicalDisk.HealthStatus) {
            'Healthy'   { 'Saludable' }
            'Warning'   { 'Advertencia' }
            'Unhealthy' { 'No saludable' }
            default     { [string]$physicalDisk.HealthStatus }
        }
        $reliability = try { Get-StorageReliabilityCounter -PhysicalDisk $physicalDisk -ErrorAction Stop } catch { $null }
        [PSCustomObject]@{
            FriendlyName=$physicalDisk.FriendlyName; MediaType=$physicalDisk.MediaType; SerialNumber=$physicalDisk.SerialNumber
            HealthStatus=$healthText; OperationalStatus=($physicalDisk.OperationalStatus -join ', ')
            Temperature=$(if ($reliability) { $reliability.Temperature } else { $null })
            Wear=$(if ($reliability) { $reliability.Wear } else { $null })
            PowerOnHours=$(if ($reliability) { $reliability.PowerOnHours } else { $null })
            ReadErrorsTotal=$(if ($reliability) { $reliability.ReadErrorsTotal } else { $null })
            WriteErrorsTotal=$(if ($reliability) { $reliability.WriteErrorsTotal } else { $null })
            HealthSource=$(if ($reliability) { 'Storage Reliability Counter' } else { 'Storage HealthStatus' })
        }
    }) } catch { Write-Warning "No se pudo leer la salud de discos fisicos: $($_.Exception.Message)"; @() }

    # -- Detalles RAM, Usuarios, Puertos --
    $ramDetails = try { @(Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | Select-Object DeviceLocator, Manufacturer, PartNumber, Capacity, Speed) } catch { @() }
    $localUsers = try { @(Get-LocalUser -ErrorAction Stop | Select-Object Name, Enabled, LastLogon) } catch { @() }
    $adminUsers = try {
        $adminGroup = Get-LocalGroup -SID ([System.Security.Principal.SecurityIdentifier]'S-1-5-32-544') -ErrorAction Stop
        @(Get-LocalGroupMember -Group $adminGroup.Name -ErrorAction Stop | Select-Object Name, PrincipalSource)
    } catch {
        Write-Warning "No se pudieron consultar los administradores locales: $($_.Exception.Message)"
        @()
    }
    $listeningPorts = try {
        $processesById = @{}
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object { $processesById[[int]$_.ProcessId] = $_ }
        @(Get-NetTCPConnection -State Listen -ErrorAction Stop | ForEach-Object {
            $process = $processesById[[int]$_.OwningProcess]
            [PSCustomObject]@{
                LocalAddress=$_.LocalAddress; LocalPort=$_.LocalPort; OwningProcess=$_.OwningProcess
                ProcessName=$(if ($process) { $process.Name } else { 'No disponible' })
                ProcessPath=$(if ($process) { $process.ExecutablePath } else { $null })
                Scope=$(if ($_.LocalAddress -in @('127.0.0.1','::1')) { 'Solo equipo local' } else { 'Red' })
            }
        } | Sort-Object LocalPort)
    } catch { @() }
    $powerPlanResult = Invoke-AegisNativeProcess -FilePath 'powercfg.exe' -ArgumentList @('/getactivescheme') -TimeoutSeconds 30 -NoThrow
    $powerPlan = if ($powerPlanResult.Succeeded -and ($powerPlanResult.StdOut -match '\((.*?)\)')) {
        $matches[1]
    } elseif ($powerPlanResult.Succeeded) {
        $powerPlanResult.StdOut.Trim()
    } else {
        "No disponible"
    }

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

    $E = { param($Value) ConvertTo-AegisHtmlSafe -Value $Value }

    # --- Paleta de colores y CSS rediseñados ---
    $head = @"
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Inventario - Aegis Phoenix Suite</title>
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
            --success-color: #1e8449;
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
    $body += "<p class='timestamp'>Generado el: $(& $E $InventoryData.ReportDate) para el equipo $(& $E $InventoryData.System.Hostname)</p>"

    # Funcion interna para generar barras de progreso
    function Get-ProgressBarHtml($value) {
        $color = if ($value -gt 90) { 'var(--danger-color)' } elseif ($value -gt 75) { 'var(--warning-color)' } else { 'var(--primary-color)' }
        return "<div class='progress-container'><div class='progress-bar' style='width: $($value)%; background-color: $($color);'></div></div>"
    }

    # -- Secciones --
    $body += "<div class='section' id='sistema'><h2><i class='fas fa-desktop'></i>Sistema Operativo y CPU</h2><div class='grid-container'>"
    $body += "<div><span class='info-label'>Sistema:</span> $(& $E $InventoryData.System.WindowsVersion)</div>"
    $body += "<div><span class='info-label'>Procesador:</span> $(& $E $InventoryData.System.Procesador)</div>"
    $body += "<div><span class='info-label'>Nucleos:</span> $(& $E $InventoryData.System.Nucleos)</div>"
    $body += "<div><span class='info-label'>Tiempo de Actividad:</span> $(& $E $InventoryData.System.Uptime)</div>"
    $body += "<div><span class='info-label'>Memoria RAM Instalada:</span> $($InventoryData.System.MemoriaTotalGB) GB $($InventoryData.System.MemoriaEnUsoPorc)% Usado" + (Get-ProgressBarHtml($InventoryData.System.MemoriaEnUsoPorc)) + "</div>"
	$body += "<div><span class='info-label'>Capacidad Maxima Soportada (segun BIOS):</span> <strong>$($InventoryData.System.MemoriaMaxGB) GB</strong></div>"
    $body += "</div></div>"

    $body += "<div class='section' id='hardware'><h2><i class='fas fa-microchip'></i>Hardware Detallado</h2><div class='grid-container'>"
    $body += "<div><span class='info-label'>Placa Base:</span> $(& $E $InventoryData.Hardware.PlacaBase.Manufacturer) $(& $E $InventoryData.Hardware.PlacaBase.Product)</div>"
    $body += "<div><span class='info-label'>BIOS:</span> $(& $E $InventoryData.Hardware.BIOS)</div>"
    $body += "<div><span class='info-label'>VRAM dedicada total detectada:</span> <strong>$(& $E $InventoryData.Hardware.VRAMTotalDisplay)</strong></div>"
    foreach ($gpu in $InventoryData.Hardware.GPU) {
        $body += "<div><span class='info-label'>GPU:</span> $(& $E $gpu.Name) ($(& $E $gpu.VRAM_Display) VRAM; fuente: $(& $E $gpu.VRAM_Source))</div>"
        $body += "<div><span class='info-label'>Driver de Video:</span> $(& $E $gpu.DriverVersion)</div>"
    }
    $body += "</div></div>"

    # --- MODULOS DE RAM ---
    $body += "<div class='section' id='ram'><h2><i class='fas fa-memory'></i>Modulos de Memoria RAM</h2><table id='ramTable'><thead><tr><th>Ranura (Slot)</th><th>Fabricante</th><th>No. de Serie</th><th>Capacidad (GB)</th><th>Velocidad (MHz)</th></tr></thead><tbody>"
        foreach ($ram in $InventoryData.RAMDetails) {
    $body += "<tr><td>$(& $E $ram.DeviceLocator)</td><td>$(& $E $ram.Manufacturer)</td><td>$(& $E $ram.PartNumber)</td><td>$([math]::Round($ram.Capacity / 1GB, 2))</td><td>$(& $E $ram.Speed)</td></tr>"
    }
    $body += "</tbody></table></div>"

    # --- CUENTAS DE USUARIO Y ADMINS ---
    $body += "<div class='section' id='usuarios'><h2><i class='fas fa-users-cog'></i>Cuentas de Usuario y Administradores</h2><div class='grid-container'>"
    $body += "<div><h3>Cuentas Locales</h3><div class='search-box'><input type='text' id='userSearch' onkeyup=`"searchTable('userSearch', 'userTable')`" placeholder='Buscar usuario...'></div><table id='userTable'><thead><tr><th>Nombre</th><th>Habilitado</th><th>Ultimo Inicio de Sesion</th></tr></thead><tbody>"
        foreach($user in $InventoryData.LocalUsers){ $body += "<tr><td>$(& $E $user.Name)</td><td>$(& $E $user.Enabled)</td><td>$(& $E $user.LastLogon)</td></tr>" }
    $body += "</tbody></table></div>"
    $body += "<div><h3>Miembros del Grupo de Administradores</h3><div class='search-box'><input type='text' id='adminSearch' onkeyup=`"searchTable('adminSearch', 'adminTable')`" placeholder='Buscar administrador...'></div><table id='adminTable'><thead><tr><th>Nombre</th><th>Origen</th></tr></thead><tbody>"
        foreach($admin in $InventoryData.AdminUsers){ $body += "<tr><td>$(& $E $admin.Name)</td><td>$(& $E $admin.PrincipalSource)</td></tr>" }
    $body += "</tbody></table></div></div></div>"

    # --- PLAN DE ENERGIA ---
    $body += "<div class='section' id='energia'><h2><i class='fas fa-bolt'></i>Plan de Energia Activo</h2><p>$(& $E $InventoryData.PowerPlan)</p></div>"

    # --- PUERTOS ABIERTOS ---
    $body += "<div class='section' id='puertos'><h2><i class='fas fa-network-wired'></i>Puertos de Red Abiertos (Escuchando)</h2><div class='search-box'><input type='text' id='portSearch' onkeyup=`"searchTable('portSearch', 'portTable')`" placeholder='Buscar por puerto o proceso...'></div><table id='portTable'><thead><tr><th>Direccion Local</th><th>Puerto</th><th>Proceso</th><th>PID</th><th>Alcance</th></tr></thead><tbody>"
        foreach ($port in $InventoryData.ListeningPorts) {
    $body += "<tr><td>$(& $E $port.LocalAddress)</td><td>$(& $E $port.LocalPort)</td><td title='$(& $E $port.ProcessPath)'>$(& $E $port.ProcessName)</td><td>$(& $E $port.OwningProcess)</td><td>$(& $E $port.Scope)</td></tr>"
    }
    $body += "</tbody></table></div>"

    $body += "<div class='section' id='seguridad'><h2><i class='fas fa-lock'></i>Estado de Seguridad</h2><div class='grid-container'>"
    $avNames = if ($InventoryData.Security.Antivirus) { ($InventoryData.Security.Antivirus.displayName -join ', ') } else { 'No Detectado' }
    $body += "<div><span class='info-label'>Antivirus Registrado:</span> $(& $E $avNames)</div>"
    $firewallStatus = ($InventoryData.Security.Firewall | ForEach-Object { "$($_.Name): $(if($_.Enabled){'Activado'}else{'Desactivado'})" }) -join ' | '
    $body += "<div><span class='info-label'>Firewall:</span> $(& $E $firewallStatus)</div>"
    $body += "<div><span class='info-label'>Cifrado de Disco (BitLocker):</span> $(& $E $InventoryData.Security.BitLocker)</div>"
    $body += "</div></div>"

    $body += "<div class='section' id='discos'><h2><i class='fas fa-hdd'></i>Discos</h2><div class='search-box'><input type='text' id='disksSearch' onkeyup=`"searchTable('disksSearch', 'disksTable')`" placeholder='Buscar en discos...'></div><table id='disksTable'><thead><tr><th>Dispositivo</th><th>Tipo</th><th>Tamano (GB)</th><th>Libre (GB)</th><th>Uso</th></tr></thead><tbody>"
        foreach ($disk in $InventoryData.Disks) { $body += "<tr><td>$(& $E $disk.Dispositivo) ($(& $E $disk.Nombre))</td><td>$(& $E $disk.Tipo)</td><td>$($disk.TamanoTotalGB)</td><td>$($disk.EspacioLibreGB)</td><td>$($disk.UsoPorc)%" + (Get-ProgressBarHtml($disk.UsoPorc)) + "</td></tr>" }
    $body += "</tbody></table></div>"
	
	# ---salud de discos fisicos ---
    $body += "<div class='section' id='salud-discos'><h2><i class='fas fa-heartbeat'></i>Salud de almacenamiento</h2><div class='search-box'><input type='text' id='smartSearch' onkeyup=`"searchTable('smartSearch', 'smartTable')`" placeholder='Buscar por nombre o estado...'></div><table id='smartTable'><thead><tr><th>Nombre</th><th>Tipo</th><th>No. de Serie</th><th>Estado</th><th>Temperatura</th><th>Desgaste</th><th>Horas</th><th>Fuente</th></tr></thead><tbody>"
    foreach ($pdisk in $InventoryData.PhysicalDisks) {
        $healthColor = switch ($pdisk.HealthStatus) {
            'Saludable'   { 'var(--success-color)' }
            'Advertencia' { 'var(--warning-color)' }
            'No saludable' { 'var(--danger-color)' }
            default       { 'var(--main-text-color)' }
        }
        $temperature = if ($null -ne $pdisk.Temperature) { "$($pdisk.Temperature) C" } else { 'N/D' }
        $wear = if ($null -ne $pdisk.Wear) { "$($pdisk.Wear)%" } else { 'N/D' }
        $hours = if ($null -ne $pdisk.PowerOnHours) { $pdisk.PowerOnHours } else { 'N/D' }
        $body += "<tr><td>$(& $E $pdisk.FriendlyName)</td><td>$(& $E $pdisk.MediaType)</td><td>$(& $E $pdisk.SerialNumber)</td><td style='color: $healthColor;'><strong>$(& $E $pdisk.HealthStatus)</strong></td><td>$(& $E $temperature)</td><td>$(& $E $wear)</td><td>$(& $E $hours)</td><td>$(& $E $pdisk.HealthSource)</td></tr>"
    }
    $body += "</tbody></table></div>"
    
    $body += "<div class='section' id='procesos'><h2><i class='fas fa-chart-line'></i>Procesos de Mayor Consumo</h2><div class='grid-container'>"
    $body += "<div><h3>Top 5 por CPU</h3><table><thead><tr><th>Nombre</th><th>CPU</th></tr></thead><tbody>"
    foreach($p in $InventoryData.OSConfig.TopCPU){ $body += "<tr><td>$(& $E $p.Name)</td><td>$(& $E $p.CPU)</td></tr>" }
    $body += "</tbody></table></div>"
    $body += "<div><h3>Top 5 por Memoria</h3><table><thead><tr><th>Nombre</th><th>Memoria (MB)</th></tr></thead><tbody>"
    foreach($p in $InventoryData.OSConfig.TopMemory){ $body += "<tr><td>$(& $E $p.Name)</td><td>$(& $E $p.Memoria_MB)</td></tr>" }
    $body += "</tbody></table></div></div></div>"
    
    $body += "<div class='section' id='updates'><h2><i class='fas fa-history'></i>Ultimas Actualizaciones Instaladas</h2><table><thead><tr><th>ID</th><th>Descripcion</th><th>Fecha</th></tr></thead><tbody>"
    foreach ($hotfix in $InventoryData.OSConfig.Hotfixes) {
        $installedOn = if ($hotfix.InstalledOn) { try { $hotfix.InstalledOn.ToString('yyyy-MM-dd') } catch { [string]$hotfix.InstalledOn } } else { 'No disponible' }
        $body += "<tr><td>$(& $E $hotfix.HotFixID)</td><td>$(& $E $hotfix.Description)</td><td>$(& $E $installedOn)</td></tr>"
    }
    $body += "</tbody></table></div>"

    # --- Instalacion al HTML ---
    $body += "<div class='section' id='software'><h2><i class='fas fa-box-open'></i>Software Instalado ($($InventoryData.Software.Count))</h2>"
    $body += "<div class='search-box'><input type='text' id='softwareSearch' onkeyup='searchSoftware()' placeholder='Buscar software por nombre...'></div>"
    $body += "<table id='softwareTable'><thead><tr><th>Nombre</th><th>Version</th><th>Editor</th><th>Fecha de Instalacion</th></tr></thead><tbody>"
    foreach ($app in $InventoryData.Software) {
        $body += "<tr><td>$(& $E $app.DisplayName)</td><td>$(& $E $app.DisplayVersion)</td><td>$(& $E $app.Publisher)</td><td>$(& $E $app.InstallDate)</td></tr>"
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
            $reportContent += "VRAM total       : $($inventoryData.Hardware.VRAMTotalDisplay)"
            foreach ($gpu in $inventoryData.Hardware.GPU) {
                $reportContent += "GPU              : $($gpu.Name) ($($gpu.VRAM_Display) VRAM; fuente: $($gpu.VRAM_Source))"
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