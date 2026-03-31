local ffi = require("ffi")

ffi.cdef[[
    typedef void* HANDLE;
    typedef void* LPVOID;
    typedef unsigned long DWORD;
    typedef int BOOL;

    HANDLE CreateFileMappingA(
        HANDLE hFile,
        void* lpFileMappingAttributes,
        DWORD flProtect,
        DWORD dwMaximumSizeHigh,
        DWORD dwMaximumSizeLow,
        const char* lpName
    );

    LPVOID MapViewOfFile(
        HANDLE hFileMappingObject,
        DWORD dwDesiredAccess,
        DWORD dwFileOffsetHigh,
        DWORD dwFileOffsetLow,
        size_t dwNumberOfBytesToMap
    );

    BOOL UnmapViewOfFile(const void* lpBaseAddress);
    BOOL CloseHandle(HANDLE hObject);
    DWORD GetLastError();

    // Mutex for robust single-instance
    HANDLE CreateMutexA(void* lpMutexAttributes, BOOL bInitialOwner, const char* lpName);
    BOOL ReleaseMutex(HANDLE hMutex);

    typedef struct {
        double size;
        double sensitivity;
        double color_r;
        double color_g;
        double color_b;
        double color_a;
        double posX;
        double posY;
        double winW;
        double winH;
        double floatX;
        double floatY;
        double pulseScale;
        double dpiScale;
        double shouldExit;
        double menuX;
        double menuY;
        double showMenu;
        double isTopmost;
        double language;
    } SharedConfig;
]]

local kernel32 = ffi.load("kernel32")
local PAGE_READWRITE = 0x04
local FILE_MAP_ALL_ACCESS = 0xF001F

local SharedMem = {}
local hMapFile = nil
local hMutex = nil
local pBuf = nil
local sharedConfig = nil

function SharedMem.init()
    -- 1. [SINGLE INSTANCE] 使用互斥体 (Mutex) 实现内核级单例保护
    -- CreateMutexA 如果互斥体已存在，会返回句柄并设置 GetLastError = 183
    hMutex = kernel32.CreateMutexA(nil, ffi.cast("BOOL", 0), "Local\\BeatingHeart_SingleInstance_Mutex")
    local isFirstInstance = (kernel32.GetLastError() == 0)

    local size = ffi.sizeof("SharedConfig")
    
    -- 2. 创建共享内存映射
    hMapFile = kernel32.CreateFileMappingA(
        ffi.cast("HANDLE", ffi.cast("intptr_t", -1)), 
        nil,
        PAGE_READWRITE,
        0,
        size,
        "Local\\BeatingHeart_ConfigMemory"
    )

    if hMapFile == nil or ffi.cast("intptr_t", hMapFile) == -1 then
        return nil, false
    end

    -- Map Pointer address
    pBuf = kernel32.MapViewOfFile(hMapFile, FILE_MAP_ALL_ACCESS, 0, 0, size)

    if pBuf == nil then
        kernel32.CloseHandle(hMapFile)
        return nil, false
    end
    
    sharedConfig = ffi.cast("SharedConfig*", pBuf)
    return sharedConfig, isFirstInstance
end

function SharedMem.get()
    return sharedConfig
end

function SharedMem.cleanup()
    if pBuf then
        kernel32.UnmapViewOfFile(pBuf)
        pBuf = nil
    end
    if hMapFile then
        kernel32.CloseHandle(hMapFile)
        hMapFile = nil
    end
    if hMutex then
        kernel32.CloseHandle(hMutex)
        hMutex = nil
    end
end

return SharedMem
