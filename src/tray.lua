local ffi = require("ffi")
local Tray = {}

ffi.cdef[[
    typedef void* HWND;
    typedef void* HINSTANCE;
    typedef void* HICON;
    typedef unsigned int UINT;
    typedef unsigned int UINT_PTR;
    typedef unsigned long DWORD;
    typedef long LONG;
    typedef long long LONG_PTR;
    typedef long long LRESULT;
    typedef unsigned long long WPARAM;
    typedef long long LPARAM;
    typedef void* HRGN;
    
    typedef struct {
        long x;
        long y;
    } POINT;

    typedef struct {
        DWORD cbSize;
        HWND hWnd;
        UINT uID;
        UINT uFlags;
        UINT uCallbackMessage;
        HICON hIcon;
        char szTip[128];
        DWORD dwState;
        DWORD dwStateMask;
        char szInfo[256];
        union {
            UINT  uTimeout;
            UINT  uVersion;
        } DUMMYUNIONNAME;
        char szInfoTitle[64];
        DWORD dwInfoFlags;
    } NOTIFYICONDATA;

    typedef LRESULT (__stdcall *WNDPROC)(HWND, UINT, WPARAM, LPARAM);

    typedef void* HMENU;
    typedef struct {
        long left;
        long top;
        long right;
        long bottom;
    } RECT;
    
    HMENU CreatePopupMenu();
    int DestroyMenu(HMENU hMenu);
    int TrackPopupMenu(HMENU hMenu, UINT uFlags, int x, int y, int nReserved, HWND hWnd, const RECT *prcRect);
    int PostMessageA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
    
    int MultiByteToWideChar(UINT CodePage, DWORD dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
    int InsertMenuW(HMENU hMenu, UINT uPosition, UINT uFlags, UINT_PTR uIDNewItem, const wchar_t* lpNewItem);

    typedef void* HMODULE;
    typedef void* FARPROC;
    HMODULE LoadLibraryA(const char* lpLibFileName);
    FARPROC GetProcAddress(HMODULE hModule, const char* lpProcName);

    HWND FindWindowA(const char* lpClassName, const char* lpWindowName);
    int Shell_NotifyIconA(DWORD dwMessage, NOTIFYICONDATA* lpData);
    HICON LoadIconA(HINSTANCE hInstance, const char* lpIconName);
    int SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags);
    
    int GetCursorPos(POINT* lpPoint);
    int SetForegroundWindow(HWND hWnd);
    int ShowWindow(HWND hWnd, int nCmdShow);
    
    LONG GetWindowLongA(HWND hWnd, int nIndex);
    LONG_PTR SetWindowLongPtrA(HWND hWnd, int nIndex, LONG_PTR dwNewLong);
    LRESULT CallWindowProcA(WNDPROC lpPrevWndFunc, HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
    
    typedef struct _MARGINS {
        int cxLeftWidth;
        int cxRightWidth;
        int cyTopHeight;
        int cyBottomHeight;
    } MARGINS;
    
    int DwmExtendFrameIntoClientArea(HWND hWnd, const MARGINS* pMarInset);
    unsigned int WinExec(const char* lpCmdLine, unsigned int uCmdShow);
]]

local shell32 = ffi.load("shell32")
local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")
local dwmapi = nil
pcall(function() dwmapi = ffi.load("dwmapi") end)

local NIF_MESSAGE = 0x1
local NIF_ICON = 0x2
local NIF_TIP = 0x4
local WM_USER = 0x0400
local WM_LBUTTONUP = 0x0202
local WM_RBUTTONUP = 0x0205
local TRAY_CALLBACK = WM_USER + 101
local GWLP_WNDPROC = -4

local WM_NCHITTEST = 0x0084
local HTTRANSPARENT = -1
local HTCLIENT = 1

local hwnd = nil
local nid = nil
local oldWndProc = nil
local wndProcCallback = nil

function Tray.showNativeMenu(config)
    -- This is called by the INVISIBLE helper process ('love . menu')
    local pt = ffi.new("POINT")
    user32.GetCursorPos(pt)
    
    -- Try to find a window with the menu name, fallback to main
    local hwndMenu = user32.FindWindowA(nil, "BeatingHeartMenu")
    if not hwndMenu or ffi.cast("intptr_t", hwndMenu) == 0 then
        hwndMenu = user32.FindWindowA(nil, "Beating Heart")
    end
    
    if not hwndMenu then return end
    
    user32.SetForegroundWindow(hwndMenu)
    local hMenu = user32.CreatePopupMenu()
    
    local function utf8_to_utf16(str)
        local len = kernel32.MultiByteToWideChar(65001, 0, str, -1, nil, 0)
        local buf = ffi.new("wchar_t[?]", len)
        kernel32.MultiByteToWideChar(65001, 0, str, -1, buf, len)
        return buf
    end
    
    local i18n = require("src.i18n")
    local langID = config and config.language or 0
    user32.InsertMenuW(hMenu, 0, 0x00000000, 1001, utf8_to_utf16(i18n.get("tray_settings", langID)))
    user32.InsertMenuW(hMenu, 1, 0x00000800, 0, nil) -- SEPARATOR
    user32.InsertMenuW(hMenu, 2, 0x00000000, 1002, utf8_to_utf16(i18n.get("tray_exit", langID)))
    
    -- TPM_RETURNCMD=0x0100, TPM_RIGHTBUTTON=0x0002
    local cmd = user32.TrackPopupMenu(hMenu, 0x0102, pt.x, pt.y, 0, hwndMenu, nil)
    user32.PostMessageA(hwndMenu, 0, 0, 0)
    user32.DestroyMenu(hMenu)
    
    if cmd == 1001 then
        if not Tray.showSpecificWindow("Settings") then
            Tray.spawnProcess('love . settings')
        end
    elseif cmd == 1002 then
        config.shouldExit = 1 -- Signal the main process to exit (shared memory)
    end
end

function Tray.init(windowTitle, config, noIcon)
    hwnd = user32.FindWindowA(nil, windowTitle)
    if not hwnd then return end

    if not noIcon then
        nid = ffi.new("NOTIFYICONDATA")
        nid.cbSize = ffi.sizeof("NOTIFYICONDATA")
        nid.hWnd = hwnd
        nid.uID = 1
        nid.uFlags = bit.bor(NIF_ICON, NIF_TIP, NIF_MESSAGE)
        nid.uCallbackMessage = TRAY_CALLBACK
        nid.hIcon = user32.LoadIconA(nil, ffi.cast("const char*", 32512)) -- IDI_APPLICATION
        ffi.copy(nid.szTip, "Beating Heart", 14)
        shell32.Shell_NotifyIconA(0, nid) -- NIM_ADD
    end

    -- [ZERO-LATENCY HITTEST] 全局注册 WNDPROC 钩子
    local isMainHeart = (windowTitle == "Beating Heart")
    wndProcCallback = ffi.cast("WNDPROC", function(h, msg, w, l)
        -- 1. 处理系统穿透判定 (仅对主心脏窗口生效)
        if msg == WM_NCHITTEST then
            if not isMainHeart then return HTCLIENT end
            
            if config then
                local x = tonumber(bit.band(l, 0xFFFF))
            -- 处理负坐标 (多显示器支持)
            if x >= 32768 then x = x - 65536 end
            local y = tonumber(bit.rshift(l, 16))
            if y >= 32768 then y = y - 65536 end
            
            -- [NATIVE SYNC] 从共享内存读取实时坐标与缩放
            local dpiScale = config.dpiScale or 1.0
            local localX = (x - config.posX) / dpiScale
            local localY = (y - config.posY) / dpiScale
            
            local centerX = config.winW / 2 + config.floatX
            local centerY = config.winH / 2 + config.floatY
            local dist2 = (localX - centerX)^2 + (localY - centerY)^2
            
                local hitR = config.size * config.pulseScale * 1.2
                if dist2 <= hitR^2 then
                    return HTCLIENT -- 命中：拦截点击供 Lua 使用
                else
                    return HTTRANSPARENT -- 穿透：把点击扔给正下方的窗口
                end
            end
        end

        -- 2. 处理托盘回调
        if msg == TRAY_CALLBACK then
            local mouseMsg = tonumber(l)
            if mouseMsg == WM_RBUTTONUP then
                Tray.spawnProcess('love . menu')
            elseif mouseMsg == WM_LBUTTONUP then
                Tray.restore()
            end
            return 0
        end
        return user32.CallWindowProcA(oldWndProc, h, msg, w, l)
    end)
    oldWndProc = ffi.cast("WNDPROC", user32.SetWindowLongPtrA(hwnd, GWLP_WNDPROC, ffi.cast("LONG_PTR", wndProcCallback)))

    -- Hook Dark Mode
    pcall(function()
        local hTheme = kernel32.LoadLibraryA("uxtheme.dll")
        if hTheme ~= nil then
            local setAppMode = kernel32.GetProcAddress(hTheme, ffi.cast("const char*", 135))
            if setAppMode ~= nil then ffi.cast("int (*)(int)", setAppMode)(1) end
            local flushMenu = kernel32.GetProcAddress(hTheme, ffi.cast("const char*", 136))
            if flushMenu ~= nil then ffi.cast("void (*)()", flushMenu)() end
        end
    end)
end

function Tray.makeTransparent()
    if not hwnd or not dwmapi then return end
    local margins = ffi.new("MARGINS", -1, -1, -1, -1)
    dwmapi.DwmExtendFrameIntoClientArea(hwnd, margins)
end

function Tray.hideFromTaskbar()
    if not hwnd then return end
    local GWL_EXSTYLE = -20
    local WS_EX_APPWINDOW = 0x00040000
    local WS_EX_TOOLWINDOW = 0x00000080
    local oldEx = user32.GetWindowLongA(hwnd, GWL_EXSTYLE)
    oldEx = bit.band(oldEx, bit.bnot(WS_EX_APPWINDOW))
    oldEx = bit.bor(oldEx, WS_EX_TOOLWINDOW)
    user32.SetWindowLongPtrA(hwnd, GWL_EXSTYLE, ffi.cast("LONG_PTR", oldEx))
end

function Tray.setClickThrough(enable)
    if not hwnd then return end
    local GWL_EXSTYLE = -20
    local WS_EX_TRANSPARENT = 0x00000020
    local WS_EX_LAYERED = 0x00080000
    local oldEx = user32.GetWindowLongA(hwnd, GWL_EXSTYLE)
    local newEx = enable and bit.bor(oldEx, WS_EX_TRANSPARENT, WS_EX_LAYERED) or bit.band(oldEx, bit.bnot(WS_EX_TRANSPARENT))
    if oldEx ~= newEx then user32.SetWindowLongPtrA(hwnd, GWL_EXSTYLE, ffi.cast("LONG_PTR", newEx)) end
end

function Tray.setTopmost(topmost)
    if not hwnd then return end
    local insertAfter = topmost and ffi.cast("HWND", -1) or ffi.cast("HWND", -2) -- HWND_TOPMOST or HWND_NOTOPMOST
    user32.SetWindowPos(hwnd, insertAfter, 0, 0, 0, 0, 0x0003) -- SWP_NOMOVE | SWP_NOSIZE
end

function Tray.showSpecificWindow(title)
    local h = user32.FindWindowA(nil, title)
    if h and ffi.cast("intptr_t", h) ~= 0 then
        user32.ShowWindow(h, 5) -- SW_SHOW
        user32.SetForegroundWindow(h)
        return true
    end
    return false
end

function Tray.spawnProcess(cmd)
    kernel32.WinExec(cmd, 5)
end

function Tray.hide()
    if hwnd then user32.ShowWindow(hwnd, 0) end
end

function Tray.restore()
    if hwnd then user32.ShowWindow(hwnd, 5); user32.SetForegroundWindow(hwnd) end
end

function Tray.getCursorPos()
    local pt = ffi.new("POINT"); user32.GetCursorPos(pt); return pt.x, pt.y
end

function Tray.cleanup()
    if nid then shell32.Shell_NotifyIconA(2, nid) end -- NIM_DELETE
    if hwnd and oldWndProc then user32.SetWindowLongPtrA(hwnd, GWLP_WNDPROC, ffi.cast("LONG_PTR", oldWndProc)) end
end

return Tray
