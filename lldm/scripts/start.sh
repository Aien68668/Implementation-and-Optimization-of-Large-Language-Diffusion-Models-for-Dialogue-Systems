#!/bin/bash

# LLaDA 模型对话系统启动脚本 v2.0

echo "🚀 正在启动LLaDA扩散语言模型可视化系统..."
echo "================================================"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 初始化清理标志
CLEANUP_DONE=false

# 进入项目根目录
cd "$PROJECT_ROOT"

# 设置日志系统
log_info "初始化日志系统..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 调用日志设置脚本
if [ -f "scripts/setup_logging.sh" ]; then
    source scripts/setup_logging.sh
    setup_logging_structure "$TIMESTAMP"
else
    # 后备方案：直接创建日志目录结构
    LOG_SESSION_DIR="logs/session_$TIMESTAMP"
    mkdir -p "$LOG_SESSION_DIR"
    
    # 设置日志文件路径
    BACKEND_LOG="$LOG_SESSION_DIR/backend.log"
    FRONTEND_LOG="$LOG_SESSION_DIR/frontend.log"
    SYSTEM_LOG="$LOG_SESSION_DIR/system.log"
    
    # 创建软链接指向最新日志（为了兼容性）
    ln -sf "$LOG_SESSION_DIR/backend.log" "backend.log"
    ln -sf "$LOG_SESSION_DIR/frontend.log" "frontend.log"
    ln -sf "$LOG_SESSION_DIR/system.log" "system.log"
fi

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

# 错误处理函数
handle_error() {
    log_error "启动过程中出现错误，正在退出..."
    cleanup
    exit 1
}

# 设置错误处理
trap handle_error ERR

# 检查Python环境
check_python() {
    log_info "检查Python环境..."
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 未安装"
        exit 1
    fi
    
    python_version=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    log_success "Python版本: $python_version"
}

# 检查Node.js环境
check_nodejs() {
    log_info "检查Node.js环境..."
    if ! command -v npm &> /dev/null; then
        log_error "Node.js/npm 未安装"
        exit 1
    fi
    
    node_version=$(node --version)
    npm_version=$(npm --version)
    log_success "Node.js版本: $node_version, npm版本: $npm_version"
}

# 检查模型文件
check_model() {
    log_info "检查模型文件..."
    if [ ! -d "/root/autodl-tmp/model" ]; then
        log_error "模型路径 /root/autodl-tmp/model 不存在"
        log_error "请确保LLaDA模型已下载到正确位置"
        exit 1
    fi
    
    model_files=$(ls -la /root/autodl-tmp/model/ 2>/dev/null | wc -l)
    log_success "模型目录存在，包含 $((model_files-3)) 个文件"
}

# 安装Python依赖
install_python_deps() {
    log_info "检查Python依赖..."
    
    # 检查必要的包
    missing_packages=()
    required_packages=("flask" "torch" "transformers" "flask_cors" "psutil")
    
    for package in "${required_packages[@]}"; do
        if ! python3 -c "import $package" 2>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        log_warning "缺少Python包: ${missing_packages[*]}"
        log_info "正在安装Python依赖..."
        pip3 install flask flask-cors torch transformers psutil requests
        log_success "Python依赖安装完成"
    else
        log_success "Python依赖已满足"
    fi
}

# 安装Node.js依赖
install_nodejs_deps() {
    log_info "检查Node.js依赖..."
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        log_info "正在安装Node.js依赖..."
        npm install
        log_success "Node.js依赖安装完成"
    else
        log_success "Node.js依赖已存在"
    fi
}

# 启动后端服务
start_backend() {
    log_info "启动后端服务..."
    
    # 检查端口是否被占用
    if lsof -Pi :9000 -sTCP:LISTEN -t >/dev/null; then
        log_warning "端口9000已被占用，尝试停止现有进程..."
        pkill -f "python.*server.py" || true
        sleep 2
    fi
    
    # 启动新的后端服务，设置详细日志
    log_info "启动后端服务，日志保存到: $BACKEND_LOG"
    BACKEND_LOG_FILE="$BACKEND_LOG" PYTHONUNBUFFERED=1 nohup python3 -u server.py > /dev/null 2>&1 &
    BACKEND_PID=$!
    
    log_info "后端服务 PID: $BACKEND_PID (日志会话: $TIMESTAMP)"
    
    # 等待服务启动
    log_info "等待后端服务启动..."
    for i in {1..30}; do
        if curl -s http://localhost:9000/health >/dev/null 2>&1; then
            echo ""
            log_success "后端服务启动成功 (PID: $BACKEND_PID)"
            log_info "后端日志路径: $BACKEND_LOG"
            return 0
        fi
        sleep 1
        echo -n "."
    done
    echo
    
    log_error "后端服务启动失败或超时"
    log_error "检查后端日志: tail -20 '$BACKEND_LOG'"
    return 1
}

