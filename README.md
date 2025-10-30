# riscv64-ghc-bindist

This repo provides binary distributions for the Glasgow Haskell Compiler for the
RISC-V 64-bit instruction set architecture. The purpose is to use them as a
bootstrap compiler for a native build of GHC on RISC-V. The included Dockerfile
is intended to be either build natively on a RISC-V machine or through user
mode emulation with QEMU via Docker's
[multi-platform build support](https://docs.docker.com/build/building/multi-platform/#qemu).

Since GHC <9.12 does not have a native code generator for riscv64, these builds
use the LLVM backend. For compatibility with newer LLVM versions patches from
https://github.com/NixOS/nixpkgs/pull/440774 are also applied, which themselves
are derived from upstream patches.
