FROM debian:trixie-20251020-slim as base

COPY <<EOF /etc/apt/sources.list.d/debian.sources
Types: deb deb-src
URIs: http://snapshot.debian.org/archive/debian/20251021T000000Z
Suites: trixie
Components: main
check-valid-until: no
trusted: yes
EOF

RUN apt-get update -yq \
&& DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
autoconf automake bzip2 ca-certificates curl g++ gcc git libc6-dev libgmp-dev libncurses-dev locales make patch patchutils python3 xz-utils \
alex happy \
&& apt-get clean \
&& rm -fr /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

###############################################################################

FROM base as boot-ghc96-llvm18

RUN apt-get update -yq \
&& DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
cabal-install libghc-base16-bytestring-dev libghc-cryptohash-sha256-dev libghc-quickcheck2-dev libghc-shake-dev llvm-18 \
&& apt-get clean \
&& rm -fr /var/lib/apt/lists/*
RUN cabal update

###############################################################################

FROM boot-ghc96-llvm18 as build-ghc-9.8.4-llvm18

RUN curl -sL https://downloads.haskell.org/~ghc/9.8.4/ghc-9.8.4-src.tar.xz | tar -xJ 
WORKDIR /ghc-9.8.4

# LLVM RELATED
# https://gitlab.haskell.org/ghc/ghc/-/merge_requests/8999
ADD ghc-9.8-llvm-use-new-pass-manager.patch .
RUN patch -Np1 -i ghc-9.8-llvm-use-new-pass-manager.patch

# https://gitlab.haskell.org/ghc/ghc/-/merge_requests/11124
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/fcfc1777c22ad47613256c3c5e7304cfd29bc761.patch | patch -Np1
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/5880fff6d353a14785c457999fded5a7100c9514.patch | patch -Np1
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/86ce92a2f81a04aa980da2891d0e300cb3cb7efd.patch | patch -Np1
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/a6a3874276ced1b037365c059dcd0a758e813a5b.patch | patch -Np1
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/e9af2cf3f16ab60b5c79ed91df95359b11784df6.patch | patch -Np1
# https://gitlab.haskell.org/ghc/ghc/-/merge_requests/12726
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/ae170155e82f1e5f78882f7a682d02a8e46a5823.patch | patch -Np1
# # https://gitlab.haskell.org/ghc/ghc/-/merge_requests/13311
# RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/36bbb167f354a2fbc6c4842755f2b1e374e3580e.patch | filterdiff -p1 -x .gitlab-ci.yml | patch -Np1
# # https://gitlab.haskell.org/ghc/ghc/-/merge_requests/14600
# RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/ca03226db2db2696460bfcb8035dd3268d546706.patch | patch -Np1

# RISCV64 RELATED
# https://gitlab.haskell.org/ghc/ghc/-/merge_requests/10714
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/dd38aca95ac25adc9888083669b32ff551151259.patch | patch -Np1
# https://gitlab.haskell.org/ghc/ghc/-/merge_requests/12286
RUN curl -sL https://gitlab.haskell.org/ghc/ghc/-/commit/c5e47441ab2ee2568b5a913ce75809644ba83271.patch | patch -Np1

COPY <<EOF ./mk/build.mk
INTEGER_LIBRARY=integer-simple
BuildFlavour=quick
include mk/flavours/quick.mk
V=0
WITH_TERMINFO=NO
EOF

RUN python3 boot.source
RUN ./configure
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage0:lib:ghc
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage1:exe:ghc-bin
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage1:exe:ghc-pkg
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage1:lib:rts
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage1:lib:base
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage1:lib:ghc
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage2:exe:ghc-bin
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum stage2:exe:ghc-pkg
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum
RUN ./hadrian/build -j$(nproc) --docs=none --flavour=quick+native_bignum binary-dist

###############################################################################

FROM scratch AS ghc-9.8.4-llvm18
COPY --from=build-ghc-9.8.4-llvm18 /ghc-*/_build/bindist/ghc-*.tar.xz /

# For docs
# python3-sphinx texlive-xetex texlive-fonts-recommended fonts-lmodern texlive-latex-recommended texlive-latex-extra
