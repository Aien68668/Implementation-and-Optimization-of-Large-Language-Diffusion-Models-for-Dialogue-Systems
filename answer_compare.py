import sys
import json
import time
import requests
from tqdm import tqdm

# ==== 文件路径 ====
#src_path = "/root/LLaDA-main/out/LLDA_math500_test_nothink.res_extracted.res"
src_path = "/root/LLaDA-main/out/LLDA_gsm8k_test_nothink.res_extracted.res"

output_path = src_path + "_evaled.res"

# ==== 加载数据 ====
data = json.load(open(src_path, encoding="utf-8"))
out = open(output_path, "a+", encoding="utf-8")

all_item = []
for item in data:
    gt = item["ground_truth"]
    ans = item["answer"]
    if gt == ans:
        out.write(f"{gt} ⟷ {ans} → Yes\n")
    elif ans == "":
        out.write(f"{gt} ⟷ {ans} → No\n")
    else:
        all_item.append([gt, ans])

# ==== API配置 ====
url = "https://api.bltcy.ai/v1/chat/completions"
YOUR_API_KEY = "sk-KWo5sSuyR5wa5Uac87217f24Ed7d420099375a02F76e2dDb"

# ==== GPT比较函数（带重试与延时） ====
def match_with_gpt(item, retries=3, delay=2):
    prompt = r"""
        Look at the following two expressions (answers to a math problem) and judge whether they are equivalent. Only perform trivial simplifications

        Examples:

            Expression 1: $2x+3$
            Expression 2: $3+2x$
        Yes

            Expression 1: 3/2
            Expression 2: 1.5
        Yes

            Expression 1: $x^2+2x+1$
            Expression 2: $y^2+2y+1$
        No

            Expression 1: $x^2+2x+1$
            Expression 2: $(x+1)^2$
        Yes

            Expression 1: 3245/5
            Expression 2: 649
        No

            Expression 1: 2/(-3)
            Expression 2: -2/3
        Yes

            Expression 1: 72 degrees
            Expression 2: 72
        Yes

            Expression 1: 64
            Expression 2: 64 square feet
        Yes

        ---
        YOUR TASK

        Respond with only "Yes" or "No" (without quotes). Do not include a rationale.

            Expression 1: our_answer_1
            Expression 2: our_answer_2
    """

    prompt = prompt.replace("our_answer_1", item[0]).replace("our_answer_2", item[1])

    payload = json.dumps({
        "model": "gpt-4o-mini",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 2
    })

    headers = {
        'Authorization': f"Bearer {YOUR_API_KEY}",
        'Content-Type': 'application/json'
    }

    for attempt in range(retries):
        try:
            response = requests.post(url, headers=headers, data=payload, timeout=10)
            response.raise_for_status()
            res = json.loads(response.text)["choices"][0]["message"]["content"].strip()
            return res
        except Exception as e:
            print(f"[Retry {attempt+1}] Error for item {item}: {e}")
            time.sleep(delay * (attempt + 1))
    
    return "No"  # 保守处理

# ==== 串行处理（避免限流） ====
def process_serially():
    results = []
    for item in tqdm(all_item, desc="Evaluating"):
        res = match_with_gpt(item)
        out.write(f"{item[0]} ⟷ {item[1]} → {res}\n")
        print(f"{item[0]} ⟷ {item[1]} → {res}")
        time.sleep(1.2)  # 限流
        results.append((item[0], item[1], res))
    return results

# ==== 执行 ====
if __name__ == "__main__":
    process_serially()
    out.close()

    # ==== 准确率统计 ====
    with open(output_path, "r", encoding="utf-8") as res_data:
        all_res = [line.strip().split("→")[-1].strip() for line in res_data]

    yes = all_res.count("Yes")
    no = all_res.count("No")
    total = yes + no
    acc = yes / total if total > 0 else 0.0
    print(f"\n✅ Accuracy: {acc:.4f} ({yes}/{total})")
