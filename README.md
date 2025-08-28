# Host Updater - OpenWrt软件包

一个用于OpenWrt的hosts订阅源管理软件包，支持多个hosts源的定时抓取和手动更新。

## 功能特性

- 🔄 **多源管理**: 支持配置多个hosts订阅源
- ⏰ **定时更新**: 支持设置定时自动更新（1-24小时间隔）
- 🖱️ **手动更新**: 支持通过Web界面或命令行手动更新
- 💾 **自动备份**: 自动备份原始hosts文件，支持一键还原
- 🌐 **Web界面**: 提供完整的Luci Web管理界面
- 📝 **日志记录**: 详细的操作日志记录
- 🧹 **干净卸载**: 卸载时自动还原系统到安装前的状态
- 🧠 **去重合并**: 合并最终hosts时会自动去除重复的域名映射，按"先出现先保留"的策略处理，原始系统hosts优先级最高，其次是订阅源按顺序依次合并，避免冲突与污染。

## 安装方法

### 方法1: 从源码编译

1. 将本软件包放入OpenWrt SDK的`package/utils/`目录
2. 在OpenWrt源码根目录执行：
   ```bash
   make menuconfig
   ```
3. 进入 `Utilities` → `hostupdater` 并选择为 `M` 或 `*`
4. 编译：
   ```bash
   make package/hostupdater/compile V=s
   ```

### 方法2: 直接安装

将编译好的`.ipk`文件上传到路由器，然后执行：
```bash
opkg install hostupdater_1.0.0-1_all.ipk
```

## 配置说明

### 基本配置

软件包安装后，配置文件位于：
- UCI配置: `/etc/config/hostupdater`
- 源配置: `/etc/hostupdater/sources.conf`

### 添加hosts源

编辑 `/etc/hostupdater/sources.conf` 文件，格式如下：
```
# 格式: 名称|URL|启用状态(1=启用,0=禁用)
tinsfox|https://github-hosts.tinsfox.com/hosts|0
tmdb_ipv4|https://raw.githubusercontent.com/cnwikee/CheckTMDB/refs/heads/main/Tmdb_host_ipv4|0
tmdb_ipv6|https://raw.githubusercontent.com/cnwikee/CheckTMDB/refs/heads/main/Tmdb_host_ipv6|0
```

### 去重与优先级策略
- 最终 `/etc/hosts` 会包含：
  - 原始系统hosts（安装时备份的内容）
  - 每个订阅源的BEGIN/END注释块
- 去重策略：按行解析得到"IP + 主机名列表"，对主机名进行去重，保留首次出现的映射
- 优先级：
  1. 原始系统hosts（最高）
  2. 第1个订阅源
  3. 第2个订阅源 … 依次类推
- 这样可以避免同一域名被后续源覆盖，保障系统自带记录与用户自定记录优先

## 使用方法

### Web界面

1. 登录Luci Web界面
2. 进入 `服务` → `Host Updater`
3. 配置基本设置和hosts源
4. 点击 `执行更新` 进行手动更新

### 命令行

```bash
# 查看帮助
hostupdater help

# 执行更新
hostupdater update

# 查看状态
hostupdater status

# 创建备份
hostupdater backup

# 还原到原始状态
hostupdater restore
```

### 服务管理

```bash
# 启用服务
/etc/init.d/hostupdater enable

# 启动服务
/etc/init.d/hostupdater start

# 停止服务
/etc/init.d/hostupdater stop

# 重启服务
/etc/init.d/hostupdater restart

# 查看服务状态
/etc/init.d/hostupdater status
```

## 文件结构

```
/etc/config/hostupdater          # UCI配置文件
/etc/hostupdater/                # 软件包数据目录
├── sources.conf                 # hosts源配置文件
└── backup/                      # 备份目录
    └── hosts.original           # 原始hosts文件备份
/usr/bin/hostupdater             # 主程序
/etc/init.d/hostupdater          # 服务脚本
/var/log/hostupdater.log         # 日志文件
```

## 日志查看

```bash
# 查看实时日志
tail -f /var/log/hostupdater.log

# 查看最近100行日志
tail -n 100 /var/log/hostupdater.log
```

## 故障排除

### 常见问题

1. **更新后无订阅内容**
   - 检查订阅URL是否可访问
   - 查看`/tmp/hostupdater/*.tmp`是否有内容
   - 查看日志“解析完成 (有效行 N)”是否>0

2. **重复或冲突的解析**
   - 新版已启用“按出现顺序去重”，原始系统hosts优先

3. **Web界面无法访问**
   - 确保已安装luci-base和luci-compat
   - 重启rpcd与uhttpd

## 卸载

卸载软件包时会自动：
1. 停止并禁用服务
2. 还原原始hosts文件
3. 清理所有配置文件和数据

```bash
opkg remove hostupdater
```

## 许可证

本软件包采用MIT许可证。详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交Issue和Pull Request来改进这个软件包。

## 更新日志

### v1.0.0
- 初始版本发布
- 支持多hosts源管理
- 提供Web界面和命令行工具
- 支持定时和手动更新
- 自动备份和还原功能
- 去重合并最终hosts（原始hosts最高优先）