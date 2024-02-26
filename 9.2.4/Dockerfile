FROM debian:unstable-20230814 as build

COPY <<EOF /etc/apt/sources.list.d/debian.sources
Types: deb deb-src
URIs: http://snapshot.debian.org/archive/debian/20230814T000000Z
Suites: unstable
Components: main
check-valid-until: no
trusted: yes
EOF

RUN apt-get update -yq \
&& DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
autoconf automake build-essential ca-certificates curl ghc locales make patch python3 xz-utils \
&& apt-get clean \
&& rm -fr /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN curl -sL https://downloads.haskell.org/~ghc/9.2.4/ghc-9.2.4-src.tar.xz | tar -xJ
WORKDIR /ghc-9.2.4
COPY <<EOF ./mk/build.mk
INTEGER_LIBRARY=integer-simple
BuildFlavour=quick
include mk/flavours/quick.mk
V=0
EOF

RUN python3 boot
RUN ./configure --enable-unregisterised
RUN make -j$(nproc)
RUN make -j$(nproc) binary-dist

FROM scratch
COPY --from=build /ghc-9.2.4/ghc-9.2.4-*.tar.xz /
