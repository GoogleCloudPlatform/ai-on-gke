# Use an official Node.js runtime as a parent image
FROM node:16-alpine

# Install curl using the Alpine package manager
RUN apk add --no-cache curl

# Set the working directory to /app
WORKDIR /app

# Copy the package.json and install dependencies
COPY package.json ./
RUN npm install

# Copy the current directory contents into the container at /app
COPY . .

# Build the app for production
RUN npm run build

# Install serve to serve the build folder
RUN npm install -g serve

# Set the environment variable to production
ENV NODE_ENV=production

# Expose port 3000 to the outside world
EXPOSE 3000

# Serve the built app
CMD ["serve", "-s", "build"]
