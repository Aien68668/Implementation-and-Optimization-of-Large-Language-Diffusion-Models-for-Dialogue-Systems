# -*- coding: utf-8 -*-
import json

# ===== 路径配置 =====
input_path = "/root/LLaDA-main/out/LLDA_arc_challenge1_test_nothink.res_extracted.res"
output_path = input_path + "_evaled.res"

# ===== 加载数据 =====
with open(input_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# ===== 逐条比对答案并写入结果 =====
correct = 0
total = 0
lines = []

for item in data:
    gt = item.get("ground_truth", "").strip().upper()
    pred = item.get("answer", "").strip().upper()

    if gt and pred:
        total += 1
        res = "yes" if gt == pred else "no"
        if res == "yes":
            correct += 1
        line = f"{gt} ⟷ {pred} → {res}"
        lines.append(line)

# ===== 保存输出文件 =====
with open(output_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

# ===== 打印准确率 =====
accuracy = correct / total if total > 0 else 0.0
print(f"Total: {total}, Correct: {correct}, Accuracy: {accuracy:.2%}")
