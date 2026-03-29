@echo off
set GCC_PATH="D:\Program Files\mingw64\bin\gcc.exe"
echo [SharpEye] Building WASAPI Bridge v1.02...
%GCC_PATH% -O2 -shared -o wasapi_bridge.dll src/wasapi_bridge.c -lole32 -lmmdevapi -lavrt -luuid
if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] wasapi_bridge.dll has been generated in the project root.
) else (
    echo [ERROR] Compilation failed.
    pause
)
