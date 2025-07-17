// 根据置信度获取颜色
export const getConfidenceColor = (confidence) => {
  if (confidence === 0) return '#666'; // 灰色表示MASK
  if (confidence < 0.3) return '#FF6666'; // 红色表示低置信度
  if (confidence < 0.7) return '#FFAA33'; // 橙色表示中置信度
  return '#66CC66'; // 绿色表示高置信度
};

// 将可视化状态转换为token数组
export const parseVisualizationState = (visualizationState) => {
  return visualizationState.map((item, index) => ({
    id: index,
    char: item[0],
    confidence: item[0] === '[MASK]' ? 0 : 1.0,
    color: item[1],
    isGenerated: item[0] !== '[MASK]'
  }));
};

// 格式化时间
export const formatTime = (timestamp) => {
  return timestamp.toLocaleTimeString('zh-CN', { 
    hour: '2-digit', 
    minute: '2-digit' 
  });
};

// 生成初始tokens
export const generateInitialTokens = (length) => {
  return Array(length).fill(null).map((_, index) => ({
    id: index,
    char: '[MASK]',
    confidence: 0,
    color: '#444444',
    isGenerated: false
  }));
};
