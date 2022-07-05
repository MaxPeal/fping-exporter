FROM golang:alpine AS build
RUN apk add --update --no-cache ca-certificates git
# https://zchee.github.io/golang-wiki/GoArm/
# https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/
# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
# ARG BUILDPLATFORM TARGETOS TARGETARCH TARGETPLATFORM
ARG TARGETPLATFORM TARGETOS TARGETARCH TARGETVARIANT BUILDPLATFORM BUILDOS BUILDARCH BUILDVARIANT
#    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
#    TARGETOS - OS component of TARGETPLATFORM
#    TARGETARCH - architecture component of TARGETPLATFORM
#    TARGETVARIANT - variant component of TARGETPLATFORM
#    BUILDPLATFORM - platform of the node performing the build.
#    BUILDOS - OS component of BUILDPLATFORM
#    BUILDARCH - architecture component of BUILDPLATFORM
#    BUILDVARIANT - variant component of BUILDPLATFORM
#
# https://github.com/BretFisher/multi-platform-docker-build
RUN printf "I'm building for TARGETPLATFORM=${TARGETPLATFORM}" \
    && printf ", TARGETARCH=${TARGETARCH}" \
    && printf ", TARGETVARIANT=${TARGETVARIANT} \n" \
    && printf "With uname -s : " && uname -s \
    && printf "and  uname -m : " && uname -mm
# RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

# 
# SHELL ["/bin/bash", "-exc"]
# ENV GOCACHE=/go/.buildcache
# We need to first generate everything w/o setting GOOS/GOARCH/GOARM
# Otherwise it will try to build supporting binaries (for the build itself) for the $TARGETPLATFORM, which we don't want.
# Those helper bins need to be for the $BUILDPLATFORM.
# RUN \
#	--mount=type=cache,target=/go/pkg/mod \
#	--mount=type=cache,target=/go/.buildcache \
#	make clean generate; \
#	export GOOS="$TARGETOS"; \
#	export GOARCH="$TARGETARCH"; \
#	if [ -n TARGETVARIANT ] && [ "$TARGETARCH" = "arm" ]; then \
#		export GOARM="${TARGETVARIANT//v}"; \
#	fi; \
#	make build

# Building Go can be achieved with the xx-go wrapper that automatically sets up values for GOOS, GOARCH, GOARM etc. It also sets up pkg-config and C compiler if building with CGo. Note that by default, CGo is enabled in Go when compiling for native architecture and disabled when cross-compiling. This can easily produce unexpected results; therefore, you should always define either CGO_ENABLED=1 or CGO_ENABLED=0 depending on if you expect your compilation to use CGo or not. https://github.com/tonistiigi/xx
#ENV CGO_ENABLED=1
ENV CGO_ENABLED=0
ENV GOCACHE=/go/.buildcache
ADD . /src
#RUN cd /src && CGO_ENABLED=0 go build -o fping-exporter
RUN cd /src && go build -v "fmt"
#RUN cd /src && GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=$TARGETVARIANT go mod download
#RUN cd /src && GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=$TARGETVARIANT go build -v -ldflags="-extldflags=-static -s -w -X main.version={{.Version}} -X main.commit={{.Commit}} -X main.date={{.Date}}"
# We need to first generate everything w/o setting GOOS/GOARCH/GOARM
# Otherwise it will try to build supporting binaries (for the build itself) for the $TARGETPLATFORM, which we don't want.
# Those helper bins need to be for the $BUILDPLATFORM.
# RUN cd /src && GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=$TARGETVARIANT go mod download
RUN \
	--mount=type=cache,target=/go/pkg/mod \
	--mount=type=cache,target=/go/.buildcache \
	export GOOS="$TARGETOS"; \
	export GOARCH="$TARGETARCH"; \
	if [ -n TARGETVARIANT ] && [ "$TARGETARCH" = "arm" ]; then \
		export GOARM="${TARGETVARIANT//v}"; \
	fi; \
    cd /src && go mod download

RUN \
	--mount=type=cache,target=/go/pkg/mod \
	--mount=type=cache,target=/go/.buildcache \
	export GOOS="$TARGETOS"; \
	export GOARCH="$TARGETARCH"; \
	if [ -n TARGETVARIANT ] && [ "$TARGETARCH" = "arm" ]; then \
		export GOARM="${TARGETVARIANT//v}"; \
	fi; \
    cd /src && go build -v -ldflags="-extldflags=-static -s -w -X main.version={{.Version}} -X main.commit={{.Commit}} -X main.date={{.Date}} \
    			-X main.buildCommit=`git rev-parse --short HEAD` -X main.buildDate=`date +%Y-%m-%d` -X main.buildVersion=$(VERSION)"

FROM alpine:latest
RUN apk add --update --no-cache ca-certificates fping
COPY --from=build /src/fping-exporter /
EXPOSE 9605
ENTRYPOINT ["/fping-exporter", "--fping=/usr/sbin/fping"]

