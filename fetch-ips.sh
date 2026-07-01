#!/bin/bash

# ==========================================
# 环境变量与路径定义
# ==========================================
CONFIG_DIR="/app/config"
DATA_DIR="/app/data"
DOMAIN_LIST="$CONFIG_DIR/domains.txt"
LOG_FILE="$DATA_DIR/optimizer.log"

# 获取当前时间
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
FILE_TIME=$(date +"%Y%m%d_%H%M%S")
CSV_FILE="$DATA_DIR/optimized_ips_${FILE_TIME}.csv"

# ==========================================
# 1. 初始化与函数定义
# ==========================================
mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"

# 日志输出函数
log() {
    echo "[$CURRENT_TIME] $1" | tee -a "$LOG_FILE"
}

log "任务启动: 开始 IP 优选流程。"

if [ ! -f "$DOMAIN_LIST" ]; then
    log "[错误] 找不到配置文件: $DOMAIN_LIST，请检查挂载路径。"
    exit 1
fi

# ==========================================
# 2. 解析域名并生成 CSV
# ==========================================
log "开始解析域名列表..."
echo "Domain,Optimized_IP,Update_Time" > "$CSV_FILE"

while IFS= read -r domain || [ -n "$domain" ]; do
    domain=$(echo "$domain" | awk '{$1=$1};1')
    case "$domain" in ""|\#*) continue ;; esac

    # 解析 IP
    BEST_IP=$(curl -s "https://dns.alidns.com/resolve?name=${domain}&type=1" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

    if [ -n "$BEST_IP" ]; then
        log "成功: [$domain] -> $BEST_IP"
        echo "${domain},${BEST_IP},${FILE_TIME}" >> "$CSV_FILE"
    else
        log "[警告]: $domain 解析失败。"
        echo "${domain},ERROR,${FILE_TIME}" >> "$CSV_FILE"
    fi
done < "$DOMAIN_LIST"

log "任务完成: 结果已生成至 $CSV_FILE"

# ==========================================
# 3. 历史数据轮转 (保留最近 7 次 CSV)
# ==========================================
log "正在轮转旧数据..."
cd "$DATA_DIR" || exit
# 保留最近 7 个 csv 文件
ls -1t optimized_ips_*.csv 2>/dev/null | tail -n +8 | xargs -I {} rm -f "{}"
log "轮转结束，仅保留最近 7 次数据记录。"