# 启动前端服务
start_frontend() {
    log_info "启动前端服务..."
    
    # 检查端口是否被占用
    if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null; then
        log_warning "端口3000已被占用，尝试停止现有进程..."
        pkill -f "node.*react-scripts" || true
        sleep 2
    fi
    
    # 设置环境变量以获得更详细的日志
    export BROWSER=none
    export CI=true
    export REACT_APP_LOG_LEVEL=debug
    export GENERATE_SOURCEMAP=false
    
    # 创建前端日志文件头部信息
    {
        echo "=== LLaDA 前端服务日志 ==="
        echo "启动时间: $(date)"
        echo "日志会话: $TIMESTAMP"
        echo "Node版本: $(node --version 2>/dev/null || echo '未安装')"
        echo "NPM版本: $(npm --version 2>/dev/null || echo '未安装')"
        echo "工作目录: $(pwd)"
        echo "环境变量:"
        echo "  BROWSER=$BROWSER"
        echo "  CI=$CI"
        echo "  REACT_APP_LOG_LEVEL=$REACT_APP_LOG_LEVEL"
        echo "=========================="
        echo
    } > "$FRONTEND_LOG"
    
    # 启动前端服务，使用详细日志
    log_info "启动前端服务，日志保存到: $FRONTEND_LOG"
    nohup npm start >> "$FRONTEND_LOG" 2>&1 &
    FRONTEND_PID=$!
    
    log_info "前端服务 PID: $FRONTEND_PID (日志会话: $TIMESTAMP)"
    
    # 等待服务启动
    log_info "等待前端服务启动..."
    for i in {1..60}; do
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            echo ""
            log_success "前端服务启动成功 (PID: $FRONTEND_PID)"
            log_info "前端访问地址: http://localhost:3000"
            log_info "前端日志路径: $FRONTEND_LOG"
            return 0
        fi
        sleep 1
        # 每10秒检查一次日志是否有错误
        if [ $((i % 10)) -eq 0 ]; then
            if grep -i "error\|failed\|cannot" "$FRONTEND_LOG" >/dev/null 2>&1; then
                log_warning "前端日志中检测到可能的错误，请检查 $FRONTEND_LOG"
            fi
        fi
        echo -n "."
    done
    echo
    
    log_error "前端服务启动失败或超时"
    log_error "检查前端日志: tail -20 '$FRONTEND_LOG'"
    return 1
}

