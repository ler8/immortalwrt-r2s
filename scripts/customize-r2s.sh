#!/bin/bash
# =========================================================================
# NanoPi R2S 自定义配置脚本
# 功能：
#   1. LAN/WAN 口对调（原始：WAN=eth0, LAN=eth1 → 对调后：WAN=eth1, LAN=eth0）
#   2. 默认 IP 改为 192.168.2.1
#   3. DHCP 服务器下发 DNS 为 223.5.5.5 和 114.114.114.114（给客户端）
#   4. dnsmasq 上游 DNS 配置为 223.5.5.5 和 114.114.114.114（路由器自身使用）
#   5. 固件空间调整为 512MB
# =========================================================================

set -e

OPENWRT_DIR="$1"

if [ -z "$OPENWRT_DIR" ]; then
    echo "错误：请提供 OpenWRT 源码路径"
    exit 1
fi

echo "========================================="
echo "应用 NanoPi R2S 自定义配置"
echo "========================================="

# 1. 修改默认网络配置 - LAN/WAN 对调
NETWORK_CONFIG="$OPENWRT_DIR/target/linux/rockchip/armv8/base-files/etc/board.d/02_network"
if [ -f "$NETWORK_CONFIG" ]; then
    echo ">> 修改网络接口配置（LAN/WAN 对调）..."
    
    # 备份原文件
    cp "$NETWORK_CONFIG" "$NETWORK_CONFIG.bak"
    
    # 原始配置（R2S 默认）：
    # nanopi-r2s)
    #     ucidef_set_interfaces_lan_wan 'eth1' 'eth0'
    #     ;;
    # 
    # 含义：LAN=eth1, WAN=eth0
    #
    # 对调后目标：
    # LAN=eth0, WAN=eth1
    
    # 查找并注释掉原有的 R2S 配置
    sed -i '/friendlyarm,nanopi-r2s/,/;;/{
        s/^/#/
    }' "$NETWORK_CONFIG"
    
    # 添加自定义配置（LAN/WAN 对调）
    cat >> "$NETWORK_CONFIG" << 'EOF'

# Custom: LAN/WAN swapped for NanoPi R2S
# Original: LAN=eth1, WAN=eth0
# Swapped:  LAN=eth0, WAN=eth1
friendlyarm,nanopi-r2s)
    ucidef_set_interfaces_lan_wan 'eth0' 'eth1'
    ;;
EOF
    echo "   ✓ 网络接口配置已修改（LAN=eth0, WAN=eth1）"
else
    echo "   ⚠ 警告：未找到网络配置文件 $NETWORK_CONFIG"
fi

# 2. 修改默认 IP 地址
DEFAULT_NETWORK="$OPENWRT_DIR/target/linux/rockchip/armv8/base-files/etc/config/network"
if [ -f "$DEFAULT_NETWORK" ]; then
    echo ">> 修改默认 IP 地址..."
    
    # 备份原文件
    cp "$DEFAULT_NETWORK" "$DEFAULT_NETWORK.bak"
    
    # 将 192.168.1.1 改为 192.168.2.1
    sed -i 's/192\.168\.1\.1/192.168.2.1/g' "$DEFAULT_NETWORK"
    
    echo "   ✓ 默认 IP 已改为 192.168.2.1"
fi

# 3. 配置 DHCP 服务器下发的 DNS（给局域网客户端）
# 注意：这是 DHCP 服务器告诉客户端"你应该用哪个 DNS"
# 重要：不要在 config dnsmasq 中设置 noresolv 和固定 server！
# 原因：SSRP 插件需要 dnsmasq 读取系统 resolv.conf 来实现 DNS 分流功能
#       如果设置 noresolv，会导致 SSRP 的 DNS 分流失效！
DEFAULT_DHCP="$OPENWRT_DIR/target/linux/rockchip/armv8/base-files/etc/config/dhcp"
if [ -f "$DEFAULT_DHCP" ]; then
    echo ">> 配置 DHCP 下发的 DNS 服务器（给客户端）..."
    
    # 备份原文件
    cp "$DEFAULT_DHCP" "$DEFAULT_DHCP.bak"
    
    # 在 config dhcp 'lan' 段中添加 DNS 选项
    # 使用 dhcp_option 下发 DNS 给客户端（选项 6）
    if grep -q "config dhcp 'lan'" "$DEFAULT_DHCP" || grep -q "config dhcp lan" "$DEFAULT_DHCP"; then
        # 在 lan 段的末尾添加 DNS 配置
        sed -i "/config dhcp 'lan'/,/^$/ {
            /^$/i\\
    # Custom DNS servers for DHCP clients (AliDNS + 114DNS)\\
    list dns '223.5.5.5'\\
    list dns '114.114.114.114'\\

        }" "$DEFAULT_DHCP"
        
        # 检查是否成功添加，如果没有则用备用方案
        if ! grep -q "223.5.5.5" "$DEFAULT_DHCP"; then
            echo "   ⚠ sed 添加失败，使用备用方案..."
            # 直接重建文件（注意：不修改 config dnsmasq 部分！）
            cat > "$DEFAULT_DHCP" << 'EOFDHCP'
