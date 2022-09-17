<#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜 
#̷𝓍   
#̷𝓍   Get-WinGetPakageInfo for WINDOWS POWERSHELL (v5 and +)
#̷𝓍   
#>



Function Get-WinGetExePath {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $wingetCmd = Get-Command 'winget.exe' -ErrorAction Ignore
    if(($wingetCmd -ne $Null ) -And (test-path -Path "$($wingetCmd.Source)" -PathType Leaf)){
        $wingetApp = $wingetCmd.Source
        Write-Verbose "✅ Found winget.exe CMD [$wingetApp]"
        Return $wingetApp 
    }
    $wingetAppxPackage = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller"
    if($wingetAppxPackage -ne $Null ){
        $wingetApp = Join-Path "$($wingetAppxPackage.InstallLocation)" "winget.exe"
        if (test-path -Path "$wingetApp" -PathType Leaf){
            Write-Verbose "✅ Found winget.exe APP PACKAGE PATH [$wingetApp]"
            Return $wingetApp    
        }

    }
    Throw "Could not locate winget.exe"
}

