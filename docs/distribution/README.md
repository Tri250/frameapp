# 独立发布与材料模板

[简体中文](README.md) | [English](README.en.md)

本目录为开发者提供分发与上架所需的签名示例、本地政策页面、检查表和软著材料模板。开发者可按实际版本和目标市场要求酌情修改；模板不代表备案、登记或审核通过。

## 发布前填写

| 内容 | 位置与要求 |
| --- | --- |
| 运营者、联系邮箱、政策版本 | [config.json](../../policies/config.json)，按实际服务填写；修改正文与生成方式见 [本地政策页面](../../policies/README.md) |
| 应用名称、图标、包名和版本 | `pubspec.yaml`、Android／iOS 工程；独立版本使用自己的标识与素材 |
| 签名与商店账号 | [Android](../android-release.zh-CN.md)、[iOS](../ios-setup.zh-CN.md)；使用自己的账号和证书 |
| 商店文案、截图、隐私申报 | [上架资料模板](templates/store-listing.md)，所有陈述须匹配实际发布包 |
| 软著申请与说明书 | [材料填写项](templates/copyright-application.md)、[元数据](templates/copyright-metadata.example.json)、[说明书](templates/software-description.md) |
| 独立仓库与贡献者展示 | `policies/community.json`、`.github/contributors-ownership.json`、CODEOWNERS 和规则模板；Fork 维护者改为自己的仓库与治理信息，保留上游版权声明 |

填写后的个人／公司资料、证书、申请表及导出文件保存在 Git 外或已忽略的 `docs/software-copyright/`，不要替换仓库中的空白模板。联系邮箱等占位值应在分发前填写。

## 软著材料生成

复制三个软著模板到 `docs/software-copyright/`，将元数据文件重命名为 `copyright-metadata.json` 并填写元数据与说明书。按实际权属说明上游代码、自己的新增部分和第三方素材；不能将整个 Fork 声明为全部原创，也不能把 MIT 许可当成著作权转让。发表状态按实际公开情况填写，开源不等于“未发表”。

安装 Python 的 `reportlab`，准备有使用许可、支持中文的 TTF 字体，再执行：

~~~sh
python3 tools/build_software_copyright_materials.py \
  --metadata docs/software-copyright/copyright-metadata.json \
  --description docs/software-copyright/software-description.md \
  --font /path/to/licensed-cjk.ttf
~~~

输出为 `docs/software-copyright/source-materials.pdf` 与 `software-description.pdf`。生成器按每页 50 行列出源码；超过 60 页取前、后各 30 页，不足则输出全文。它只辅助排版，不判断登记资格，也不保证符合受理机构最新要求；提交前检查内容完整性和版面。

发布前完成 [验收表](../release-checklist.zh-CN.md)，核对目标市场及所在地的现行要求。代码适用 MIT；独立发布者负责自己的数据处理、素材授权、申报与用户支持，详见 [法律与许可](../legal.zh-CN.md)。
