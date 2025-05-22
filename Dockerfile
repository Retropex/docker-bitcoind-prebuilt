# Build stage
FROM --platform=$BUILDPLATFORM debian:stable-slim AS builder
LABEL org.opencontainers.image.authors="Umbrel, Inc. <https://umbrel.com>"

ARG VERSION
ARG TARGETPLATFORM

WORKDIR /build

RUN echo "Installing build deps"
RUN apt-get update
RUN apt-get install -y build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 libevent-dev libboost-dev libsqlite3-dev libminiupnpc-dev libnatpmp-dev libzmq3-dev systemtap-sdt-dev git

RUN git clone --branch custom-knots https://github.com/retropex/bitcoin

WORKDIR /build/bitcoin

RUN ./autogen.sh && ./configure --with-gui=no --disable-tests --with-miniupnpc=no --with-natpmp=no

RUN make -j $(nproc)

# Final image
FROM debian:stable-slim

RUN apt update

RUN apt install curl libevent-dev libboost-dev libzmq3-dev libsqlite3-dev -y

COPY --from=builder /build/bitcoin/src/bitcoind /bin
COPY --from=builder /build/bitcoin/src/bitcoin-cli /bin

ENV HOME=/data
VOLUME /data/.bitcoin

EXPOSE 8332 8333 18332 18333 18443 18444

ENTRYPOINT ["bitcoind"]