config dnsmasq
    option domainneeded '1'
    option boguspriv '1'
    option filterwin2k '0'
    option localise_queries '1'
    option rebind_protection '1'
    option rebind_localhost '1'
    option local '/lan/'
    option domain 'lan'
    option expandhosts '1'
    option nonegcache '0'
    option authoritative '1'
    option readethers '1'
    option leasefile '/tmp/dhcp.leases'
    option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'
    # 注意：不设置 noresolv 和 server，保持默认！
    # SSRP 插件需要 dnsmasq 读取系统 resolv.conf 来实现 DNS 分流

config dhcp 'lan'
    option interface 'lan'
    option start '100'
    option limit '150'
    option leasetime '12h'
    # DNS servers to assign to DHCP clients (下发给客户端的 DNS)
    list dns '223.5.5.5'
    list dns '114.114.114.114'

config dhcp 'wan'
    option interface 'wan'
    option ignore '1'
EOFDHCP
        fi
        
        echo "   ✓ DHCP DNS 已配置（下发给客户端：223.5.5.5, 114.114.114.114）"
        echo "   ✓ dnsmasq 上游 DNS 保持默认（由 SSRP 管理，不影响 DNS 分流）"
    else
        echo "   ⚠ 未找到 lan 配置段，使用备用方案..."
        cat >> "$DEFAULT_DHCP" << 'EOFDHCP2'

config dhcp 'lan'
    option interface 'lan'
    option start '100'
    option limit '150'
    option leasetime '12h'
    list dns '223.5.5.5'
    list dns '114.114.114.114'
EOFDHCP2
        echo "   ✓ DHCP DNS 已配置"
    fi
else
    echo ">> 创建 DHCP 配置文件..."
    mkdir -p "$(dirname "$DEFAULT_DHCP")"
    cat > "$DEFAULT_DHCP" << 'EOFDHCP3'
config dnsmasq
    option domainneeded '1'
    option boguspriv '1'
    option filterwin2k '0'
    option localise_queries '1'
    option rebind_protection '1'
    option rebind_localhost '1'
    option local '/lan/'
    option domain 'lan'
    option expandhosts '1'
    option nonegcache '0'
    option authoritative '1'
    option readethers '1'
    option leasefile '/tmp/dhcp.leases'
    option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'

config dhcp 'lan'
    option interface 'lan'
    option start '100'
    option limit '150'
    option leasetime '12h'
    list dns '223.5.5.5'
    list dns '114.114.114.114'

config dhcp 'wan'
    option interface 'wan'
    option ignore '1'
EOFDHCP3
    echo "   ✓ DHCP 配置文件已创建"
fi

# 4. 调整固件根文件系统大小到 512MB
echo ">> 配置固件空间..."

CONFIG_FILE="$OPENWRT_DIR/.config"
if [ -f "$CONFIG_FILE" ]; then
    # 设置 rootfs 分区大小为 512MB
    if grep -q "CONFIG_TARGET_ROOTFS_PARTSIZE" "$CONFIG_FILE"; then
        sed -i 's|CONFIG_TARGET_ROOTFS_PARTSIZE=.*|CONFIG_TARGET_ROOTFS_PARTSIZE=512|g' "$CONFIG_FILE"
        echo "   ✓ 根文件系统大小已设置为 512MB"
    else
        echo "CONFIG_TARGET_ROOTFS_PARTSIZE=512" >> "$CONFIG_FILE"
        echo "   ✓ 根文件系统大小已设置为 512MB（新增）"
    fi
