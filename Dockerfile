# Build stage
FROM --platform=$BUILDPLATFORM debian:stable-slim AS builder
LABEL org.opencontainers.image.authors="Umbrel, Inc. <https://umbrel.com>"

ARG VERSION
ARG TARGETPLATFORM

WORKDIR /build

RUN echo "Installing build deps"
RUN apt-get update
RUN apt-get install -y wget pgp

RUN echo "Deriving tarball name from \$TARGETPLATFORM" && \
    case "${TARGETPLATFORM}" in \
      "linux/amd64")  echo "bitcoin-${VERSION}-x86_64-linux-gnu.tar.gz"    > /tarball-name ;; \
      "linux/arm64")  echo "bitcoin-${VERSION}-aarch64-linux-gnu.tar.gz"   > /tarball-name ;; \
      *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    echo "Tarball name: $(cat /tarball-name)"

RUN echo "Downloading release assets"
RUN wget https://bitcoinknots.org/files/28.x/28.1.knots20250305/$(cat /tarball-name)
RUN wget https://bitcoinknots.org/files/28.x/28.1.knots20250305/SHA256SUMS.asc
RUN wget https://bitcoinknots.org/files/28.x/28.1.knots20250305/SHA256SUMS
RUN echo "Downloaded release assets:" && ls

RUN echo "Verifying PGP signatures"
RUN curl -s "https://api.github.com/repos/bitcoinknots/guix.sigs/contents/builder-keys" | jq -r '.[].download_url' | while read url; do curl -s "$url" | gpg --import; done
RUN gpg --verify SHA256SUMS.asc 2>&1 >/dev/null | grep "^gpg: Good signature from" || { echo "No valid signature"; exit 1; }
RUN echo "PGP signature verification passed"

RUN echo "Verifying checksums"
RUN [ -f SHA256SUMS ] && cp SHA256SUMS /sha256sums || cp SHA256SUMS.asc /sha256sums
RUN grep $(cat /tarball-name) /sha256sums | sha256sum -c
RUN echo "Checksums verified ok"

RUN echo "Extracting release assets"
RUN tar -zxvf $(cat /tarball-name) --strip-components=1

# Final image
FROM debian:stable-slim

RUN apt update

RUN apt install curl -y

COPY --from=builder /build/bin/bitcoind /bin
COPY --from=builder /build/bin/bitcoin-cli /bin

ENV HOME=/data
VOLUME /data/.bitcoin

EXPOSE 8332 8333 18332 18333 18443 18444

ENTRYPOINT ["bitcoind"]
