#!/bin/bash

# LLaDA 日志监控脚本
# 提供实时日志监控和分析功能

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "🔍 LLaDA 日志监控工具"
echo "===================="

# 自动检测日志目录
detect_log_directory() {
    # 如果指定了参数，使用参数作为日志目录
    if [ ! -z "$1" ] && [ -d "$1" ]; then
        LOG_DIR="$1"
        echo "📁 使用指定的日志目录: $LOG_DIR"
        return 0
    fi
    
    # 检查是否有软链接指向的日志文件
    if [ -L "backend.log" ] && [ -L "frontend.log" ]; then
        LOG_DIR=$(dirname $(readlink "backend.log"))
        echo "📁 通过软链接检测到日志目录: $LOG_DIR"
        return 0
    fi
    
    # 查找最新的日志会话目录
    if [ -d "logs" ]; then
        LATEST_SESSION=$(ls -1t logs/ | grep "^session_" | head -1)
        if [ ! -z "$LATEST_SESSION" ]; then
            LOG_DIR="logs/$LATEST_SESSION"
            echo "� 使用最新的日志会话: $LOG_DIR"
            return 0
        fi
    fi
    
    # 检查当前目录的日志文件
    if [ -f "backend.log" ] || [ -f "frontend.log" ]; then
        LOG_DIR="."
        echo "📁 使用当前目录的日志文件"
        return 0
    fi
    
    echo "❌ 未找到日志文件或目录"
    echo "请确保系统已启动或指定正确的日志目录路径"
    return 1
}

# 检查日志文件
check_log_files() {
    echo "📄 检查日志文件 (目录: $LOG_DIR)..."
    
    BACKEND_LOG="$LOG_DIR/backend.log"
    FRONTEND_LOG="$LOG_DIR/frontend.log"
    SYSTEM_LOG="$LOG_DIR/system.log"
    
    if [ ! -f "$BACKEND_LOG" ]; then
        echo "❌ backend.log 不存在"
        BACKEND_EXISTS=false
    else
        backend_size=$(du -h "$BACKEND_LOG" | cut -f1)
        backend_lines=$(wc -l < "$BACKEND_LOG")
        echo "✅ backend.log: $backend_size ($backend_lines 行)"
        BACKEND_EXISTS=true
    fi
    
    if [ ! -f "$FRONTEND_LOG" ]; then
        echo "❌ frontend.log 不存在"
        FRONTEND_EXISTS=false
    else
        frontend_size=$(du -h "$FRONTEND_LOG" | cut -f1)
        frontend_lines=$(wc -l < "$FRONTEND_LOG")
        echo "✅ frontend.log: $frontend_size ($frontend_lines 行)"
        FRONTEND_EXISTS=true
    fi
    
    if [ ! -f "$SYSTEM_LOG" ]; then
        echo "❌ system.log 不存在"
        SYSTEM_EXISTS=false
    else
        system_size=$(du -h "$SYSTEM_LOG" | cut -f1)
        system_lines=$(wc -l < "$SYSTEM_LOG")
        echo "✅ system.log: $system_size ($system_lines 行)"
        SYSTEM_EXISTS=true
    fi
    echo ""
}

# 显示最近的错误
show_recent_errors() {
    echo "🚨 最近的错误信息:"
    echo "=================="
    
    if [ "$BACKEND_EXISTS" = true ]; then
        echo -e "${RED}后端错误:${NC}"
        grep -i "error\|exception\|failed\|traceback" "$BACKEND_LOG" | tail -5 | while read line; do
            echo "  $line"
        done
        echo ""
    fi
    
    if [ "$FRONTEND_EXISTS" = true ]; then
        echo -e "${RED}前端错误:${NC}"
        grep -i "error\|failed\|exception" "$FRONTEND_LOG" | tail -5 | while read line; do
            echo "  $line"
        done
        echo ""
    fi
    
    if [ "$SYSTEM_EXISTS" = true ]; then
        echo -e "${RED}系统错误:${NC}"
        grep -i "error\|failed\|exception" "$SYSTEM_LOG" | tail -5 | while read line; do
            echo "  $line"
        done
        echo ""
    fi
}

