FROM nginx:alpine

# Copy the build output to replace the default nginx contents.
COPY build/web /usr/share/nginx/html

# Configure for single-page application routing
RUN echo 'server {                                                      \
    listen 80;                                                          \
    server_name  localhost;                                             \
    location / {                                                        \
        root   /usr/share/nginx/html;                                   \
        index  index.html index.htm;                                    \
        try_files $uri $uri/ /index.html;                               \
    }                                                                   \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
