# cast3d 开发计划

> 图片/文本 → Tripo API → GLB 3D 模型 → 浏览器交互展示

## 四层架构

```
Layer 4: Viewer（展示层）
  view_3d() → 自定义 htmlwidget + Three.js GLTFLoader + OrbitControls
  rgl2gltf 降级展示作为兜底

Layer 3: Model（模型层）
  download_model() → 本地 .glb  + 元数据
  model_info() → 顶点/面数/纹理信息

Layer 2: Task（任务层）
  create_3d_from_image() → Tripo image-to-3d 任务
  poll_task() → 轮询任务状态（指数退避）
  generate_3d() → 一步到位快捷函数

Layer 1: API（通信层）
  cast3d_setup() → API key 全局配置
  cast3d_request() → httr2 统一出口（Bearer auth + 重试 + 超时）
```

## 展示层方案选择

- **方案 A（主力）**：自定义 htmlwidget 包装 Three.js GLTFLoader + OrbitControls
- **方案 B（降级）**：rgl2gltf::readGLB() → as.mesh3d() → 基础 3D 视图
- **不可行**：CRAN threejs 包不支持 GLB 加载

## 依赖

| 类型 | 包 | 用途 |
|------|-----|------|
| Imports | httr2 | HTTP 通信 |
| Imports | jsonlite | JSON 解析 |
| Imports | htmlwidgets | 3D viewer widget |
| Imports | cli | 进度提示 |
| Imports | fs | 文件管理 |
| Suggests | rgl2gltf | GLB 解析 + 降级展示 |
| Suggests | testthat (>= 3.0.0) | 测试 |
| Suggests | knitr/rmarkdown | 文档 |
| Suggests | shiny | Shiny 集成演示 |

## 阶段计划

### Phase 1: 包骨架 ✅
- [x] 创建目录结构 (R/, inst/, tests/, vignettes/)
- [x] DESCRIPTION（含 httr2/htmlwidgets 等 Imports）
- [x] NAMESPACE（roxygen2 自动生成）
- [x] R/zzz.R（.onAttach/.onLoad）
- [x] R/config.R（cast3d_setup + options 管理）
- [x] R/s3-classes.R（cast3d_task + cast3d_model S3 类 + print 方法）
- [x] R/cast3d-package.R

### Phase 2: API 通信层 ✅
- [x] R/api.R（cast3d_request：统一 httr2 出口）
- [x] R/utils.R（错误类 cast3d_api_error/cast3d_timeout_error + 路径 helper）
- [x] 重试逻辑（req_retry + 指数退避）
- [x] 超时配置（可配总超时 300s）

### Phase 3: 任务层 ✅
- [x] R/task.R
- [x] create_3d_from_image()（支持文件路径/URL/raw，自动 base64）
- [x] poll_task()（轮询 + cli 进度条 + 超时中断）
- [x] generate_3d()（create + poll + download 一步到位）

### Phase 4: 模型层 ✅
- [x] R/model.R
- [x] download_model()（从 Tripo 下载 GLB 到本地缓存）
- [x] model_info()（读取 GLB 元数据，Suggests rgl2gltf）

### Phase 5: 展示层 ✅
- [x] R/viewer.R（view_3d htmlwidget 封装）
- [x] inst/htmlwidgets/glb_viewer.yaml
- [x] inst/htmlwidgets/glb_viewer.js（Three.js GLTFLoader + OrbitControls）
- [x] 降级方案：rgl2gltf 桥接

### Phase 6: 测试 + 文档 + 检查 ✅
- [x] tests/testthat/（test-utils, test-config, test-task, test-s3-classes, test-viewer）
- [x] vignettes/cast3d.Rmd
- [x] README.md
- [x] R CMD check 测试全部通过
- [x] LICENSE 文件

### Phase 7: R 绘图 → 3D ✅
- [x] `ggplot_to_3d()` — ggplot2 对象一键转 3D
- [x] `plot_to_3d()` — base R 图形转 3D
- [x] `create_3d_from_text()` / `generate_3d_from_text()` — text-to-3D
- [x] `describe_image_for_3d()` / `generate_3d_via_llm()` — aisdk vision LLM 增强
  - [x] `mode = "data_viz"` 专用 prompt：散点→圆柱、线条→管状、聚类→凸包
  - [x] `mode = "object"` 通用物体描述
  - [x] `via_llm` 参数控制 ggplot_to_3d 路由
- [x] `show_grid` 参数控制地面网格
- [x] `proxy` 参数支持 HTTP 代理

### Phase 8: 数据 → 精确 3D 几何 ✅
- [x] `data_sculpture()` — x/y/z 数据直接构建 3D 几何（无需 AI）
  - [x] `type = "pin"` — 圆柱针雕塑
  - [x] `type = "bar"` — 方块雕塑
  - [x] `type = "terrain"` — 阶梯地形
- [x] `write_meshes_glb()` — 内置最小 GLB 序列化器（无外部依赖）
