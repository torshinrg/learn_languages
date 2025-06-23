# Use lightweight nginx base image
FROM nginx:alpine

# Copy built Flutter web output
COPY build/web /usr/share/nginx/html

# Optional: Set caching headers or routing rules (optional)
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose default web port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
