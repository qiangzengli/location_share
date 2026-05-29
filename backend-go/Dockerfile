FROM alpine:3.20
RUN apk add --no-cache tzdata ca-certificates
ENV TZ=Asia/Shanghai
WORKDIR /app
COPY server_linux ./server
EXPOSE 8080
CMD ["./server"]
