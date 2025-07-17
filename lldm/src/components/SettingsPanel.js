import React from 'react';

const SettingsPanel = ({ settings, setSettings, isGenerating }) => {
  const handleSettingChange = (key, value) => {
    setSettings(prev => ({
      ...prev,
      [key]: value
    }));
  };

  return (
    <div className="settings-panel">
      <div className="settings-row">
        <label>
          <span>生成长度</span>
          <span className="value-display">{settings.gen_length}</span>
        </label>
        <input
          type="range"
          min="16"
          max="128"
          step="8"
          value={settings.gen_length}
          onChange={(e) => handleSettingChange('gen_length', parseInt(e.target.value))}
          disabled={isGenerating}
        />
      </div>
      
      <div className="settings-row">
        <label>
          <span>去噪步数</span>
          <span className="value-display">{settings.steps}</span>
        </label>
        <input
          type="range"
          min="8"
          max="64"
          step="4"
          value={settings.steps}
          onChange={(e) => handleSettingChange('steps', parseInt(e.target.value))}
          disabled={isGenerating}
        />
      </div>
      
      <div className="settings-row">
        <label>
          <span>温度</span>
          <span className="value-display">{settings.temperature.toFixed(1)}</span>
        </label>
        <input
          type="range"
          min="0.0"
          max="1.0"
          step="0.1"
          value={settings.temperature}
          onChange={(e) => handleSettingChange('temperature', parseFloat(e.target.value))}
          disabled={isGenerating}
        />
      </div>
      
      <div className="settings-row">
        <label>
          <span>Top-p</span>
          <span className="value-display">{settings.top_p.toFixed(2)}</span>
        </label>
        <input
          type="range"
          min="0.0"
          max="1.0"
          step="0.05"
          value={settings.top_p}
          onChange={(e) => handleSettingChange('top_p', parseFloat(e.target.value))}
          disabled={isGenerating}
        />
      </div>
      
      <div className="settings-row">
        <label>
          <span>Beam数量</span>
          <span className="value-display">{settings.num_beams}</span>
        </label>
        <input
          type="range"
          min="1"
          max="8"
          step="1"
          value={settings.num_beams}
          onChange={(e) => handleSettingChange('num_beams', parseInt(e.target.value))}
          disabled={isGenerating}
        />
      </div>
      
      <div className="settings-row">
        <label>
          <span>CFG比例</span>
          <span className="value-display">{settings.cfg_scale.toFixed(1)}</span>
        </label>
        <input
          type="range"
          min="0.0"
          max="2.0"
          step="0.1"
          value={settings.cfg_scale}
          onChange={(e) => handleSettingChange('cfg_scale', parseFloat(e.target.value))}
          disabled={isGenerating}
        />
      </div>
    </div>
  );
};

export default SettingsPanel;
