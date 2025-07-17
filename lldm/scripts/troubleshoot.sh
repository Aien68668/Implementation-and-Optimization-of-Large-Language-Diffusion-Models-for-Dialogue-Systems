#!/bin/bash

# 故障排除脚本
# 用于解决常见的启动问题

echo "🔧 LLaDA系统故障排除工具"
echo "================================================"

# 检查并释放端口5000
echo "[检查] 检查端口5000是否被占用..."
PORT_PID=$(lsof -ti:5000)
if [ -n "$PORT_PID" ]; then
  echo "[发现] 端口5000被进程 $PORT_PID 占用"
  echo "[操作] 正在终止进程..."
  kill -9 $PORT_PID
  sleep 1
  if lsof -ti:5000 > /dev/null; then
    echo "[失败] 无法释放端口5000，请手动终止占用进程"
  else
    echo "[成功] 端口5000已释放"
  fi
else
  echo "[正常] 端口5000未被占用"
fi

# 检查并释放端口3000
echo "[检查] 检查端口3000是否被占用..."
PORT_PID=$(lsof -ti:3000)
if [ -n "$PORT_PID" ]; then
  echo "[发现] 端口3000被进程 $PORT_PID 占用"
  echo "[操作] 正在终止进程..."
  kill -9 $PORT_PID
  sleep 1
  if lsof -ti:3000 > /dev/null; then
    echo "[失败] 无法释放端口3000，请手动终止占用进程"
  else
    echo "[成功] 端口3000已释放"
  fi
else
  echo "[正常] 端口3000未被占用"
fi

# 检查日志文件
echo "[检查] 检查后端日志文件..."
if [ -f "backend.log" ]; then
  echo "[发现] 后端日志文件存在，最后10行内容："
  tail -n 10 backend.log
else
  echo "[信息] 后端日志文件不存在"
fi

echo "================================================"
echo "🔄 故障排除完成，请尝试重新启动系统"
