$url = "https://github.com/brechtsanders/winlibs_mingw/releases/download/14.2.0-18.1.8-12.0.0-msvcrt-r1/winlibs-x86_64-posix-seh-gcc-14.2.0-mingw-w64msvcrt-12.0.0-r1.zip"
$destZip = "D:\mingw64_temp.zip"
$destPath = "D:\Program Files"

if (-not (Test-Path $destPath)) {
    New-Item -ItemType Directory -Force -Path $destPath
}

Write-Host "Downloading GCC 14.2.0 from WinLibs..."
Invoke-WebRequest -Uri $url -OutFile $destZip

Write-Host "Extracting to $destPath..."
Expand-Archive -Path $destZip -DestinationPath $destPath -Force

Write-Host "Cleaning up..."
Remove-Item $destZip

Write-Host "Verifying installation..."
$gccPath = "D:\Program Files\mingw64\bin\gcc.exe"
if (Test-Path $gccPath) {
    & $gccPath --version
    Write-Host "GCC installed successfully at $gccPath"
} else {
    Write-Error "GCC not found at $gccPath"
}
