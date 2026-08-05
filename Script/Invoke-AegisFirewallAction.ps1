[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Block','Unblock')]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [string]$Program
)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'),
        '-Action', $Action, '-Program', ('"' + $Program + '"')
    )
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -ErrorAction Stop | Out-Null
    } catch {
        # El usuario cancelo el prompt de UAC u otro error al elevar; salir sin ruido.
    }
    return
}

$fullPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Program))
if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "El ejecutable no existe: $fullPath" }
if ([IO.Path]::GetExtension($fullPath) -ine '.exe') { throw 'Solo se admiten archivos .exe.' }

$sha = [Security.Cryptography.SHA256]::Create()
try {
    $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($fullPath.ToLowerInvariant()))) -replace '-', '').Substring(0, 20)
} finally { $sha.Dispose() }
$ruleName = "AegisPhoenixBlock_$hash"
$displayName = "Aegis Phoenix - Bloqueo - $([IO.Path]::GetFileName($fullPath))"

if ($Action -eq 'Block') {
    Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction Stop
    New-NetFirewallRule -Name $ruleName -DisplayName $displayName -Direction Outbound -Program $fullPath -Action Block -Enabled True -Profile Any -ErrorAction Stop | Out-Null
} else {
    Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction Stop
}
