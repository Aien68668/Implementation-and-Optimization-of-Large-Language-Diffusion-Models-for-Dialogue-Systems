import React, { useState } from 'react';
import '../styles/Sidebar.css';

const Sidebar = ({
  conversations,
  activeConversationId,
  onNewConversation,
  onSelectConversation,
  onDeleteConversation,
  systemStatus,
  isGenerating
}) => {
  const [isCollapsed, setIsCollapsed] = useState(false);

  const formatConversationTitle = (conversation) => {
    if (conversation.title) {
      return conversation.title;
    }
    // 从第一条用户消息生成标题
    const firstUserMessage = conversation.messages?.find(m => m.sender === 'user');
    if (firstUserMessage) {
      return firstUserMessage.text.slice(0, 20) + (firstUserMessage.text.length > 20 ? '...' : '');
    }
    return `对话 ${conversation.id}`;
  };

  const formatTime = (timestamp) => {
    const now = new Date();
    const time = new Date(timestamp);
    const diffMs = now.getTime() - time.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    if (diffDays === 0) {
      return time.toLocaleTimeString('zh-CN', { 
        hour: '2-digit', 
        minute: '2-digit' 
      });
    } else if (diffDays === 1) {
      return '昨天';
    } else if (diffDays < 7) {
      return `${diffDays}天前`;
    } else {
      return time.toLocaleDateString('zh-CN', { 
        month: 'short', 
        day: 'numeric' 
      });
    }
  };

  return (
    <div className={`sidebar ${isCollapsed ? 'collapsed' : ''}`}>
      {/* 顶部标题区域 */}
      <div className="sidebar-header">
        <div className="system-title">
          <h2>🚀 LLaDA</h2>
          <p>扩散语言模型</p>
        </div>
        
        <button 
          className="collapse-btn"
          onClick={() => setIsCollapsed(!isCollapsed)}
          title={isCollapsed ? "展开侧边栏" : "收起侧边栏"}
        >
          <span className="collapse-icon">{isCollapsed ? '▶' : '◀'}</span>
        </button>
      </div>

      {!isCollapsed && (
        <div className="sidebar-content">
          {/* 控制按钮区域 */}
          <div className="controls-section">
            <button 
              className="control-btn new-conversation-btn"
              onClick={onNewConversation}
              title="新建对话"
            >
              <span className="btn-icon">➕</span>
              <span className="btn-text">新建对话</span>
            </button>
          </div>

          {/* 对话历史列表 - 添加固定高度和滚动 */}
          <div className="conversations-section">
            <h3 className="section-title">对话历史</h3>
            <div className="conversations-list scrollable">
              {conversations.length === 0 ? (
                <div className="empty-conversations">
                  <p>暂无对话记录</p>
                  <p className="hint">点击"新建对话"开始聊天</p>
                </div>
              ) : (
                conversations.map((conversation) => (
                  <div
                    key={conversation.id}
                    className={`conversation-item ${activeConversationId === conversation.id ? 'active' : ''}`}
                    onClick={() => onSelectConversation(conversation.id)}
                  >
                    <div className="conversation-content">
                      <div className="conversation-title">
                        {conversation.name || formatConversationTitle(conversation)}
                      </div>
                      <div className="conversation-preview">
                        {conversation.history?.length > 0 
                          ? conversation.history[conversation.history.length - 1]?.text?.slice(0, 30) + '...'
                          : '新对话'
                        }
                      </div>
                      <div className="conversation-time">
                        {conversation.lastUpdate 
                          ? formatTime(conversation.lastUpdate)
                          : '刚刚'
                        }
                      </div>
                    </div>
                    <button 
                      className="delete-btn"
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeleteConversation(conversation.id);
                      }}
                      title="删除对话"
                    >
                      🗑️
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
      
      {/* 系统状态区域 */}
      {!isCollapsed && (
        <div className="system-status">
          <div className="status-title">系统状态</div>
          
          <div className="status-item">
            <div className="status-label">后端连接</div>
            <div className={`status-value ${systemStatus?.backendConnected ? 'connected' : 'disconnected'}`}>
              <div className={`status-dot ${systemStatus?.backendConnected ? 'success' : 'error'}`}></div>
              {systemStatus?.backendConnected ? '已连接' : '连接失败'}
            </div>
          </div>
          
          <div className="status-item">
            <div className="status-label">计算设备</div>
            <div className="status-value">
              <div className={`device-icon ${systemStatus?.device?.toLowerCase()}`}>
                {systemStatus?.device === 'cuda' ? '🎮' : '💻'}
              </div>
              {systemStatus?.device === 'cuda' ? 'GPU加速' : 'CPU模式'}
            </div>
          </div>
          
          <div className="status-item">
            <div className="status-label">模型状态</div>
            <div className={`status-value ${systemStatus?.modelLoaded ? 'loaded' : 'loading'}`}>
              <div className={`status-dot ${systemStatus?.modelLoaded ? 'success' : 'warning'}`}></div>
              {systemStatus?.modelLoaded ? '已加载' : '加载中'}
            </div>
          </div>
          
          {isGenerating && (
            <div className="status-item">
              <div className="status-label">生成状态</div>
              <div className="status-value generating">
                <div className="generating-spinner"></div>
                正在生成...
              </div>
            </div>
          )}
          
          {systemStatus?.lastCheck && (
            <div className="last-check">
              最后检查: {new Date(systemStatus.lastCheck).toLocaleTimeString()}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default Sidebar;
