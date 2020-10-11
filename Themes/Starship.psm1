#requires -Version 2 -Modules posh-git

function Get-Directory {
  $drive = $PWD.Path
  $status = Get-VCSStatus
  if ($PWD.Path -like "$HOME*") {
    $drive = $sl.PromptSymbols.HomeSymbol + $Pwd.Path.Replace($HOME, "")
  }
  if ($status) {
    $drive = "$(Split-Path -Path (Split-Path -Path $status.GitDir -Parent) -Leaf)"
    $drive += $PWD.Path.Substring((Split-Path -Path $status.GitDir -Parent).Length)
  }
  return $drive
}

function Get-BatteryInfo {
  $batteryInfo = Get-CimInstance -ClassName Win32_Battery -Property Availability, BatteryStatus, EstimatedChargeRemaining
  if ($batteryInfo.Availability) {
    $powerInfo = Get-CimInstance -ClassName batterystatus -Namespace root/WMI -Property Charging, Discharging, PowerOnline
    $estimatedChargeRemaining = $batteryInfo.EstimatedChargeRemaining | Measure-Object -Sum
    $estimatedChargeRemaining = $estimatedChargeRemaining.Sum / $estimatedChargeRemaining.Count
    if ($powerInfo.PowerOnline -eq $true) {
      $prompt += Write-Prompt -Object $(if ($powerInfo.Charging -eq $true) { $sl.PromptSymbols.Charging } else { $sl.PromptSymbols.Idle }) -ForegroundColor $sl.Colors.PromptSymbolColor
    }  
    if ($powerInfo.Discharging -eq $true) {
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.Discharging) -ForegroundColor $sl.Colors.PromptSymbolColor
    }
    $prompt += Write-Prompt -Object ("$estimatedChargeRemaining% ") -ForegroundColor $sl.Colors.PromptSymbolColor
  }
}

function Test-Git {
  $status = Get-VCSStatus
  if ($status) {
    $prompt += Write-Prompt -Object " on " -ForegroundColor $sl.Colors.PromptForegroundColor
    $prompt += Write-Prompt -Object "$($sl.GitSymbols.BranchSymbol+' ')" -ForegroundColor $sl.Colors.GitDefaultColor
    $prompt += Write-Prompt -Object "$($status.Branch)" -ForegroundColor $sl.Colors.GitDefaultColor
    
    [string[]]$vcsinfo = (Get-VcsInfo $status).VcInfo.Substring(2).Split($status.Branch) | Select-Object -Last 1
    if ($status.HasUntracked + $status.HasIndex + $status.HasWorking) {
      if ($status.HasIndex) {
        $staged = $vcsinfo[0]
      }
      else {
        $changed = $vcsinfo[0]
      }

      if ($status.HasIndex -and $status.HasWorking) {
        $changed = $vcsinfo[1]
      }

      if ($staged) {
        $prompt += Write-Prompt -Object "$staged" -ForegroundColor $sl.Colors.PromptSymbolColor
      }
      if ($status.HasIndex -and $status.HasWorking) {
        $prompt += Write-Prompt -Object " | "
      }
      if ($changed) {
        $prompt += Write-Prompt -Object "$changed" -ForegroundColor $sl.Colors.WithForegroundColor
      }
    }

    if (-not ($status.HasUntracked + $status.HasIndex + $status.HasWorking) -and -not ($status.AheadBy -gt 0 -or $status.BehindBy -gt 0) -and $status.Upstream.Length -gt 0) {
      $prompt += Write-Prompt -Object (" $($sl.PromptSymbols.GitCleanSymbol)") -ForegroundColor $sl.Colors.PromptSymbolColor
    }
    elseif ($status.AheadBy -gt 0) {
      $prompt += Write-Prompt -Object (" "+$sl.PromptSymbols.GitAheadSymbol+$status.AheadBy) -ForegroundColor $sl.Colors.GitDefaultColor
    }
    elseif ($status.BehindBy -gt 0) {
      $prompt += Write-Prompt -Object (" "+$sl.PromptSymbols.GitBehindSymbol+$status.BehindBy) -ForegroundColor $sl.Colors.GitDefaultColor
    }
  }
}

