#!/bin/bash

# LLaDA 日志系统设置脚本
# 用于创建按启动时间命名的日志目录结构

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 进入项目根目录
cd "$PROJECT_ROOT"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数 - 增强版，同时输出到控制台和系统日志
log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]    ${NC} $message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $message" >> "$SYSTEM_LOG"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS] ${NC} $message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS - $message" >> "$SYSTEM_LOG"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING] ${NC} $message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING - $message" >> "$SYSTEM_LOG"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]   ${NC} $message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $message" >> "$SYSTEM_LOG"
}

# 创建日志目录结构
setup_logging_structure() {
    local timestamp="${1:-$(date +%Y%m%d_%H%M%S)}"
    local log_session_dir="logs/session_$timestamp"
    
    log_info "设置日志目录结构..."
    
    # 创建主日志目录
    if [ ! -d "logs" ]; then
        mkdir -p "logs"
        log_success "创建主日志目录: logs/"
    fi
    
    # 创建当前会话目录
    mkdir -p "$log_session_dir"
    log_success "创建会话目录: $log_session_dir"
    
    # 设置日志文件路径
    local backend_log="$log_session_dir/backend.log"
    local frontend_log="$log_session_dir/frontend.log"
    local system_log="$log_session_dir/system.log"
    
    # 备份现有日志文件
    if [ -f "backend.log" ] && [ ! -L "backend.log" ]; then
        local backup_name="backend.log.$(date +%Y%m%d_%H%M%S).bak"
        mv "backend.log" "$backup_name"
        log_warning "备份现有后端日志为: $backup_name"
    fi
    
    if [ -f "frontend.log" ] && [ ! -L "frontend.log" ]; then
        local backup_name="frontend.log.$(date +%Y%m%d_%H%M%S).bak"
        mv "frontend.log" "$backup_name"
        log_warning "备份现有前端日志为: $backup_name"
    fi
    
    # 删除现有软链接
    [ -L "backend.log" ] && rm -f "backend.log"
    [ -L "frontend.log" ] && rm -f "frontend.log"
    [ -L "system.log" ] && rm -f "system.log"
    
    # 创建新的软链接
    ln -sf "$log_session_dir/backend.log" "backend.log"
    ln -sf "$log_session_dir/frontend.log" "frontend.log"
    ln -sf "$log_session_dir/system.log" "system.log"
    
    log_success "创建软链接:"
    log_success "  backend.log -> $backend_log"
    log_success "  frontend.log -> $frontend_log"
    log_success "  system.log -> $system_log"
    
    # 创建日志文件并写入头部信息
    {
        echo "=== LLaDA 后端服务日志 ==="
        echo "启动时间: $(date)"
        echo "日志会话: $timestamp"
        echo "Python版本: $(python3 --version 2>&1)"
        echo "工作目录: $(pwd)"
        echo "设备检测: $(python3 -c 'import torch; print(f"CUDA可用: {torch.cuda.is_available()}")' 2>/dev/null || echo '未知')"
        echo "=========================="
        echo
    } > "$backend_log"
    
    {
        echo "=== LLaDA 前端服务日志 ==="
        echo "启动时间: $(date)"
        echo "日志会话: $timestamp"
        echo "Node版本: $(node --version 2>/dev/null || echo '未安装')"
        echo "NPM版本: $(npm --version 2>/dev/null || echo '未安装')"
        echo "工作目录: $(pwd)"
        echo "=========================="
        echo
    } > "$frontend_log"
    
    {
        echo "=== LLaDA 系统日志 ==="
        echo "启动时间: $(date)"
        echo "日志会话: $timestamp"
        echo "系统信息: $(uname -a)"
        echo "内存信息: $(free -h | head -2)"
        echo "磁盘信息: $(df -h . | tail -1)"
        echo "===================="
        echo
    } > "$system_log"
    
    # 导出环境变量，供其他脚本使用
    export LOG_SESSION_DIR="$log_session_dir"
    export LOG_TIMESTAMP="$timestamp"
    export BACKEND_LOG="$backend_log"
    export FRONTEND_LOG="$frontend_log"
    export SYSTEM_LOG="$system_log"
    
    log_success "日志系统设置完成！"
    log_info "会话目录: $log_session_dir"
    
    return 0
}

