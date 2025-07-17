# LLaDA扩散语言模型可视化系统

一个基于React和Flask的创新型可视化平台，专门用于展示LLaDA扩散语言模型的生成过程。

## 快速开始

### 一键启动
```bash
cd lldm
./run.sh
```

启动成功后，访问：
- **前端界面**: http://localhost:3000
- **后端API**: http://localhost:9000
- **健康检查**: http://localhost:9000/health

### 环境要求
本项目中，后端使用的python版本为3.12，前端使用的是React 22
开发。

## 📂 项目架构

```
lldm/
├── src/                     # 前端源代码
│   ├── components/          # React组件
│   ├── services/            # API服务层
│   ├── styles/              # 样式文件
│   └── utils/               # 工具函数
├── scripts/                 # 启动和管理脚本
├── docs/                    # 详细文档
└── tests/                   # 测试文件
```

## 📚 详细文档

- 📖 **[项目架构分析](docs/项目架构分析.md)** - 完整的技术架构和模块分析
- 🔗 **[前后端连接详解](docs/前后端连接详解.md)** - 详细的API接口和数据流说明
- ⚙️ **[核心算法详解](docs/核心算法详解.md)** - 扩散生成、Block处理、约束控制、置信度计算的实现原理
- � **[系统流程图](docs/系统流程图.md)** - Mermaid流程图展示完整的输入到输出流程
- �📋 **[项目结构说明](docs/项目结构.md)** - 目录结构和文件功能说明
- 🚀 **[运行指南](docs/运行指南.md)** - 详细的安装和运行说明
- 🔧 **[重构报告](docs/重构报告.md)** - 系统改进和优化记录

详细架构说明: [项目结构文档](docs/项目结构.md)

## 🎯 核心技术

### 前端技术栈
- **React 18.2** - 组件化UI框架
- **Axios** - HTTP客户端
- **CSS3** - 动画和样式
- **ES6+** - 现代JavaScript

### 后端技术栈  
- **Flask** - 轻量级Web框架- **PyTorch** - 深度学习推理
- **Transformers** - 模型加载和处理
- **LLaDA模型** - 扩散语言模型

## 🎮 使用指南

### 界面布局
- **左侧边栏**: 对话管理和系统状态监控
  - 📋 多对话会话切换
  - 📊 实时系统状态（连接状态、GPU/CPU、模型状态）
- **中央对话区**: 主要的聊天和可视化界面
- **右侧设置栏**: 参数调节和置信度指示器

### 基本对话
1. 在输入框中输入您的问题
2. 点击发送或按回车键
3. 观察模型逐步生成回答的过程

### 高级功能

#### 参数调节
- **生成长度**: 控制回答的最大长度 (1-128)
- **扩散步数**: 影响生成质量和速度 (1-64)  
- **温度**: 控制生成的随机性 (0.0-2.0)
- **CFG缩放**: 分类器自由引导强度 (0.0-10.0)

#### 约束生成
在约束输入框中指定特定位置的词语：
```
格式: "位置:词语, 位置:词语"
示例: "0:今天, 3:天气, 7:很好"
```

#### 置信度观察
- 🔴 **红色**: 低置信度 (<30%)
- 🟠 **橙色**: 中置信度 (30%-70%)
- 🟢 **绿色**: 高置信度 (>70%)
- 🔵 **蓝色**: 之前生成的token
- ⚫ **深灰色**: [MASK]标记，带大小呼吸动画

**智能显示逻辑**：
- 生成过程中：显示所有token（包括[MASK]）
- 生成完成后：自动过滤并移除空的token格子，保留有内容的token可视化样式

#### 系统状态监控
左侧边栏底部实时显示：
- 📡 **后端连接**: 🟢已连接 / 🔴连接失败
- 🎮 **计算设备**: 🎮GPU加速 / 💻CPU模式
- 📦 **模型状态**: 🟢已加载 / 🟡加载中
- ⚡ **生成状态**: 🔵正在生成... (生成时显示)

## 📝 日志监控

系统提供完整的日志记录和监控功能，所有日志按启动时间自动分类存储。

### 日志目录结构

```
logs/
├── session_20250713_143021/    # 启动时间命名的会话目录
│   ├── backend.log             # 后端详细日志
│   ├── frontend.log            # 前端详细日志
│   └── system.log              # 系统启动日志
├── session_20250713_095412/    # 上一次启动的日志
│   ├── backend.log
│   ├── frontend.log
│   └── system.log
└── ...
backend.log -> logs/session_xxx/backend.log    # 软链接指向最新日志
frontend.log -> logs/session_xxx/frontend.log  # 软链接指向最新日志
```

