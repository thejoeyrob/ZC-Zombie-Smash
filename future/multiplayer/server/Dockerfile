FROM node:22-bookworm-slim
WORKDIR /app
COPY --chown=node:node . .
USER node
ENV PORT=8080 BIND=0.0.0.0
EXPOSE 8080
CMD ["node", "server.mjs"]
