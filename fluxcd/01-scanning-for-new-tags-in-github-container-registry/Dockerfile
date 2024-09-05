FROM nginx:alpine
WORKDIR /usr/share/nginx/html
RUN echo "<html><body><h1>Hello world</h1></body></html>" > index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
