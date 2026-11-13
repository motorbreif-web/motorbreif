FROM node:22-alpine AS build

WORKDIR /app

# Use the package-manager version recorded in the project manifest.
RUN npm install --global npm@10.9.2

COPY package.json ./package.json
COPY server/package.json server/package-lock.json ./server/
COPY client/package.json client/package-lock.json ./client/

RUN npm ci --prefix server && npm ci --prefix client

COPY server ./server
COPY client ./client

RUN npm run build

FROM node:22-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

COPY --from=build /app/package.json ./package.json
COPY --from=build --chown=node:node /app/server ./server
COPY --from=build --chown=node:node /app/client/dist ./client/dist

USER node

EXPOSE 3000

CMD ["npm", "start"]
