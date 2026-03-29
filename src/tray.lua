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
    
    HRGN CreateEllipticRgn(int x1, int y1, int x2, int y2);
    int SetWindowRgn(HWND hWnd, HRGN hRgn, int bRedraw);
]]

local shell32 = ffi.load("shell32")
local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")
local gdi32 = ffi.load("gdi32")
local dwmapi = nil
pcall(function() dwmapi = ffi.load("dwmapi") end)

local NIF_MESSAGE = 0x1
local NIF_ICON = 0x2
local NIF_TIP = 0x4
local WM_USER = 0x0400
local TRAY_CALLBACK = WM_USER + 101

local WM_LBUTTONUP = 0x0202
local WM_RBUTTONUP = 0x0205
local GWLP_WNDPROC = -4

local hwnd = nil
local nid = nil
local oldWndProc = nil
local wndProcCallback = nil

local onSettingsCallback = nil
local onExitCallback = nil

function Tray.init(windowTitle, onSettings, onExit, noIcon)
    onSettingsCallback = onSettings
    onExitCallback = onExit
    
    hwnd = user32.FindWindowA(nil, windowTitle)
    if not hwnd then
        return
    end

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

        wndProcCallback = ffi.cast("WNDPROC", function(h, msg, w, l)
            if msg == TRAY_CALLBACK then
                local mouseMsg = tonumber(l)
                if mouseMsg == WM_RBUTTONUP then
                    local pt = ffi.new("POINT")
                    user32.GetCursorPos(pt)
                    
                    user32.SetForegroundWindow(hwnd)
                    local hMenu = user32.CreatePopupMenu()
                    
                    local function utf8_to_utf16(str)
                        local len = kernel32.MultiByteToWideChar(65001, 0, str, -1, nil, 0)
                        local buf = ffi.new("wchar_t[?]", len)
                        kernel32.MultiByteToWideChar(65001, 0, str, -1, buf, len)
                        return buf
                    end
                    
                    user32.InsertMenuW(hMenu, 0, 0x00000000, 1001, utf8_to_utf16("设置面板 (Settings)"))
                    user32.InsertMenuW(hMenu, 1, 0x00000800, 0, nil) -- SEPARATOR
                    user32.InsertMenuW(hMenu, 2, 0x00000000, 1002, utf8_to_utf16("彻底退出 (Exit)"))
                    
                    -- TPM_RETURNCMD=0x0100, TPM_RIGHTBUTTON=0x0002, TPM_BOTTOMALIGN=0x0020, TPM_NONOTIFY=0x0080
                    local cmd = user32.TrackPopupMenu(hMenu, 0x01A2, pt.x, pt.y, 0, hwnd, nil)
                    user32.PostMessageA(hwnd, 0, 0, 0)
                    user32.DestroyMenu(hMenu)
                    
                    if cmd == 1001 and onSettingsCallback then
                        onSettingsCallback()
                    elseif cmd == 1002 and onExitCallback then
                        onExitCallback()
                    end
                elseif mouseMsg == WM_LBUTTONUP then
                    Tray.restore()
                end
                return 0
            end
            return user32.CallWindowProcA(oldWndProc, h, msg, w, l)
        end)
        
        
        oldWndProc = ffi.cast("WNDPROC", user32.SetWindowLongPtrA(hwnd, GWLP_WNDPROC, ffi.cast("LONG_PTR", wndProcCallback)))
    end

    -- Hook into modern Windows immersive Dark Mode for standard components (Popup Menus)
    -- This relies on uxtheme.dll ordinals (135 = SetPreferredAppMode)
    pcall(function()
        local hTheme = kernel32.LoadLibraryA("uxtheme.dll")
        if hTheme ~= nil then
            -- Ordinal 135: SetPreferredAppMode (1 = AllowDark => dynamically adapt to user OS theme)
            local setAppMode = kernel32.GetProcAddress(hTheme, ffi.cast("const char*", 135))
            if setAppMode ~= nil then
                ffi.cast("int (*)(int)", setAppMode)(1)
            else
                -- Fallback: Ordinal 133 AllowDarkModeForApp for Win10 1809
                local allowDark = kernel32.GetProcAddress(hTheme, ffi.cast("const char*", 133))
                if allowDark ~= nil then
                    ffi.cast("int (*)(int)", allowDark)(1)
                end
            end
            
            -- Ordinal 136: FlushMenuThemes to re-render context menus using the new app mode
            local flushMenu = kernel32.GetProcAddress(hTheme, ffi.cast("const char*", 136))
            if flushMenu ~= nil then
                ffi.cast("void (*)()", flushMenu)()
            end
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
    local newEx = oldEx
    if enable then
        newEx = bit.bor(oldEx, WS_EX_TRANSPARENT, WS_EX_LAYERED)
    else
        newEx = bit.band(oldEx, bit.bnot(WS_EX_TRANSPARENT))
    end
    
    if oldEx ~= newEx then
        user32.SetWindowLongPtrA(hwnd, GWL_EXSTYLE, ffi.cast("LONG_PTR", newEx))
    end
end

function Tray.setTopmost(topmost)
    if not hwnd then return end
    local HWND_TOPMOST = ffi.cast("HWND", -1)
    local HWND_NOTOPMOST = ffi.cast("HWND", -2)
    local SWP_NOMOVE = 0x0002
    local SWP_NOSIZE = 0x0001
    local insertAfter = topmost and HWND_TOPMOST or HWND_NOTOPMOST
    user32.SetWindowPos(hwnd, insertAfter, 0, 0, 0, 0, bit.bor(SWP_NOMOVE, SWP_NOSIZE))
end

-- showMenu logic removed since Main loop orchestrates MMF UI spawning

function Tray.showSpecificWindow(title)
    local specificHwnd = user32.FindWindowA(nil, title)
    if specificHwnd and ffi.cast("intptr_t", specificHwnd) ~= 0 then
        user32.ShowWindow(specificHwnd, 5) -- SW_SHOW
        user32.SetForegroundWindow(specificHwnd)
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
    if hwnd then
        user32.ShowWindow(hwnd, 5)
        user32.SetForegroundWindow(hwnd)
    end
end

function Tray.getCursorPos()
    local pt = ffi.new("POINT")
    user32.GetCursorPos(pt)
    return pt.x, pt.y
end

function Tray.cleanup()
    if nid then
        shell32.Shell_NotifyIconA(2, nid) -- NIM_DELETE
    end
    if hwnd and oldWndProc then
        user32.SetWindowLongPtrA(hwnd, GWLP_WNDPROC, ffi.cast("LONG_PTR", oldWndProc))
    end
    if wndProcCallback then
        wndProcCallback:free()
    end
end

return Tray
