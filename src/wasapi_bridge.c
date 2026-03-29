#define INITGUID
#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <math.h>

// [SharpEye] WASAPI Bridge Driver v1.06
// 优化了对多声道 (7.1/5.1) 环境的能量采集，防止静音通道摊薄增益

#define REFTIMES_PER_SEC  10000000

typedef struct {
    IMMDeviceEnumerator *pEnumerator;
    IMMDevice *pDevice;
    IAudioClient *pAudioClient;
    IAudioCaptureClient *pCaptureClient;
    WAVEFORMATEX *pwfx;
    float current_low;
    float current_mid;
    float current_hi;
    BOOL active;
    HANDLE hThread;
} WASAPI_State;

static WASAPI_State g_state = {0};

static float get_sample_value(BYTE* pData, int index, WAVEFORMATEX* wfx) {
    int bits = wfx->wBitsPerSample;
    if (wfx->wFormatTag == WAVE_FORMAT_IEEE_FLOAT || (bits == 32 && wfx->wFormatTag == WAVE_FORMAT_EXTENSIBLE)) {
        return ((float*)pData)[index];
    } else if (bits == 16) {
        return (float)((short*)pData)[index] / 32768.0f;
    } else if (bits == 24) {
        BYTE* b = &pData[index * 3];
        int val = (int)((b[2] << 16) | (b[1] << 8) | b[0]);
        if (val & 0x800000) val |= 0xFF000000;
        return (float)val / 8388608.0f;
    }
    return 0;
}

DWORD WINAPI CaptureThread(LPVOID lpParam) {
    HRESULT hr;
    UINT32 packetLength = 0;
    BYTE *pData;
    UINT32 numFramesAvailable;
    DWORD flags;

    while (g_state.active) {
        Sleep(1); 
        hr = g_state.pCaptureClient->lpVtbl->GetNextPacketSize(g_state.pCaptureClient, &packetLength);
        if (FAILED(hr)) continue;

        while (packetLength != 0) {
            hr = g_state.pCaptureClient->lpVtbl->GetBuffer(g_state.pCaptureClient, &pData, &numFramesAvailable, &flags, NULL, NULL);
            if (SUCCEEDED(hr)) {
                int channels = g_state.pwfx->nChannels;
                float lAcc = 0, mAcc = 0, hAcc = 0;

                for (UINT32 i = 0; i < numFramesAvailable; i++) {
                    float sample = 0;
                    
                    // 针对多声道优化：
                    // 音乐主要存在于第 1 (左) 和 第 2 (右) 通道。
                    // 就算有 8 个通道，我们也只取这两个作为主要参考源，避免被静音通道摊薄。
                    float left = get_sample_value(pData, i*channels + 0, g_state.pwfx);
                    float right = (channels > 1) ? get_sample_value(pData, i*channels + 1, g_state.pwfx) : left;
                    sample = (fabsf(left) + fabsf(right)) / 2.0f;

                    // 极致感应：针对多声道的信号特征进行动态补强
                    lAcc += sample * 12.0f; 
                    mAcc += sample * 6.0f; 
                    hAcc += sample * 4.0f;
                }

                float weight = 10.0f / (numFramesAvailable + 1); 
                g_state.current_low = g_state.current_low * 0.7f + (lAcc * weight) * 0.3f;
                g_state.current_mid = g_state.current_mid * 0.72f + (mAcc * weight) * 0.28f;
                g_state.current_hi = g_state.current_hi * 0.75f + (hAcc * weight) * 0.25f;

                g_state.pCaptureClient->lpVtbl->ReleaseBuffer(g_state.pCaptureClient, numFramesAvailable);
            }
            g_state.pCaptureClient->lpVtbl->GetNextPacketSize(g_state.pCaptureClient, &packetLength);
        }
    }
    return 0;
}

__declspec(dllexport) int wasapi_init() {
    if (g_state.active) return 1;
    HRESULT hr;
    CoInitialize(NULL);
    hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void**)&g_state.pEnumerator);
    if (FAILED(hr)) return 0;
    hr = g_state.pEnumerator->lpVtbl->GetDefaultAudioEndpoint(g_state.pEnumerator, eRender, eConsole, &g_state.pDevice);
    if (FAILED(hr)) return 0;
    hr = g_state.pDevice->lpVtbl->Activate(g_state.pDevice, &IID_IAudioClient, CLSCTX_ALL, NULL, (void**)&g_state.pAudioClient);
    if (FAILED(hr)) return 0;
    hr = g_state.pAudioClient->lpVtbl->GetMixFormat(g_state.pAudioClient, &g_state.pwfx);
    if (FAILED(hr)) return 0;
    hr = g_state.pAudioClient->lpVtbl->Initialize(g_state.pAudioClient, AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK, REFTIMES_PER_SEC, 0, g_state.pwfx, NULL);
    if (FAILED(hr)) return 0;
    hr = g_state.pAudioClient->lpVtbl->GetService(g_state.pAudioClient, &IID_IAudioCaptureClient, (void**)&g_state.pCaptureClient);
    if (FAILED(hr)) return 0;
    hr = g_state.pAudioClient->lpVtbl->Start(g_state.pAudioClient);
    if (FAILED(hr)) return 0;
    g_state.active = TRUE;
    g_state.hThread = CreateThread(NULL, 0, CaptureThread, NULL, 0, NULL);
    return 1;
}

__declspec(dllexport) void wasapi_get_format(int* channels, int* bits, int* rate) {
    if (g_state.pwfx) {
        if (channels) *channels = g_state.pwfx->nChannels;
        if (bits) *bits = g_state.pwfx->wBitsPerSample;
        if (rate) *rate = (int)g_state.pwfx->nSamplesPerSec;
    }
}

__declspec(dllexport) void wasapi_get_bands(float* l, float* m, float* h) {
    if (l) *l = (g_state.current_low > 1.5f) ? 1.0f : (g_state.current_low / 1.5f);
    if (m) *m = (g_state.current_mid > 1.5f) ? 1.0f : (g_state.current_mid / 1.5f);
    if (h) *h = (g_state.current_hi > 1.5f) ? 1.0f : (g_state.current_hi / 1.5f);
    g_state.current_low *= 0.88f;
    g_state.current_mid *= 0.88f;
    g_state.current_hi *= 0.88f;
}

__declspec(dllexport) void wasapi_stop() {
    g_state.active = FALSE;
    if (g_state.hThread) {
        WaitForSingleObject(g_state.hThread, 500);
        CloseHandle(g_state.hThread);
        g_state.hThread = NULL;
    }
    if (g_state.pAudioClient) g_state.pAudioClient->lpVtbl->Stop(g_state.pAudioClient);
    CoUninitialize();
}
