#!/bin/bash

# LLaDA 系统启动入口
echo "🚀 LLaDA扩散语言模型可视化系统"
echo "================================================"

# 进入项目目录
cd "$(dirname "$0")"



# 检查并使用可用的启动脚本
if [ -f "./scripts/start.sh" ]; then
    exec ./scripts/start.sh
else
    echo "❌ 错误: 找不到启动脚本"
    echo "请确保 scripts/start.sh存在"
    exit 1
fi
