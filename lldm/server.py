from flask import Flask, request, jsonify
from flask_cors import CORS
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModel
import re
import logging
import json
import traceback
from datetime import datetime
import sys
import os

# 配置详细的日志记录
def setup_logging():
    """设置详细的日志记录"""
    # 获取日志文件路径，优先使用环境变量，否则使用默认值
    import os
    log_file = os.environ.get('BACKEND_LOG_FILE', 'backend.log')
    
    # 创建日志格式
    log_format = logging.Formatter(
        '%(asctime)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # 设置根日志记录器
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    
    # 清除已有的处理器
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # 文件处理器 - 详细日志
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(log_format)
    root_logger.addHandler(file_handler)
    
    # 控制台处理器 - 简要信息
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(log_format)
    root_logger.addHandler(console_handler)
    
    return root_logger

# 初始化日志
logger = setup_logging()

app = Flask(__name__)
CORS(app)  # 启用CORS以支持前端调用

# 请求日志中间件
@app.before_request
def log_request():
    """记录所有请求的详细信息"""
    request_data = {
        'method': request.method,
        'url': request.url,
        'remote_addr': request.remote_addr,
        'user_agent': str(request.user_agent),
        'timestamp': datetime.now().isoformat()
    }
    
    # 记录请求体（如果有）
    if request.is_json:
        try:
            request_data['json_data'] = request.get_json()
        except Exception as e:
            request_data['json_error'] = str(e)
    elif request.form:
        request_data['form_data'] = dict(request.form)
    elif request.args:
        request_data['args'] = dict(request.args)
    
    logger.info(f"收到请求: {json.dumps(request_data, ensure_ascii=False, indent=2)}")

@app.after_request
def log_response(response):
    """记录所有响应的详细信息"""
    response_data = {
        'status_code': response.status_code,
        'content_length': response.content_length,
        'content_type': response.content_type,
        'timestamp': datetime.now().isoformat()
    }
    
    # 记录响应体（小于1000字符时）
    if response.content_length and response.content_length < 1000:
        try:
            response_data['response_body'] = response.get_data(as_text=True)
        except Exception as e:
            response_data['response_error'] = str(e)
    
    logger.info(f"发送响应: {json.dumps(response_data, ensure_ascii=False, indent=2)}")
    return response

# 全局模型和tokenizer
device = 'cuda' if torch.cuda.is_available() else 'cpu'
logger.info(f"初始化设备: {device}")

try:
    # 清理GPU内存
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        gpu_memory_total = torch.cuda.get_device_properties(0).total_memory / 1024**3
        logger.info(f"GPU总内存: {gpu_memory_total:.1f}GB")
    
    # 加载模型和tokenizer
    logger.info("开始加载tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained('/root/autodl-tmp/model', trust_remote_code=True)
    logger.info("Tokenizer加载成功")
    
    logger.info("开始加载模型...")
    try:
        # 尝试以半精度加载到GPU
        if device == 'cuda':
            model = AutoModel.from_pretrained('/root/autodl-tmp/model', trust_remote_code=True, 
                                            torch_dtype=torch.bfloat16, device_map="auto")
        else:
            model = AutoModel.from_pretrained('/root/autodl-tmp/model', trust_remote_code=True)
    except torch.cuda.OutOfMemoryError as e:
        logger.error(f"GPU内存不足: {e}")
        logger.info("回退到CPU...")
        device = 'cpu'
        # 清理GPU内存
        torch.cuda.empty_cache()
        # 在CPU上加载模型
        model = AutoModel.from_pretrained('/root/autodl-tmp/model', trust_remote_code=True, 
                                        torch_dtype=torch.float32).to(device)
    
    logger.info(f"模型加载成功，设备: {device}")
    if device == 'cuda':
        gpu_memory_allocated = torch.cuda.memory_allocated() / 1024**3
        logger.info(f"GPU已分配内存: {gpu_memory_allocated:.1f}GB")
        
except Exception as e:
    logger.error(f"模型加载错误: {e}")
    logger.error(f"错误堆栈: {traceback.format_exc()}")
    logger.info("回退到CPU...")
    device = 'cpu'
    model = AutoModel.from_pretrained('/root/autodl-tmp/model', trust_remote_code=True).to(device)

# 常量
MASK_TOKEN = "[MASK]"
MASK_ID = 126336

def parse_constraints(constraints_text):
    """解析约束条件"""
    constraints = {}
    if not constraints_text:
        return constraints
        
    parts = constraints_text.split(',')
    for part in parts:
        if ':' not in part:
            continue
        pos_str, word = part.split(':', 1)
        try:
            pos = int(pos_str.strip())
            word = word.strip()
            if word and pos >= 0:
                constraints[pos] = word
        except ValueError:
            continue
    
    return constraints

def format_chat_history(history):
    """格式化聊天历史"""
    messages = []
    for msg in history:
        messages.append({"role": msg["role"], "content": msg["content"]})
    return messages

def add_gumbel_noise(logits, temperature):
    """添加Gumbel噪声"""
    if temperature <= 0:
        return logits
        
    logits = logits.to(torch.float64)
    noise = torch.rand_like(logits, dtype=torch.float64)
    gumbel_noise = (- torch.log(noise)) ** temperature
    return logits.exp() / gumbel_noise

def get_num_transfer_tokens(mask_index, steps):
    """计算转移token数量"""
    mask_num = mask_index.sum(dim=1, keepdim=True)
    base = mask_num // steps
    remainder = mask_num % steps
    num_transfer_tokens = torch.zeros(mask_num.size(0), steps, device=mask_index.device, dtype=torch.int64) + base
    for i in range(mask_num.size(0)):
        num_transfer_tokens[i, :remainder[i]] += 1
    return num_transfer_tokens

def generate_response(messages, settings):
    """
    生成响应主函数
    返回: (response_text, visualization_steps)
    """
    start_time = datetime.now()
    
    # 记录详细的输入参数
    logger.info("=" * 60)
    logger.info("开始生成响应")
    logger.info(f"输入消息数量: {len(messages)}")
    for i, msg in enumerate(messages):
        logger.info(f"消息 {i+1}: 角色={msg.get('role', 'unknown')}, 内容长度={len(msg.get('content', ''))}")
        logger.debug(f"消息 {i+1} 内容: {msg.get('content', '')}")
    
    logger.info(f"设置参数: {json.dumps(settings, ensure_ascii=False, indent=2)}")
    
    try:
        # 解析设置参数
        gen_length = settings.get("gen_length", 64)
        steps = settings.get("steps", 32)
        constraints = parse_constraints(settings.get("constraints", ""))
        temperature = settings.get("temperature", 0.0)
        cfg_scale = settings.get("cfg_scale", 0.0)
        block_length = settings.get("block_length", 32)
        remasking = settings.get("remasking", "low_confidence")
        
        logger.info(f"解析后的约束: {constraints}")
        
        # 记录内存使用情况
        if device == 'cuda':
            memory_before = torch.cuda.memory_allocated() / 1024**3
            logger.info(f"生成前GPU内存使用: {memory_before:.2f}GB")
        
        # 准备prompt
        logger.info("准备输入prompt...")
        chat_input = tokenizer.apply_chat_template(messages, add_generation_prompt=True, tokenize=False)
        logger.debug(f"格式化后的chat输入: {chat_input}")
        
        input_ids = tokenizer(chat_input)['input_ids']
        input_ids = torch.tensor(input_ids).to(device).unsqueeze(0)
        logger.info(f"输入token数量: {len(input_ids[0])}")
        
        # 初始化序列
        prompt_length = input_ids.shape[1]
        x = torch.full((1, prompt_length + gen_length), MASK_ID, dtype=torch.long).to(device)
        x[:, :prompt_length] = input_ids.clone()
        
        logger.info(f"序列总长度: {x.shape[1]}, prompt长度: {prompt_length}, 生成长度: {gen_length}")
        
        # 应用约束
        processed_constraints = {}
        for pos, word in constraints.items():
            tokens = tokenizer.encode(" " + word, add_special_tokens=False)
            for i, token_id in enumerate(tokens):
                processed_constraints[pos + i] = token_id
        
        logger.info(f"应用约束数量: {len(processed_constraints)}")
        for pos, token_id in processed_constraints.items():
            absolute_pos = prompt_length + pos
            if absolute_pos < x.shape[1]:
                x[:, absolute_pos] = token_id
                logger.debug(f"约束位置 {pos} (绝对位置 {absolute_pos}): token_id={token_id}")
        
        # 初始化可视化状态
        visualization_steps = []
        initial_state = [(MASK_TOKEN, "#444444") for _ in range(gen_length)]
        visualization_steps.append(initial_state)
        
        # 标记prompt位置
        prompt_index = (x != MASK_ID)
        
        # 处理block
        block_length = min(block_length, gen_length)
        num_blocks = (gen_length + block_length - 1) // block_length
        steps_per_block = max(1, steps // num_blocks)
        
        logger.info(f"块处理配置: 块长度={block_length}, 块数量={num_blocks}, 每块步数={steps_per_block}")
        
        # 处理每个block
        for block_idx in range(num_blocks):
            logger.info(f"处理第 {block_idx + 1}/{num_blocks} 块...")
            
            block_start = prompt_length + block_idx * block_length
            block_end = min(prompt_length + (block_idx + 1) * block_length, x.shape[1])
            block_mask_index = (x[:, block_start:block_end] == MASK_ID)
            
            if not block_mask_index.any():
                logger.info(f"块 {block_idx + 1} 没有MASK token，跳过")
                continue
            
            # 计算当前块的转移token数量
            num_transfer_tokens = get_num_transfer_tokens(block_mask_index, steps_per_block)
            
            # 处理每个step
            for step_idx in range(steps_per_block):
                logger.debug(f"块 {block_idx + 1}, 步骤 {step_idx + 1}/{steps_per_block}")
                
                mask_index = (x == MASK_ID)
                if not mask_index.any():
                    logger.debug("没有剩余的MASK token，提前结束")
                    break
                    
                # 应用分类器自由引导
                if cfg_scale > 0.0:
                    un_x = x.clone()
                    un_x[prompt_index] = MASK_ID
                    x_ = torch.cat([x, un_x], dim=0)
                    logits = model(x_).logits
                    logits, un_logits = torch.chunk(logits, 2, dim=0)
                    logits = un_logits + (cfg_scale + 1) * (logits - un_logits)
                else:
                    logits = model(x).logits
                
                # 添加噪声
                logits_with_noise = add_gumbel_noise(logits, temperature)
                x0 = torch.argmax(logits_with_noise, dim=-1)
                
                # 计算置信度
                if remasking == 'low_confidence':
                    p = F.softmax(logits.to(torch.float64), dim=-1)
                    x0_p = torch.squeeze(torch.gather(p, dim=-1, index=torch.unsqueeze(x0, -1)), -1)
                elif remasking == 'random':
                    x0_p = torch.rand((x0.shape[0], x0.shape[1]), device=x0.device)
                else:
                    raise ValueError(f"Unknown remasking strategy: {remasking}")
                
                # 不考虑当前块之外的位置
                x0_p[:, block_end:] = -float('inf')
                
                # 更新token
                old_x = x.clone()
                x0 = torch.where(mask_index, x0, x)
                confidence = torch.where(mask_index, x0_p, -float('inf'))
                
                # 选择要转移的token
                transfer_index = torch.zeros_like(x0, dtype=torch.bool, device=x0.device)
                for j in range(confidence.shape[0]):
                    # 只考虑当前块的置信度
                    block_confidence = confidence[j, block_start:block_end]
                    if step_idx < steps_per_block - 1:  # 不是最后一步
                        # 选择top-k置信度最高的token
                        _, select_indices = torch.topk(
                            block_confidence, 
                            k=min(num_transfer_tokens[j, step_idx].item(), block_confidence.numel())
                        )
                        # 调整索引到全局位置
                        select_indices = select_indices + block_start
                        transfer_index[j, select_indices] = True
                    else:  # 最后一步 - 取消所有剩余的mask
                        transfer_index[j, block_start:block_end] = mask_index[j, block_start:block_end]
                
                # 应用更新
                x = torch.where(transfer_index, x0, x)
                
                # 确保约束
                for pos, token_id in processed_constraints.items():
                    absolute_pos = prompt_length + pos
                    if absolute_pos < x.shape[1]:
                        x[:, absolute_pos] = token_id
                
                # 创建可视化状态
                current_state = []
                for i in range(gen_length):
                    pos = prompt_length + i
                    
                    if x[0, pos] == MASK_ID:
                        current_state.append((MASK_TOKEN, "#444444"))
                    elif old_x[0, pos] == MASK_ID:
                        token = tokenizer.decode([x[0, pos].item()], skip_special_tokens=False)
                        conf = float(x0_p[0, pos].cpu())
                        if conf < 0.3:
                            color = "#FF6666"
                        elif conf < 0.7:
                            color = "#FFAA33"
                        else:
                            color = "#66CC66"
                        current_state.append((token, color))
                    else:
                        token = tokenizer.decode([x[0, pos].item()], skip_special_tokens=False)
                        current_state.append((token, "#6699CC"))
                
                visualization_steps.append(current_state)
                
                # 清理GPU内存
                if device == 'cuda':
                    torch.cuda.empty_cache()
    
        # 提取最终响应
        response_tokens = x[0, prompt_length:]
        final_text = tokenizer.decode(
            response_tokens, 
            skip_special_tokens=True,
            clean_up_tokenization_spaces=True
        )
        
        # 记录生成结果
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        if device == 'cuda':
            memory_after = torch.cuda.memory_allocated() / 1024**3
            logger.info(f"生成后GPU内存使用: {memory_after:.2f}GB")
        
        logger.info(f"生成完成!")
        logger.info(f"响应文本长度: {len(final_text)}")
        logger.info(f"可视化步骤数: {len(visualization_steps)}")
        logger.info(f"生成耗时: {duration:.2f}秒")
        logger.debug(f"生成的响应文本: {final_text}")
        logger.info("=" * 60)
        
        return final_text, visualization_steps
        
    except Exception as e:
        # 记录详细的错误信息
        error_time = datetime.now()
        duration = (error_time - start_time).total_seconds()
        
        logger.error("生成过程中发生错误!")
        logger.error(f"错误类型: {type(e).__name__}")
        logger.error(f"错误信息: {str(e)}")
        logger.error(f"错误发生时间: {error_time.isoformat()}")
        logger.error(f"生成耗时(至错误): {duration:.2f}秒")
        logger.error(f"输入消息数量: {len(messages) if 'messages' in locals() else '未知'}")
        logger.error(f"设置参数: {json.dumps(settings, ensure_ascii=False) if 'settings' in locals() else '未知'}")
        logger.error(f"详细错误堆栈:")
        logger.error(traceback.format_exc())
        logger.info("=" * 60)
        
        # 清理GPU内存
        if device == 'cuda':
            torch.cuda.empty_cache()
            
        # 重新抛出异常
        raise e


@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    return jsonify({"status": "healthy", "device": device})

@app.route('/generate', methods=['POST'])
def generate():
    """生成API端点"""
    request_time = datetime.now()
    request_id = f"req_{int(request_time.timestamp() * 1000)}"
    
    try:
        # 记录请求开始
        logger.info(f"[{request_id}] 收到生成请求")
        
        # 获取请求体
        data = request.json
        messages = data.get('messages', [])
        settings = data.get('settings', {})
        
        # 详细记录请求数据
        logger.info(f"[{request_id}] 请求数据详情:")
        logger.info(f"[{request_id}] - 消息数量: {len(messages)}")
        logger.info(f"[{request_id}] - 设置参数: {json.dumps(settings, ensure_ascii=False, indent=2)}")
        logger.debug(f"[{request_id}] - 完整消息列表: {json.dumps(messages, ensure_ascii=False, indent=2)}")
        
        # 验证输入
        if not messages:
            logger.warning(f"[{request_id}] 空消息列表")
            return jsonify({"error": "Empty message list"}), 400
            
        if messages[-1]['role'] != 'user':
            logger.warning(f"[{request_id}] 最后一条消息不是用户消息: {messages[-1].get('role', 'unknown')}")
            return jsonify({"error": "Last message must be from user"}), 400
        
        logger.info(f"[{request_id}] 开始生成响应...")
        
        # 生成响应
        response_text, visualization = generate_response(messages, settings)
        
        # 记录成功响应
        response_time = datetime.now()
        duration = (response_time - request_time).total_seconds()
        
        logger.info(f"[{request_id}] 生成成功!")
        logger.info(f"[{request_id}] 响应长度: {len(response_text)}")
        logger.info(f"[{request_id}] 可视化步骤: {len(visualization)}")
        logger.info(f"[{request_id}] 总耗时: {duration:.2f}秒")
        logger.debug(f"[{request_id}] 响应文本: {response_text}")
        
        return jsonify({
            "response": response_text,
            "visualization": visualization,
            "request_id": request_id,
            "duration": duration
        })
        
    except Exception as e:
        # 记录错误
        error_time = datetime.now()
        duration = (error_time - request_time).total_seconds()
        
        logger.error(f"[{request_id}] 生成过程中发生错误!")
        logger.error(f"[{request_id}] 错误类型: {type(e).__name__}")
        logger.error(f"[{request_id}] 错误信息: {str(e)}")
        logger.error(f"[{request_id}] 错误耗时: {duration:.2f}秒")
        logger.error(f"[{request_id}] 错误堆栈:")
        logger.error(traceback.format_exc())
        
        return jsonify({
            "error": str(e), 
            "request_id": request_id,
            "error_type": type(e).__name__
        }), 500

if __name__ == '__main__':
    # 记录启动信息
    logger.info("=" * 50)
    logger.info("🚀 LLaDA后端服务启动")
    logger.info(f"启动时间: {datetime.now().isoformat()}")
    logger.info(f"Python版本: {sys.version}")
    logger.info(f"工作目录: {os.getcwd()}")
    logger.info(f"设备: {device}")
    if device == 'cuda':
        logger.info(f"GPU内存: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f}GB")
    logger.info("=" * 50)
    
    app.run(host='0.0.0.0', port=9000, threaded=True)