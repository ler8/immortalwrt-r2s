# ImmortalWrt NanoPi R2S 编译项目

本项目用于通过 GitHub Actions 自动编译 ImmortalWrt 固件并集成插件。

## 使用方法

### 1. Fork 本仓库

点击右上角的 "Fork" 按钮，将此仓库复制到你自己的 GitHub 账户下。

### 2. 启动编译

在你的 Fork 仓库中：

1. 点击 **Actions** 标签
2. 选择 **Build ImmortalWrt with SSRP** 工作流
3. 点击 **Run workflow**
4. 选择以下参数：
   - **ImmortalWrt 分支**: openwrt-24.10 / openwrt-23.05 / master
   - **目标平台**: 选择你的设备架构（如 x86_64, aarch64_generic 等）
   - **目标设备** (可选): 特定设备型号，留空使用默认配置
   - **代理插件模式**: full (完整版) / lite (精简版)
5. 点击 **Run workflow** 开始编译

### 3. 下载固件

编译完成后（通常需要 2-4 小时），在以下位置下载：

- 仓库右侧的 **Releases** 区域
- Actions 页面的编译产物

---

## 🎯 NanoPi R2S 专属配置

本项目已为 **NanoPi R2S** 做了专门的优化：

### 已应用的修改

✅ **LAN/WAN 口对调**
- 原始配置：LAN=eth1（USB 网卡，靠近 USB 接口）, WAN=eth0（板载网卡，靠近 GPIO）
- 修改后：**LAN=eth0, WAN=eth1**
- 原因：根据用户需求对调网口功能

⚠️ **重要提示**：本固件已对调 LAN/WAN，**请勿按照外壳丝印连接网线！**

✅ **默认 IP 地址修改**
- 原始：192.168.1.1
- 修改后：**192.168.2.1**
- 原因：避免与主路由器 IP 冲突

✅ **DNS 配置**

**DHCP 服务器下发的 DNS**（给局域网客户端）
- DNS1：223.5.5.5（阿里 DNS）
- DNS2：114.114.114.114（114 DNS）
- 作用：连接到 R2S LAN 口的设备（电脑/手机）自动获得的 DNS 服务器

**dnsmasq 上游 DNS**（路由器自身使用）
- ⚠️ **保持默认，不手动配置**
- 原因：SSRP 插件需要 dnsmasq 读取系统 resolv.conf 来实现 DNS 分流功能
- 如果设置 `noresolv` 或固定 `server`，会导致 SSRP 的 DNS 分流**失效**！
- SSRP 启动后会自动管理 DNS 分流配置

✅ **固件空间调整**
- 根文件系统：**512MB**
- 原因：确保安装软件后有足够的可用空间

✅ **SSP 插件集成**
- 完整集成 SSP
- 支持所有主流代理协议

### R2S 端口说明

**连接方式（本固件）**：
- **WAN 口**（eth1，靠近 GPIO 针脚）→ 连接上级路由器/光猫
- **LAN 口**（eth0，靠近 USB 接口）→ 连接电脑或其他设备
- **管理地址**：http://192.168.2.1

### 编译 R2S 固件

选择参数：
- **Branch**: `openwrt-24.10`（推荐稳定版）
- **Target**: `aarch64_generic`
- **Profile**: 留空（自动识别 R2S）
- **SSP Mode**: `full`

## 支持的平台

常见的目标平台包括：

| 平台 | 适用设备 |
|------|----------|
| x86_64 | x86/64 位路由器、软路由、虚拟机 |
| aarch64_generic | 大多数 ARM64 设备 |
| aarch64_cortex-a53 | Cortex-A53 设备（如 R2S） |
| aarch64_cortex-a72 | Cortex-A72 设备（如 R4S、R5S） |
| arm_cortex-a7 | Cortex-A7 设备 |
| arm_cortex-a9 | Cortex-A9 设备 |
| ramips_mt7621 | MT7621 设备（如 Newifi D2、K2P） |
| ramips_mt7620 | MT7620 设备 |
| ramips_mt76x8 | MT76x8 设备 |
| mediatek_mt7622 | MT7622 设备 |
| ipq40xx_generic | IPQ40xx 设备 |
| ipq806x_generic | IPQ806x 设备 |


## 自定义配置

### 修改软件包配置

编辑 `configs/config.seed` 文件，添加或移除你需要的软件包。

格式示例：
```
CONFIG_PACKAGE_<package-name>=y
```

### 修改 feeds 源

编辑 `.github/workflows/build-immortalwrt-ssrp.yml` 中的 `Load custom feeds` 步骤，添加更多第三方插件源。

### 添加更多插件

在 `feeds.conf.custom` 中添加新的插件源：

```
src-git <feeds-name> https://github.com/<user>/<repo>.git
```

然后在配置文件中启用对应的包：

```
CONFIG_PACKAGE_<package-name>=y
```

## 编译失败排查

### 1. 查看日志

在 Actions 页面中点击失败的 job，查看完整日志。

### 2. 常见问题

**问题**: 下载失败
**解决**: 重新运行 workflow

**问题**: 空间不足
**解决**: workflow 已包含清理磁盘空间的步骤

**问题**: 编译错误
**解决**: 检查配置文件是否有冲突的选项

**问题**: SSRP 插件未编译
**解决**: 确认 feeds 源正确，配置中已启用

## 许可证

- ImmortalWrt: [MIT License](https://github.com/immortalwrt/immortalwrt/blob/master/LICENSE)
- SSRP: [License](https://github.com/fw876/helloworld/blob/master/LICENSE)

## 致谢

- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)
- [SSRP](https://github.com/fw876/helloworld)

## 免责声明

本工具仅供学习研究使用，请遵守当地法律法规。
