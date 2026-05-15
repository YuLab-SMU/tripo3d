# tripo3d 使用指南：从注册到交互看 3D

> 用 R 调 Tripo API，把任意图片变成 3D 模型，在 RStudio 里拖拽旋转查看。

---

## 1. 注册 & 拿 API Key

Tripo 是 VAST-AI 团队做的图片/文本转 3D 服务。API Key 获取流程：

### Step 1：打开 Tripo 开发者平台

浏览器访问：**https://platform.tripo3d.ai**

### Step 2：注册/登录

用邮箱注册账号（免费额度足够测试用）。

### Step 3：生成 API Key

登录后进入 **API Keys** 页面：**https://platform.tripo3d.ai/api-keys**

点击 "Create API Key"，给它起个名字（比如 `my-r-project`），点确认。

> ⚠️ **关键的 5 秒钟**：Key 生成后，**secret key 只会显示这一次**。立刻复制保存到安全的地方（密码管理器或 `.Renviron`）。关掉弹窗后就再也看不到了。

Key 的格式通常以 `tsk_` 开头，长这样：

```
tsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 2. 安装 tripo3d

```r
remotes::install_github("yulab-github/tripo3d")
```

依赖会自动安装（httr2、jsonlite、htmlwidgets、cli、fs）。

---

## 3. 配置 API Key

三种方式，任选其一：

### 方式 A：环境变量（推荐）

在 `~/.Renviron` 里加一行：

```
TRIPO_API_KEY=tsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

重启 R 后自动读取，不用每次设。

### 方式 B：`tripo_setup()` 显式设置

```r
library(tripo3d)
tripo_setup(api_key = "tsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
```

当前 R 会话有效。

### 方式 C：`Sys.setenv()` 临时设置

```r
Sys.setenv(TRIPO_API_KEY = "tsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
```

### 配置代理（如需要）

如果你的网络需要通过代理访问外网：

```r
tripo_setup(
  api_key = "你的Key",
  proxy = "http://127.0.0.1:7897"
)
```

也可以通过环境变量：

```
TRIPO_PROXY=http://127.0.0.1:7897
```

---

## 4. 一分钟上手

```r
library(tripo3d)

# 如果没用环境变量，先设 Key
tripo_setup(api_key = "你的Key")

# 一步到位：上传图片 → 等生成 → 下载 → 查看
model <- generate_3d("cat.jpg")
view_3d(model)
```

`view_3d()` 会在 RStudio Viewer 窗格弹出一个交互式 3D 查看器。鼠标操作：

| 操作 | 效果 |
|------|------|
| 左键拖拽 | 旋转模型 |
| 右键拖拽 | 平移模型 |
| 滚轮 | 缩放 |
| 双击 | 复位视角 |

---

## 5. 分步控制（当你想看中间状态）

`generate_3d()` 是个快捷包装，底层分三步。当你需要监控进度或分别处理时可以手动来：

### Step 1：提交任务

```r
task <- create_3d_from_image(
  "cat.jpg",
  model_version = "v2.5-20250123",   # 模型版本
  texture = TRUE,            # 要不要贴图
  face_limit = 50000         # 面数上限
)
task
#> ── Tripo 3D Task ──
#> • Task ID: ef731ad6-aeb0-4950-9a2e-2298359dfaf8
#> • Status:  pending
#> • Created: 2026-05-14 15:30:00
```

### Step 2：轮询等待

```r
result <- poll_task(task, interval = 3, max_wait = 300)
#> ⠏ Tripo task ef731ad6... processing
#> ✔ Task ef731ad6... complete
```

`interval` 是轮询间隔（秒），`max_wait` 是最大等多久。超时会报 `tripo_timeout_error`。

### Step 3：下载模型

```r
model <- download_model(result)
#> ✔ Model saved to C:/Users/xxx/AppData/Local/R/.../tripo3d/ef731ad6.glb (2.3 MB)

model
#> ── Tripo 3D Model ──
#> • Path:   C:/.../tripo3d/ef731ad6.glb
#> • Task:   ef731ad6-aeb0-4950-9a2e-2298359dfaf8
#> • Format: GLB
#> • Size: 2.3 MB
```

