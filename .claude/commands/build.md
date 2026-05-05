---
description: 构建 VirtualOR（visionOS 26.4.1 模拟器）并只输出末尾
---

跑构建并只显示 tail：

```
xcodebuild -project /Users/geding/Documents/VirtualOR/VirtualOR.xcodeproj \
  -scheme VirtualOR \
  -destination 'platform=visionOS Simulator,id=FB652FE1-8226-4191-94BA-B378EE01059C' \
  build 2>&1 | tail -5
```

成功只报 `BUILD SUCCEEDED`。失败时定位报错的 .swift 文件 + 行号 + 错误信息，
不要全 dump。