# 显示请求统计
show_request_stats() {
    echo "📊 请求统计:"
    echo "============"
    
    if [ "$BACKEND_EXISTS" = true ]; then
        echo -e "${BLUE}后端统计:${NC}"
        
        # 总请求数
        total_requests=$(grep -c "收到生成请求\|收到API请求" "$BACKEND_LOG" 2>/dev/null || echo "0")
        echo "  总请求数: $total_requests"
        
        # 成功请求数
        success_requests=$(grep -c "生成完成\|生成成功" "$BACKEND_LOG" 2>/dev/null || echo "0")
        echo "  成功请求: $success_requests"
        
        # 失败请求数
        failed_requests=$(grep -c "生成过程中发生错误\|API请求失败" "$BACKEND_LOG" 2>/dev/null || echo "0")
        echo "  失败请求: $failed_requests"
        
        # GPU内存使用
        if grep -q "GPU内存" "$BACKEND_LOG" 2>/dev/null; then
            latest_gpu=$(grep "GPU内存" "$BACKEND_LOG" | tail -1)
            echo "  GPU内存: $latest_gpu"
        fi
        echo ""
    fi
    
    if [ "$FRONTEND_EXISTS" = true ]; then
        echo -e "${BLUE}前端统计:${NC}"
        
        # API调用次数
        api_calls=$(grep -c "发送API请求\|开始发送消息" "$FRONTEND_LOG" 2>/dev/null || echo "0")
        echo "  API调用次数: $api_calls"
        
        # 用户交互次数
        user_interactions=$(grep -c "用户发送请求\|处理用户发送" "$FRONTEND_LOG" 2>/dev/null || echo "0")
        echo "  用户交互: $user_interactions"
        echo ""
    fi
    
    if [ "$SYSTEM_EXISTS" = true ]; then
        echo -e "${BLUE}系统统计:${NC}"
        
        # 启动信息
        start_time=$(grep "启动时间" "$SYSTEM_LOG" | head -1 | cut -d':' -f2- | xargs)
        if [ ! -z "$start_time" ]; then
            echo "  启动时间: $start_time"
        fi
        
        # 系统事件数
        system_events=$(wc -l < "$SYSTEM_LOG" 2>/dev/null || echo "0")
        echo "  系统事件: $system_events"
        echo ""
    fi
}

# 实时监控模式
real_time_monitor() {
    echo "🔄 实时监控模式 (按 Ctrl+C 退出)"
    echo "日志目录: $LOG_DIR"
    echo "================================"
    echo ""
    
    # 启动tail进程监控所有日志文件
    {
        if [ "$BACKEND_EXISTS" = true ]; then
            tail -f "$BACKEND_LOG" | sed 's/^/[BACKEND] /' &
            BACKEND_PID=$!
        fi
        
        if [ "$FRONTEND_EXISTS" = true ]; then
            tail -f "$FRONTEND_LOG" | sed 's/^/[FRONTEND] /' &
            FRONTEND_PID=$!
        fi
        
        if [ "$SYSTEM_EXISTS" = true ]; then
            tail -f "$SYSTEM_LOG" | sed 's/^/[SYSTEM] /' &
            SYSTEM_PID=$!
        fi
        
        wait
    } | while read line; do
        # 根据日志级别着色
        if echo "$line" | grep -qi "error\|exception\|failed"; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -qi "warn"; then
            echo -e "${YELLOW}$line${NC}"
        elif echo "$line" | grep -qi "info\|success"; then
            echo -e "${GREEN}$line${NC}"
        elif echo "$line" | grep -qi "debug"; then
            echo -e "${CYAN}$line${NC}"
        else
            echo "$line"
        fi
    done
    
    # 清理
    [ ! -z "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null
    [ ! -z "$FRONTEND_PID" ] && kill "$FRONTEND_PID" 2>/dev/null
    [ ! -z "$SYSTEM_PID" ] && kill "$SYSTEM_PID" 2>/dev/null
}

# 导出日志
export_logs() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    EXPORT_DIR="logs_export_$TIMESTAMP"
    
    echo "📦 导出日志到 $EXPORT_DIR"
    
    mkdir -p "$EXPORT_DIR"
    
    if [ "$BACKEND_EXISTS" = true ]; then
        cp "$BACKEND_LOG" "$EXPORT_DIR/"
        echo "  ✅ backend.log 已复制"
    fi
    
    if [ "$FRONTEND_EXISTS" = true ]; then
        cp "$FRONTEND_LOG" "$EXPORT_DIR/"
        echo "  ✅ frontend.log 已复制"
    fi
    
    if [ "$SYSTEM_EXISTS" = true ]; then
        cp "$SYSTEM_LOG" "$EXPORT_DIR/"
        echo "  ✅ system.log 已复制"
    fi
    
    # 创建摘要报告
    cat > "$EXPORT_DIR/summary.txt" << EOF
LLaDA 日志摘要报告
生成时间: $(date)
日志目录: $LOG_DIR
==================

$(show_request_stats)

最近错误:
$(show_recent_errors)
EOF
    
    echo "  ✅ summary.txt 已生成"
    echo "  📁 导出目录: $EXPORT_DIR"
}

