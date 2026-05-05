---
description: 同步 project_structure.md 到当前 HEAD 状态
---

按 CLAUDE.md §2 规则更新 [project_structure.md](../../project_structure.md)：

1. Read project_structure.md 顶部"最后同步"行的 commit hash（旧 hash）
2. `git log --oneline <旧hash>..HEAD` 看变更 commit
3. `git diff <旧hash>..HEAD --stat` 看影响文件
4. 只动真正变化的小节：目录布局 / 新增类 / 状态机 / 实体命名 / 网络层 / 数据流
5. 顶部"最后同步"改成 today；commit hash 用 `git log -1 --format='%h %s'`
6. 纯改动（注释、日志文案、空格）不动文档
7. **不要自动 commit**，让用户决定

如果旧 hash 到 HEAD 之间没有结构性改动，直接打印"无需更新"，不动文档。
