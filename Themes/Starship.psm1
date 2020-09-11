#requires -Version 2 -Modules posh-git

function Get-Directory {
  $drive = $PWD.Path
  $status = Get-VCSStatus
  if ($PWD.Path -like "$HOME*") {
      $drive = $sl.PromptSymbols.HomeSymbol+$Pwd.Path.Replace($HOME,"")
  }
  if ($status) {
      $drive = "$(Split-Path -Path (Split-Path -Path $status.GitDir -Parent) -Leaf)"
      $drive += $PWD.Path.Substring((Split-Path -Path $status.GitDir -Parent).Length)
  }
  return $drive
}

function Get-BatteryInfo {
  
}

function Test-Git {
  $status = Get-VCSStatus
  if ($status) {
      $prompt += Write-Prompt -Object " on " -ForegroundColor $sl.Colors.PromptForegroundColor
      $prompt += Write-Prompt -Object "$($sl.GitSymbols.BranchSymbol+' ')" -ForegroundColor $sl.Colors.GitDefaultColor
      $prompt += Write-Prompt -Object "$($status.Branch) " -ForegroundColor $sl.Colors.GitDefaultColor
      [string[]]$vcsinfo = (Get-VcsInfo $status).VcInfo.Substring(2).Split($status.Branch)[1].Trim().Split("|").Trim() | Where-Object { $_ -ne "" }
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

      if (-not ($status.HasUntracked + $status.HasIndex + $status.HasWorking) -and $status.Upstream.Length -gt 0) {
          $prompt += Write-Prompt -Object ("$($sl.PromptSymbols.GitCleanSymbol)") -ForegroundColor $sl.Colors.PromptSymbolColor
      }
  }
  return $prompt
}

function Test-Node {
  if (Test-Path "package.json") {
      $sl.Projects.Node = @{
          Version = (node.exe -v 2>$null)
          ProjectPath = $PWD.Path
          ProjectVersion = (Get-Content "package.json" | ConvertFrom-Json | Select-Object -ExpandProperty Version)
      }
  }
  if ($sl.Projects.Node -and ($PWD.Path -like $sl.Projects.Node.ProjectPath+"*")) {
      $prompt += Write-Prompt -Object (" is ")
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.NPM+" v"+$sl.Projects.Node.ProjectVersion) -ForegroundColor $sl.Colors.GitDefaultColor
      $prompt += Write-Prompt -Object (" via ")
      $prompt += Write-Prompt -Object ($sl.PromptSymbols.Node+" "+$sl.Projects.Node.Version) -ForegroundColor $sl.Colors.PromptSymbolColor
  }
  else {
      $sl.Projects.Remove("Node")
  }
}

function Test-DotNet {
  if ((Test-Path "*.sln","*.*proj") -eq $true) {
      $availablesdks = (dotnet.exe --list-sdks | Select-String -Pattern "\d+\.\d+\.\d+").Matches.Value
      $path = $PWD.Path
      do {
          if (Test-Path "$path\global.json") {
              $version = (Get-Content "$path\global.json"|ConvertFrom-Json).sdk.version
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
          HasVersion = ($hasversion -eq $true)
          Version = $(if ($version) { $version } else { $availablesdks | Select-Object -Last 1 })
          AvailableSdks = $availablesdks
          ProjectPath = $PWD.Path
      }
  }
  if ($sl.Projects.DotNet -and ($PWD.Path -like $sl.Projects.DotNet.ProjectPath+"*")) {
      $prompt += Write-Prompt -Object (" via ")
      if ($sl.Projects.DotNet.HasVersion) {
          $prompt += Write-Prompt -Object ($sl.PromptSymbols.DotNet+" v"+$sl.Projects.DotNet.Version) -ForegroundColor $sl.Colors.PromptSymbolColor
      }
      else {
          # $prompt += Write-Prompt -Object "[" -ForegroundColor $sl.Colors.WithForegroundColor
          $prompt += Write-Prompt -Object ($sl.PromptSymbols.DotNet+" v"+$sl.Projects.DotNet.Version) -ForegroundColor $sl.Colors.WithForegroundColor
          $prompt += Write-Prompt -Object ($sl.PromptSymbols.DotNetMissing+"{"+($sl.Projects.DotNet.AvailableSdks -join ", ")+"}") -ForegroundColor $sl.Colors.WithForegroundColor
          # $prompt += Write-Prompt -Object "]" -ForegroundColor $sl.Colors.WithForegroundColor
      }
  }
  else {
      $sl.Projects.Remove("DotNet")
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
  $prompt += Get-BatteryInfo
  if ($lastCommandFailed) {
      $prompt += Write-Prompt -Object (Get-Directory) -ForegroundColor $sl.Colors.WithForegroundColor
  }
  else {
      $prompt += Write-Prompt -Object (Get-Directory) -ForegroundColor $sl.Colors.DriveForegroundColor
  }
  $prompt += Test-Git
  $prompt += Test-Node
  $prompt += Test-DotNet
  if ($with) {
      $prompt += Write-Prompt -Object "$($with.ToUpper()) " -BackgroundColor $sl.Colors.WithBackgroundColor -ForegroundColor $sl.Colors.WithForegroundColor
  }
  $prompt += Set-Newline
  $prompt += Write-Prompt -Object ($sl.PromptSymbols.PromptIndicator) -ForegroundColor  $sl.Colors.PromptSymbolColor
  $prompt += '  '
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
$sl.PromptSymbols.NPM = [char]::ConvertFromUtf32(0x2b23)                # ⬣
$sl.PromptSymbols.Node = [char]::ConvertFromUtf32(0x2b22)               # ⬢
$sl.PromptSymbols.DotNet = [char]::ConvertFromUtf32(0x2B24)             # ⬤
$sl.PromptSymbols.DotNetMissing = [char]::ConvertFromUtf32(0x00A2)      # ¢
$sl.Colors.PromptSymbolColor = [ConsoleColor]::Green
$sl.Colors.PromptHighlightColor = [ConsoleColor]::Blue
$sl.Colors.DriveForegroundColor = [ConsoleColor]::Cyan
$sl.Colors.WithForegroundColor = [ConsoleColor]::Red
$sl.Colors.GitDefaultColor = [ConsoleColor]::Yellow