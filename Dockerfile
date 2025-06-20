# Dockerfile
FROM nginx:alpine

# Clean out the default Nginx site
RUN rm -rf /usr/share/nginx/html/*

# Copy the web build output
COPY build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
