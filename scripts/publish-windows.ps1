param(
  [string]$Version = "1.0.0",
  [string[]]$Runtimes = @("win-x64", "win-arm64")
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectPath = [IO.Path]::Combine($ProjectRoot, "windows", "BizboxNotch.Windows", "BizboxNotch.Windows.csproj")
$DistPath = [IO.Path]::Combine($ProjectRoot, "dist")

New-Item -ItemType Directory -Force -Path $DistPath | Out-Null

foreach ($Runtime in $Runtimes) {
  dotnet publish $ProjectPath `
    -c Release `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:PublishReadyToRun=true

  $PublishPath = [IO.Path]::Combine(
    $ProjectRoot,
    "windows",
    "BizboxNotch.Windows",
    "bin",
    "Release",
    "net8.0-windows10.0.19041.0",
    $Runtime,
    "publish"
  )
  $ExePath = [IO.Path]::Combine($PublishPath, "BizboxNotch.exe")
  $ZipPath = [IO.Path]::Combine($DistPath, "Bizbox-Notch-Windows-$Runtime-$Version.zip")

  if (-not (Test-Path $ExePath)) {
    throw "Published executable was not found: $ExePath"
  }

  Remove-Item $ZipPath -ErrorAction SilentlyContinue
  Compress-Archive -Path $ExePath -DestinationPath $ZipPath -Force
  Write-Host "Created $ZipPath"
}
