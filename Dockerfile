FROM node:24-slim

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/chromium"

RUN apt-get update && apt-get install -y --no-install-recommends \
  g++ make cmake unzip libcurl4-openssl-dev autoconf automake autotools-dev libtool python3 curl \
  fonts-liberation libasound2  libatk-bridge2.0-0 libatk1.0-0 libcups2 libdrm2 \
  libgbm1 libgtk-3-0 libnspr4 libnss3 libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 \
  xdg-utils libu2f-udev libxshmfence1 libglu1-mesa chromium \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci
COPY src .

USER node
ENTRYPOINT ["node", "--unhandled-rejections=strict"]
