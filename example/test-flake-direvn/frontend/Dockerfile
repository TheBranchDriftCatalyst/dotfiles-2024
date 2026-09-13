FROM node:22-slim
RUN npm install -g pnpm@11

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

EXPOSE 5173
# vite dev server (not a prod build) — this is the inner dev loop
CMD ["pnpm", "dev", "--host", "0.0.0.0"]
