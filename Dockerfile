FROM node:18.17-alpine AS builder
WORKDIR /app
RUN npm install -g pnpm
COPY pnpm-lock.yaml .npmrc ./
RUN pnpm fetch --prod

COPY . ./
RUN mv .env.example .env
RUN pnpm install --prod --offline --frozen-lockfile
#RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store pnpm install --prod --offline --frozen-lockfile
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

ARG BUILD_DATE
ARG CID
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name="scypi/a11y-audit-server"
LABEL org.label-schema.vcs-url="https://github.com/scypi/a11y-audit-tool"
LABEL org.label-schema.vcs-ref=$CID

##########

FROM nginx:alpine AS statics
WORKDIR /app
COPY --from=builder /app/.output/public/ /usr/share/nginx/html/

ARG BUILD_DATE
ARG CID
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name="scypi/a11y-audit-statics"
LABEL org.label-schema.vcs-url="https://github.com/scypi/a11y-audit-tool"
LABEL org.label-schema.vcs-ref=$CID
