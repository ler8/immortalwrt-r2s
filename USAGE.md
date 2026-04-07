#
# NanoPi R2S 快速编译指南
#

本文件提供 NanoPi R2S 的快速使用说明。

## 🎯 R2S 专属优化说明

本项目已为 **NanoPi R2S** 做了专门优化，自动应用以下修改：

### ✅ LAN/WAN 口对调
- **原始配置**: LAN=eth1（USB网卡，靠近USB接口）, WAN=eth0（板载网卡，靠近GPIO）
- **修改后**: LAN=eth0, WAN=eth1
- **原因**: 根据用户需求对调网口功能

⚠️ **重要提示**：本固件已对调 LAN/WAN，**请勿按照外壳丝印连接网线！**

### ✅ 默认 IP 地址修改
- **原始 IP**: 192.168.1.1
- **修改后**: 192.168.2.1
- **原因**: 避免与主路由器 IP 冲突

### ✅ DNS 配置

**DHCP 下发的 DNS**（给局域网客户端）
- **配置位置**: `/etc/config/dhcp` → `config dhcp 'lan'` → `list dns`
- **DNS 地址**: 223.5.5.5, 114.114.114.114
- **作用**: 当你的电脑/手机连接到 R2S 的 LAN 口时，自动获得的 DNS 服务器地址
- **简单理解**: "路由器告诉客户端：你们用这两个 DNS"

**dnsmasq 上游 DNS**（路由器自身使用）
- ⚠️ **保持默认，不手动配置！**
- **原因**: SSRP 插件的工作原理是：
  1. SSRP 启动后会在本地运行 DNS 代理服务（如 dns2socks，监听 5335 端口）
  2. SSRP 会动态生成 dnsmasq 配置文件到 `/tmp/dnsmasq.d/dnsmasq-ssrplus.d/`
  3. SSRP 需要 dnsmasq **读取系统 resolv.conf** 来获取 WAN 口的上游 DNS
  4. 如果设置 `noresolv '1'`，dnsmasq 就不读取 resolv.conf，导致 SSRP DNS 分流**失效**！
- **结论**: 让 SSRP 自己管理 DNS 分流，不要手动干预

### ✅ 固件空间调整
- **根文件系统**: 512MB
- **原因**: 确保安装软件后有足够的可用空间（约 512MB 可用）

### ✅ SSRP 插件集成
- 完整集成 luci-app-ssr-plus
- 支持 Shadowsocks/Xray/Trojan/Hysteria 等协议

## R2S 端口说明

NanoPi R2S 有两个千兆网口，**原始默认**对应关系：

```
┌──────────────────────────────┐
│  ○ USB 3.0    ○ USB 2.0     │
│                              │
│   [eth1/LAN]    [eth0/WAN]   │
│   (靠近 USB)    (靠近 GPIO)  │
│                              │
│   ↑ 这是原始默认配置           │
└──────────────────────────────┘
```

**本固件已对调 LAN/WAN**，实际对应关系：

```
┌──────────────────────────────┐
│  ○ USB 3.0    ○ USB 2.0     │
│                              │
│   [eth0/LAN]    [eth1/WAN]   │
│   (靠近 USB)    (靠近 GPIO)  │
│      ↓             ↓         │
│   连接电脑     连接上级路由   │
└──────────────────────────────┘
```

**连接方式（本固件）**：
- **WAN 口**（eth1，靠近 GPIO 针脚）→ 连接上级路由器/光猫
- **LAN 口**（eth0，靠近 USB 接口）→ 连接电脑或其他设备
- **管理地址**：http://192.168.2.1

⚠️ **再次提醒**：本固件已对调 LAN/WAN，**请勿按照外壳丝印连接网线！**

---

## 最简使用步骤

### 1. Fork 仓库
点击 GitHub 页面右上角的 "Fork" 按钮。

### 2. 启动编译
1. 进入你 Fork 的仓库
2. 点击顶部 **Actions** 标签
3. 点击左侧 **Build ImmortalWrt with SSRP**
4. 点击右侧 **Run workflow** 下拉按钮
5. 选择参数：
   - **Branch**: 选择 `openwrt-24.10`（推荐稳定版）
   - **Target**: 选择 `aarch64_generic`（R2S 平台）
   - **Profile**: 留空（自动识别 R2S）
   - **Proxy Mode**: 选择 `full`
6. 点击 **Run workflow**

### 3. 等待编译
大约 2-4 小时后完成。

### 4. 下载固件
- 在仓库右侧找到 **Releases**
- 或在 **Actions** 页面点击已完成的 workflow，下载底部的 Artifacts

## 固件文件说明

编译完成后会生成多个文件：

对于 R2S，你需要的是：
- `*-squashfs-sysupgrade.bin`: 推荐用于升级已有 OpenWrt 系统
- `*-ext4-sysupgrade.bin`: ext4 格式升级包
- `*.manifest`: 已安装的软件包列表
- `config.seed`: 编译配置文件

**首次刷入 R2S**：
- 使用 `immortalwrt-*-squashfs-sysupgrade.bin.gz` 文件
- 通过 SD 卡刷入（使用 Rufus/BalenaEtcher 等工具）

## 刷入步骤

### 方法一：SD 卡刷入（首次安装）

