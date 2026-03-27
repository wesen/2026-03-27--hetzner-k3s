FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags='-s -w' -o /out/demo-go-app ./main.go

FROM alpine:3.20
RUN adduser -D -H -u 10001 appuser
USER 10001
WORKDIR /
COPY --from=build /out/demo-go-app /demo-go-app
EXPOSE 8080
ENTRYPOINT ["/demo-go-app"]
