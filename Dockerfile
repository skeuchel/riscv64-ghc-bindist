FROM debian:trixie-20240211-slim as base

COPY <<EOF /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://snapshot.debian.org/archive/debian/20240211T000000Z
Suites: trixie
Components: main
check-valid-until: no
trusted: yes
EOF

RUN apt-get update -yq \
&& DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
autoconf automake bzip2 ca-certificates curl g++ gcc git libc6-dev libgmp-dev libncurses-dev locales make patch python3 xz-utils \
alex happy \
&& apt-get clean \
&& rm -fr /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN curl -sL https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2024.02.02/riscv64-glibc-ubuntu-22.04-gcc-nightly-2024.02.02-nightly.tar.gz | tar -zxC /opt
ENV PATH=/opt/riscv/bin:$PATH

###############################################################################

FROM base as boot-8.10.7
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV BOOTSTRAP_HASKELL_GHC_VERSION=8.10.7
ENV BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1
ENV PATH="$HOME/.cabal/bin:/root/.ghcup/bin:$PATH"
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# RUN curl -sL https://downloads.haskell.org/~ghc/8.10.7/ghc-8.10.7-x86_64-deb10-linux.tar.xz | tar -xJ \
# && cd /ghc-8.10.7 && ./configure && make install && cd / && rm -fR /ghc-8.10.7

###############################################################################

FROM base as boot-9.4.7
RUN apt-get update -yq \
&& DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
cabal-install libghc-quickcheck2-dev libghc-shake-dev \
&& apt-get clean \
&& rm -fr /var/lib/apt/lists/*
RUN cabal update

###############################################################################

FROM base as boot-9.4.8

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV BOOTSTRAP_HASKELL_GHC_VERSION=9.4.8
ENV BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1
ENV PATH="$HOME/.cabal/bin:/root/.ghcup/bin:$PATH"
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

###############################################################################

FROM boot-8.10.7 as ghc-8.10.7

RUN curl -sL https://downloads.haskell.org/~ghc/8.10.7/ghc-8.10.7-src.tar.xz | tar -xJ
WORKDIR /ghc-8.10.7
COPY <<EOF ./mk/build.mk
INTEGER_LIBRARY=integer-simple
BuildFlavour=quick
include mk/flavours/quick.mk
V=0
WITH_TERMINFO=NO
EOF

RUN python3 boot
RUN ./configure --target=riscv64-unknown-linux-gnu --enable-unregisterised
RUN make -j$(nproc)
RUN make -j$(nproc) binary-dist

###############################################################################

FROM boot-8.10.7 as ghc-9.2.4

RUN curl -sL https://downloads.haskell.org/~ghc/9.2.4/ghc-9.2.4-src.tar.xz | tar -xJ
WORKDIR /ghc-9.2.4
COPY <<EOF ./mk/build.mk
INTEGER_LIBRARY=integer-simple
BuildFlavour=quick
include mk/flavours/quick.mk
V=0
WITH_TERMINFO=NO
EOF

RUN python3 boot
RUN ./configure --target=riscv64-unknown-linux-gnu --enable-unregisterised
RUN make -j$(nproc)
RUN make -j$(nproc) binary-dist

###############################################################################

FROM boot-8.10.7 as ghc-9.4.8

RUN curl -sL https://downloads.haskell.org/~ghc/9.4.8/ghc-9.4.8-src.tar.xz | tar -xJ 
WORKDIR /ghc-9.4.8
COPY <<EOF ./mk/build.mk
INTEGER_LIBRARY=integer-simple
BuildFlavour=quick
include mk/flavours/quick.mk
V=0
WITH_TERMINFO=NO
EOF

RUN python3 boot.source
RUN sed -i 's/MinBootGhcVersion="9.0"/MinBootGhcVersion="8.10"/' configure
RUN ./configure --target=riscv64-unknown-linux-gnu --enable-unregisterised
RUN make -j$(nproc)
RUN make -j$(nproc) binary-dist

###############################################################################

FROM boot-9.4.8 as ghc-9.6.4

RUN curl -sL https://downloads.haskell.org/~ghc/9.6.4/ghc-9.6.4-src.tar.xz | tar -xJ 
WORKDIR /ghc-9.6.4
COPY <<EOF ./mk/build.mk
INTEGER_LIBRARY=integer-simple
BuildFlavour=quick
include mk/flavours/quick.mk
V=0
WITH_TERMINFO=NO
EOF

RUN python3 boot.source
RUN ./configure --target=riscv64-unknown-linux-gnu --enable-unregisterised
RUN ./hadrian/build -j$(nproc) --flavour=quick+native_bignum
RUN ./hadrian/build -j$(nproc) --flavour=quick+native_bignum binary-dist

###############################################################################

FROM scratch
COPY --from=ghc-8.10.7 /ghc-*/ghc-*.tar.xz /
COPY --from=ghc-9.2.4 /ghc-*/ghc-*.tar.xz /
COPY --from=ghc-9.4.8 /ghc-*/ghc-*.tar.xz /
COPY --from=ghc-9.6.4 /ghc-*/_build/bindist/ghc-*.tar.xz /
