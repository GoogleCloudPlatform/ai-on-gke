FROM google-go.pkg.dev/golang:1.21.7 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download -x

COPY main.go ./

# Purposefully set AFTER downloading and caching dependencies
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags="-w -s" -o /go/bin/kuberay-tpu-webhook .

FROM gke.gcr.io/gke-distroless/static:gke_distroless_20240107.00_p0@sha256:115bea5bea0fcdf50755147c60772474ed6c67baf0bb55851d1c4c050bb420df
COPY --from=builder /go/bin/kuberay-tpu-webhook /usr/local/bin/kuberay-tpu-webhook

EXPOSE 443
ENTRYPOINT ["kuberay-tpu-webhook"]