# 主菜单
show_menu() {
    echo "请选择操作:"
    echo "1) 检查日志文件状态"
    echo "2) 显示最近错误"
    echo "3) 显示请求统计"
    echo "4) 实时监控"
    echo "5) 导出日志"
    echo "6) 清理日志"
    echo "7) 显示日志目录结构"
    echo "0) 退出"
    echo ""
    read -p "请输入选项 (0-7): " choice
    
    case $choice in
        1)
            check_log_files
            ;;
        2)
            show_recent_errors
            ;;
        3)
            show_request_stats
            ;;
        4)
            real_time_monitor
            ;;
        5)
            export_logs
            ;;
        6)
            echo "🗑️ 清理日志..."
            if [ "$LOG_DIR" != "." ]; then
                > "$BACKEND_LOG" 2>/dev/null && echo "  ✅ backend.log 已清理"
                > "$FRONTEND_LOG" 2>/dev/null && echo "  ✅ frontend.log 已清理"
                > "$SYSTEM_LOG" 2>/dev/null && echo "  ✅ system.log 已清理"
            else
                > backend.log 2>/dev/null && echo "  ✅ backend.log 已清理"
                > frontend.log 2>/dev/null && echo "  ✅ frontend.log 已清理"
            fi
            ;;
        7)
            echo "📂 显示日志目录结构..."
            if [ -d "logs" ]; then
                echo "日志目录结构:"
                ls -la logs/ | head -20
                echo ""
                echo "总会话数: $(ls -1 logs/ | grep '^session_' | wc -l)"
            else
                echo "  ❌ logs目录不存在"
            fi
            ;;
        0)
            echo "👋 再见!"
            exit 0
            ;;
        *)
            echo "❌ 无效选项"
            ;;
    esac
    
    echo ""
    echo "按回车键继续..."
    read
    echo ""
}

# 主循环
main() {
    # 检测日志目录
    if ! detect_log_directory "$1"; then
        exit 1
    fi
    
    # 如果有参数，直接执行对应功能
    if [ "$2" = "monitor" ] || [ "$1" = "monitor" ]; then
        check_log_files
        real_time_monitor
        exit 0
    elif [ "$2" = "export" ] || [ "$1" = "export" ]; then
        check_log_files
        export_logs
        exit 0
    elif [ "$2" = "stats" ] || [ "$1" = "stats" ]; then
        check_log_files
        show_request_stats
        exit 0
    fi
    
    # 交互模式
    check_log_files
    
    while true; do
        show_menu
    done
}

# 信号处理
trap 'echo ""; echo "🛑 监控已停止"; exit 0' INT TERM

# 执行主函数
main "$@"
