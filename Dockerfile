FROM node:18.17-alpine AS builder

WORKDIR /app

RUN apk add python3 build-base
RUN npm install -g pnpm

COPY pnpm-lock.yaml .npmrc ./
RUN pnpm fetch --prod

COPY . ./
#RUN mv .env.example .env
RUN pnpm install --prod --offline --frozen-lockfile
RUN npx update-browserslist-db@latest
RUN pnpm build
RUN pnpm playwright

##########

FROM node:18.17-alpine AS server

ENV NODE_ENV=production

WORKDIR /app

COPY --from=builder /app/.output /app/.output

CMD [ "node", ".output/server/index.mjs" ]

EXPOSE 3000

##########

FROM nginx:alpine AS statics

WORKDIR /app

COPY --from=builder /app/.output/public/ /usr/share/nginx/html/
