# --- CATALOGO CENTRAL DE SERVICIOS ---
# Define todos los servicios gestionables, su proposito, categoria y estado por defecto.
# Esto hace que la funcion sea facilmente extensible.
$script:ServiceCatalog = @(
    # Categoria: Estandar (Servicios que a menudo se pueden desactivar para liberar recursos)
    [PSCustomObject]@{
        Name               = "Fax"
        Description        = "Permite enviar y recibir faxes. Innecesario si no se usa un modem de fax."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "PrintSpooler"
        Description        = "Gestiona los trabajos de impresion. Desactivar si no se utiliza ninguna impresora (fisica o virtual como PDF)."
        Category           = "Estandar"
        DefaultStartupType = "Automatic"
    },
    [PSCustomObject]@{
        Name               = "RemoteRegistry"
        Description        = "Permite a usuarios remotos modificar el registro. Se recomienda desactivarlo por seguridad."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "SysMain"
        Description        = "Mantiene y mejora el rendimiento del sistema (antes Superfetch). Puede causar uso de disco en HDD."
        Category           = "Estandar"
        DefaultStartupType = "Automatic"
    },
    [PSCustomObject]@{
        Name               = "TabletInputService" # CORRECCIoN: Este es el nombre de servicio real.
        Description        = "Habilita el teclado tactil y el panel de escritura. Innecesario en equipos de escritorio sin pantalla tactil."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
	},
    [PSCustomObject]@{
        Name               = "WalletService"
        Description        = "Servicio del sistema para la Cartera de Windows. Innecesario si no se utiliza."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
    },
	[PSCustomObject]@{
        Name               = "wisvc"
        Description        = "Gestiona la participacion en el programa Windows Insider. Innecesario si no se usan compilaciones de prueba."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
	},
	[PSCustomObject]@{
        Name               = "AJRouter"
        Description        = "Relacionado con la comunicacion de dispositivos IoT (Internet de las Cosas). Innecesario para la mayoria de usuarios."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
	},	
	[PSCustomObject]@{
        Name               = "MapsBroker"
        Description        = "Para la aplicacion 'Mapas de Windows'. Si usas otros servicios de mapas (Google/Waze), es innecesario."
        Category           = "Estandar"
        DefaultStartupType = "Automatic"
	},
	[PSCustomObject]@{
        Name               = "icssvc"
        Description        = "Permite compartir una conexion a internet con otros dispositivos (Hotspot movil). Innecesario si no se usa esta funcion."
        Category           = "Estandar"
        DefaultStartupType = "Manual"
	},
    [PSCustomObject]@{
        Name               = "WSearch"
        Description        = "Proporciona indexacion de contenido y resultados de busqueda para archivos, correo y otro contenido."
        Category           = "Estandar"
        DefaultStartupType = "Automatic"
    },
    # Categoria: Avanzado/Opcional (Servicios para funciones especificas)
    [PSCustomObject]@{
        Name               = "TermService"
        Description        = "Permite a los usuarios conectarse de forma remota al equipo usando Escritorio Remoto."
        Category           = "Avanzado"
        DefaultStartupType = "Manual"
    },
    [PSCustomObject]@{
        Name               = "WMPNetworkSvc"
        Description        = "Comparte bibliotecas de Windows Media Player con otros dispositivos de la red."
        Category           = "Avanzado"
        DefaultStartupType = "Manual"
    },
	[PSCustomObject]@{
        Name               = "DiagTrack"
        Description        = "Servicio de telemetria principal (Connected User Experiences and Telemetry). Desactivarlo mejora la privacidad."
        Category           = "Avanzado"
        DefaultStartupType = "Automatic"
	},
	[PSCustomObject]@{
        Name               = "lfsvc"
        Description        = "Permite a las aplicaciones acceder a la ubicacion GPS y de red del equipo. Desactivar por privacidad si no se usa."
        Category           = "Avanzado"
        DefaultStartupType = "Manual"
	},
    
	[PSCustomObject]@{
        Name               = "CscService"
        Description        = "Servicio de Archivos sin conexion, para acceder a archivos de red localmente. Innecesario para usuarios domesticos."
        Category           = "Avanzado"
        DefaultStartupType = "Automatic"
	}
)
