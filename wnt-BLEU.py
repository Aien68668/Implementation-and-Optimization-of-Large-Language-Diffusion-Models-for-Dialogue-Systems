# -*- coding: utf-8 -*-
import json
from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction

# ========== 输入输出路径 ==========
input_path = "/root/LLaDA-main/out/LLDA_WMT23_test_nothink.res_extracted.res"
output_path = input_path + "_evaled.res"

# ========== 读取数据 ==========
with open(input_path, encoding="utf-8") as f:
    data = json.load(f)

# ========== BLEU 评分 ==========
smoothie = SmoothingFunction().method4  # 推荐平滑方法
filtered_data = []
bleu_scores = []

for item in data:
    ref = item.get("ground_truth", "").strip()
    hyp = item.get("answer", "").strip()

    if ref and hyp:
        reference = [ref.split()]
        hypothesis = hyp.split()
        bleu = sentence_bleu(reference, hypothesis, smoothing_function=smoothie)
    else:
        bleu = 0.0

    bleu = round(bleu, 4)
    bleu_scores.append(bleu)

    filtered_data.append({
        "ground_truth": ref,
        "answer": hyp,
        "bleu": bleu
    })

# ========== 保存结果 ==========
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(filtered_data, f, ensure_ascii=False, indent=4)

# ========== 输出平均 BLEU ==========
avg_bleu = sum(bleu_scores) / len(bleu_scores) if bleu_scores else 0.0
print(f"保存完成：{output_path}")
print(f"平均 BLEU 分数：{round(avg_bleu, 4)}")
