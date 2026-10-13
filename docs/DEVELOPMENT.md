# 开发与发布约定

源码在工作目录顶层维护。参考仓库位于本地 `work/`；原始日志与逆向分析位于本地 `research/`。二者不上传 GitHub。

构建产物统一写入 `outputs/`，该目录由 `.gitignore` 排除。每次完成可验证的修改后执行相关测试，再正常 commit 和 push。GitHub Release、标签及附件由维护者手动发布。

公开仓库只包含可供开发的源码、必要素材、测试及已注明许可的辅助代码。提交前检查暂存文件列表，不要用 `git add -f` 上传被忽略的文件。

原有资源路径 `mods/peril_warning/crusher_probe`、GUID 和菜单选项 ID 是兼容性标识，不随展示名称变更。
