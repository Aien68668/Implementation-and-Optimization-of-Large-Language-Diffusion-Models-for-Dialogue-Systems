import React from 'react';

const ConfidenceIndicator = () => {
  const confidenceLevels = [
    { level: 0, color: '#444444', label: '[MASK]' },
    { level: 0.25, color: 'rgb(255,102,102)', label: '低置信度' },
    { level: 0.5, color: 'rgb(255,170,51)', label: '中置信度' },
    { level: 0.75, color: 'rgb(102,204,102)', label: '高置信度' },
    { level: 1.0, color: 'rgb(102, 153, 204)', label: '确定' }
  ];

  return (
    <div className="confidence-indicator">
      <div className="indicator-header">
        <h4>置信度颜色说明</h4>
      </div>
      <div className="confidence-levels">
        {confidenceLevels.map((item, index) => (
          <div key={index} className="confidence-scale">
            <div 
              className="color-box" 
              style={{ backgroundColor: item.color }}
            ></div>
            <span>{item.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ConfidenceIndicator;
