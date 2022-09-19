



function Convert-ArrayToAppInfoObjects {
<#  
    .Synopsis
       Repair-WinGetOutput : Gets a string and repair it.
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true, position=0)]
        [system.collections.arraylist]$winget_cmd_results,
        [Parameter(Mandatory=$true, position=1)]
        [system.collections.arraylist]$categories,
        [Parameter(Mandatory=$false)]
        [switch]$LatestVersion
           
    )
    $software_list = [system.collections.arraylist]::new()
    $IndexLine = $winget_cmd_results |  Where-Object {($_ -match $categories[0]) -And ($_ -match $categories[1]) -And ($_ -match $categories[1]) -And ($_ -match $categories[2]) -And ($_ -match $categories[3]) } | Out-String
    
    if($IndexLine -eq $Null){ throw "Can parse command output"}

    # Indexes...
    $id_start = $IndexLine.IndexOf($categories[1])
    $id_verstart = $IndexLine.IndexOf($categories[2])
    $id_lastver = $IndexLine.IndexOf($categories[3])
    $id_srcstart = $IndexLine.IndexOf($categories[4])

    # Max lenght. I did this ecause some packages had HUGE NAMEs, like 'Windows Software Development Kit - WINDOWS SDK - DEV' so I cut them down
    $max_len_name = $id_start - 10
    $max_len_id =  $id_verstart-($id_verstart - $id_start) - 5
    $max_len_ver =  14


    $winget_cmd_results | Select-Object -Skip 1   | Select-Object -SkipLast 1 | ForEach-Object {
        $appname = $_.Substring(0, $id_start).TrimEnd()
        $pattern="^(?<GROUPNAME>[\w\(\) \. \-a-zA-Z0-9\*]{0,35})"
        $appname = Repair-WinGetOutput $appname -max_len $max_len_name # -pattern $pattern

        $appid = $_.Substring($id_start, $id_verstart - $id_start).TrimEnd()
        $pattern = "^(?<Name>[\w\(\) \. \-a-zA-Z0-9\*]{0,35})(\s+)(?<GROUPNAME>[\.\-a-zA-Z0-9]{0,38})"
        $appid = Repair-WinGetOutput $appid -max_len $max_len_id -pattern $pattern

        [string]$curr_ver_str = $_.Substring($id_verstart, $id_lastver - $id_verstart).TrimEnd()
        if("$curr_ver_str" -eq "Unknown"){  $curr_ver_str = "1.0.0"}
        $pattern = "^(?<GROUPNAME>[\.0-9]{0,17})"
        $curr_ver_str = Repair-WinGetOutput $curr_ver_str -max_len $max_len_ver -is_version # -pattern $pattern
        [WinGetPackageVersion]$curr_ver = [WinGetPackageVersion]::new($curr_ver_str)
        
        [string]$avail_ver_str = '0.0.0'
        if($LatestVersion){
            [string]$avail_ver_str = $_.Substring($id_lastver, $id_srcstart - $id_lastver).TrimEnd()
            $pattern = "^(?<GROUPNAME>[\.0-9]{0,17})"
            $avail_ver_str = Repair-WinGetOutput $avail_ver_str -max_len $max_len_ver -is_version # -pattern $pattern
        }
        try{
            $pkg_data = [PSCustomObject]@{
                Name            = [string]$appname
                Id              = [string]$appid
                Version         = [WinGetPackageVersion]$curr_ver
            }
        }catch{
            Write-Warning "Parsing error: `"$_`""
        }
        if($LatestVersion){
            #[WinGetPackageVersion]$avail_ver = [WinGetPackageVersion]::new($avail_ver_str)
            $pkg_data | Add-Member -NotePropertyName LatestVersion -NotePropertyValue $avail_ver_str
        }
        [void]$software_list.Add($pkg_data)
    }

    $software_list
}

function Repair-WinGetOutput {
<#  
    .Synopsis
       Repair-WinGetOutput : Gets a string and repair it.
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true, position=0)]
        [String]$string,
        [Parameter(Mandatory=$false)]
        [int]$max_len=0,
        [Parameter(Mandatory=$false)]
        [String]$pattern="",
        [Parameter(Mandatory=$false)]
        [switch]$is_version,
        [Parameter(Mandatory=$false)]
        [String]$group_name="GROUPNAME"
           
    )
    $new_string = $string
    if($is_version){
        $string = $string.Replace('-','.')
        $new_string = ($string.Replace('<','').Trim().TrimEnd()) # SOME LOCAL VERSION NUMBER ARE GIVEN AS '  < 1.0.11.832' because they are too far behind
        $new_string = $new_string.Substring($new_string.IndexOf(' ')+1) 
        if("$new_String" -ne "$string"){
            Write-Verbose "❗WARNING❗ [reg ex]`tUpdating `"$string`" to `"$new_string`"" 
            $string =$new_string
        }    
    }

    if($PSBoundParameters.ContainsKey('pattern') -eq $True){
        if($string -match $pattern){
            $new_string = $Matches.$group_name
        }
        if("$new_String" -ne "$string"){
            Write-Verbose "❗WARNING❗ [reg ex]`tUpdating `"$string`" to `"$new_string`"" 
            $string =$new_string
        }
    }
    if($PSBoundParameters.ContainsKey('max_len') -eq $True){
        $appname_length = $string.Length 
        if($appname_length -ge $max_len){ 
            $toRemove = $appname_length - $max_len  
            $new_string=$string.Substring(0,($appname_length - $toRemove))
        }
        if("$new_String" -ne "$string"){
            Write-Verbose "❗WARNING❗ [lenght]`tUpdating `"$string`" to `"$new_string`" ($appname_length)" 
            $string =$new_string
        }
    }
    $string
}


function Get-InstalledSoftware {
    <#
    .SYNOPSIS
        Retrieves a list of all software installed
    .EXAMPLE
        Get-InstalledSoftware
        
        This example retrieves all software installed on the local computer
    .PARAMETER Name
        The software title you'd like to limit the query to.
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    $UninstallKeys = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $null = New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS
    $UninstallKeys += Get-ChildItem HKU: -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | ForEach-Object { "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall" }
    if (-not $UninstallKeys) {
        Write-Verbose -Message 'No software registry keys found'
    } else {
        foreach ($UninstallKey in $UninstallKeys) {
            if ($PSBoundParameters.ContainsKey('Name')) {
                $WhereBlock = { ($_.PSChildName -match '^{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}$') -and ($_.GetValue('DisplayName') -imatch $Name) }
            } else {
                $WhereBlock = { ($_.PSChildName -match '^{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}$') -and ($_.GetValue('DisplayName')) }
            }
            $gciParams = @{
                Path        = $UninstallKey
                ErrorAction = 'SilentlyContinue'
            }
            $selectProperties = @(
                @{n='GUID'; e={$_.PSChildName}}, 
                @{n='Name'; e={$_.GetValue('DisplayName')}}
                @{n='Version'; e={$_.GetValue('Version')}}
                @{n='DisplayVersion'; e={$_.GetValue('DisplayVersion')}}
                @{n='VersionMajor'; e={$_.GetValue('VersionMajor')}}
                @{n='VersionMinor'; e={$_.GetValue('VersionMinor')}}
                @{n='UninstallString'; e={$_.GetValue('UninstallString')}}
                @{n='InstallLocation'; e={$_.GetValue('InstallLocation')}}
            )
            Get-ChildItem @gciParams | Where $WhereBlock | Select-Object -Property $selectProperties
        }
    }
}

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

    $wingetApp = Join-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.18.2091.0_x64__8wekyb3d8bbwe" "winget.exe"
    if(test-path $wingetApp){
        return $wingetApp
    }
    Throw "Could not locate winget.exe"
}



Class WinGetPackageVersion : IComparable {
        # Added a GetEnumerator() Override
        [int]$Major  
        [int]$Minor  
        [int]$Build  
        [int]$RevMajor
        [int]$RevMinor
        [int]$VersionBuffer
        [string]ToString() {
            if($($this.RevMajor) -eq 0 -And $($this.RevMinor) -eq 0 -And $($this.VersionBuffer) -eq 0){ return "$($this.Major).$($this.Minor).$($this.Build)"}
            if($($this.RevMinor) -eq 0 -And $($this.VersionBuffer) -eq 0){ return "$($this.Major).$($this.Minor).$($this.Build).$($this.RevMajor)"}
            if($($this.VersionBuffer) -eq 0){ return "$($this.Major).$($this.Minor).$($this.Build).$($this.RevMajor).$($this.RevMinor)"}
                return "$($this.Major).$($this.Minor).$($this.Build).$($this.RevMajor).$($this.RevMinor).$($this.VersionBuffer)"
            }
         [bool] Equals([Object] $other) {
            #
            # Equals() is required for the -eq operator.
            #
              return $this.ToString() -eq $other.ToString()
           }

           [int] CompareTo([Object] $other) {
            #
            # CompareTo() is required for the -lt
            # and -gt operator.
            # 
                [WinGetPackageVersion]$incomingver = $other
    
                if ($incomingver -eq $null){
                    return 1;
                }

                if ($this.Major -ne $incomingver.Major){
                    if( $this.Major -gt $incomingver.Major) { return 1;} else{ return -1;};
                }

                if ($this.Minor -ne $incomingver.Minor){
                    if( $this.Minor -gt $incomingver.Minor) { return 1;} else{ return -1;};
                }

                if ($this.Build -ne $incomingver.Build){
                    if( $this.Build -gt $incomingver.Build) { return 1;} else{ return -1;};
                }

                if ($this.RevMajor -ne $incomingver.RevMajor){
                    if( $this.RevMajor -gt $incomingver.RevMajor) { return 1;} else{ return -1;};
                }

                if ($this.RevMinor -ne $incomingver.RevMinor){
                    if( $this.RevMinor -gt $incomingver.RevMinor) { return 1;} else{ return -1;};
                }

                if ($this.VersionBuffer -ne $incomingver.VersionBuffer){
                    if( $this.VersionBuffer -gt $incomingver.VersionBuffer) { return 1;} else{ return -1;};
                }
                  

                return if($this.GetHashCode() -gt $incomingver.GetHashCode())  { return 1;} else{ return -1;};
           }

           [int] GetHashCode() {
            #
            # An object that overrides the Equals() method
            # should (must?) also override GetHashCode()
            #
              return $this.ToString().GetHashCode();
           }
        [void]Default(){
            $this.Major = 0
            $this.Build = 0
            $this.RevMajor = 0
            $this.RevMinor = 0
            $this.VersionBuffer = 0
        }

        WinGetPackageVersion(){
            $this.Default()
        }

        WinGetPackageVersion([string]$strver){
            if($strver -match 'Unknown'){ $this.Default(); return;}
            $data = $strver.split('.')
            if($data.Count -eq 0){throw "WinGetPackageVersion error"}
            try{
                if($data[0] -ne $Null){ $this.Major = $data[0]}
                if($data[1] -ne $Null){ $this.Minor = $data[1]}
                if($data[2] -ne $Null){ $this.Build = $data[2]}
                if($data[3] -ne $Null){ $this.RevMajor = $data[3]}
                if($data[4] -ne $Null){ $this.RevMinor = $data[4]}
                if($data[5] -ne $Null){ $this.VersionBuffer = $data[5]}
            }catch{
                Write-Verbose "ERROR IN VERSION CONVERSION"
            }

        }
        WinGetPackageVersion([int]$ver_maj, [int]$ver_min, [int]$ver_build=0, [int]$ver_revmaj=0, [int]$ver_revmin=0, [int]$ver_buf=0){
            $this.Major = $ver_maj
            $this.Minor = $ver_min
            $this.Build = $ver_build
            $this.RevMajor = $ver_revmaj
            $this.RevMinor = $ver_revmin
            $this.VersionBuffer = $ver_buf
        }
}


Function Invoke-PSWinGet {

    <#  
        .Synopsis
           invoke the WinGet command in PowerShell and parse the command output.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(

        [ValidateScript({
            $supported_commands = @('l','list', 'installed','s','search', 'online','u','update', 'upgrade','e','export')
            $user_entry = $_.ToLower()
            $Ok = $supported_commands.Contains($user_entry)
            if(-Not ($Ok) ){
                throw "command not supported ($user_entry). Supported Commands are 'l','list', 'installed','s','search', 'online','u','update', 'upgrade','e' and 'export'"
            }
            return $true 
        })]
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('c', 'cmd')]
        [String]$Command,
        [Parameter(Mandatory=$false,Position=1)]
        [String]$Option
    )


    #requires -version 5.0

    # =================================================================
    # sanity checks : validate that dependencies are registered...
    # =================================================================
    try{
        [WinGetPackageVersion]$testver = [WinGetPackageVersion]::new("1.0.0")
        if($testver.Major -ne 1){ throw "Error with WinGetPackageVersion"}
        if((Test-Path "$(Get-WinGetExePath -Verbose:$False)") -ne $true){ throw "Error with WinGetExePath"}
    }catch{
        Write-Error "$_"
        return
    }

    # =================================================================
    # cmd type: easier when its an enum
    # =================================================================
    try{
        Add-Type -ErrorAction Ignore -TypeDefinition @"
           public enum CmdType
           {
                invalid = 0,
                installed,
                online,
                upgradable,
                export
           }
"@  
    }catch{
        Write-Verbose "New Type already added"
    }


    $Script:OutputHack - $False
    [CmdType]$CmdType = [CmdType]::invalid
    $WinGetExe = Get-WinGetExePath

    # try my best to fix the OUTPUT from WinGet...
    $e = "$([char]27)"
    if($Script:OutputHack){
        #hide the cursor
        Write-Host "$e[?25l"  -NoNewline  
        write-host "$($e)[s" -NoNewline
        Write-Host "$e[u" -NoNewline   
    }


    ########################################
    # REGEX USEFUL FOR PARSING MY OUTPUT....
    # package info (well-formed)
    $ptrn_pkinf = "^(?<Name>[\w\(\) \. \-a-zA-Z0-9\*]{0,35})(\s+)(?<Id>[\.\-a-zA-Z0-9]{0,38})(\s+)(?<Version>[\.\-a-zA-Z0-9]{0,38})(\s+)(?<NewVersion>[\.\-a-zA-Z0-9]{0,38})"
    # package title
    $ptrn_title = "^(?<Name>Name)(\s*)(?<Id>Id)(\s*)(?<Version>Version)(\s*)(?<Available>Available)"
    # unicode garage that I experiened... may be different at your place. I filter out the trash with this.
    $poo_unicd  ="^(?<UNICODE00>[\u00C0-\u00FF]*)(\s+)(?<UNICODE01>[\u00C0-\u00FF]*)(\s*)(?<Version>[\.0-9]{0,5})(\s*)(?<LatestVersion>[\.0-9]{0,5})"
    # ascii garbage foobar
    $poo_ascii  ="^(?<ASCII00>[\x2D]*)(\s+)(?<ASCII01>[\x2D]*)(\s*)(?<ASCII02>[\x2D]*)(\s*)(?<ASCII03>[\x2D]*)"
    $winget_cmd_results = [system.collections.arraylist]::new()

    $categories = [system.collections.arraylist]::new()
    [void]$categories.Add('Name')
    [void]$categories.Add('Id')
    [void]$categories.Add('Version')
    [void]$categories.Add('Available')
    [void]$categories.Add('Source')
    switch($Command.ToLower()){


        { 'l','list', 'installed' -eq $_ }   {
            [CmdType]$CmdType = [CmdType]::installed

            # Call command AND PARSE the output
            &"$WinGetExe"  "list"  | out-string -stream | foreach-object{ 
                $line = "$_`n"
                # NICE TO HAVE, replace the PROGRESS characters... suck but no go with MSPOWERSHELLv5, just works with core. Fuck it.
                #$line = $line.Replace("-\\|/┤┘┴└├┌┬┐⠂-–—–-", "$e[u")
                if(($line -notmatch $poo_unicd) -and ($line -notmatch $poo_ascii) ){ 
                    if($line -match $ptrn_title) { 
                        [void]$winget_cmd_results.Add($line);  
                    }elseif($line -match $ptrn_pkinf) { 
                        [void]$winget_cmd_results.Add($line);  
                    }
                }
            }
        }

        { 's','search', 'online' -eq $_ }    {
            [CmdType]$CmdType = [CmdType]::online
            if($PSBoundParameters.ContainsKey('Option') -eq $False){ throw "Command 'search/online' requires search argument"}
            $categories = [system.collections.arraylist]::new()
            [void]$categories.Add('Name')
            [void]$categories.Add('Id')
            [void]$categories.Add('Version')
            [void]$categories.Add('Match')
            [void]$categories.Add('Source')
            $ptrn_title = "^(?<Name>Name)(\s*)(?<Id>Id)(\s*)(?<Version>Version)(\s*)(?<Match>Match)(\s*)(?<Source>Source)"
            $ptrn_pkinf = "^(?<Name>[\w\(\) \. \-a-zA-Z0-9\*]{0,35})(\s+)(?<Id>[\.\-a-zA-Z0-9]{0,38})(\s+)(?<Version>[\.\-a-zA-Z0-9]{0,38})(\s+)(?<Match>[\:\-a-zA-Z0-9 ]{0,38})(\s+)(?<Source>[a-zA-Z0-9]{0,10})"

            # Call command AND PARSE the output
            &"$WinGetExe"  "search" "$Option" | out-string -stream | foreach-object{ 
                $line = "$_`n"
                # NICE TO HAVE, replace the PROGRESS characters... suck but no go with MSPOWERSHELLv5, just works with core. Fuck it.
                #$line = $line.Replace("-\\|/┤┘┴└├┌┬┐⠂-–—–-", "$e[u")
                if(($line -notmatch $poo_unicd) -and ($line -notmatch $poo_ascii) ){ 
                    if($line -match $ptrn_title) { 
                        [void]$winget_cmd_results.Add($line);  
                    }elseif($line -match $ptrn_pkinf) { 
                        [void]$winget_cmd_results.Add($line);  
                    }
                }
            }
        }


        { 'u','update', 'upgrade' -eq $_ } {
            [CmdType]$CmdType = [CmdType]::upgradable
            &"$WinGetExe"  "upgrade" "--include-unknown"  | out-string -stream | foreach-object{ 
                $line = "$_`n"
                # NICE TO HAVE, replace the PROGRESS characters... suck but no go with MSPOWERSHELLv5, just works with core. Fuck it.
                #$line = $line.Replace("-\\|/┤┘┴└├┌┬┐⠂-–—–-", "$e[u")
                if(($line -notmatch $poo_unicd) -and ($line -notmatch $poo_ascii) ){ 
                    if($line -match $ptrn_title) { 
                        [void]$winget_cmd_results.Add($line);  
                    }elseif($line -match $ptrn_pkinf) { 
                        [void]$winget_cmd_results.Add($line);  
                    }
                }
            }
        }

        { 'e','export' -eq $_ } {
            [CmdType]$CmdType = [CmdType]::export
            if($PSBoundParameters.ContainsKey('Option') -eq $False){ throw "Command 'export' requires file path argument"}
            $upgrade_cmd_results = [system.collections.arraylist]::new()
            # Call command AND PARSE the output
            &"$WinGetExe"  "list"  | out-string -stream | foreach-object{ 
                $line = "$_`n"
                # NICE TO HAVE, replace the PROGRESS characters... suck but no go with MSPOWERSHELLv5, just works with core. Fuck it.
                #$line = $line.Replace("-\\|/┤┘┴└├┌┬┐⠂-–—–-", "$e[u")
                if(($line -notmatch $poo_unicd) -and ($line -notmatch $poo_ascii) ){ 
                    if($line -match $ptrn_title) { 
                        [void]$winget_cmd_results.Add($line);  
                    }elseif($line -match $ptrn_pkinf) { 
                        [void]$winget_cmd_results.Add($line);  
                    }
                }
            }
            &"$WinGetExe"  "upgrade" "--include-unknown"  | out-string -stream | foreach-object{ 
                $line = "$_`n"
                # NICE TO HAVE, replace the PROGRESS characters... suck but no go with MSPOWERSHELLv5, just works with core. Fuck it.
                #$line = $line.Replace("-\\|/┤┘┴└├┌┬┐⠂-–—–-", "$e[u")
                if(($line -notmatch $poo_unicd) -and ($line -notmatch $poo_ascii) ){ 
                    if($line -match $ptrn_title) { 
                        [void]$upgrade_cmd_results.Add($line);  
                    }elseif($line -match $ptrn_pkinf) { 
                        [void]$upgrade_cmd_results.Add($line);  
                    }
                }
            }

            # MERGE HERE
        }
        
    } # switch
    
    if($Script:OutputHack){
        #restore scrolling region
        Write-Host "$e[s$($e)[r$($e)[u" -NoNewline
        #show the cursor
        Write-Host "$e[?25h" 
    }

    $software_list_res = [system.collections.arraylist]::new()
    $LatestVersion = $CmdType -eq [CmdType]::upgradable
    $software_list_res = Convert-ArrayToAppInfoObjects $winget_cmd_results $categories -LatestVersion:$LatestVersion
    
    if($CmdType -eq [CmdType]::export){
        $software_list_upgradable = [system.collections.arraylist]::new()
        $software_list_upgradable = Convert-ArrayToAppInfoObjects $upgrade_cmd_results $categories -LatestVersion:$true

        $software_list_export = [system.collections.arraylist]::new()
        $IdCheckList = $software_list_upgradable.Id
        ForEach($app in $software_list_res){
            $pkg_data = [PSCustomObject]@{
                Name            = $app.Name
                Id              = $app.Id
                Version         = $app.Version.ToString()
                UpdatedOn       = (Get-Date).GetDateTimeFormats()[33]
            }
            $appid = $app.Id
            [string]$avail_ver = "0.0.0"
            $new_version_availale = $false
            if($IdCheckList.Contains($appid)){
                $new_version_availale = $true
                $obj = $software_list_upgradable | where -Property Id -eq $appid | select -Unique | select -ExpandProperty LatestVersion
                if($obj -eq $Null){ throw "Error when merging datatables..."}
                if($($obj.GetType().Name) -eq 'WinGetPackageVersion'){
                    $avail_ver = $obj.ToString()
                }else{
                    $avail_ver = $obj
                }
            }
            $pkg_data | Add-Member -NotePropertyName NewVersionAvailable -NotePropertyValue $new_version_availale
            $pkg_data | Add-Member -NotePropertyName LatestVersion -NotePropertyValue $avail_ver

            [void]$software_list_export.Add($pkg_data)
        }

        $parsed_json = $software_list_export | ConvertTo-Json
        if(Test-Path $Option -PathType Leaf){ 
            write-host "WARNING! " -f DarkRed -n ; 
            write-host "File `"$Option`" already exists! . Overwite (y/N)" -f DarkGray -n ; 
            
            $a=Read-Host -Prompt "?" ; 
            if($a -notmatch "y") {
                write-host "Exiting on user request. " -f DarkYellow
                return $software_list_export;
            }  
        }

        $Null = New-Item -Path $Option -ItemType file -Force -ErrorAction Ignore
        Write-Verbose "✅ Writing $Option"
        Set-Content -Path $Option -Value $parsed_json -Force
        return $software_list_export;
    }
    
    return $software_list_res;

}

# First: Get the entire content of the application data
$AppData = Invoke-PSWinget List | Where name -imatch "VP9 Video Extensions"

# Retrieve the version as a version OBJECT
[WinGetPackageVersion]$AppVersion = $AppData.Version

#Then get the version String
[string]$BuildString = $AppVersion.Build

# Get App name
[string]$AppName = $AppData.Name

Write-Host "The Build number for $AppName is " -n -f DarkYellow
Write-Host "$BuildString" -f DarkRed