### 日志内容

- **backend.log** - 后端详细日志
  - 请求接收和响应详情
  - 消息内容和参数记录
  - GPU内存使用情况
  - 错误堆栈和异常信息
  - 生成耗时和性能指标

- **frontend.log** - 前端详细日志
  - API调用详情
  - 用户交互记录
  - 组件状态变化
  - 错误和警告信息

- **system.log** - 系统启动日志
  - 启动过程记录
  - 服务状态变化
  - 环境检查结果
  - 管理操作记录

### 日志监控工具

```bash
# 实时查看最新日志
tail -f backend.log frontend.log

# 查看特定会话日志
tail -f logs/session_20250713_143021/*.log

# 使用专用监控脚本（自动检测最新日志）
./scripts/monitor_logs.sh

# 监控指定会话
./scripts/monitor_logs.sh logs/session_20250713_143021

# 快速模式
./scripts/monitor_logs.sh monitor    # 实时监控
./scripts/monitor_logs.sh stats      # 显示统计
./scripts/monitor_logs.sh export     # 导出日志
```

### 日志特性

- ✅ **会话隔离** - 每次启动创建独立的日志目录
- ✅ **时间命名** - 目录名包含启动时间，便于管理
- ✅ **软链接** - 兼容性链接指向最新日志
- ✅ **请求ID追踪** - 每个请求都有唯一ID，便于追踪完整流程
- ✅ **详细参数记录** - 完整记录所有输入参数和设置
- ✅ **性能指标** - 请求耗时、GPU内存使用等
- ✅ **错误堆栈** - 完整的错误信息和调用栈
- ✅ **历史保留** - 自动保留历史日志会话
- ✅ **实时监控** - 彩色输出和错误过滤

### 日志示例

```bash
# 后端日志示例 (logs/session_xxx/backend.log)
2025-07-13 10:30:15,123 - INFO - [req_abc123] 收到生成请求
2025-07-13 10:30:15,124 - INFO - [req_abc123] 消息数量: 3, 设置参数: {"temperature": 0.7, "steps": 32}
2025-07-13 10:30:15,125 - INFO - [req_abc123] 开始生成前GPU内存: 14.93GB
2025-07-13 10:30:17,456 - INFO - [req_abc123] 生成完成, 响应长度: 25, 耗时: 2.33秒

# 前端日志示例 (logs/session_xxx/frontend.log)
[API-INFO] [frontend_abc456] 开始处理用户发送请求: {"userInput": "你好", "settings": {...}}
[API-INFO] 发送API请求 [req_def789]: {"method": "POST", "url": "/generate", "data": {...}}
[API-INFO] 收到API响应 [req_def789]: {"status": 200, "duration": "2340ms"}

# 系统日志示例 (logs/session_xxx/system.log)
2025-07-13 10:28:30,001 - INFO - 开始启动流程...
2025-07-13 10:28:32,456 - SUCCESS - 后端服务启动成功 (PID: 12345)
2025-07-13 10:28:45,789 - SUCCESS - 前端服务启动成功 (PID: 12346)
```

## � 详细文档

- [🚀 运行指南](docs/运行指南.md) - 安装、配置和故障排除
- [🏗️ 项目结构](docs/项目结构.md) - 代码组织和架构说明
- [⚙️ 工作原理](docs/工作原理.md) - 技术原理和算法详解
- [📋 重构报告](docs/重构报告.md) - 项目优化历程

## 🛠️ 开发指南

### 本地开发

```bash
# 安装依赖
npm install
pip install -r requirements.txt

# 分别启动服务
# 终端1 - 后端
python server/server.py

# 终端2 - 前端  
npm start
```

### 测试

```bash
# 前端测试
npm test

# 后端API测试
python scripts/test_api.py

# 完整系统测试
./scripts/start.sh
```

### 构建部署

```bash
# 构建前端
npm run build

# 生产环境部署
# 参见 scripts/DEPLOY.md
```

## 🔧 常见问题

### 启动失败
```bash
# 检查端口占用
netstat -tlnp | grep :3000
netstat -tlnp | grep :5000

# 检查模型路径
ls -la /root/autodl-tmp/model/

# 查看详细日志
tail -f backend.log
tail -f frontend.log
```

### 性能优化
- 确保使用GPU加速：`nvidia-smi`
- 调整生成参数减少计算量
- 监控内存使用：`htop`

