# PowerShell.Module.InvokeWinGet

Helper module to invoke the WinGet command in PowerShell and parse the command output.

## Available Command: Invoke-PSWinGet

## How To Use This Module ?

```
    import-module .\PowerShell.Invoke.WinGetCommand.psm1
```

### To Install, I will refer to Microoft's Module Documentation

A this [link](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_modules?view=powershell-7.2)

## COMMANDS -- FUN STUFF :)


### Get list of installed software

```
    pswinget installed
```

### Get list of software online (not installed)

```
    pswinget online <search term>
```

### Get list of software with a new version available (upgradable)

```
    pswinget upgradable
```

### Export list of installed software with information if theres a new version available (in a json file)

```
    pswinget export "PATH to File"
```

#### MORE ON EXPORT

```
    pswinget export "c:\Temp\apps.json"

    # Then later...
    $AppsInfos = Get-Content "c:\Temp\apps.json" | ConvertFrom-Json
    $AppsInfos | % { if($_.NewVersionAvailable) { 
    	Write-Host "Yo $ENV:USERNAME! " -f DarkRed -n
    	Write-Host " YUO NEED TO UPDATE $($_.Name)" -f DarkYellow 
    }}
```