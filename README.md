# cast3d

<!-- badges: start -->
<!-- badges: end -->

图片/文本 → [Tripo API](https://api.tripo3d.ai) → GLB 3D 模型 → 浏览器交互展示

## 安装

```r
remotes::install_github("YuLab-SMU/cast3d")
```

## 快速开始

```r
library(cast3d)

cast3d_setup(api_key = "your-api-key")

model <- generate_3d("photo.jpg")

view_3d(model)
```

三步：**配置密钥** → **生成模型** → **交互查看**。

### 例子

+ [噬菌体图片](https://yulab-smu.top/cast3d/phage.png)
+ [噬菌体3D模型](https://yulab-smu.top/cast3d/)


## 核心函数

| 函数 | 说明 |
|------|------|
| `cast3d_setup()` | 配置 API key、超时、输出目录等全局选项 |
| `create_3d_from_image()` | 提交图片到 Tripo image-to-3D 管线 |
| `poll_task()` | 轮询任务状态直到完成或超时 |
| `generate_3d()` | 一步到位：创建 + 轮询 + 下载 |
| `download_model()` | 下载完成的 .glb 模型到本地缓存 |
| `view_3d()` | Three.js 交互式 3D 查看器 |
| `model_info()` | 查看模型元数据（顶点/面数/大小） |

## 环境变量

也可以不用 `cast3d_setup()`，直接设环境变量：

```r
Sys.setenv(TRIPO_API_KEY = "your-api-key")
```

packages 加载时自动读取。

## Shiny 集成

```r
library(shiny)
library(cast3d)

ui <- fluidPage(
  glb_viewer_output("model_3d")
)

server <- function(input, output, session) {
  model <- generate_3d("photo.jpg")
  output$model_3d <- render_glb_viewer({
    view_3d(model)
  })
}
```

## 架构

```
Layer 4: Viewer ── view_3d() → htmlwidget + Three.js GLTFLoader + OrbitControls
Layer 3: Model  ── download_model() / model_info()
Layer 2: Task   ── create_3d_from_image() / poll_task() / generate_3d()
Layer 1: API    ── cast3d_request() → httr2 (Bearer auth + 重试 + 超时)
```

基础通信用 **httr2**，展示层用 **htmlwidgets** 包装 Three.js。