### 连接问题
```bash
# 测试后端连接
curl http://localhost:5000/health

# 测试前端可用性
curl http://localhost:3000
```

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📜 更新日志

### v2.0.0 (2025-07-10)
- ✨ 完全重构项目架构
- 🎯 新增服务层抽象
- 📚 完善文档系统
- 🔧 优化启动流程
- 🎨 改进用户界面

### v1.0.0 (2025-07-09)
- 🎉 初始版本发布
- ⚡ 基础扩散生成功能
- 🎨 可视化界面实现

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- [Hugging Face Transformers](https://huggingface.co/transformers/) - 模型加载框架
- [React](https://reactjs.org/) - 前端UI框架  
- [Flask](https://flask.palletsprojects.com/) - 后端Web框架
- [PyTorch](https://pytorch.org/) - 深度学习框架

## 📧 联系方式

如有问题或建议，请：
- 开启 [Issue](https://github.com/your-repo/issues)
- 发送邮件至: your-email@example.com
- 查看 [文档](docs/) 获取更多帮助

---

**让AI的思考过程变得可见！** 🚀✨

- 右侧设置栏中有置信度指示器，显示颜色说明
- 不同颜色代表不同的置信度级别：
  - 深灰色: [MASK] 标记，持续大小闪动
  - 红色: 低置信度 (< 0.3)
  - 橙色: 中置信度 (0.3-0.7)
  - 绿色: 高置信度 (> 0.7)
  - 蓝色: 之前生成的token

### 约束生成

在约束输入框中输入位置约束，格式为：`位置:单词, 位置:单词`

例如：`0:Once, 5:upon, 10:time`

这将强制模型在第1个、第6个、第11个位置生成指定的词语。

### 参数调节

- **生成长度**: 控制生成文本的最大长度
- **去噪步数**: 控制扩散过程的迭代步数
- **温度**: 控制生成的随机性 (0.0 = 确定性, 1.0 = 高随机性)
- **CFG比例**: 分类器无关引导的强度

## API 接口

### POST /generate

生成文本的主要接口。

**请求体**：
```json
{
  "messages": [
    {"role": "user", "content": "你好"},
    {"role": "assistant", "content": "你好！"}
  ],
  "settings": {
    "gen_length": 64,
    "steps": 32,
    "temperature": 0.0,
    "cfg_scale": 0.0,
    "block_length": 32,
    "remasking": "low_confidence",
    "constraints": "0:Once, 5:upon"
  }
}
```

**响应**：
```json
{
  "response": "生成的文本",
  "visualization": [
    [["[MASK]", "#444444"], ["[MASK]", "#444444"]],
    [["Hello", "#FF6666"], ["[MASK]", "#444444"]],
    [["Hello", "#66CC66"], ["world", "#FFAA33"]]
  ]
}
```

### GET /health

健康检查接口。

**响应**：
```json
{
  "status": "healthy",
  "device": "cuda"
}
```

## 开发说明

### 前端开发

前端使用React构建，主要组件：

- `DiffusionModel`: 主要的可视化组件
- `ConfidenceIndicator`: 置信度指示器组件
- `api.js`: 与后端通信的工具函数

### 后端开发

后端使用Flask构建，主要功能：

- 加载和运行LLaDA模型
- 处理文本生成请求
- 提供可视化数据

### 自定义配置

可以通过修改以下文件来自定义系统：

- `src/DiffusionModel.js`: 修改前端界面和行为
- `server.py`: 修改后端API和模型配置
- `src/DiffusionModel.css`: 修改界面样式

## 故障排除

### 常见问题

1. **模型加载失败**：
   - 检查模型路径是否正确
   - 确保有足够的GPU内存
   - 检查transformers库版本

2. **前端无法连接后端**：
   - 确保后端服务器正在运行
   - 检查CORS设置
   - 验证API端点URL

3. **生成速度慢**：
   - 使用GPU加速
   - 减少生成长度和步数
   - 调整批处理大小

### 日志查看

- 后端日志：在运行`python server.py`的终端中查看
- 前端日志：在浏览器的开发者工具控制台中查看

## 许可证

本项目基于MIT许可证开源。

## 致谢

- [LLaDA](https://github.com/ML-GSAI/LLaDA) 项目团队
- [Transformers](https://huggingface.co/transformers/) 库
- [React](https://reactjs.org/) 框架
- [Flask](https://flask.palletsprojects.com/) 框架