function Test-Node {
  if (Test-Path "package.json") {
    $sl.Projects.Node = @{
      Version        = $(if (Get-Command node.exe -ErrorAction Ignore) { (node.exe -v 2>$null) } else { $null })
      ProjectPath    = $PWD.Path
      ProjectVersion = (Get-Content "package.json" | ConvertFrom-Json | Select-Object -ExpandProperty Version)
    }
  }
  if ($sl.Projects.Node -and ($PWD.Path -like $sl.Projects.Node.ProjectPath + "*")) {
    $prompt += Write-Prompt -Object (" is ")
    $prompt += Write-Prompt -Object ($sl.PromptSymbols.NPM + " v" + $sl.Projects.Node.ProjectVersion) -ForegroundColor $sl.Colors.GitDefaultColor
    $prompt += Write-Prompt -Object (" via ")
    if (-not $sl.Projects.Node.Version) {
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.Node + " not installed") -ForegroundColor $sl.Colors.WithForegroundColor
    }
    else {
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.Node + " " + $sl.Projects.Node.Version) -ForegroundColor $sl.Colors.PromptSymbolColor
    }
  }
  else {
    $sl.Projects.Remove("Node")
  }
}

function Test-DotNet {
  if (-not (Get-Command dotnet.exe -ErrorAction Ignore)) {
    return
  }
  if ((Test-Path "*.sln", "*.*proj") -eq $true) {
    $availablesdks = (dotnet.exe --list-sdks | Select-String -Pattern "\d+\.\d+\.\d+").Matches.Value
    $path = $PWD.Path
    do {
      if (Test-Path "$path\global.json") {
        $globalFound = $true
        $version = (Get-Content "$path\global.json" | ConvertFrom-Json).sdk.version
        if ($availablesdks -contains $version) {
          $hasversion = $true
        }
        else {
          $hasversion = $false
        }
      }
      $path = Split-Path $path
    }
    while (($null -eq $hasversion) -and ($path -ne $PWD.Drive.Root))
    $sl.Projects.DotNet = @{
      HasVersion    = ($hasversion -eq $true) -or ($null -eq $globalFound)
      Version       = $(if ($version) { $version } else { $availablesdks | Select-Object -Last 1 })
      AvailableSdks = $availablesdks
      ProjectPath   = $PWD.Path
    }
  }
  if ($sl.Projects.DotNet -and ($PWD.Path -like $sl.Projects.DotNet.ProjectPath + "*")) {
    $prompt += Write-Prompt -Object (" via ")
    if ($sl.Projects.DotNet.HasVersion) {
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.DotNet + " v" + $sl.Projects.DotNet.Version) -ForegroundColor $sl.Colors.PromptSymbolColor
    }
    else {
      # $prompt += Write-Prompt -Object "[" -ForegroundColor $sl.Colors.WithForegroundColor
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.DotNet + " v" + $sl.Projects.DotNet.Version) -ForegroundColor $sl.Colors.WithForegroundColor
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.DotNetMissing + "{" + ($sl.Projects.DotNet.AvailableSdks -join ", ") + "}") -ForegroundColor $sl.Colors.WithForegroundColor
      # $prompt += Write-Prompt -Object "]" -ForegroundColor $sl.Colors.WithForegroundColor
    }
  }
  else {
    $sl.Projects.Remove("DotNet")
  }
}

