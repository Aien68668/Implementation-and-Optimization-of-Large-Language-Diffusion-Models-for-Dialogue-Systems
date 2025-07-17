import React, { useRef, useEffect } from 'react';

const InputArea = ({ 
  inputValue, 
  setInputValue, 
  constraints, 
  setConstraints, 
  handleSend, 
  handleKeyPress, 
  isGenerating 
}) => {
  const textareaRef = useRef(null);

  // 自动调整文本框高度
  const adjustTextareaHeight = () => {
    const textarea = textareaRef.current;
    if (textarea) {
      // 重置高度以计算实际需要的高度
      textarea.style.height = 'auto';
      
      // 计算内容高度
      const scrollHeight = textarea.scrollHeight;
      
      // 获取计算后的样式
      const style = window.getComputedStyle(textarea);
      const paddingTop = parseInt(style.paddingTop, 10);
      const paddingBottom = parseInt(style.paddingBottom, 10);
      const lineHeight = parseInt(style.lineHeight, 10) || 21; // 默认行高
      
      // 计算最小和最大高度
      const minHeight = 40; // 最小高度
      const maxLines = 6;
      const maxHeight = (lineHeight * maxLines) + paddingTop + paddingBottom;
      
      // 设置高度，但限制在最小和最大高度之间
      const newHeight = Math.max(minHeight, Math.min(scrollHeight, maxHeight));
      textarea.style.height = `${newHeight}px`;
      
      // 如果内容超过最大高度，启用滚动
      if (scrollHeight > maxHeight) {
        textarea.style.overflowY = 'auto';
      } else {
        textarea.style.overflowY = 'hidden';
      }
    }
  };

  // 当输入值改变时调整高度
  useEffect(() => {
    adjustTextareaHeight();
  }, [inputValue]);

  // 处理输入变化
  const handleInputChange = (e) => {
    setInputValue(e.target.value);
  };

  return (
    <>
      {/* 约束输入 */}
      <div className="constraints-container">
        <input
          type="text"
          value={constraints}
          onChange={(e) => setConstraints(e.target.value)}
          placeholder="位置约束 (例如: 0:Once, 5:upon, 10:time)"
          className="constraints-input"
          disabled={isGenerating}
        />
      </div>
      
      {/* 消息输入 */}
      <div className="input-container">
        <textarea
          ref={textareaRef}
          value={inputValue}
          onChange={handleInputChange}
          onKeyPress={handleKeyPress}
          placeholder="输入您的消息来触发LLaDA扩散生成过程..."
          className="input-field auto-resize"
          rows="1"
          disabled={isGenerating}
          style={{
            resize: 'none',
            overflow: 'auto'
          }}
        />
        <button 
          onClick={handleSend}
          className="send-button"
          disabled={inputValue.trim() === '' || isGenerating}
        >
          {isGenerating ? '生成中...' : '发送'}
        </button>
      </div>
    </>
  );
};

export default InputArea;
