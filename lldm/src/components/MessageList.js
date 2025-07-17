import React from 'react';

const MessageList = ({ 
  messages, 
  isGenerating, 
  serverError, 
  getConfidenceColor, 
  formatTime, 
  messagesEndRef 
}) => {
  
  return (
    <div className="messages-container">
      {messages.map((message) => (
        <div key={message.id} className={`message ${message.sender}`}>
          <div className="message-content">
            <div className="message-text">
              {message.sender === 'bot' && message.tokens ? (
                // 优先显示token可视化，除非消息为空
                message.text && message.text.trim() === '' ? (
                  // 消息为空时，删除token格子，显示空文本
                  message.text
                ) : (
                  // 有token数据时，显示可视化样式
                  <div className="token-container">
                    {message.tokens
                      .filter((token, index) => {
                        // 简单过滤：过滤掉空的已生成token（但保留MASK）
                        const isMask = token.char === '[MASK]';
                        const isEmpty = !token.char || token.char.trim() === '';
                        
                        // // 如果是已生成的空token（非MASK），直接不显示
                        // if (token.isGenerated && isEmpty && !isMask) {
                        //   return false;
                        // }
                        
                        return true;
                      })
                      .map((token, filteredIndex) => {
                        const isMask = token.char === '[MASK]';
                        
                        // 根据置信度确定CSS类名
                        let confidenceClass = '';
                        if (isMask) {
                          confidenceClass = 'mask-token';
                        } else {
                          // 根据置信度分配类名
                          if (token.confidence < 0.3) {
                            confidenceClass = 'confidence-low';
                          } else if (token.confidence < 0.7) {
                            confidenceClass = 'confidence-medium';
                          } else {
                            confidenceClass = 'confidence-high';
                          }
                          
                          // 如果是之前生成的token（颜色为蓝色）
                          if (token.color === '#6699CC') {
                            confidenceClass = 'confidence-previous';
                          }
                        }
                        
                        return (
                          <span
                            key={`${message.id}_${token.id || filteredIndex}_${token.char}`}
                            className={`token ${confidenceClass} ${
                              token.isGenerated && !isMask ? 'just-generated' : ''
                            } ${
                              !token.isGenerated ? 'generating' : ''
                            } ${
                              message.isGenerated ? 'final-generated' : ''
                            }`}
                            style={{ 
                              animationDelay: token.isGenerated && !isMask ? `${filteredIndex * 0.08}s` : '0s'
                            }}
                          >
                            {token.char}
                          </span>
                        );
                      })}
                  </div>
                )
              ) : (
                // 非bot消息或没有token数据时显示普通文本
                message.text
              )}
            </div>
            <div className="message-time">{formatTime(message.timestamp)}</div>
          </div>
        </div>
      ))}
      
      {isGenerating && (
        <div className="generating-indicator">
          <div className="generating-dots">
            <span></span>
            <span></span>
            <span></span>
          </div>
          <span>正在生成中...</span>
        </div>
      )}
      
      {serverError && (
        <div className="error-message">
          <div className="error-content">
            <strong>错误：</strong> {serverError}
          </div>
        </div>
      )}
      
      <div ref={messagesEndRef} />
    </div>
  );
};

export default MessageList;
