# 铲铲数据（JCCData）

把 [dataj.cc/comp](https://www.dataj.cc/comp) 的金铲铲阵容排行做成的 iOS 原生应用（SwiftUI，iOS 16+），个人自用。

## 功能

- **阵容排行**：评级、平均排名、出场率、登顶率、前四率；按任一指标升/降序；按 S/A/B/C/D 筛选；最小样本筛选；搜索阵容名 / 英雄 / 羁绊；切换游戏版本；下拉刷新
- **一图流**：按 S/A/B/C/D 分层的主C头像墙，点一个即在下方显示该阵容：4 人口到 10 人口各阶段最常见的站位（可换前三套，带样本和胜率）、成型站位、羁绊、核心出装；还能打开 dataj.cc 生成的一图流长图，双指缩放、保存到相册或分享
- **阵容详情**：蜂窝棋盘站位、每个英雄的推荐装备与出场数据、羁绊、阵容码一键复制、名次分布图、近 7 天趋势图、常用装备、海克斯强化（含排名变化）
- **收藏**：左滑收藏，单独一页查看
- **对比**：右滑加入对比（最多 3 个），并排比较各项数据，最优值标绿
- 断网时显示上次加载的数据

## 没有 Mac，怎么编译出 IPA

用 GitHub Actions 的免费 macOS 机器编译，生成**未签名**的 IPA，再用你自己的签名工具签名安装。

1. 在 GitHub 新建一个仓库（公开或私有都行），把本文件夹里的**全部内容**上传进去，注意 `.github` 这个隐藏文件夹也要上传。
   - 网页上传：仓库页面 → Add file → Upload files，把文件夹拖进去。
   - 或用 git：`git init && git add . && git commit -m init && git branch -M main && git remote add origin <仓库地址> && git push -u origin main`
2. 推送后会自动开始编译。打开仓库的 **Actions** 页，等「Build unsigned IPA」变成绿色对勾（大约 5～10 分钟）。也可以在该页点 **Run workflow** 手动触发。
3. 点进这次运行，页面底部 **Artifacts** 里下载 `JCCData-unsigned-ipa`，解压得到 `JCCData-unsigned.ipa`。
4. 用你常用的工具签名安装（例如爱思助手的「IPA 签名」、Sideloadly、轻松签/ESign、AltStore 等）。

> 编译失败时，点开失败的步骤看红色报错，把报错贴给我改就行。

## 项目结构

```
project.yml                     XcodeGen 配置（CI 里生成 .xcodeproj）
.github/workflows/build-ipa.yml 云端编译脚本
JCCData/
  JCCDataApp.swift              入口、底部三个标签页
  AppModel.swift                状态：版本、排行、收藏、对比
  API.swift                     接口请求 + 离线缓存 + 图片加载
  Models.swift                  数据模型
  Views/                        各页面
  Assets.xcassets               图标
```

## 用到的接口（均为 dataj.cc 网页公开接口）

| 用途 | 地址 |
|---|---|
| 版本列表 | `GET /api/web/gamedata/gameVersion?setId=18` |
| 英雄/装备/羁绊资料 | `GET /api/web/gamedata?setId=18` |
| 阵容排行 | `GET /api/web/comp/rank?setId=18&gameVersion=18.6&minSample=1` |
| 阵容详情 | `GET /api/web/comp/{compId}?setId=&gameVersion=` |
| 英雄数据 | `GET /api/web/comp/{compId}/heroes?...` |
| 常用装备 | `GET /api/web/comp/{compId}/equips?...` |
| 海克斯 | `GET /api/web/comp/{compId}/hexes?...` |
| 近期趋势 | `GET /api/web/comp/{compId}/trend` |
| 分人口站位 | `GET /api/web/comp/{compId}/battle-builds?...` |
| 一图流长图 | `GET /api/web/comp/{compId}/single-image?...` |

网站改版后接口可能变化；新赛季开始时，在 App 左上角版本菜单 → 设置里把 setId 加 1。

## 修改常见项

- App 名称：`project.yml` 里的 `INFOPLIST_KEY_CFBundleDisplayName`
- Bundle ID：`project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`（有些签名方式会要求和证书匹配）
- 图标：替换 `JCCData/Assets.xcassets/AppIcon.appiconset/icon-1024.png`（1024×1024）

数据来自 dataj.cc，仅供个人参考，非官方应用。
