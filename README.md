# MeetingMinutesATS - 會議轉錄系統

MeetingMinutesATS 是一個針對 M3 Pro (18GB) 硬體優化的會議轉錄系統，使用 MLX 框架和 Whisper large-v3-q4 模型，專為繁體中文和英文混合會議設計。

## 系統要求

- Apple Silicon Mac (M3 Pro 或同等級)
- macOS Sonoma 或更新版本
- 至少 18GB RAM
- 至少 10GB 可用磁碟空間

## 主要特點

- **高效能轉錄**: 1.5x 即時處理速度 (60 分鐘音頻 ≤40 分鐘處理時間)
- **高準確度**: 段落級準確率 ≥95% (人工抽檢)
- **記憶體優化**: 峰值使用 ≤14GB (保留 4GB 給系統)
- **混合語言支援**: 針對繁體中文(70%)和英文(30%)混合會議優化
- **自動化整合**: 支援 Raycast 和 Folder Action 自動化

## 目錄結構

```
MeetingMinutesATS/
├── src/                    # 源代碼
│   ├── transcribe.py       # 核心轉錄模組
│   ├── postprocess.py      # 後處理流水線
│   └── quality_validation.py # 質量驗證系統
├── scripts/                # 腳本
│   ├── setup.sh            # 環境設置腳本
│   ├── monitor_resources.sh # 資源監控腳本
│   ├── folder_monitor.sh   # 資料夾監控腳本
│   ├── process.sh          # 處理腳本
│   ├── maintenance.sh      # 維護腳本
│   └── raycast_integration.applescript # Raycast 整合
├── models/                 # 模型文件
├── logs/                   # 日誌文件
├── recordings/             # 錄音文件
├── transcriptions/         # 轉錄結果
├── test_cases/             # 測試案例
├── test_results/           # 測試結果
└── config/                 # 配置文件
```

## 安裝與設置

### 1. 克隆儲存庫

```bash
git clone https://github.com/yourusername/MeetingMinutesATS.git
cd MeetingMinutesATS
```

### 2. 運行設置腳本

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

此腳本將:
- 安裝系統依賴 (pyenv, pyenv-virtualenv, ffmpeg)
- 創建 Python 3.10.13 環境
- 安裝 MLX 框架
- 配置 Metal 加速
- 設置記憶體限制

### 3. 下載模型

設置腳本完成後，系統將自動下載 Whisper large-v3-q4 模型。如果需要手動下載:

```bash
mkdir -p ~/models/whisper-large-v3-mlx
wget https://huggingface.co/mlx-community/whisper-large-v3-mlx/resolve/main/weights.npz -P ~/models/whisper-large-v3-mlx/
```

## 使用方法

### 方法 1: 使用 Raycast 整合

#### 選項 A: 使用 AppleScript (推薦)

1. 在 Raycast 中添加 Script Command:
   - 打開 Raycast 偏好設置 (⌘+,)
   - 選擇 "Extensions" 標籤
   - 選擇 "Script Commands"
   - 點擊 "+" 添加新腳本
   - 選擇 "AppleScript" 作為語言
   - 將 `scripts/raycast_integration.applescript` 的內容複製到編輯器中
   - 命名為 "Meeting Recorder" 並保存

2. 通過 Raycast 運行腳本開始錄音和轉錄

#### 選項 B: 使用 Python 腳本

1. 在 Raycast 中添加 Script Command:
   - 打開 Raycast 偏好設置 (⌘+,)
   - 選擇 "Extensions" 標籤
   - 選擇 "Script Commands"
   - 點擊 "+" 添加新腳本
   - 選擇 "Bash" 作為語言
   - 輸入: `python3 $HOME/Documents/Projects/MeetingMinutesATS/scripts/raycast_integration.py`
   - 命名為 "Meeting Recorder (Python)" 並保存

2. 通過 Raycast 運行腳本開始錄音和轉錄

#### 選項 C: 直接運行腳本

如果您在 Raycast 中遇到問題，可以直接運行腳本:

```bash
# AppleScript 版本
osascript scripts/raycast_integration.applescript

# Python 版本
python3 scripts/raycast_integration.py
```

### 方法 2: 使用資料夾監控

1. 啟動資料夾監控腳本:

```bash
chmod +x scripts/folder_monitor.sh
./scripts/folder_monitor.sh &
```

2. 將音頻文件放入 VoiceMemos 資料夾，系統將自動處理

### 方法 3: 手動轉錄

1. 激活 Python 環境:

```bash
pyenv activate whisper-env
```

2. 運行轉錄:

```bash
python src/transcribe.py path/to/audio/file.m4a
```

3. 運行後處理:

```bash
python src/postprocess.py transcriptions/file.json
```

## 質量驗證

運行質量驗證測試:

```bash
python src/quality_validation.py --test all
```

可用的測試類型:
- `all`: 運行所有測試
- `pure_chinese`: 純中文測試
- `mixed_language`: 中英混合測試
- `noisy`: 含背景噪音測試

## 維護與監控

啟動維護和監控腳本:

```bash
chmod +x scripts/maintenance.sh
./scripts/maintenance.sh &
```

此腳本將:
- 監控系統記憶體使用
- 分析日誌文件尋找錯誤
- 在必要時進行記憶體回收
- 在出現問題時發送警報

## 故障排除

### 記憶體問題

如果遇到記憶體不足錯誤:

1. 檢查 `logs/maintenance.log` 中的記憶體使用情況
2. 調整 `MLX_GPU_MEMORY_LIMIT` 環境變數 (預設為 0.75)
3. 使用較小的模型 (medium-q8 而非 large-v3-q4)
4. 增加音頻分塊大小 (使用 `--chunk_size` 參數)

### 轉錄質量問題

如果轉錄質量不佳:

1. 運行質量驗證測試確定問題
2. 調整 `--beam_size` 和 `--temperature` 參數
3. 修改初始提示以更好地匹配會議內容
4. 確保音頻質量良好，減少背景噪音

### MLX 相關問題

如果遇到 MLX 相關錯誤:

1. 確保已安裝正確版本的 MLX: `pip install mlx==0.24.1`
2. 安裝 mlx_whisper: `pip install git+https://github.com/mlx-community/mlx-whisper.git`
3. 運行測試腳本檢查 MLX 導入: `python test_mlx.py`
4. 檢查 Python 環境是否正確激活: `pyenv activate whisper-env`

### AppleScript 錯誤

如果 Raycast 整合腳本出現錯誤:

1. 嘗試使用 Python 版本的整合腳本: `python scripts/raycast_integration.py`
2. 直接從命令行運行 AppleScript: `osascript scripts/raycast_integration.applescript`
3. 檢查 SoX 是否已安裝: `brew install sox`

## 版本歷史

詳細的更改記錄請參閱 [CHANGELOG.md](CHANGELOG.md)。

## 貢獻

歡迎提交 Pull Requests 和 Issues!

## 授權
