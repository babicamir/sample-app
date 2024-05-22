FROM nginx:stable-alpine3.19

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80