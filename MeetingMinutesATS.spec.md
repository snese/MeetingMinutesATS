# M3 Pro (18GB) 會議轉錄系統專案規格書  

## 總體架構要求  
- **硬體限制**: 記憶體峰值使用 ≤14GB (保留 4GB 給系統)  
- **品質標準**: 段落級準確率 ≥95% (人工抽檢)  
- **處理速度**: 1.5x 即時 (60 分鐘音頻 ≤40 分鐘處理時間)  

---

## 子任務分解表  

### 任務 1: 基礎環境建置   
**目標**: 建立安全的隔離開發環境  

| 步驟 | 操作指令 | 驗收標準 |  
|------|----------|----------|  
| 1.1 安裝系統依賴 | `brew install pyenv pyenv-virtualenv ffmpeg` | `/opt/homebrew/bin/ffmpeg` 存在 |  
| 1.2 創建 Python 3.10.13 環境 | `pyenv install 3.10.13 && pyenv virtualenv 3.10.13 whisper-env` | `pyenv versions` 顯示 whisper-env |  
| 1.3 安裝 MLX 框架 | `pip install mlx==0.0.14` | 可執行 `import mlx` 無錯誤 |  
| 1.4 配置 Metal 加速 | `export DYLD_LIBRARY_PATH=/opt/homebrew/lib` | `metal_version` 顯示 ≥3.0 |  
| 1.5 記憶體限制設定 | `echo 'export MLX_GPU_MEMORY_LIMIT=0.75' >> ~/.zshrc` | `printenv MLX_GPU_MEMORY_LIMIT` 返回 0.75 |  

**資源監控方案**:  
```bash
# 實時監控腳本 (保存為 monitor_resources.sh)
while true; do
    echo "=== $(date) ===" >> resource.log
    vm_stat | grep "Pages free" >> resource.log
    top -l 1 -s 0 | grep "PhysMem" >> resource.log
    sleep 30
done
```

---

### 任務 2: 核心轉錄模組部署 
**模型選型**: large-v3-q4 (1.7GB 量化版)  

| 組件 | 配置參數 | 記憶體佔用 |  
|------|----------|------------|  
| 主模型 | `--model large-v3-q4 --quant q4_0` | 3.2GB |  
| 聲學處理 | `--beam_size 5 --temperature 0.2` | +0.8GB |  
| 語言處理 | `--language zh-tw --initial_prompt "會議語言:繁體中文70%,英文30%"` | +1.1GB |  

**部署步驟**:  
```bash
# 步驟 2.1 下載模型
wget https://huggingface.co/mlx-community/whisper-large-v3-mlx/resolve/main/weights.npz -P ~/models/

# 步驟 2.2 驗證轉錄功能
python -c "import mlx_whisper; model = mlx_whisper.load_model('large-v3', quant='q4_0'); print(model.transcribe('test.m4a'))"

# 步驟 2.3 壓力測試 (監控 memory_pressure)
for i in {1..5}; do
    time whisper ~/VoiceMemos/meeting_$i.m4a \
        --model large-v3-q4 \
        --device mps \
        --memory_log ~/logs/memory_$i.csv
done
```

**驗收標準**:  
- 連續處理 5 個 30 分鐘音頻無 OOM 錯誤  
- 平均記憶體峰值 ≤12.8GB (包含系統佔用)  

---

### 任務 3: 後處理流水線開發 

#### 子任務 3.1: 標點校正模組  
```python
def correct_punctuation(text: str) -> str:
    replacements = {
        r'(\w)([，。]) ?([A-Z])': r'\1. \3',  # 中英標點轉換
        r'(\d+)[的]?年': r'\1年',            # 日期格式修正
        r'([a-zA-Z])([，。])': r'\1.'        # 英文句尾修正
    }
    for pattern, repl in replacements.items():
        text = re.sub(pattern, repl, text)
    return text
```

#### 子任務 3.2: 分段邏輯設計  
```python
def segment_by_speaker(text: str, max_chars=500) -> list:
    segments = []
    current_segment = []
    char_count = 0
    
    for sentence in re.split(r'(? max_chars:
            segments.append(''.join(current_segment))
            current_segment = []
            char_count = 0
        current_segment.append(sentence)
        char_count += s_length
    
    return segments
```

**記憶體優化措施**:  
- 啟用分塊處理模式 `--process_chunk 300` (每 300 秒分段)  
- 啟用增量式輸出 `--stream_output ~/transcriptions`  

---

### 任務 4: 自動化整合 

