import React from 'react';

const TestComponent = () => {
  return (
    <div style={{ padding: '20px', backgroundColor: '#f0f0f0', minHeight: '100vh' }}>
      <h1>LLaDA 系统测试页面</h1>
      <p>如果您能看到这个页面，说明 React 应用正在正常运行。</p>
      <div style={{ marginTop: '20px', padding: '10px', backgroundColor: 'white', borderRadius: '5px' }}>
        <h2>系统状态</h2>
        <ul>
          <li>前端服务: ✅ 运行中</li>
          <li>React 渲染: ✅ 正常</li>
          <li>样式加载: ✅ 正常</li>
        </ul>
      </div>
    </div>
  );
};

export default TestComponent;
