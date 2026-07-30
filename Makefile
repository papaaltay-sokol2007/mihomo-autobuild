# Makefile for building optimized Mihomo for Keenetic routers
# Supports cross-compilation for ARM, ARM64, MIPSel, MIPS

.PHONY: all clean help arm arm64 mipsel mips release

# Version
MIHOMO_VERSION := v1.19.3
GO_VERSION := 1.21

# Architectures
ARCHS := armv7 aarch64 mipsel mips

# Build directory
BUILD_DIR := build
DIST_DIR := dist

# Go build flags for optimization
GO_FLAGS := -ldflags="-s -w -extldflags '-static'" -trimpath

help:
	@echo "Optimized Mihomo Build System for Keenetic"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build all architectures"
	@echo "  arm          - Build ARMv7"
	@echo "  arm64        - Build ARM64 (aarch64)"
	@echo "  mipsel       - Build MIPSel"
	@echo "  mips         - Build MIPS"
	@echo "  ipk          - Create IPK packages"
	@echo "  clean        - Clean build artifacts"
	@echo "  release      - Build and package for release"
	@echo ""
	@echo "Requirements:"
	@echo "  - Go $(GO_VERSION)+"
	@echo "  - Cross-compilation toolchains (gcc-arm-linux-gnueabihf, etc.)"

all: arm arm64 mipsel mips

arm:
	@echo "Building Mihomo for ARMv7..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build $(GO_FLAGS) -o $(BUILD_DIR)/mihomo-armv7 github.com/MetaCubeX/mihomo
	@file $(BUILD_DIR)/mihomo-armv7
	@ls -lh $(BUILD_DIR)/mihomo-armv7

arm64:
	@echo "Building Mihomo for ARM64..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build $(GO_FLAGS) -o $(BUILD_DIR)/mihomo-aarch64 github.com/MetaCubeX/mihomo
	@file $(BUILD_DIR)/mihomo-aarch64
	@ls -lh $(BUILD_DIR)/mihomo-aarch64

mipsel:
	@echo "Building Mihomo for MIPSel..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=mipsle CGO_ENABLED=0 go build $(GO_FLAGS) -o $(BUILD_DIR)/mihomo-mipsel github.com/MetaCubeX/mihomo
	@file $(BUILD_DIR)/mihomo-mipsel
	@ls -lh $(BUILD_DIR)/mihomo-mipsel

mips:
	@echo "Building Mihomo for MIPS..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=mips CGO_ENABLED=0 go build $(GO_FLAGS) -o $(BUILD_DIR)/mihomo-mips github.com/MetaCubeX/mihomo
	@file $(BUILD_DIR)/mihomo-mips
	@ls -lh $(BUILD_DIR)/mihomo-mips

ipk: all
	@echo "Creating IPK packages..."
	@mkdir -p $(DIST_DIR)
	@for arch in $(ARCHS); do \
		echo "Creating IPK for $$arch..."; \
		$(MAKE) create-ipk ARCH=$$arch; \
	done

create-ipk:
	@echo "Creating IPK for $(ARCH)..."
	@mkdir -p ipk-build/opt/bin
	@mkdir -p ipk-build/opt/etc/mihomo
	@mkdir -p ipk-build/opt/etc/init.d
	@mkdir -p ipk-build/CONTROL
	
	@cp $(BUILD_DIR)/mihomo-$(ARCH) ipk-build/opt/bin/mihomo
	@chmod +x ipk-build/opt/bin/mihomo
	
	@cat > ipk-build/CONTROL/control << EOF
Package: mihomo
Version: $(MIHOMO_VERSION)-$(ARCH)
Architecture: $(ARCH)
Maintainer: Keenetic Optimizer
Section: net
Priority: optional
Description: Mihomo (Clash Meta) - Optimized for Keenetic routers
 High-performance proxy core with reduced memory footprint
Depends: libc, libpthread
EOF
	
	@cat > ipk-build/CONTROL/postinst << 'EOF'
#!/bin/sh
chmod +x /opt/bin/mihomo
if [ ! -f /opt/etc/mihomo/config.yaml ]; then
    mkdir -p /opt/etc/mihomo
    echo "# Add your Mihomo config here" > /opt/etc/mihomo/config.yaml
fi
echo "Mihomo installed successfully"
EOF
	@chmod +x ipk-build/CONTROL/postinst
	
	@cat > ipk-build/opt/etc/init.d/S99mihomo << 'EOF'
#!/bin/sh
case "$1" in
start)
if [ -f /opt/etc/mihomo/config.yaml ]; then
    /opt/bin/mihomo -d /opt/etc/mihomo &
    echo "Mihomo started"
else
    echo "Config not found, skipping"
fi
;;
stop)
killall mihomo 2>/dev/null
echo "Mihomo stopped"
;;
restart)
$0 stop
sleep 2
$0 start
;;
status)
if pgrep -x mihomo >/dev/null; then
    echo "Mihomo is running"
else
    echo "Mihomo is not running"
fi
;;
*)
echo "Usage: $0 {start|stop|restart|status}"
exit 1
esac
EOF
	@chmod +x ipk-build/opt/etc/init.d/S99mihomo
	
	@cd ipk-build && \
	tar czf ../control.tar.gz CONTROL && \
	tar czf ../data.tar.gz opt && \
	echo 2.0 > ../debian-binary && \
	ar r ../$(DIST_DIR)/mihomo_$(MIHOMO_VERSION)_$(ARCH).ipk debian-binary control.tar.gz data.tar.gz && \
	cd .. && \
	rm -rf ipk-build debian-binary control.tar.gz data.tar.gz

release: ipk
	@echo "Release packages created in $(DIST_DIR)/"
	@ls -lh $(DIST_DIR)/

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR) ipk-build
	@echo "Clean complete"

# Download Mihomo source
download:
	@echo "Downloading Mihomo source $(MIHOMO_VERSION)..."
	@git clone --depth 1 --branch $(MIHOMO_VERSION) https://github.com/MetaCubeX/mihomo.git /tmp/mihomo
	@cd /tmp/mihomo && go mod download
	@echo "Source downloaded to /tmp/mihomo"