1. 准备一张 8GB 以上的 microSD 卡
2. 下载 `*-squashfs-sysupgrade.bin.gz` 文件并解压
3. 使用 **Rufus**（Windows）或 **BalenaEtcher** 将镜像写入 SD 卡
4. 将 SD 卡插入 R2S
5. 连接电源启动 R2S
6. 电脑连接 R2S 的 LAN 口（靠近 USB 的口）
7. 设置电脑 IP 为 `192.168.2.x`（如 `192.168.2.100`）
8. 浏览器访问 http://192.168.2.1
9. 默认密码为空（首次登录需设置密码）

### 方法二：Web 升级（已有 OpenWrt）

1. 登录现有 OpenWrt 系统
2. 进入 **系统** → **备份/升级**
3. 上传 `*-squashfs-sysupgrade.bin` 文件
4. 点击 **升级**，等待完成

## 首次登录

1. 电脑连接到 R2S 的 **LAN 口**（靠近 USB 的口）
2. 设置电脑 IP 为 `192.168.2.x`（DHCP 自动获取或手动设置）
3. 浏览器访问 **http://192.168.2.1**
4. 首次登录会提示设置 root 密码
5. 登录后即可配置 SSRP 插件

## 配置 SSRP 插件

1. 登录 LuCI 界面（http://192.168.2.1）
2. 进入 **服务** → **ShadowSocksR Plus+**
3. 配置你的服务器信息
4. 保存并应用
5. 启用服务

## 注意事项

⚠️ **重要提示**:
1. 请遵守当地法律法规
2. ⚠️ **本固件已对调 LAN/WAN，请勿按照外壳丝印连接网线！**
   - WAN 口：eth1（靠近 GPIO 针脚）
   - LAN 口：eth0（靠近 USB 接口）
3. 首次使用建议先测试 x86_64 平台熟悉流程
4. 不要同时编译多个平台，容易失败
5. Releases 默认保留最近 10 个版本
6. 如果连接不上，请检查：
   - 电脑是否连接到 **LAN 口（靠近 USB 的口，不是外壳丝印的 LAN）**
   - 电脑 IP 是否在 `192.168.2.x` 网段
   - 网线是否正常

## 常见问题

### Q: 无法访问 192.168.2.1？
A: 请检查：
1. 电脑是否连接到 LAN 口（靠近 USB 的口，不是 WAN 口）
2. 电脑 IP 是否设置为 `192.168.2.x`（如 `192.168.2.100`）
3. 尝试 `ping 192.168.2.1` 测试连通性

### Q: WAN 和 LAN 口如何区分？
A: 
- **外壳丝印的 WAN** = eth0 = 靠近 GPIO 针脚的网口
- **外壳丝印的 LAN** = eth1 = 靠近 USB 接口的网口
- **但本固件已对调！** 实际使用：
  - **当作 WAN 用的口**：eth1（外壳丝印的 LAN，靠近 GPIO）
  - **当作 LAN 用的口**：eth0（外壳丝印的 WAN，靠近 USB）
- 简单记法：**和外壳丝印反过来接**

### Q: 为什么我连不上 192.168.2.1？
A: 最常见原因：
1. **接错网口**：请确认电脑接到 LAN 口（eth0，靠近 USB 的口）
2. **IP 不在同一网段**：电脑 IP 应为 `192.168.2.x`（如 `192.168.2.100`）
3. **接了外壳丝印的 LAN 口**：本固件已对调，请接另一个口试试

### Q: DHCP DNS 和路由器 DNS 有什么区别？
A: 
- **DHCP DNS**（`config dhcp 'lan'` → `list dns`）:
  - 作用对象：连接到 R2S 的**客户端设备**（电脑/手机）
  - 简单理解："路由器告诉客户端你们用哪个 DNS"
  - 查看方式：电脑执行 `ipconfig /all` 看到的 DNS 服务器
  - 本固件配置为：223.5.5.5, 114.114.114.114
  
- **dnsmasq 上游 DNS**（`config dnsmasq` → `list server`）:
  - ⚠️ **本固件不修改此项，保持默认**
  - 原因：SSRP 插件需要 dnsmasq 读取系统 resolv.conf 来实现 DNS 分流
  - 如果手动设置 `noresolv` 或固定 `server`，会导致 SSRP DNS 分流失效
  - SSRP 启动后会自动管理 DNS 分流配置

### Q: 如何恢复原始 IP (192.168.1.1)？
A: 登录 LuCI 后，进入 **网络** → **接口** → **LAN** → **修改**，将 IPv4 地址改回 `192.168.1.1`

### Q: DNS 服务器如何修改？
A: 登录 LuCI 后，进入 **网络** → **DHCP/DNS**，在 **常规设置** 中修改 DNS 服务器列表。

### Q: 固件空间如何调整？
A: 当前已配置为 512MB 根文件系统。如需调整，请修改 `configs/config.seed` 中的 `CONFIG_TARGET_ROOTFS_PARTSIZE` 值。

### Q: 如何查看 DNS 是否生效？
A: 登录后 SSH 连接到 R2S，执行 `cat /etc/resolv.conf` 应显示配置的 DNS 服务器。或在 **网络** → **DHCP/DNS** 中查看。

## 问题反馈

如遇到问题，请查看：
1. Actions 页面的完整日志
2. README.md 中的常见问题部分
