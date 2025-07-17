#!/bin/bash

# LLaDA 日志监控和管理工具 v3.0
# 支持多会话日志目录结构，自动检测最新日志会话

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
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 获取最新的日志会话目录
get_latest_log_session() {
    if [ ! -d "logs" ]; then
        echo ""
        return 1
    fi
    
    local latest_session=$(ls -1t logs/session_* 2>/dev/null | head -1)
    if [ -n "$latest_session" ] && [ -d "$latest_session" ]; then
        echo "$latest_session"
        return 0
    else
        echo ""
        return 1
    fi
}

# 获取所有日志会话目录（按时间倒序）
get_all_log_sessions() {
    if [ ! -d "logs" ]; then
        return 1
    fi
    
    find logs -maxdepth 1 -name "session_*" -type d | sort -r | head -20  # 最多显示20个会话
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示日志会话选择菜单
select_log_session() {
    echo -e "${WHITE}=== 日志会话选择 ===${NC}"
    echo
    
    local sessions=($(get_all_log_sessions))
    if [ ${#sessions[@]} -eq 0 ]; then
        log_error "没有找到任何日志会话"
        return 1
    fi
    
    echo "可用的日志会话："
    for i in "${!sessions[@]}"; do
        local session="${sessions[$i]}"
        local session_name=$(basename "$session")
        local session_time=$(echo "$session_name" | sed 's/session_//' | sed 's/_/ /')
        local file_count=$(find "$session" -name "*.log" -type f | wc -l)
        local total_size=$(du -sh "$session" 2>/dev/null | cut -f1)
        
        if [ $i -eq 0 ]; then
            echo -e "${GREEN}[$((i+1))] $session_name${NC} (最新) - $file_count 文件, $total_size"
        else
            echo -e "[$((i+1))] $session_name - $file_count 文件, $total_size"
        fi
    done
    
    echo
    echo "选择会话 (1-${#sessions[@]}) 或按 Enter 使用最新会话: "
    read -r choice
    
    if [ -z "$choice" ]; then
        choice=1
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#sessions[@]} ]; then
        echo "${sessions[$((choice-1))]}"
        return 0
    else
        log_error "无效选择"
        return 1
    fi
}

# 实时监控日志
monitor_logs() {
    local session_dir="$1"
    local filter="$2"
    
    if [ -z "$session_dir" ]; then
        session_dir=$(get_latest_log_session)
        if [ -z "$session_dir" ]; then
            log_error "没有找到日志会话目录"
            return 1
        fi
    fi
    
    if [ ! -d "$session_dir" ]; then
        log_error "日志会话目录不存在: $session_dir"
        return 1
    fi
    
    local session_name=$(basename "$session_dir")
    log_info "监控日志会话: $session_name"
    
    local log_files=()
    for log_type in backend frontend system; do
        local log_file="$session_dir/${log_type}.log"
        if [ -f "$log_file" ]; then
            log_files+=("$log_file")
        fi
    done
    
    if [ ${#log_files[@]} -eq 0 ]; then
        log_error "在 $session_dir 中没有找到日志文件"
        return 1
    fi
    
    echo -e "${WHITE}=== 实时日志监控 ===${NC}"
    echo -e "${CYAN}会话:${NC} $session_name"
    echo -e "${CYAN}文件:${NC} ${log_files[*]}"
    if [ -n "$filter" ]; then
        echo -e "${CYAN}过滤:${NC} $filter"
    fi
    echo -e "${YELLOW}按 Ctrl+C 停止监控${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -n "$filter" ]; then
        tail -f "${log_files[@]}" | grep --color=always -i "$filter"
    else
        tail -f "${log_files[@]}"
    fi
}

# 搜索日志内容
search_logs() {
    local session_dir="$1"
    local search_pattern="$2"
    local context_lines="${3:-3}"
    
    if [ -z "$session_dir" ]; then
        session_dir=$(get_latest_log_session)
        if [ -z "$session_dir" ]; then
            log_error "没有找到日志会话目录"
            return 1
        fi
    fi
    
    if [ -z "$search_pattern" ]; then
        echo "请输入搜索关键词: "
        read -r search_pattern
        if [ -z "$search_pattern" ]; then
            log_error "搜索关键词不能为空"
            return 1
        fi
    fi
    
    local session_name=$(basename "$session_dir")
    log_info "在日志会话 $session_name 中搜索: $search_pattern"
    
    local found=false
    for log_type in backend frontend system; do
        local log_file="$session_dir/${log_type}.log"
        if [ -f "$log_file" ]; then
            echo -e "\n${WHITE}=== $log_type.log ===${NC}"
            if grep -n -C"$context_lines" --color=always -i "$search_pattern" "$log_file"; then
                found=true
            else
                echo -e "${YELLOW}无匹配结果${NC}"
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        log_warning "在任何日志文件中都没有找到匹配的内容"
    fi
}

# 显示日志统计信息
show_log_stats() {
    local session_dir="$1"
    
    if [ -z "$session_dir" ]; then
        # 显示所有会话的统计
        echo -e "${WHITE}=== 所有日志会话统计 ===${NC}"
        echo
        
        local sessions=($(get_all_log_sessions))
        if [ ${#sessions[@]} -eq 0 ]; then
            log_error "没有找到任何日志会话"
            return 1
        fi
        
        local total_size=0
        local total_files=0
        local total_lines=0
        
        printf "%-25s %-15s %-10s %-10s %-15s\n" "会话" "状态" "文件数" "总行数" "总大小"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        local sessions=($(get_all_log_sessions))
        for session in "${sessions[@]}"; do
            if [ -d "$session" ]; then
                local session_name=$(basename "$session")
                local file_count=$(find "$session" -name "*.log" -type f 2>/dev/null | wc -l)
                local session_size=$(du -sh "$session" 2>/dev/null | cut -f1)
                local session_lines=0
                
                # 计算总行数
                for log_file in "$session"/*.log; do
                    if [ -f "$log_file" ]; then
                        local lines=$(wc -l < "$log_file" 2>/dev/null || echo 0)
                        session_lines=$((session_lines + lines))
                    fi
                done
                
                total_files=$((total_files + file_count))
                total_lines=$((total_lines + session_lines))
                
                # 判断会话状态
                local status="历史"
                if [ "$session" = "$(get_latest_log_session)" ]; then
                    status="当前"
                    printf "${GREEN}%-25s %-15s %-10s %-10s %-15s${NC}\n" "$session_name" "$status" "$file_count" "$session_lines" "$session_size"
                else
                    printf "%-25s %-15s %-10s %-10s %-15s\n" "$session_name" "$status" "$file_count" "$session_lines" "$session_size"
                fi
            fi
        done
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "${WHITE}总计: %d 会话, %d 文件, %d 行${NC}\n" "${#sessions[@]}" "$total_files" "$total_lines"
        
    else
        # 显示特定会话的详细统计
        local session_name=$(basename "$session_dir")
        echo -e "${WHITE}=== 日志会话详细统计: $session_name ===${NC}"
        echo
        
        if [ ! -d "$session_dir" ]; then
            log_error "日志会话目录不存在: $session_dir"
            return 1
        fi
        
        # 会话基本信息
        local session_time=$(echo "$session_name" | sed 's/session_//' | sed 's/_\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)$/_\1:\2:\3/')
        local session_date=$(echo "$session_time" | cut -d'_' -f1)
        local session_time_only=$(echo "$session_time" | cut -d'_' -f2)
        
        echo -e "${CYAN}会话日期:${NC} $session_date"
        echo -e "${CYAN}启动时间:${NC} $session_time_only"
        echo -e "${CYAN}会话目录:${NC} $session_dir"
        echo
        
        # 文件统计
        printf "%-15s %-10s %-10s %-15s %-20s\n" "日志类型" "大小" "行数" "最后修改" "状态"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for log_type in backend frontend system; do
            local log_file="$session_dir/${log_type}.log"
            if [ -f "$log_file" ]; then
                local size=$(du -h "$log_file" 2>/dev/null | cut -f1)
                local lines=$(wc -l < "$log_file" 2>/dev/null)
                local mtime=$(stat -c '%Y' "$log_file" 2>/dev/null)
                local formatted_time=$(date -d "@$mtime" '+%H:%M:%S' 2>/dev/null || echo "未知")
                
                # 判断日志活跃状态
                local current_time=$(date +%s)
                local time_diff=$((current_time - mtime))
                local status="活跃"
                
                if [ $time_diff -gt 300 ]; then  # 5分钟
                    status="静默"
                elif [ $time_diff -gt 60 ]; then   # 1分钟
                    status="较静默"
                fi
                
                printf "%-15s %-10s %-10s %-15s %-20s\n" "$log_type" "$size" "$lines" "$formatted_time" "$status"
            else
                printf "%-15s %-10s %-10s %-15s %-20s\n" "$log_type" "不存在" "0" "-" "无"
            fi
        done
        
        echo
        
        # 错误和警告统计
        echo -e "${WHITE}错误和警告统计:${NC}"
        local total_errors=0
        local total_warnings=0
        
        for log_type in backend frontend system; do
            local log_file="$session_dir/${log_type}.log"
            if [ -f "$log_file" ]; then
                local errors=$(grep -c -i "error\|错误\|exception\|failed" "$log_file" 2>/dev/null || echo 0)
                local warnings=$(grep -c -i "warning\|warn\|警告" "$log_file" 2>/dev/null || echo 0)
                
                total_errors=$((total_errors + errors))
                total_warnings=$((total_warnings + warnings))
                
                if [ $errors -gt 0 ] || [ $warnings -gt 0 ]; then
                    printf "  %-10s: ${RED}%d 错误${NC}, ${YELLOW}%d 警告${NC}\n" "$log_type" "$errors" "$warnings"
                fi
            fi
        done
        
        if [ $total_errors -eq 0 ] && [ $total_warnings -eq 0 ]; then
            echo -e "  ${GREEN}无错误或警告${NC}"
        else
            echo -e "  ${WHITE}总计: ${RED}$total_errors 错误${NC}, ${YELLOW}$total_warnings 警告${NC}"
        fi
    fi
}

# 清理旧日志
cleanup_old_logs() {
    local keep_days="${1:-7}"
    local force="${2:-false}"
    
    log_info "查找 $keep_days 天前的日志会话..."
    
    if [ ! -d "logs" ]; then
        log_error "logs目录不存在"
        return 1
    fi
    
    local old_sessions=()
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - keep_days * 24 * 3600))
    
    for session in logs/session_*; do
        if [ -d "$session" ]; then
            local session_mtime=$(stat -c '%Y' "$session" 2>/dev/null)
            if [ -n "$session_mtime" ] && [ $session_mtime -lt $cutoff_time ]; then
                old_sessions+=("$session")
            fi
        fi
    done
    
    if [ ${#old_sessions[@]} -eq 0 ]; then
        log_success "没有需要清理的旧日志会话"
        return 0
    fi
    
    echo -e "${WHITE}找到 ${#old_sessions[@]} 个过期会话:${NC}"
    for session in "${old_sessions[@]}"; do
        local session_name=$(basename "$session")
        local size=$(du -sh "$session" 2>/dev/null | cut -f1)
        echo "  - $session_name ($size)"
    done
    
    if [ "$force" != "true" ]; then
        echo
        echo "确认删除这些会话? (y/N): "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "取消清理操作"
            return 0
        fi
    fi
    
    local cleaned_count=0
    for session in "${old_sessions[@]}"; do
        local session_name=$(basename "$session")
        log_info "删除会话: $session_name"
        if rm -rf "$session"; then
            cleaned_count=$((cleaned_count + 1))
        else
            log_error "删除失败: $session_name"
        fi
    done
    
    log_success "成功清理了 $cleaned_count 个过期会话"
}

# 导出日志
export_logs() {
    local session_dir="$1"
    local export_dir="$2"
    local export_format="${3:-tar}"  # tar, zip, copy
    
    if [ -z "$session_dir" ]; then
        log_info "选择要导出的日志会话:"
        session_dir=$(select_log_session)
        if [ -z "$session_dir" ]; then
            return 1
        fi
    fi
    
    if [ ! -d "$session_dir" ]; then
        log_error "日志会话目录不存在: $session_dir"
        return 1
    fi
    
    local session_name=$(basename "$session_dir")
    if [ -z "$export_dir" ]; then
        export_dir="logs_export_${session_name}_$(date +%Y%m%d_%H%M%S)"
    fi
    
    log_info "导出日志会话: $session_name"
    log_info "导出格式: $export_format"
    log_info "导出目标: $export_dir"
    
    case "$export_format" in
        "tar")
            if tar -czf "${export_dir}.tar.gz" -C "$(dirname "$session_dir")" "$(basename "$session_dir")"; then
                log_success "日志已导出到: ${export_dir}.tar.gz"
                log_info "解压命令: tar -xzf ${export_dir}.tar.gz"
            else
                log_error "导出失败"
                return 1
            fi
            ;;
        "zip")
            if command -v zip >/dev/null 2>&1; then
                if (cd "$(dirname "$session_dir")" && zip -r "${PWD}/${export_dir}.zip" "$(basename "$session_dir")"); then
                    log_success "日志已导出到: ${export_dir}.zip"
                    log_info "解压命令: unzip ${export_dir}.zip"
                else
                    log_error "导出失败"
                    return 1
                fi
            else
                log_error "zip命令不可用，请使用 tar 格式"
                return 1
            fi
            ;;
        "copy")
            if cp -r "$session_dir" "$export_dir"; then
                log_success "日志已复制到: $export_dir"
            else
                log_error "复制失败"
                return 1
            fi
            ;;
        *)
            log_error "不支持的导出格式: $export_format"
            log_info "支持的格式: tar, zip, copy"
            return 1
            ;;
    esac
    
    # 创建导出报告
    {
        echo "=== LLaDA 日志导出报告 ==="
        echo "导出时间: $(date)"
        echo "源会话: $session_name"
        echo "导出格式: $export_format"
        echo "导出目标: $export_dir"
        echo "=========================="
        echo
        
        echo "会话详情:"
        show_log_stats "$session_dir"
        
    } > "${export_dir}_report.txt"
    
    log_info "导出报告: ${export_dir}_report.txt"
}

# 显示帮助信息
show_help() {
    echo -e "${WHITE}LLaDA 日志监控和管理工具 v3.0${NC}"
    echo
    echo -e "${CYAN}用法:${NC} $0 [命令] [参数...]"
    echo
    echo -e "${WHITE}命令:${NC}"
    echo -e "  ${GREEN}monitor${NC} [会话] [过滤器]    - 实时监控日志"
    echo -e "  ${GREEN}search${NC} [会话] [关键词] [上下文行数] - 搜索日志内容"
    echo -e "  ${GREEN}stats${NC} [会话]              - 显示日志统计信息"
    echo -e "  ${GREEN}list${NC}                     - 列出所有日志会话"
    echo -e "  ${GREEN}cleanup${NC} [天数] [强制]     - 清理指定天数前的日志 (默认7天)"
    echo -e "  ${GREEN}export${NC} [会话] [目录] [格式] - 导出日志会话"
    echo -e "  ${GREEN}select${NC}                   - 交互式选择日志会话"
    echo -e "  ${GREEN}help${NC}                     - 显示此帮助信息"
    echo
    echo -e "${WHITE}参数说明:${NC}"
    echo -e "  ${YELLOW}会话${NC}    - 日志会话目录路径，如 logs/session_20250713_120000"
    echo -e "           如果不指定，将使用最新的会话"
    echo -e "  ${YELLOW}过滤器${NC}  - 用于过滤日志内容的关键词（支持正则表达式）"
    echo -e "  ${YELLOW}关键词${NC}  - 搜索的关键词或正则表达式"
    echo -e "  ${YELLOW}天数${NC}    - 保留最近几天的日志，删除更早的日志"
    echo -e "  ${YELLOW}格式${NC}    - 导出格式：tar（默认）、zip、copy"
    echo
    echo -e "${WHITE}示例:${NC}"
    echo -e "  ${CYAN}# 监控最新日志会话${NC}"
    echo "  $0 monitor"
    echo
    echo -e "  ${CYAN}# 监控特定会话并过滤错误${NC}"
    echo "  $0 monitor logs/session_20250713_120000 error"
    echo
    echo -e "  ${CYAN}# 搜索最新会话中的特定内容${NC}"
    echo "  $0 search \"GPU memory\""
    echo
    echo -e "  ${CYAN}# 显示所有会话统计${NC}"
    echo "  $0 stats"
    echo
    echo -e "  ${CYAN}# 清理7天前的日志${NC}"
    echo "  $0 cleanup 7"
    echo
    echo -e "  ${CYAN}# 导出特定会话为tar格式${NC}"
    echo "  $0 export logs/session_20250713_120000 backup_logs tar"
    echo
    echo -e "${WHITE}快捷操作:${NC}"
    echo -e "  ${PURPLE}# 查看当前会话实时日志${NC}"
    echo "  tail -f backend.log frontend.log system.log"
    echo
    echo -e "  ${PURPLE}# 查看所有会话目录${NC}"
    echo "  ls -la logs/"
    echo
    echo -e "  ${PURPLE}# 查看最新错误${NC}"
    echo "  grep -i error logs/*/\*.log | tail -10"
    echo
}

# 主函数
main() {
    local command="${1:-monitor}"
    
    case "$command" in
        "monitor"|"tail"|"watch")
            monitor_logs "$2" "$3"
            ;;
        "search"|"grep"|"find")
            search_logs "$2" "$3" "$4"
            ;;
        "stats"|"stat"|"status")
            show_log_stats "$2"
            ;;
        "list"|"ls")
            if [ -d "logs" ]; then
                echo -e "${WHITE}=== 所有日志会话 ===${NC}"
                for session in logs/session_*; do
                    if [ -d "$session" ]; then
                        local session_name=$(basename "$session")
                        local file_count=$(find "$session" -name "*.log" -type f 2>/dev/null | wc -l)
                        local total_size=$(du -sh "$session" 2>/dev/null | cut -f1)
                        
                        # 检查是否是最新会话
                        local latest_session=$(get_latest_log_session)
                        if [ "$session" = "$latest_session" ]; then
                            echo -e "${GREEN}$session_name${NC} (最新) - $file_count 文件, $total_size"
                        else
                            echo "$session_name - $file_count 文件, $total_size"
                        fi
                    fi
                done
            else
                log_error "logs目录不存在"
            fi
            ;;
        "cleanup"|"clean")
            cleanup_old_logs "$2" "$3"
            ;;
        "export"|"backup")
            export_logs "$2" "$3" "$4"
            ;;
        "select")
            local selected_session=$(select_log_session)
            if [ -n "$selected_session" ]; then
                log_success "已选择会话: $(basename "$selected_session")"
                show_log_stats "$selected_session"
            fi
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
