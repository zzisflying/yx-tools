#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import csv
import os
import re
import sys
from datetime import datetime

import requests

APP_DIR = "/app"
CONFIG_DIR = f"{APP_DIR}/config"
DATA_DIR = f"{APP_DIR}/data"

CONFIG_FILE = f"{CONFIG_DIR}/uuid.txt"
LOG_FILE = f"{DATA_DIR}/upload.log"

# 上传前多少个 IP
UPLOAD_COUNT = 10


def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"

    print(line, flush=True)

    os.makedirs(DATA_DIR, exist_ok=True)

    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def load_config():
    """
    支持两种格式：

    host=cfnew-edge.longway.cc.cd
    uuid=edge/sub/xxxxxxxx

    或

    https://cfnew-edge.longway.cc.cd/edge/sub/xxxxxxxx/api/preferred-ips
    """

    if not os.path.exists(CONFIG_FILE):
        raise Exception(f"配置文件不存在：{CONFIG_FILE}")

    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        content = f.read().strip()

    # 完整 URL 格式
    if content.startswith("http"):
        m = re.match(
            r"https://([^/]+)/(.+)/api/preferred-ips/?$",
            content
        )

        if not m:
            raise Exception("uuid.txt URL 格式错误")

        return m.group(1), m.group(2)

    host = None
    uuid = None

    for line in content.splitlines():
        line = line.strip()

        if not line:
            continue

        if line.startswith("#"):
            continue

        if "=" not in line:
            continue

        k, v = line.split("=", 1)

        k = k.strip()
        v = v.strip()

        if k == "host":
            host = v

        elif k == "uuid":
            uuid = v

    if not host:
        raise Exception("uuid.txt 缺少 host")

    if not uuid:
        raise Exception("uuid.txt 缺少 uuid")

    return host, uuid


def load_ips(result_file):
    ips = []
    region_counter = {}

    with open(result_file, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        for row in reader:
            if len(ips) >= UPLOAD_COUNT:
                break

            ip = row.get("IP 地址", "").strip()

            if not ip:
                continue

            try:
                port = int(row.get("端口", 443))
            except Exception:
                port = 443

            region = row.get("地区码", "").strip()

            if (
                not region
                or region == "-"
                or region.lower() == "unknown"
            ):
                region = "CF"

            region_counter.setdefault(region, 0)
            region_counter[region] += 1

            name = f"{region}-{region_counter[region]}"

            ips.append({
                "ip": ip,
                "port": port,
                "name": name
            })

    return ips


def clear_old_ips(api):
    log("正在清空旧 IP...")

    r = requests.delete(
        api,
        json={"all": True},
        timeout=15
    )

    if r.status_code != 200:
        raise Exception(
            f"清空失败：HTTP {r.status_code} {r.text}"
        )

    log("旧 IP 已清空")


def upload_ips(api, ips):
    log(f"开始上传 {len(ips)} 个 IP...")

    r = requests.post(
        api,
        json=ips,
        timeout=30
    )

    if r.status_code != 200:
        raise Exception(
            f"上传失败：HTTP {r.status_code} {r.text}"
        )

    log("上传成功")
    log(r.text)


def main():
    if len(sys.argv) > 1:
        result_file = sys.argv[1]
    else:
        result_file = f"{APP_DIR}/result.csv"

    if not os.path.exists(result_file):
        log(f"ERROR: CSV 文件不存在：{result_file}")
        sys.exit(1)

    try:
        host, uuid = load_config()

        api = f"https://{host}/{uuid}/api/preferred-ips"

        log(f"API: {api}")
        log(f"CSV: {result_file}")

        ips = load_ips(result_file)

        if len(ips) == 0:
            raise Exception("CSV 中未找到任何可上传 IP")

        log(f"准备上传 {len(ips)} 个 IP")

        # 先确认有数据，再清空旧数据
        clear_old_ips(api)

        # 上传新数据
        upload_ips(api, ips)

        log("全部完成")

    except Exception as e:
        log(f"ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
