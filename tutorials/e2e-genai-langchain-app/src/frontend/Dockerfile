# Use a Node.js image
FROM node:16-slim

# Set the working directory
WORKDIR /app

# Copy the build files from the local system to the container
COPY . ./
RUN npm install && \
    npm run build && \
    npm install serve && \
    npm cache clean --force

# Command to run the application
CMD ["npx", "serve", "-s", "dist", "-l", "3000"]

# Expose the port the app runs on
EXPOSE 3000