# 清理函数
cleanup() {
    # 避免重复清理
    if [ "$CLEANUP_DONE" = "true" ]; then
        return 0
    fi
    CLEANUP_DONE=true
    echo ""
    
    log_info "正在停止服务..."
    
    # 停止后端服务
    if [ ! -z "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        kill "$BACKEND_PID" 2>/dev/null || true
        # 等待进程结束
        for i in {1..5}; do
            if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        log_success "后端服务已停止"
    fi
    
    # 停止前端服务
    if [ ! -z "$FRONTEND_PID" ]; then
        if kill -0 "$FRONTEND_PID" 2>/dev/null; then
            kill "$FRONTEND_PID" 2>/dev/null || true
            # 等待进程结束
            for i in {1..5}; do
                if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            log_success "前端服务已停止"
        else
            log_success "前端服务已停止"
        fi
    else
        log_info "前端服务PID为空"
    fi
    
    # 清理可能残留的进程（静默执行）
    pkill -f "python.*server.py" 2>/dev/null || true
    pkill -f "node.*react-scripts" 2>/dev/null || true
    
    log_success "所有服务已停止！"
}

# 注册清理函数 - 只处理用户中断，避免EXIT重复清理
trap cleanup INT TERM

# 运行测试
run_tests() {
    log_info "运行基本测试..."
    
    # 测试后端API
    if command -v python3 &> /dev/null && [ -f "scripts/test_api_simple.py" ]; then
        log_info "测试后端API..."
        if python3 scripts/test_api_simple.py; then
            log_success "后端API测试通过"
        else
            log_warning "后端API测试失败，但继续启动"
        fi
    fi
    
    # 测试前端组件
    if [ -f "tests/frontend/test_components.sh" ]; then
        log_info "测试前端组件..."
        chmod +x tests/frontend/test_components.sh
        if bash tests/frontend/test_components.sh; then
            log_success "前端组件测试通过"
        else
            log_warning "前端组件测试失败，但继续启动"
        fi
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "🎉 LLaDA系统启动完成！"
    echo "========================"
    echo ""
    log_success "前端界面: http://localhost:3000"
    log_success "后端API:  http://localhost:9000"
    log_success "健康检查: http://localhost:9000/health"
    echo ""
    echo "📋 系统信息:"
    echo "   - 日志会话ID: $TIMESTAMP"
    echo "   - 后端PID: $BACKEND_PID"
    echo "   - 前端PID: $FRONTEND_PID"
    echo "   - 日志目录: $LOG_SESSION_DIR"
    echo ""
    echo "� 详细日志监控:"
    echo "   - 后端日志: tail -f '$BACKEND_LOG'"
    echo "   - 前端日志: tail -f '$FRONTEND_LOG'"
    echo "   - 系统日志: tail -f '$SYSTEM_LOG'"
    echo "   - 同时监控: tail -f '$LOG_SESSION_DIR'/*.log"
    echo "   - 错误过滤: grep -i error '$LOG_SESSION_DIR'/*.log"
    echo ""
    echo "💡 日志内容说明:"
    echo "   - 后端: 请求参数、消息内容、GPU内存、错误堆栈"
    echo "   - 前端: API调用、用户交互、状态变化、性能指标"
    echo "   - 所有日志包含时间戳和请求ID用于追踪"
    echo ""
    echo "�🛠️ 管理命令:"
    echo "   - 停止系统: Ctrl+C 或关闭终端"
    echo "   - 备份日志: cp backend.log logs/backend_$(date +%Y%m%d_%H%M%S).log"
    echo "   - 清理日志: > backend.log && > frontend.log"
    echo "   - 手动测试: python3 scripts/test_api.py"
    echo ""
    
    # 显示当前日志文件状态
    if [ -f "backend.log" ]; then
        backend_size=$(du -h backend.log 2>/dev/null | cut -f1 || echo "0B")
        backend_lines=$(wc -l < backend.log 2>/dev/null || echo "0")
        echo "📄 后端日志: $backend_size ($backend_lines 行)"
    fi
    
    if [ -f "frontend.log" ]; then
        frontend_size=$(du -h frontend.log 2>/dev/null | cut -f1 || echo "0B")
        frontend_lines=$(wc -l < frontend.log 2>/dev/null || echo "0")
        echo "📄 前端日志: $frontend_size ($frontend_lines 行)"
    fi
    
    echo ""
    echo "❓ 如有问题，请查看文档: docs/运行指南.md"
    echo ""
    log_info "系统正在运行，实时日志追踪: tail -f backend.log frontend.log"
}

# 主函数
main() {
    log_info "开始启动流程..."
    
    # 环境检查
    check_python
    check_nodejs
    check_model
    
    # 依赖安装
    install_python_deps
    install_nodejs_deps
    
    # 启动服务
    start_backend
    start_frontend
    
    # 运行测试
    run_tests
    
    # 显示访问信息
    show_access_info
    
    # 保持运行
    log_info "系统运行中，按 Ctrl+C 停止..."
    echo ""
    while true; do
        sleep 10
        
        # 如果已经开始清理，则退出循环
        if [ "$CLEANUP_DONE" = "true" ]; then
            break
        fi
        
        # 检查服务状态（静默检查，只在真正异常时输出错误）
        if [ ! -z "$BACKEND_PID" ] && ! kill -0 "$BACKEND_PID" 2>/dev/null; then
            # 只有在没有开始清理时才认为是意外停止
            if [ "$CLEANUP_DONE" != "true" ]; then
                log_error "后端服务意外停止"
                cleanup
            fi
            break
        fi
        
        if [ ! -z "$FRONTEND_PID" ] && ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
            # 只有在没有开始清理时才认为是意外停止
            if [ "$CLEANUP_DONE" != "true" ]; then
                log_error "前端服务意外停止"
                cleanup
            fi
            break
        fi
    done
}

# 执行主函数
main "$@"
