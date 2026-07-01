# 使用官方Python镜像作为基础镜像
FROM python:3.9-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8

# 1. 安装系统依赖：包含 SSH、cron、网络工具等
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    curl \
    wget \
    tree \
    iputils-ping \
    traceroute \
	vim \
    iproute2 \
    net-tools \	
	dnsutils \
    ca-certificates \
    tzdata \
    cron \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. 配置 SSH 服务
RUN echo 'root:password' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 3. 复制依赖与项目文件
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制脚本与二进制文件
COPY cloudflare_speedtest.py .
#COPY CloudflareST_proxy_linux_amd64 /app/CloudflareST_proxy_linux_amd64
COPY CloudflareST_proxy_linux_arm64 /app/CloudflareST_proxy_linux_arm64
COPY run.sh /app/run.sh
COPY upload-cfst.py /app/upload-cfst.py

# 4. 权限处理：确保所有工具可执行
#RUN chmod +x /app/CloudflareST_proxy_linux_amd64 \
RUN chmod +x /app/CloudflareST_proxy_linux_arm64

# 5. 数据与配置目录
RUN mkdir -p /app/data /app/config

# 6. 复制启动脚本 (确保 docker-entrypoint.sh 包含启动 SSH 的逻辑)
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

# 暴露端口：22 (SSH)
EXPOSE 22

# 设置入口点
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# 默认命令（保持容器运行）
CMD ["/usr/sbin/sshd", "-D"]