#### 方案 A: Raycast 深度整合  
```applescript
tell application "Raycast"  
    activate  
    set input to display dialog "開始會議錄音嗎?" default answer "60"  
    set duration to text returned of input as integer  
    
    do shell script "rec meeting_$(date +%s).wav trim 0 " & duration  
    
    set progress to display progress "轉錄進度" with title "處理中..."
    try
        do shell script "whisper_transcribe.sh latest"
        close progress with result "完成"
    on error
        close progress with result "失敗"
    end try
end tell
```

#### 方案 B: Folder Action 監控  
```bash
# 監控 VoiceMemos 資料夾
fswatch -0 ~/Library/Group\ Containers/group.com.apple.VoiceMemos/ |  
while read -d "" event  
do
    if [[ $event == *.m4a ]]; then
        /opt/whisper/process.sh "$event" &
        logger -t Whisper "開始處理: $event"
    fi  
done
```

**資源限流配置**:  
```bash
# 限制並發處理數
semaphore_file="/tmp/whisper_semaphore"
max_processes=2

( flock -n 200 || exit 1
  /opt/whisper/process.sh "$1"
) 200>$semaphore_file
```

---

### 任務 5: 質量驗證系統

#### 測試案例設計  
| 測試類型 | 樣本特徵 | 合格標準 |  
|----------|----------|----------|  
| 純中文 | 普通話朗讀文章 | CER ≤5% |  
| 中英混合 | 每分鐘切換 3 次語言 | 段落準確率 ≥90% |  
| 含背景音 | 50dB 白噪音環境 | 關鍵字識別率 ≥85% |  

#### 自動化測試腳本  
```python
import jiwer  
import sounddevice as sd  

def generate_test_case(duration=60, noise_level=0.2):  
    # 生成混合語音測試樣本  
    pure_chinese = record_audio(duration/2)  
    mixed_lang = insert_english(pure_chinese, interval=20)  
    noisy_sample = add_noise(mixed_lang, noise_level)  
    return noisy_sample  

def evaluate_quality(reference, hypothesis):  
    cer = jiwer.cer(reference, hypothesis)  
    wer = jiwer.wer(reference, hypothesis)  
    return {"CER": cer, "WER": wer, "KeyPhrases": extract_keywords(reference, hypothesis)}  
```

---

### 任務 6: 維護與監控方案 (持續性任務)  

#### 記憶體回收機制  
```python
import gc  
import mlx.core as mx  

class MemoryGuard:  
    def __enter__(self):  
        self.start_mem = mx.metal.get_active_memory()  
        return self  
        
    def __exit__(self, *args):  
        mx.gc()  
        if mx.metal.get_active_memory() > self.start_mem * 1.2:  
            mx.metal.clear_cache()  
        logger.info(f"記憶體回收完成, 當前使用: {mx.metal.get_active_memory()/1e9:.1f}GB")  
```

#### 日誌分析規則  
```bash
# 錯誤模式自動檢測
logtail -f ~/logs/whisper.log |  
grep -E -e "OutOfMemoryError" -e "CudaError" |  
while read line  
do  
    send_alert "Whisper 記憶體異常: $line"  
    adjust_parameters --model medium-q4  # 自動降級模型  
done  
```

---

## 硬體資源預留策略  
| 組件 | 預留資源 | 監控指標 | 應急方案 |  
|------|----------|----------|----------|  
| GPU | ≤14GB | `metalPerformanceShadersGraph` | 啟用分塊處理 |  
| CPU | 2 cores | `cpu_usage` ≥90% | 限制並發數 |  
| 磁碟 | ≥50MB/s | `disk_io` ≥80% | 啟用 RAM Disk |  

---

## 風險管理計劃  

### 風險 1: 長音頻處理失敗  
**緩解措施**:  
- 啟用分段處理模式 `--split_audio 600` (每 10 分鐘分段)  
- 部署斷點續傳功能:  
```python
def resume_transcribe(audio_path, checkpoint):  
    if os.path.exists(checkpoint):  
        with open(checkpoint, 'r') as f:  
            progress = json.load(f)  
        return process_segment(audio_path, progress['last_pos'])  
```

### 風險 2: 混合語言識別漂移  
**解決方案**:  
- 每 5 分鐘注入語言錨定提示:  
```bash
whisper input.m4a \
  --prompt_interval 300 \
  --initial_prompt "[此刻主要語言:繁體中文]"  
```

---

本規格書已考量 18GB RAM 限制，各子任務可並行開展。建議每日執行資源監控腳本並保存日誌，當記憶體使用連續 3 次超過 14GB 時，應啟動應急方案切換至 medium-q8 模型。

---
Answer from Perplexity: pplx.ai/share