function Test-PowerShell {
  if ((Test-Path "*.psd1") -eq $true) {
    $sl.Projects.PowerShell = @{
      Version        = $PSVersionTable.PSVersion.ToString()
      ProjectPath    = $PWD.Path
      ProjectVersion = (Get-Content *.psd1 | Select-String -Pattern "ModuleVersion = '(.*)'").Matches.Groups[1].Value
    }
  }
  if ($sl.Projects.PowerShell -and ($PWD.Path -like $sl.Projects.PowerShell.ProjectPath + "*")) {
    $prompt += Write-Prompt -Object " is "
    $prompt += Write-Prompt -Object ($sl.PromptSymbols.PowerShellManifest + " v" + $sl.Projects.PowerShell.ProjectVersion) -ForegroundColor $sl.Colors.GitDefaultColor
    $prompt += Write-Prompt -Object " via "
    $prompt += Write-Prompt -Object ($sl.PromptSymbols.PowerShell + " v" + $sl.Projects.PowerShell.Version) -ForegroundColor $sl.Colors.PromptSymbolColor
  }
  else {
    $sl.Projects.Remove("PowerShell")
  }
}

function Write-Theme {
  param(
    [bool]
    $lastCommandFailed,
    [string]
    $with
  )
  
  $prompt = Write-Prompt -Object $sl.PromptSymbols.StartSymbol -ForegroundColor $sl.Colors.PromptForegroundColor
  if ($lastCommandFailed) {
    $prompt += Write-Prompt -Object (Get-Directory) -ForegroundColor $sl.Colors.WithForegroundColor
  }
  else {
    $prompt += Write-Prompt -Object (Get-Directory) -ForegroundColor $sl.Colors.DriveForegroundColor
  }
  Test-Git
  Test-Node
  Test-DotNet
  Test-PowerShell
  if ($with) {
    $prompt += Write-Prompt -Object "$($with.ToUpper()) " -BackgroundColor $sl.Colors.WithBackgroundColor -ForegroundColor $sl.Colors.WithForegroundColor
  }
  $prompt += Write-Prompt -Object ' '
  if ($sl.Options.NewLine) {
    $prompt += Set-Newline
  }
  Get-BatteryInfo
  $prompt += Write-Prompt -Object ($sl.PromptSymbols.PromptIndicator) -ForegroundColor  $sl.Colors.PromptSymbolColor
  $prompt += ' '
  $prompt
}

$sl = $global:ThemeSettings #local settings
if ($null -eq $sl.Projects) {
  $sl | Add-Member -MemberType NoteProperty -Name Projects -Value @{}
}
$sl.PromptSymbols.StartSymbol = ''
$sl.PromptSymbols.PromptIndicator = [char]::ConvertFromUtf32(0x276F)    # ❯
$sl.PromptSymbols.HomeSymbol = '~'
$sl.PromptSymbols.GitCleanSymbol = [char]::ConvertFromUtf32(0x2261)     # ≡
$sl.PromptSymbols.GitAheadSymbol = [char]::ConvertFromUtf32(0x21E1)     # ⇡
$sl.PromptSymbols.GitBehindSymbol = [char]::ConvertFromUtf32(0x21E3)    # ⇣
$sl.PromptSymbols.NPM = [char]::ConvertFromUtf32(0x2b23)                # ⬣
$sl.PromptSymbols.Node = [char]::ConvertFromUtf32(0x2b22)               # ⬢
$sl.PromptSymbols.DotNet = [char]::ConvertFromUtf32(0x2B24)             # ⬤
$sl.PromptSymbols.PowerShellManifest = 'PSD'
$sl.PromptSymbols.PowerShell = 'PS'
$sl.PromptSymbols.DotNetMissing = [char]::ConvertFromUtf32(0x00A2)      # ¢
$sl.PromptSymbols.Charging = [char]::ConvertFromUtf32(0x2191)           # ↑
$sl.PromptSymbols.Discharging = [char]::ConvertFromUtf32(0x2193)        # ↓
$sl.PromptSymbols.Idle = [char]::ConvertFromUtf32(0x2219)               # ∙
$sl.Colors.PromptSymbolColor = [ConsoleColor]::Green
$sl.Colors.PromptHighlightColor = [ConsoleColor]::Blue
$sl.Colors.DriveForegroundColor = [ConsoleColor]::Cyan
$sl.Colors.WithForegroundColor = [ConsoleColor]::Red
$sl.Colors.GitDefaultColor = [ConsoleColor]::Yellow