#!/bin/bash
# =========================================================================
# NanoPi R2S 自定义配置脚本
# 功能：
#   1. LAN/WAN 口对调（原始：WAN=eth0, LAN=eth1 → 对调后：WAN=eth1, LAN=eth0）
#   2. 默认 IP 改为 192.168.2.1
#   3. DHCP 服务器下发 DNS 为 223.5.5.5 和 114.114.114.114（给客户端）
#   4. dnsmasq 上游 DNS 保持默认（避免影响 SSRP DNS 分流）
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

# 1. 通过 uci-defaults 在首次启动时稳定应用 R2S 定制
echo ">> 创建首次启动自定义脚本（LAN/WAN 对调、IP、DHCP DNS）..."
UCI_DEFAULTS_DIR="$OPENWRT_DIR/files/etc/uci-defaults"
UCI_DEFAULTS_SCRIPT="$UCI_DEFAULTS_DIR/99-nanopi-r2s-custom"
mkdir -p "$UCI_DEFAULTS_DIR"

cat > "$UCI_DEFAULTS_SCRIPT" << 'EOF'
#!/bin/sh
. /lib/functions.sh

if [ "$(board_name)" = "friendlyarm,nanopi-r2s" ]; then
    uci -q batch <<'EOT'
set network.lan.device='eth0'
set network.wan.device='eth1'
set network.lan.ipaddr='192.168.2.1'
delete dhcp.lan.dhcp_option
add_list dhcp.lan.dhcp_option='6,223.5.5.5,114.114.114.114'
EOT

    uci commit network
    uci commit dhcp
fi

exit 0
EOF

chmod 0755 "$UCI_DEFAULTS_SCRIPT"
echo "   ✓ 已创建 uci-defaults 脚本，首次启动后生效（LAN=eth0, WAN=eth1）"

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
- **实现方式**: 通过 `/etc/uci-defaults/99-nanopi-r2s-custom` 在首次启动时应用
- **原因**: 避免直接修改上游 board.d 脚本带来的兼容性风险

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
