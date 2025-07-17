import React, { useState, useEffect, useRef } from 'react';
import { sendMessage, getStatus, generateText, checkServerStatus, logger } from './services/apiService';
import ConfidenceIndicator from './components/ConfidenceIndicator';
import MessageList from './components/MessageList';
import SettingsPanel from './components/SettingsPanel';
import InputArea from './components/InputArea';
import Sidebar from './components/Sidebar';
import './styles/Sidebar.css';
import './styles/DiffusionModel.css';

const DiffusionModel = () => {
    const [messages, setMessages] = useState([]);
    const [input, setInput] = useState('');
    const [isGenerating, setIsGenerating] = useState(false);
    const [chatHistory, setChatHistory] = useState([]);
    const [constraints, setConstraints] = useState('');
    const [serverError, setServerError] = useState(null);
    const [confidence, setConfidence] = useState(0);
    const [isWaitingForResponse, setIsWaitingForResponse] = useState(false);
    const [settings, setSettings] = useState({
        temperature: 0.0,
        top_p: 0.95,
        gen_length: 50,
        num_beams: 4,
        steps: 32,
        cfg_scale: 1.0
    });

    // --- Conversation Management State ---
    const [conversations, setConversations] = useState([
        { id: 0, name: '对话 1', history: [] }
    ]);
    const [currentConversationId, setCurrentConversationId] = useState(0);
    const [systemStatus, setSystemStatus] = useState({
        backendConnected: false,
        device: 'Unknown',
        modelLoaded: false,
        lastCheck: null
    });

    const messagesEndRef = useRef(null);

    useEffect(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [messages]);

    // --- Conversation Management Handlers ---

    const handleNewConversation = () => {
        // Save the current conversation's history first.
        const updatedConversations = conversations.map(conv =>
            conv.id === currentConversationId ? { ...conv, history: messages } : conv
        );

        // Create the new conversation.
        const newConversationId = Date.now(); // Use timestamp for unique ID
        const newConversation = {
            id: newConversationId,
            name: `对话 ${updatedConversations.length + 1}`,
            history: []
        };

        setConversations([...updatedConversations, newConversation]);
        setCurrentConversationId(newConversationId);
        setMessages([]); // Clear messages for the new conversation
        setInput('');
        setConfidence(0);
        setIsWaitingForResponse(false);
    };

    const handleSwitchConversation = (id) => {
        if (id === currentConversationId) return;

        // Save the current conversation's history before switching.
        const updatedConversations = conversations.map(conv =>
            conv.id === currentConversationId ? { ...conv, history: messages } : conv
        );

        const newCurrentConversation = updatedConversations.find(conv => conv.id === id);

        if (newCurrentConversation) {
            setConversations(updatedConversations);
            setCurrentConversationId(newCurrentConversation.id);
            setMessages(newCurrentConversation.history || []);
        }
    };

    const handleDeleteConversation = (id) => {
        const updatedConversations = conversations.filter(conv => conv.id !== id);
        setConversations(updatedConversations);

        if (id === currentConversationId) {
            if (updatedConversations.length > 0) {
                const firstConv = updatedConversations[0];
                setCurrentConversationId(firstConv.id);
                setMessages(firstConv.history || []);
            } else {
                // If all conversations are deleted, create a new default one.
                const newId = Date.now();
                const newConv = { id: newId, name: '对话 1', history: [] };
                setConversations([newConv]);
                setCurrentConversationId(newId);
                setMessages([]);
            }
        }
    };



    const handleSend = async () => {
        if (input.trim() === '' || isWaitingForResponse) return;
        
        const requestStartTime = Date.now();
        const requestId = `frontend_${requestStartTime}_${Math.random().toString(36).substr(2, 9)}`;
        
        logger.info(`[${requestId}] 开始处理用户发送请求`, {
            userInput: input,
            inputLength: input.length,
            conversationId: currentConversationId,
            currentMessagesCount: messages.length,
            settings: settings,
            constraints: constraints
        });
        
        const userMessage = { 
            id: Date.now(),
            text: input, 
            sender: 'user',
            timestamp: new Date()
        };
        setMessages(prevMessages => [...prevMessages, userMessage]);
        const userInput = input;
        setInput('');
        setIsWaitingForResponse(true);
        setIsGenerating(true);
        setServerError(null);

        try {
            // 准备聊天历史
            const newChatHistory = [
                ...chatHistory,
                { role: 'user', content: userInput }
            ];

            logger.info(`[${requestId}] 准备发送到后端`, {
                chatHistoryLength: newChatHistory.length,
                lastUserMessage: userInput,
                settingsUsed: settings
            });

            // 创建初始的掩码消息
            const initialTokens = Array(settings.gen_length).fill(null).map((_, index) => ({
                id: index,
                char: '[MASK]',
                confidence: 0,
                color: '#444444',
                isGenerated: false
            }));

            const botMessage = {
                id: Date.now() + 1,
                text: '',
                sender: 'bot',
                timestamp: new Date(),
                tokens: initialTokens,
                isGenerated: false
            };

            setMessages(prevMessages => [...prevMessages, botMessage]);

            // 调用后端API生成响应
            const requestSettings = {
                ...settings,
                constraints: constraints
            };

            logger.info(`[${requestId}] 发送API请求`, {
                endpoint: '/generate',
                messageCount: newChatHistory.length,
                settings: requestSettings
            });

            const response = await sendMessage(newChatHistory, requestSettings);
            
            if (response.error) {
                throw new Error(response.error);
            }

            logger.info(`[${requestId}] 收到后端响应`, {
                responseLength: response.response?.length,
                visualizationStepsCount: response.visualization?.length,
                backendRequestId: response.request_id,
                backendDuration: response.duration
            });

            // 更新聊天历史
            setChatHistory([
                ...newChatHistory,
                { role: 'assistant', content: response.response }
            ]);

            // 逐步显示可视化过程
            const visualizationSteps = response.visualization || [];
            
            logger.info(`[${requestId}] 开始可视化处理`, {
                visualizationStepsCount: visualizationSteps.length,
                animationDelay: 300
            });
            
            for (let stepIndex = 0; stepIndex < visualizationSteps.length; stepIndex++) {
                const step = visualizationSteps[stepIndex];
                const tokens = parseVisualizationState(step);
                
                // 更新消息中的tokens
                setMessages(prev => prev.map(msg => {
                    if (msg.id === botMessage.id) {
                        return { ...msg, tokens };
                    }
                    return msg;
                }));
                
                // 如果不是最后一步，等待一段时间再显示下一步
                if (stepIndex < visualizationSteps.length - 1) {
                    await new Promise(resolve => setTimeout(resolve, 300)); // 增加延迟以便观察转换效果
                }
            }

            // 生成完成，设置最终文本
            setMessages(prev => {
                const updatedMessages = prev.map(msg => {
                    if (msg.id === botMessage.id) {
                        return { 
                            ...msg, 
                            text: response.response,
                            isGenerated: true 
                        };
                    }
                    return msg;
                });
                
                // 更新当前对话
                updateCurrentConversation(updatedMessages);
                
                return updatedMessages;
            });

            setConfidence(response.confidence || 0);
            
            const requestEndTime = Date.now();
            const totalDuration = requestEndTime - requestStartTime;
            
            logger.info(`[${requestId}] 请求处理完成`, {
                totalDuration: `${totalDuration}ms`,
                finalResponseLength: response.response.length,
                conversationUpdated: true
            });
            
        } catch (error) {
            const requestEndTime = Date.now();
            const totalDuration = requestEndTime - requestStartTime;
            
            logger.error(`[${requestId}] 发送消息失败`, {
                errorMessage: error.message,
                errorType: error.name,
                errorStack: error.stack,
                totalDuration: `${totalDuration}ms`,
                userInput: userInput,
                settings: settings,
                conversationId: currentConversationId
            });
            
            const errorMessage = { 
                id: Date.now() + 2,
                text: '发送消息时出错: ' + (error.message || '未知错误'), 
                sender: 'bot',
                timestamp: new Date()
            };
            setMessages(prevMessages => prevMessages.slice(0, -1).concat([errorMessage]));
            setServerError(error.message || '服务器连接失败');
        } finally {
            setIsWaitingForResponse(false);
            setIsGenerating(false);
            
            logger.debug(`[${requestId}] 请求状态重置完成`);
        }
    };


    // 辅助函数：更新当前对话
    const updateCurrentConversation = (updatedMessages, finalChatHistory) => {
        // 更新当前对话的历史
        setConversations(prev => {
            return prev.map(conv => {
                if (conv.id === currentConversationId) {
                    return { ...conv, history: updatedMessages };
                }
                return conv;
            });
        });
    };

    // 解析可视化状态
    const parseVisualizationState = (step) => {
        if (!step || !Array.isArray(step)) {
            return [];
        }

        return step.map((tokenData, index) => {
            // tokenData是 [token_text, color] 的格式
            const [tokenText, color] = tokenData;
            
            return {
                id: index,
                char: tokenText,
                confidence: getConfidenceFromColor(color),
                color: color,
                isGenerated: tokenText !== '[MASK]'
            };
        });
    };

    // 从颜色推断置信度（与app.py保持一致）
    const getConfidenceFromColor = (color) => {
        switch (color) {
            case '#444444': return 0;     // [MASK] - 深灰色
            case '#FF6666': return 0.2;   // 低置信度 - 红色
            case '#FFAA33': return 0.5;   // 中置信度 - 橙色
            case '#66CC66': return 0.8;   // 高置信度 - 绿色
            case '#6699CC': return 1.0;   // 之前生成的token - 蓝色
            default: return 0.5;
        }
    };

    // 获取置信度颜色（与app.py保持一致）
    const getColorFromConfidence = (confidence) => {
        if (confidence < 0.3) return '#FF6666'; // 低置信度：红色
        if (confidence < 0.7) return '#FFAA33'; // 中置信度：橙色
        return '#66CC66';                       // 高置信度：绿色
    };

    // 处理按键按下事件
    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        }
    };

    // 检查服务器状态
    useEffect(() => {
        const checkStatus = async () => {
            try {
                const status = await getStatus();
                setServerError(null);
                setSystemStatus({
                    backendConnected: true,
                    device: status.device || 'Unknown',
                    modelLoaded: true,
                    lastCheck: new Date()
                });
            } catch (error) {
                setServerError('服务器连接失败');
                setSystemStatus({
                    backendConnected: false,
                    device: 'Unknown',
                    modelLoaded: false,
                    lastCheck: new Date()
                });
            }
        };

        checkStatus();
        const interval = setInterval(checkStatus, 30000); // 每30秒检查一次

        return () => clearInterval(interval);
    }, []);

    return (
        <div className="diffusion-model">
            <Sidebar
                conversations={conversations}
                activeConversationId={currentConversationId}
                onNewConversation={handleNewConversation}
                onSelectConversation={handleSwitchConversation}
                onDeleteConversation={handleDeleteConversation}
                systemStatus={systemStatus}
                isGenerating={isGenerating}
            />
            <div className="main-content">
                <div className="chat-container">
                    <MessageList 
                        messages={messages} 
                        isGenerating={isGenerating}
                        serverError={serverError}
                        getConfidenceColor={getColorFromConfidence}
                        formatTime={(timestamp) => new Date(timestamp).toLocaleTimeString()}
                        messagesEndRef={messagesEndRef}
                    />
                    <div className="input-area-container">
                        <InputArea 
                            inputValue={input}
                            setInputValue={setInput}
                            constraints={constraints}
                            setConstraints={setConstraints}
                            handleSend={handleSend}
                            handleKeyPress={handleKeyPress}
                            isGenerating={isGenerating}
                        />
                    </div>
                </div>
            </div>
            
            {/* 右侧设置边栏 - 模型设置和置信度颜色说明 */}
            <div className="settings-sidebar">
                <div className="settings-section">
                    <h3>模型设置</h3>
                    <SettingsPanel 
                        settings={settings}
                        setSettings={setSettings}
                        isGenerating={isGenerating}
                    />
                </div>
                
                <div className="confidence-section">
                    <ConfidenceIndicator />
                </div>
            </div>
        </div>
    );
};

export default DiffusionModel;
