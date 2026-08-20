FROM ghcr.io/diegosouzapw/omniroute:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends git curl ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY github-sync.sh /app/github-sync.sh
RUN chmod +x /app/github-sync.sh && chown -R node:node /app

USER node
ENV PORT=20128
ENV DATA_DIR=/app/data
EXPOSE 20128

ENTRYPOINT []
CMD ["/app/github-sync.sh"]
