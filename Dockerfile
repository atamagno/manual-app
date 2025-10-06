FROM node:20-alpine

WORKDIR /usr/src/app

# Copy package files
COPY package.json yarn.lock ./

# Install only production dependencies
RUN yarn install --frozen-lockfile --production --ignore-scripts && yarn cache clean

# Copy only necessary files for building
COPY tsconfig.json ./
COPY esbuild.config.ts ./
COPY src/ ./src/

# Build the application
RUN yarn build:prod

EXPOSE 3000

CMD ["node", "dist/index.js"]