模型会缓存到 `tools::R_user_dir("tripo3d", "data")`，重复下载同一个 task 不会重新拉。

---

## 6. 查看模型的更多方式

### 直接查看 .glb 文件

```r
view_3d("path/to/any_model.glb")
```

不限于 Tripo 生成的模型，任何标准 GLB 文件都可以。

### 查看模型元数据

```r
model_info(model)
#> $format
#> [1] "GLB"
#> $size_bytes
#> [1] 2430000
#> $vertices
#> [1] 12500
#> $faces
#> [1] 8300
```

如果装了 `rgl2gltf`，还会自动读出顶点数/面数。

### 自定义 viewer 外观

```r
view_3d(model,
  background = "#1a1a2e",  # 深色背景
  show_grid = TRUE,         # 显示参考地面网格
  width = 800,
  height = 600
)
```

---

## 7. Shiny 集成

```r
library(shiny)
library(tripo3d)

ui <- fluidPage(
  titlePanel("Tripo 3D Viewer"),
  glb_viewer_output("viewer", height = "600px")
)

server <- function(input, output, session) {
  #model <- generate_3d("my_image.jpg")
  output$viewer <- render_glb_viewer({
    view_3d(model, background = "#eef2f9")
  })
}

shinyApp(ui, server)
```

---

## 8. R 绘图 → 3D 数据雕塑

tripo3d 的 R 独有特性：把数据直接变成精确的 3D 几何体。

### 🥇 数据直接 → 3D 几何（推荐，无 AI）

`data_sculpture()` 从 x, y, z 数据直接构建 3D 几何——圆柱针、方块、或阶梯地形，精确到数据坐标。无需 AI，无需 API key。

```r
library(tripo3d)
data(mtcars)

# 散点数据 → 3D 针状雕塑
m <- data_sculpture(
  mtcars$wt, mtcars$mpg, mtcars$hp / 10,
  type = "pin", radius = 0.08,
  color = hcl.colors(32, "Viridis")
)
view_3d(m)

# 柱状图 → 3D 方块雕塑
cyl_means <- tapply(mtcars$mpg, mtcars$cyl, mean)
m <- data_sculpture(
  seq_along(cyl_means), rep(0, length(cyl_means)), unname(cyl_means),
  type = "bar", radius = 0.3, color = c("#FF6B6B", "#4ECDC4", "#45B7D1")
)
view_3d(m)
```

| type | 说明 | 用途 |
|------|------|------|
| `"pin"` | 圆柱针（高度=z值） | 散点图、UMAP |
| `"bar"` | 长方体（高度=z值） | 柱状图、箱线特征 |
| `"terrain"` | 阶梯地形网格 | 热图、密度图 |

### 🥈 ggplot2 → LLM 描述 → 3D（AI 增强）

```r
library(ggplot2)
library(aisdk)
library(tripo3d)

tripo_setup(api_key = "你的Key")

p <- ggplot(mtcars, aes(wt, mpg, size = hp, color = factor(cyl))) +
  geom_point(alpha = 0.8) +
  scale_size_continuous(range = c(3, 10)) +
  labs(title = "mtcars: Weight vs MPG") +
  theme_minimal(base_size = 16)

model <- ggplot_to_3d(p)          # 默认 via_llm = TRUE
view_3d(model)
```

### base R 图转 3D

```r
model <- plot_to_3d({
  plot(mtcars$wt, mtcars$mpg,
       pch = 19, col = "steelblue",
       xlab = "Weight", ylab = "MPG")
  abline(lm(mpg ~ wt, mtcars), col = "red", lwd = 2)
})
view_3d(model)
```

### 关闭 LLM 路由（直接 image_to_model）

```r
model <- ggplot_to_3d(p, via_llm = FALSE)
```

### 三个描述模式的对比