# 显示日志目录结构
show_log_structure() {
    log_info "当前日志目录结构:"
    
    if [ -d "logs" ]; then
        echo "logs/"
        for session_dir in logs/session_*; do
            if [ -d "$session_dir" ]; then
                echo "├── $(basename "$session_dir")/"
                for log_file in "$session_dir"/*.log; do
                    if [ -f "$log_file" ]; then
                        local size=$(du -h "$log_file" 2>/dev/null | cut -f1)
                        local lines=$(wc -l < "$log_file" 2>/dev/null)
                        echo "│   ├── $(basename "$log_file") ($size, $lines 行)"
                    fi
                done
            fi
        done
        echo
        
        # 显示软链接状态
        echo "软链接状态:"
        for link in backend.log frontend.log system.log; do
            if [ -L "$link" ]; then
                local target=$(readlink "$link")
                echo "├── $link -> $target"
            elif [ -f "$link" ]; then
                echo "├── $link (普通文件, 非软链接)"
            else
                echo "├── $link (不存在)"
            fi
        done
    else
        log_warning "logs目录不存在"
    fi
}

# 清理旧日志
cleanup_old_logs() {
    local keep_days="${1:-7}"
    
    log_info "清理 $keep_days 天前的日志文件..."
    
    if [ ! -d "logs" ]; then
        log_warning "logs目录不存在，无需清理"
        return 0
    fi
    
    local cleaned_count=0
    
    find logs/ -name "session_*" -type d -mtime +$keep_days | while read -r old_session; do
        if [ -d "$old_session" ]; then
            local session_name=$(basename "$old_session")
            log_info "删除过期会话: $session_name"
            rm -rf "$old_session"
            cleaned_count=$((cleaned_count + 1))
        fi
    done
    
    if [ $cleaned_count -eq 0 ]; then
        log_success "没有需要清理的旧日志"
    else
        log_success "清理了 $cleaned_count 个过期会话"
    fi
}

# 导出日志
export_logs() {
    local export_dir="${1:-logs_export_$(date +%Y%m%d_%H%M%S)}"
    
    log_info "导出日志到: $export_dir"
    
    if [ ! -d "logs" ]; then
        log_error "logs目录不存在，无法导出"
        return 1
    fi
    
    mkdir -p "$export_dir"
    
    # 复制所有日志会话
    cp -r logs/* "$export_dir/" 2>/dev/null || true
    
    # 创建总结文件
    {
        echo "=== LLaDA 日志导出报告 ==="
        echo "导出时间: $(date)"
        echo "导出目录: $export_dir"
        echo "=========================="
        echo
        
        echo "会话列表:"
        for session in logs/session_*; do
            if [ -d "$session" ]; then
                local session_name=$(basename "$session")
                local file_count=$(find "$session" -name "*.log" | wc -l)
                local total_size=$(du -sh "$session" 2>/dev/null | cut -f1)
                echo "- $session_name: $file_count 个日志文件, 总大小 $total_size"
            fi
        done
        
        echo
        echo "文件统计:"
        find "$export_dir" -name "*.log" -exec wc -l {} + | tail -1
        
    } > "$export_dir/export_summary.txt"
    
    log_success "日志导出完成: $export_dir"
    log_info "导出报告: $export_dir/export_summary.txt"
}

# 主函数
main() {
    local action="${1:-setup}"
    
    case "$action" in
        "setup")
            setup_logging_structure "$2"
            ;;
        "show"|"list")
            show_log_structure
            ;;
        "cleanup")
            cleanup_old_logs "$2"
            ;;
        "export")
            export_logs "$2"
            ;;
        "help"|"--help"|"-h")
            echo "LLaDA 日志系统管理工具"
            echo
            echo "用法: $0 [命令] [参数]"
            echo
            echo "命令:"
            echo "  setup [时间戳]     - 设置日志目录结构 (默认使用当前时间)"
            echo "  show|list          - 显示日志目录结构"
            echo "  cleanup [天数]     - 清理指定天数前的日志 (默认7天)"
            echo "  export [目录]      - 导出所有日志到指定目录"
            echo "  help               - 显示此帮助信息"
            echo
            echo "示例:"
            echo "  $0 setup                    # 创建新的日志会话"
            echo "  $0 setup 20250713_120000    # 使用指定时间戳创建会话"
            echo "  $0 show                     # 显示当前日志结构"
            echo "  $0 cleanup 3                # 清理3天前的日志"
            echo "  $0 export backup_logs       # 导出日志到backup_logs目录"
            ;;
        *)
            log_error "未知命令: $action"
            log_info "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
