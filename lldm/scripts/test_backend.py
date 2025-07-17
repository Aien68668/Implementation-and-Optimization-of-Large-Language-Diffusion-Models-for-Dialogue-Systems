#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
后端服务测试工具
用于检测后端API的可用性和响应情况
"""

import sys
import requests
import json
import time

# 后端API地址
API_URL = "http://localhost:5000"

def test_health():
    """测试健康检查接口"""
    print("\n测试健康检查接口...")
    try:
        response = requests.get(f"{API_URL}/health", timeout=5)
        print(f"状态码: {response.status_code}")
        if response.status_code == 200:
            print(f"响应内容: {response.json()}")
            return True
        else:
            print(f"错误: 服务器返回非200状态码")
            return False
    except requests.exceptions.RequestException as e:
        print(f"错误: 无法连接到服务器 - {str(e)}")
        return False

def test_generate():
    """测试生成接口"""
    print("\n测试生成接口...")
    data = {
        "messages": [
            {"role": "user", "content": "你好，请简单介绍一下自己。"}
        ],
        "settings": {
            "temperature": 0.7,
            "top_p": 0.95,
            "gen_length": 50,
            "num_beams": 4
        }
    }
    
    try:
        response = requests.post(
            f"{API_URL}/generate", 
            json=data,
            timeout=30
        )
        
        print(f"状态码: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"响应内容摘要:")
            print(f"- 响应文本: {result.get('response', '无响应文本')[:100]}...")
            print(f"- 置信度: {result.get('confidence', '未提供')}")
            if 'visualization' in result:
                print(f"- 可视化步骤数: {len(result['visualization'])}")
            return True
        else:
            print(f"错误: 服务器返回非200状态码")
            print(f"响应内容: {response.text}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"错误: 请求异常 - {str(e)}")
        return False
    except json.JSONDecodeError:
        print(f"错误: 无法解析JSON响应")
        return False

def main():
    """主函数"""
    print("===== 后端服务测试工具 =====")
    print(f"API地址: {API_URL}")
    
    # 测试健康检查
    health_ok = test_health()
    
    # 测试生成接口
    generate_ok = test_generate()
    
    # 汇总结果
    print("\n===== 测试结果汇总 =====")
    print(f"健康检查接口: {'✅ 通过' if health_ok else '❌ 失败'}")
    print(f"生成接口: {'✅ 通过' if generate_ok else '❌ 失败'}")
    
    if not (health_ok and generate_ok):
        print("\n⚠️ 检测到问题，请检查后端服务日志以获取更多信息")
        return 1
    else:
        print("\n✅ 后端服务运行正常")
        return 0

if __name__ == "__main__":
    sys.exit(main())
