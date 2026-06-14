FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

ENV NODE_ENV=production
ENV DATA_DIR=/data
ENV HOST=0.0.0.0

RUN mkdir -p /data

EXPOSE 4242

CMD ["node", "server.js"]
