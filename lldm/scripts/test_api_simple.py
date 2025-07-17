#!/usr/bin/env python3
"""
LLaDA API 测试脚本
快速测试后端API功能
"""

import requests
import json
import time
import sys

API_BASE = "http://localhost:9000"
TIMEOUT = 30

def test_health():
    """测试健康检查"""
    print("🔍 测试健康检查...")
    try:
        response = requests.get(f"{API_BASE}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 健康检查通过 - 设备: {data.get('device', 'unknown')}")
            return True
        else:
            print(f"❌ 健康检查失败 - 状态码: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ 健康检查失败: {e}")
        return False

def test_simple_generation():
    """测试简单文本生成"""
    print("\n💻 测试简单文本生成...")
    
    payload = {
        "messages": [
            {"role": "user", "content": "你好"}
        ],
        "settings": {
            "gen_length": 16,
            "steps": 8,
            "temperature": 0.0,
            "cfg_scale": 0.0
        }
    }
    
    try:
        response = requests.post(
            f"{API_BASE}/generate", 
            json=payload, 
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 生成成功: {data.get('response', '').strip()}")
            print(f"📊 可视化步数: {len(data.get('visualization', []))}")
            return True
        else:
            print(f"❌ 生成失败 - 状态码: {response.status_code}")
            try:
                error_data = response.json()
                print(f"❌ 错误信息: {error_data.get('error', 'unknown')}")
            except:
                print(f"❌ 响应内容: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ 生成失败: {e}")
        return False

def test_constraint_generation():
    """测试约束生成"""
    print("\n🎯 测试约束生成...")
    
    payload = {
        "messages": [
            {"role": "user", "content": "今天天气怎么样？"}
        ],
        "settings": {
            "gen_length": 12,
            "steps": 6,
            "temperature": 0.0,
            "constraints": "0:今天, 2:天气, 4:很好"
        }
    }
    
    try:
        response = requests.post(
            f"{API_BASE}/generate", 
            json=payload, 
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            data = response.json()
            result = data.get('response', '').strip()
            print(f"✅ 约束生成成功: {result}")
            
            # 检查约束是否生效
            if "今天" in result and "天气" in result:
                print("✅ 约束条件生效")
            else:
                print("⚠️ 约束条件可能未完全生效")
            
            return True
        else:
            print(f"❌ 约束生成失败 - 状态码: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ 约束生成失败: {e}")
        return False

def main():
    """主测试函数"""
    print("🧪 LLaDA API 快速测试")
    print("=" * 40)
    
    # 等待服务启动
    print("⏳ 等待服务启动...")
    time.sleep(2)
    
    tests = [
        ("健康检查", test_health),
        ("简单生成", test_simple_generation),
        ("约束生成", test_constraint_generation)
    ]
    
    passed = 0
    total = len(tests)
    
    for name, test_func in tests:
        if test_func():
            passed += 1
        time.sleep(1)  # 避免请求过快
    
    print(f"\n📊 测试结果: {passed}/{total} 通过")
    
    if passed == total:
        print("🎉 所有测试通过！API服务正常")
        return 0
    else:
        print("❌ 部分测试失败，请检查服务状态")
        return 1

if __name__ == "__main__":
    sys.exit(main())
