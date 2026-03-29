# Bionic Beating Heart (L0V3 Companion) - v0.1.4

![Beating Heart](https://github.com/ShenyfZero9211/BeatingHeart/raw/main/screenshot.png) *(Note: Placeholder link, replace with your actual screen capture)*

**Beating Heart** 是一款基于 Love2D 开发的仿生桌面音乐伴侣。它不仅仅是一个可视化工具，更是一个具备“原生感官”的数字生命——它能直接从 Windows 内核捕获声音，并以高度拟真的生物律动进行视觉反馈。

## 🌟 核心特性 (v0.1.4 Pure Soul)

### 1. 原生硬件感官 (Native WASAPI Sense)
- **零配置内录**：通过自定义 C 编写的 WASAPI Loopback 驱动，直接从扬声器捕获信号。
- **全格式兼容**：支持 16/24/32-bit PCM 采样，深度适配 5.1/7.1 环绕声环境。
- **高保真 FFT**：底层进行实时分频处理，低频爆发力提升 1.8 次幂。

### 2. 生物拟态律动 (Bionic Animation)
- **有机形变 (Organic Distortion)**：长时间的高能状态会产生“兴奋积压”，触发心脏的非等比例挤压与拉伸。
- **生理震颤 (Soft Jitter)**：模拟真实的肌肉颤动，告别电子噪波感。
- **感官唤醒**：内置“苏醒-平稳-狂暴”多种情绪状态转换逻辑。

### 3. 内核级稳定性 (Iron Pulse)
- **铁腕单例 (Iron Mutex)**：使用 Windows 内核互斥体锁，确保全系统内唯一运行实例，轻量且健壮。
- **极速秒退 (v1.07 Driver)**：重构了线程回收链，关闭延迟从 500ms 降至 10ms，点击即刻消失。
- **系统字体集成**：自动检索 `WINDIR\Fonts` 挂载微软雅黑，不再占用额外的硬盘空间（项目体积缩减 95%）。

## 🚀 快速开始

### 环境要求
- **Windows 10/11** (x64)
- [Love2D](https://love2d.org/) (推荐 11.x 版本)

### 启动
1. 下载仓库并解压。
2. 在目录内运行：`love .`
3. 播放任意音乐（无需设置立体声混音），心脏将自动开始跳动。

## ⚙️ 交互说明
- **左键拖动**：自由摆放心脏位置。
- **右键菜单**：
    - **设置**：调节心脏体积、灵敏度及 5 种预设配色。
    - **退出**：安全且快速地释放驱动并退出。

## 🛠️ 技术架构与编译 (Compilation)

本程序的核心音频驱动采用原生 C 语言编写，以实现极致的低延迟采集。

### 自行编译 C 驱动
如果您修改了 `src/wasapi_bridge.c` 或需要为当前系统重新构建 DLL，请确保已安装 **MinGW-w64 (GCC)**。

1. **环境准备**: 将 `gcc` 加入系统环境变量。
2. **一键编译**: 直接运行根目录下的 `compile.bat`。
   - 该脚本会自动链接 `ole32`, `mmdevapi`, `avrt`, `uuid` 等 Windows 多媒体内核库。
3. **产物**: 编译成功后将在根目录生成 `wasapi_bridge.dll`。

### 核心模块
- **Lua 代码**: 逻辑控制、UI 渲染 (Love2D)。
- **C 代码**: `src/wasapi_bridge.c` —— 底层 WASAPI Loopback 采集实现。
- **FFI 桥梁**: `src/wasapi_ffi.lua` —— Lua 与 C 的高效数据交换层。

---
*Created by SharpEye. Powered by L0V3 11.4.*
