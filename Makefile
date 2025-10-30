TARGETS = ghc-9.8.4-llvm18

all: $(TARGETS)
$(TARGETS):
	docker buildx build --platform linux/riscv64 --output=out --target $@ .

.PHONY: $(TARGETS)
