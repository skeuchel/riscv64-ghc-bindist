FROM debian:unstable-20220527 as build

ENV DEBIAN_FRONTEND=noninteractive
COPY <<EOF /etc/apt/sources.list
deb     [check-valid-until=no trusted=yes] http://snapshot.debian.org/archive/debian-ports/20220527T000000Z unstable main
deb-src [check-valid-until=no trusted=yes] http://snapshot.debian.org/archive/debian/20220527T000000Z experimental main
EOF

RUN apt-get update && apt-get install -yq curl locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV XZ_OPT=-1

RUN apt-get build-dep -yq ghc
RUN apt-get install -qy python3-sphinx texlive-xetex texlive-latex-extra
	
# Add ghc user and drop root
RUN useradd -lmU -s /bin/bash -G sudo -p '' ghc
USER ghc
WORKDIR /home/ghc
RUN apt-get source ghc

WORKDIR /home/ghc/ghc-8.10.7
COPY <<EOF ./mk/build.mk
INTEGER_LIBRARY=integer-simple
BuildFlavour=perf
include mk/flavours/perf.mk
GhcLibHcOpts+=-haddock
EXTRA_HADDOCK_OPTS += --hyperlinked-source --quickjump
V=0
EOF

RUN python3 boot
RUN ./configure
RUN make -j$(nproc)
RUN make -j$(nproc) binary-dist

FROM scratch
COPY --from=build /home/ghc/ghc-8.10.7/ghc-8.10.7-riscv64-unknown-linux.tar.xz /
