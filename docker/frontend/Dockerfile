# Use Nginx Alpine (lightweight web server)
FROM nginx:alpine

# Copy static HTML/CSS/JS files to Nginx's default serving directory
COPY public/ /usr/share/nginx/html/

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80 for HTTP traffic
EXPOSE 80

# Health check - verifies Nginx is serving content correctly
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1