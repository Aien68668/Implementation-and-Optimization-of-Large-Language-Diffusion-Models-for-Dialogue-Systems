#!/bin/bash

# 测试信号处理的简单脚本

echo "🧪 测试信号处理修复..."

# 模拟清理函数
CLEANUP_DONE=false

cleanup() {
    # 避免重复清理
    if [ "$CLEANUP_DONE" = "true" ]; then
        echo "⚠️  重复清理被阻止"
        return 0
    fi
    CLEANUP_DONE=true
    
    echo "✅ 执行清理操作..."
    echo "✅ 清理完成"
}

# 只处理用户中断信号
trap cleanup INT TERM

echo "📋 模拟运行状态..."
echo "按 Ctrl+C 测试信号处理..."

# 模拟主循环
for i in {1..100}; do
    sleep 1
    echo -n "."
    if [ $((i % 10)) -eq 0 ]; then
        echo " ${i}s"
    fi
done

echo ""
echo "🎯 测试完成"
