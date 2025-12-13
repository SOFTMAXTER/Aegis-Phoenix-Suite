# --- CATALOGO DE BLOATWARE Y APPS PROTEGIDAS ---

# 1. LISTA BLANCA (Protegidas)
# Previene que se eliminen componentes criticos del sistema.
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

# 2. LISTA DE RECOMENDADOS (Bloatware Seguro de Borrar)
# Apps que generalmente no afectan la estabilidad si se eliminan.
$script:RecommendedBloatwareList = @(
    'Microsoft.Microsoft3DViewer',
    'Microsoft.BingSearch',
    'Microsoft.WindowsAlarms',
    'Microsoft.549981C3F5F10',
    'Microsoft.Windows.DevHome',
    'MicrosoftCorporationII.MicrosoftFamily',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.Edge.GameAssist',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'microsoft.windowscommunicationsapps',
    'Microsoft.WindowsMaps',
    'Microsoft.MixedReality.Portal',
    'Microsoft.BingNews',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.Office.OneNote',
    'Microsoft.MSPaint', # Nota: A veces util, pero seguro de borrar
    'Microsoft.People',
    'Microsoft.PowerAutomateDesktop',
    'Microsoft.SkypeApp',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MicrosoftStickyNotes',
    'MicrosoftTeams',
    'MSTeams',
    'Microsoft.Todos',
    'Microsoft.Wallet',
    'Microsoft.BingWeather',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxApp',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.GamingApp',
    'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo'
)
