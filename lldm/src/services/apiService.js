import axios from 'axios';

// 后端API基础URL
const API_BASE_URL = 'http://localhost:9000';

// 详细日志记录功能
class APILogger {
  constructor() {
    this.logs = [];
    this.maxLogs = 1000; // 最大保存1000条日志
  }

  log(level, message, data = null) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      data: data ? JSON.parse(JSON.stringify(data)) : null,
      id: Date.now() + Math.random()
    };
    
    this.logs.push(logEntry);
    
    // 保持日志数量在限制内
    if (this.logs.length > this.maxLogs) {
      this.logs = this.logs.slice(-this.maxLogs);
    }
    
    // 同时输出到控制台
    const consoleMethod = level === 'error' ? 'error' : level === 'warn' ? 'warn' : 'log';
    console[consoleMethod](`[API-${level.toUpperCase()}] ${message}`, data || '');
    
    // 发送到后端日志（如果需要）
    this.sendToBackend(logEntry);
  }

  async sendToBackend(logEntry) {
    // 可选：将前端日志发送到后端保存
    try {
      // 这里可以实现发送到后端的逻辑
      // await api.post('/log', logEntry);
    } catch (error) {
      // 静默失败，避免无限循环
    }
  }

  info(message, data) {
    this.log('info', message, data);
  }

  warn(message, data) {
    this.log('warn', message, data);
  }

  error(message, data) {
    this.log('error', message, data);
  }

  debug(message, data) {
    this.log('debug', message, data);
  }

  getLogs() {
    return this.logs;
  }

  clearLogs() {
    this.logs = [];
  }

  exportLogs() {
    const logData = JSON.stringify(this.logs, null, 2);
    const blob = new Blob([logData], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `frontend-logs-${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
}

// 创建全局日志记录器
const logger = new APILogger();
window.apiLogger = logger; // 使其在控制台中可访问

// 创建axios实例
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 60000, // 60秒超时
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器 - 详细记录
api.interceptors.request.use(
  (config) => {
    const requestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    config.metadata = { requestId, startTime: Date.now() };
    
    logger.info(`发送API请求 [${requestId}]`, {
      method: config.method.toUpperCase(),
      url: config.url,
      baseURL: config.baseURL,
      headers: config.headers,
      data: config.data,
      timeout: config.timeout
    });
    
    return config;
  },
  (error) => {
    logger.error('请求配置错误', {
      message: error.message,
      stack: error.stack,
      config: error.config
    });
    return Promise.reject(error);
  }
);

// 响应拦截器 - 详细记录
api.interceptors.response.use(
  (response) => {
    const { requestId, startTime } = response.config.metadata || {};
    const duration = Date.now() - startTime;
    
    logger.info(`收到API响应 [${requestId}]`, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers,
      data: response.data,
      duration: `${duration}ms`,
      url: response.config.url
    });
    
    return response;
  },
  (error) => {
    const { requestId, startTime } = error.config?.metadata || {};
    const duration = startTime ? Date.now() - startTime : 0;
    
    logger.error(`API请求失败 [${requestId}]`, {
      message: error.message,
      status: error.response?.status,
      statusText: error.response?.statusText,
      data: error.response?.data,
      duration: duration ? `${duration}ms` : 'unknown',
      url: error.config?.url,
      stack: error.stack
    });
    
    return Promise.reject(error);
  }
);

// 发送消息到后端API
export const sendMessage = async (messages, settings = {}) => {
  const startTime = Date.now();
  
  try {
    logger.info('开始发送消息', {
      messageCount: messages.length,
      lastMessageRole: messages[messages.length - 1]?.role,
      lastMessageLength: messages[messages.length - 1]?.content?.length,
      settings: settings
    });
    
    // 详细记录每条消息（调试模式）
    if (process.env.REACT_APP_LOG_LEVEL === 'debug') {
      messages.forEach((msg, index) => {
        logger.debug(`消息 ${index + 1}`, {
          role: msg.role,
          content: msg.content,
          contentLength: msg.content?.length
        });
      });
    }
    
    const response = await api.post('/generate', {
      messages,
      settings
    });
    
    const duration = Date.now() - startTime;
    
    logger.info('消息发送成功', {
      responseLength: response.data.response?.length,
      visualizationSteps: response.data.visualization?.length,
      duration: `${duration}ms`,
      requestId: response.data.request_id
    });
    
    return response.data;
    
  } catch (error) {
    const duration = Date.now() - startTime;
    
    logger.error('发送消息失败', {
      errorMessage: error.message,
      errorType: error.name,
      responseStatus: error.response?.status,
      responseData: error.response?.data,
      duration: `${duration}ms`,
      messageCount: messages.length,
      settings: settings
    });
    
    throw error;
  }
};

// generateText 函数 - 为了兼容性
export const generateText = sendMessage;

// 检查服务器状态
export const getStatus = async () => {
  try {
    logger.debug('检查服务器状态');
    
    const response = await api.get('/health');
    
    logger.info('服务器状态检查成功', {
      status: response.data.status,
      device: response.data.device,
      responseTime: response.headers['response-time'] || 'unknown'
    });
    
    return response.data;
    
  } catch (error) {
    logger.error('服务器状态检查失败', {
      errorMessage: error.message,
      errorType: error.name,
      responseStatus: error.response?.status,
      responseData: error.response?.data
    });
    
    throw error;
  }
};

// checkServerStatus 函数 - 为了兼容性
export const checkServerStatus = getStatus;

// 导出日志记录器供其他组件使用
export { logger };

export default api;
