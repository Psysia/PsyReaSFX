# PsyReaSFX 0.9 UCS 分类架构

## 目标与边界

0.9 的高级检索首先建立可审计、可回滚的 UCS 分类底座。当前阶段只自动接受能够被官方 UCS 8.2.1 数据唯一验证的结果，不使用模糊猜测直接改写用户资料。

## 数据来源

- 来源：Universal Category System 官方 8.2.1 完整翻译表。
- 内置目录：753 个唯一 CatID、82 个一级分类，以及英文和简体中文名称、解释与同义词。
- 生成前校验官方工作簿 SHA-256；生成脚本同时校验表头、记录数和 CatID 唯一性。
- 运行时只读取压缩后的离线 TSV，不依赖网络，也不把官方源工作簿打入发行包。

详细来源与校验值见 `assets/ucs/README.md`。

## 分类优先级

1. 文件名以合法 CatID 开头，并紧跟 `_`、`-`、空白或文件名结束：记为 `exact / filename`。
2. 文件名未命中时，精确读取音频元数据中的 CatID；若 CatID 无效，再校验 Category 与 SubCategory 组合：记为 `exact / metadata`。
3. 元数据存在但无法映射到官方目录：保留原值，记为 `pending / metadata`，等待后续候选确认界面处理。
4. 没有可用信息：记为 `unclassified`。
5. 用户手工修改 CatID、Category 或 SubCategory：记为 `manual`，后续自动索引不得覆盖。

文件名 CatID 匹配区分大小写并要求分隔符，避免把普通英文前缀误分类。元数据字段名使用确定性的叶节点精确匹配，避免 `CATEGORY` 错误命中 `SUBCATEGORY`。

## 持久化字段

每条素材除 CatID、Category、SubCategory 外，还保存：

- `ucs_status`：`exact`、`pending`、`unclassified` 或 `manual`；
- `ucs_source`：`filename`、`metadata`、`manual` 或空；
- `ucs_version`：分类所用 UCS 数据版本；
- `ucs_classifier_version`：分类器规则版本；
- `ucs_confidence`：当前确定性分值。

这些字段随数据库表头扩展，不提升数据库主架构版本。0.8.5 可以读取同一数据库并忽略未知字段，便于 Beta 测试期间回退；旧版本再次保存时可能丢弃新增字段，但不会损坏核心素材记录。

## 性能与验证

- 运行时目录采用 CatID 哈希索引和 Category/SubCategory 组合哈希索引，单次精确分类为常数时间查找。
- CI 固定验证 753 条记录、82 个一级分类、中文字段、大小写与分隔符边界、元数据字段隔离。
- CI 每次执行 500,000 次文件名分类查找，持续约束 50 万条素材库的基本规模目标。

## 后续同一 Beta 批次

在发布 0.9.0 Beta 1 前继续完成：UCS 独立虚拟目录、现有库批量扫描与预览、候选确认/撤销、UCS 关键词搜索提示。所有自动改写现有库的操作必须先提供预览并允许用户确认。