else
    echo "   ⚠ 警告：配置文件 $CONFIG_FILE 不存在"
fi

# 5. 创建自定义配置说明文档
echo ">> 创建配置说明文档..."
cat > "$OPENWRT_DIR/target/linux/rockchip/armv8/NANOPI_R2S_CUSTOM.md" << 'EOF'
# NanoPi R2S 自定义配置说明

## 修改内容

### 1. LAN/WAN 口对调
- **原始配置**: LAN=eth1 (USB网卡), WAN=eth0 (板载网卡)
- **修改后**: LAN=eth0, WAN=eth1
- **原因**: 用户需要根据实际使用场景对调网口功能

### 2. 默认 IP 地址
- **原始 IP**: 192.168.1.1
- **修改后**: 192.168.2.1
- **原因**: 避免与主路由器 IP 冲突

### 3. DNS 配置

#### 3.1 DHCP 服务器下发的 DNS（给客户端）
- **配置位置**: `/etc/config/dhcp` → `config dhcp 'lan'` → `list dns`
- **作用**: 告诉通过 DHCP 连接到 R2S 的设备（电脑、手机等）使用哪个 DNS
- **配置值**: 
  - 223.5.5.5（阿里 DNS）
  - 114.114.114.114（114 DNS）

#### 3.2 dnsmasq 上游 DNS（⚠️ 保持默认）
- **为什么不配置**: SSRP 插件需要 dnsmasq 读取系统 resolv.conf 来实现 DNS 分流
- **如果配置会怎样**: 设置 `noresolv` 或固定 `server` 会导致 SSRP DNS 分流失效
- **SSRP 的工作原理**:
  1. SSRP 启动后运行本地 DNS 代理服务（dns2socks/dns2tcp，监听 5335 端口）
  2. SSRP 动态生成 dnsmasq 配置文件到 `/tmp/dnsmasq.d/dnsmasq-ssrplus.d/`
  3. SSRP 需要 dnsmasq 读取 resolv.conf 获取 WAN 口上游 DNS
  4. GFW 列表内域名通过代理通道解析，列表外域名普通解析

### 4. 固件空间
- **根文件系统大小**: 512MB
- **原因**: 确保安装软件后有足够的可用空间

## 物理端口说明

NanoPi R2S 有两个千兆网口：

```
┌──────────────────────────────┐
│  ○ USB 3.0    ○ USB 2.0     │
│                              │
│   [网口1]       [网口2]       │
│   (靠近 USB)   (靠近 GPIO)   │
└──────────────────────────────┘
```

**原始默认配置**（未对调）:
- 网口1（靠近 USB）= eth1 = LAN 口
- 网口2（靠近 GPIO）= eth0 = WAN 口

**对调后配置**（本固件）:
- 网口1（靠近 USB）= eth0 = LAN 口
- 网口2（靠近 GPIO）= eth1 = WAN 口

## 连接方式（对调后）

- **WAN 口**（eth1，靠近 GPIO 针脚）：连接上级路由器/光猫
- **LAN 口**（eth0，靠近 USB 接口）：连接电脑或其他设备
- **管理地址**: http://192.168.2.1
- **DHCP 下发 DNS**: 223.5.5.5, 114.114.114.114

## 注意事项

⚠️ 本固件已对调 LAN/WAN 口，请勿按照外壳丝印连接网线！
EOF

echo "========================================="
echo "✓ NanoPi R2S 自定义配置完成！"
echo "========================================="
echo ""
echo "修改总结："
echo "  1. LAN/WAN 已对调（LAN=eth0, WAN=eth1）"
echo "  2. 默认 IP: 192.168.2.1"
echo "  3. DHCP DNS: 223.5.5.5, 114.114.114.114（下发给客户端）"
echo "  4. dnsmasq 上游 DNS: 保持默认（SSRP 自行管理）"
echo "  5. 根文件系统: 512MB"
echo ""
echo "⚠️  注意：dnsmasq 上游 DNS 未修改"
echo "   原因：SSRP 需要读取 resolv.conf 实现 DNS 分流"
echo "   如果设置 noresolv 会导致 SSRP DNS 分流失效！"
echo "========================================="
