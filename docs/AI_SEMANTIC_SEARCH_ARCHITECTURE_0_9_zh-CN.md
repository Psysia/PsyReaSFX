# PsyReaSFX 0.9 AI 语义搜索架构

更新日期：2026-09-16

## 定位

AI 语义搜索是“以文字描述找声音”的独立工作流，不属于“以参考音频找相似声音”的声学/神经相似度系统。界面、结果视图、状态和排序字段均保持分离。

## 第一版流程

1. 用户输入自然语言声音描述。
2. DeepSeek、OpenAI 或 OpenAI-compatible Chat Completions 将描述转换为有界的中英文正向词、排除词和声音概念。
3. Lua 在当前库、目录、集合和工作流条件内逐帧扫描本地文本字段，使用固定 Top-120 堆选择候选。
4. API 只接收这 120 条候选的文件名、Description、Keywords、UCS Category/SubCategory/CatID 和时长。
5. 模型返回候选 ID、0–100 相关度和简短解释；Lua 校验 ID、去重、截断并发布独立结果视图。
6. API 重排失败时，可以显示 AI 扩展词生成的本地候选，并明确提示发生了回退。

## 支持的接口

- DeepSeek：`https://api.deepseek.com/chat/completions`，默认 `deepseek-chat`。
- OpenAI Chat Completions。
- 自定义 OpenAI-compatible Chat Completions 地址和模型。
- 远程服务强制 HTTPS；仅环回地址允许 HTTP，便于连接本机模型服务。

## 凭据与隐私

- API Key 不进入 Lua 普通配置、Git、日志或数据备份。
- Windows PowerShell bridge 使用当前用户 DPAPI 加密密钥。
- Lua 启动时清理可能由异常中断遗留的固定明文临时文件。
- Key 不出现在进程命令行；bridge 只从加密文件解密到当前进程内存。
- 不上传音频、完整文件路径或完整素材目录。
- 恢复出厂会删除保存的 API Key。

## 性能边界

- 本地召回逐帧执行，避免一次遍历大型目录阻塞界面。
- 候选集合固定为 120 条，避免 API 请求量随素材库规模增长。
- 最终结果固定最多 100 条。
- AI 任务通过现有 `Jobs` 协调器占用 `catalog_exclusive` 资源，可取消并避免扫描同时修改目录。

## 已知边界与后续方向

第一版只能理解文件名与文本元数据，无法直接听懂音频。后续加入 CLAP 或同类本地音频—文本 embedding 后，文本查询可先从本地向量索引召回，再选择是否使用用户配置的 API 进行查询扩展、重排和解释。