```r
# 默认识别：data_viz 模式（数据雕塑专用）
desc <- describe_image_for_3d("umap.png")

# object 模式：适合照片、物体
desc <- describe_image_for_3d("cat.jpg", mode = "object")

# 自定义画质
model <- ggplot_to_3d(p,
  width = 2400, height = 1600,
  dpi = 300,
  model_version = "v2.5-20250123"
)
```

---

## 9. LLM 增强：图片 → 描述 → 3D（可选）

如果装了我们另一个包 [aisdk](https://github.com/yulab-github/aisdk)，可以用 vision LLM 先分析图片内容，生成结构化描述，再走 Tripo 的 `text_to_model` 生成 3D。有时候这比直接 `image_to_model` 效果更好，尤其图片包含复杂细节时。

### 安装 aisdk

```r
remotes::install_github("yulab-github/aisdk")
```

### 用 LLM 描述图片

```r
library(aisdk)
library(tripo3d)

tripo_setup(api_key = "你的Key")

# model 可省略，自动用 aisdk 的默认模型（通常 openai:gpt-4o）
desc <- describe_image_for_3d("cat.jpg")
cat(desc)
#> A quadrupedal feline figurine with rounded head, pointed ears,
#> cylindrical torso, four short tapered legs, and a thin curved tail.
#> Surface is smooth matte plastic with subtle whisker indentations.
#> Eyes are large spherical protrusions. Proportions: head 1/3 of
#> total height, legs 1/4. No fine fur texture.

# 也可以显式指定模型
# library(aisdk)
# model <- create_anthropic()$language_model("claude-sonnet-4-20250514")
# desc <- describe_image_for_3d("cat.jpg", model)
```

### 一步到位：图片 → LLM 描述 → 3D

```r
result <- generate_3d_via_llm("cat.jpg")  # model 自动用默认
view_3d(result)
```

### 可选的模型对象持久化

```r
aisdk::set_model("anthropic:claude-sonnet-4-20250514")
# 之后 describe_image_for_3d("any_image.jpg") 默认用 Claude

# 或者用 tripo3d 自己的选项
options(tripo3d.llm_model = "openai:gpt-4o-mini")
```

### 纯文本生成 3D（不用图片）

如果你已经有文字描述，可以直接用 text-to-3D：

```r
model <- generate_3d_from_text("a ceramic teacup with a gold rim")
view_3d(model)
```

---

## 10. 高级配置

```r
tripo_setup(
  api_key = "你的Key",
  base_url = "https://api.tripo3d.ai",  # 默认
  timeout = 120,      # 单次请求超时秒数
  max_retries = 5,    # 失败自动重试次数
  output_dir = "D:/my_3d_models"  # 模型下载目录
)
```

---

## 11. 常见问题

### Q: API 免费吗？

Tripo 提供一定的免费额度。具体配额和计费见 [platform.tripo3d.ai](https://platform.tripo3d.ai) 的 Wallet 页面。

### Q: 图片有什么要求？

- 格式：PNG / JPG / WebP
- 建议：清晰、主体突出、正面或 3/4 视角、光照均匀
- 支持本地文件路径、HTTP URL、raw 向量

### Q: 生成一个模型要多久？

通常 30s ~ 2min，取决于模型版本和队列负载。

### Q: 报错 "Unauthorized"？

检查 Key 是否正确（是否以 `tsk_` 开头），是否在平台上仍然有效。

### Q: 报错 "No API key found"？

确认已执行 `tripo_setup()` 或设好了 `TRIPO_API_KEY` 环境变量。可以 `get_tripo_options()` 查看当前配置。

### Q: viewer 不显示？

- RStudio：确保在 Viewer 窗格而不是 Plots 窗格
- 非 RStudio 环境：viewer 会尝试在浏览器中打开
- 如果完全不工作，检查 `htmlwidgets` 包是否正常安装

---

## 12. 参考链接

| 资源 | 地址 |
|------|------|
| Tripo 开发者平台 | https://platform.tripo3d.ai |
| API Key 页面 | https://platform.tripo3d.ai/api-keys |
| API 文档 | https://platform.tripo3d.ai/docs/quick-start |
| tripo3d GitHub | https://github.com/YuLab-SMU/tripo3d |
