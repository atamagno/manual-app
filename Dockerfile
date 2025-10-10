# Stage 1: Install ALL dependencies and build
FROM node:20 AS build

WORKDIR /usr/src/app

# Copy package files
COPY package.json yarn.lock ./

# Install all dependencies
RUN yarn install --frozen-lockfile --prefer-offline

# Copy source code
COPY . .

# Build the application
RUN yarn build:prod

# Stage 2: Production image (only prod dependencies)
FROM node:20-alpine AS production

WORKDIR /usr/src/app

# Copy package.json and yarn.lock
COPY package.json yarn.lock ./

# Install only production dependencies
RUN yarn install --frozen-lockfile --production --ignore-scripts && yarn cache clean

# Copy built files from the previous stage
COPY --from=build /usr/src/app/dist ./dist

EXPOSE 80

CMD ["node", "dist/index.js"]