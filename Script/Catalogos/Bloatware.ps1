# --- CATALOGO DE APLICACIONES PROTEGIDAS ---
# Esta lista previene que el modulo de Bloatware
# desinstale aplicaciones de sistema criticas o esenciales.

$script:ProtectedAppList = @(
    "Microsoft.WindowsStore",
    "Microsoft.WindowsCalculator",
    "Microsoft.Windows.Photos",
    "Microsoft.Windows.Camera",
    "Microsoft.SecHealthUI",
    "Microsoft.UI.Xaml",
    "Microsoft.VCLibs",
    "Microsoft.NET.Native",
    "Microsoft.WebpImageExtension",
    "Microsoft.HEIFImageExtension",
    "Microsoft.VP9VideoExtensions",
    "Microsoft.ScreenSketch",
    "Microsoft.WindowsTerminal",
    "Microsoft.Paint",
    "Microsoft.WindowsNotepad"
)