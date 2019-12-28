$DefaultConfigFile = $PSScriptRoot + "\servers.json"
$Newline = "`n"

Function Println {
    Param (
        [String] $Message = ""
    )
    Write-Host "$Message"
}
Function Warning {
    Param ( [String] $Message )
    $Null = @(
        Write-Warning "$Message$Newline"
    )
}

Function LoadServers {
    Param (
        [System.Collections.ArrayList] $Servers,
        [String] $Config = $DefaultConfigFile
    )
    IF (!(Test-Path $Config -PathType Leaf)) {
        Warning "$Config not found, use the default config."
        $Config = $DefaultConfigFile
    }
    Else {
        Println "Load servers from $Config$Newline"
    }
    If (Test-Path $Config -PathType Leaf) {
        Try {
            $Conns = (Get-Content -Raw $Config) -Join ${Newline} | Out-String | ConvertFrom-Json
            ForEach ($Conn In $Conns) {
                $Null = @(
                    $Servers.Add($Conn)
                )
            }
        }
        Catch {
            Write-Error "Failed to load servers from $Config" -ErrorAction Stop
        }
    }
}

Function WriteConfig {
    Param (
        [System.Collections.ArrayList] $Servers,
        [String] $FilePath = $DefaultConfigFile
    )
    Println "Write to file: $FilePath"
    $Servers | ConvertTo-Json -AsArray -Depth 100 | Out-File $FilePath
    Println "Done.${Newline}"
}

Function GenerateHint {
    Param (
        [System.Collections.ArrayList] $List
    )
    $Prefix = "  "
    $Hint = "Select one option below:${Newline}"
    For ($Idx = 0; $Idx -lt $List.Count; $Idx++) {
        $Item = $List[$Idx]
        $Hint += "$Prefix[{0}] {1} => {2}@{3}:{4}" -f $Idx, $Item.Name, $Item.Username, $Item.Hostname, $Item.Port
        $Hint += "$Newline"
    }
    $Hint += "$Prefix[N] Create a new connection.${Newline}"
    $Hint += "$Prefix[R] Remove a connection.${Newline}"
    $Hint += "$Prefix[Q] Quit.${Newline}"
    $Hint
    Return
}

Function NewConnection {
    Println "Please fill the fields of new connection:"
    $ConnName = Read-Host "> Name of connection"
    $ConnUsername = Read-Host "> Username"
    $ConnHostname = Read-Host "> Hostname"
    $ConnPort = Read-Host "> Port[default = 22]"
    If ($ConnPort -match "^$") {
        $ConnPort = "22"
    }
    $Connection = New-Object PSObject
    $Connection | Add-Member -Type NoteProperty -Name Name -Value $ConnName
    $Connection | Add-Member -Type NoteProperty -Name Username -Value $ConnUsername
    $Connection | Add-Member -Type NoteProperty -Name Hostname -Value $ConnHostname
    $Connection | Add-Member -Type NoteProperty -Name Port -Value $ConnPort
    Println "> New Connection: ${ConnName}=>${ConnUsername}@${ConnHostname}:${ConnPort}"
    Println
    Return $Connection
}

Function SelectServer {
    Param (
        [System.Collections.ArrayList] $From
    )
    $Hint = GenerateHint -List $From
    do {
        Println $Hint
        $Input = Read-Host "Select[default = N]"
        Println
        Try {
            If ($Input -match "^$") {
                $FormatException = New-Object System.FormatException
                Throw $FormatException
            }
            $Input = [System.Convert]::ToInt32($Input)
            If ($Input -gt $From.Count) {
                Warning "Invalid number, please input a valid option!"
                Continue
            }
            $Temp = $From[$Input]
            $From.RemoveAt($Input)
            $From.Insert(0, $Temp)
            Break
        }
        Catch [System.FormatException] {
            If ($Input -match "^$" -or [Regex]::Matches($Input, "^[nN][ew|(?<=N)EW]*$")) {
                Try {
                    $Connection = NewConnection
                    $From.Insert(0, $Connection)
                    Break
                }
                Catch {
                    Write-Error -Message "Failed to create new connection!" -ErrorAction Stop
                }
            }
            ElseIf ([Regex]::Matches($Input, "^[qQ][uit|(?<=Q)UIT]*$")) {
                Println "See you."
                Exit 0
            }
            ElseIf ([Regex]::Matches($Input, "^[rR][emove|(?<=R)EMOVE]*$")) {
                $Idx = Read-Host "Enter number to remove"
                Try {
                    $Idx = [System.Convert]::ToInt32($Idx)
                }
                Catch {
                    Warning "Invalid number, remove failed!"
                    Continue
                }
                If ((0..$From.Count).IndexOf($Idx) -eq -1) {
                    Warning "Invalid number, remove failed!"
                    Continue
                }
                $Temp = $From[$Idx]
                Println "Remove: $($Temp.Name)=>$($Temp.Username)@$($Temp.Hostname):$($Temp.Port)"
                Println
                $From.RemoveAt($Idx)
                WriteConfig -Servers $From
                $Hint = GenerateHint -List $From
            }
            Else {
                Warning "Invalid option, please input a valid option!"
                Continue
            }
        }
        Catch {
            Warning "Invalid input, please input an valid option!"
            Continue
        }
    } while ($True)
    Return $From[0]
}

Function ConnectBySSH {
    Param ( [PSObject] $Server )
    Println "Connect to $($Server.Username)@$($Server.Hostname):$($Server.Port)"
    # if you don't use smark key, comment next line
    Println "Touch your smart key to auth when its light was blink: "
    Invoke-Expression "ssh $($Server.Username)@$($Server.Hostname) -p $($Server.Port)"
}

Function Main {
    # if you dont' use smark key, comment next line
    $ENV:SSH_AUTH_SOCK = "<your-custom-variable>"
    $Servers = New-Object System.Collections.ArrayList
    LoadServers $Servers
    $Server = SelectServer -From $Servers
    WriteConfig -Servers $Servers
    ConnectBySSH $Server
}

Main