# syntax=docker/dockerfile:1
# kgcheckin —— 酷狗概念版自动签到（Docker 版）
FROM node:20-alpine

ENV NODE_ENV=production \
    TZ=UTC

WORKDIR /app

# ── 根目录依赖（qrcode、node-cron）──
# 注意：--ignore-scripts 跳过根 package.json 的 install 生命周期脚本
# （该脚本会执行 cd api && npm ci 全量安装，Dockerfile 中改为下方显式按需安装）
COPY package.json ./
RUN npm install --omit=dev --ignore-scripts \
    && npm cache clean --force

# ── API 服务生产依赖（先只拷贝清单文件，充分利用构建缓存）──
COPY api/package.json api/package-lock.json ./api/
RUN cd api \
    && npm ci --omit=dev \
    && npm cache clean --force \
    && rm -rf /root/.npm

# ── 业务源码 ──
COPY main.js sent.js phoneLogin.js qrcodeLogin.js scheduler.js ./
COPY utils ./utils
COPY api ./api

# ── 运行时目录与权限 ──
# /app/data：挂载卷（userinfo.json 凭据、二维码输出）
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /app/data \
    && chown -R node:node /app/data

USER node

# 凭据文件与二维码输出统一放到挂载卷内
ENV USERINFO_FILE=/app/data/userinfo.json \
    QR_DIR=/app/data/qr \
    QR_KEYS_FILE=/app/data/qrkeys.json

# API 服务仅容器内部使用（127.0.0.1:3000），无需对外暴露端口
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "scheduler.js"]
