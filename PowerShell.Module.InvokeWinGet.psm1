
<#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜 
#̷𝓍   
#̷𝓍   PSM1 FILE
#̷𝓍   
#>

    $PrivatePaths  = @("$PSScriptRoot\dependencies","$PSScriptRoot\src")
    $PrivateScripts = @()
    Foreach($path in $PrivatePaths){
        $PrivateScripts += @( Get-ChildItem -Path $path -Filter '*.ps1' -File ).Fullname
    }
    
    $PrivatesCount = $PrivateScripts.Count

    $ImportErrors = 0
    $CurrentIndex = 0
    #Dot source the files
    Foreach ($FilePath in $PrivateScripts) {
        Try {
            $CurrentIndex++
            . "$FilePath"
            Write-Verbose "✅ $FilePath [$CurrentIndex/$PrivatesCount]"
        }  
        Catch {
            $ImportErrors++
            Write-Host "❗❗❗ $FilePath [$CurrentIndex/$PrivatesCount]" -f DarkYellow -n
            Write-Host " ERRORS [$ImportErrors/$PrivatesCount]" -f DarkRed
            
        }
    }

    if($Global:ImportErrors -gt 0){
        Write-Host -n "❗❗❗ "
        Write-Host "$ImportErrors errors on $CurrentIndex scripts loaded." -f DarkYellow
    }

