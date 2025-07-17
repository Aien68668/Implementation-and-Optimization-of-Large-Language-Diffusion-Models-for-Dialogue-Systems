# -*- coding: utf-8 -*-
import os
import json
import re
import torch
from tqdm import trange
from generate import generate  # 你自定义的generate函数
from transformers import AutoModel, AutoTokenizer

# ========== 设置环境 ==========
device = 'cuda' if torch.cuda.is_available() else 'cpu'
print(f"Using device: {device}")
os.environ["CUDA_VISIBLE_DEVICES"] = "0"

# ========== 路径配置 ==========
src_path = "/root/LLaDA-main/data/HuggingFaceH4/truthful_qa_validation.jsonl"
trg_path = "/root/LLaDA-main/out/LLDA_truthful_qa_test_nothink.res"
model_path = "/root/autodl-tmp/model"

# ========== 加载模型和 tokenizer ==========
tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
model = AutoModel.from_pretrained(
    model_path,
    trust_remote_code=True,
    torch_dtype=torch.bfloat16
).to(device)
model.eval()

# 设置 pad_token_id，避免警告
if tokenizer.pad_token_id is None:
    if tokenizer.eos_token_id is not None:
        tokenizer.pad_token = tokenizer.eos_token
        tokenizer.pad_token_id = tokenizer.eos_token_id
    else:
        tokenizer.pad_token = tokenizer.unk_token
        tokenizer.pad_token_id = tokenizer.convert_tokens_to_ids(tokenizer.pad_token)

# ========== 加载题目 ==========
with open(src_path, encoding="utf-8") as src:
    src_lines = src.readlines()

prompts = []
for line in src_lines:
    obj = json.loads(line)
    prompt = (
    f"Given the following question, provide a detailed and accurate answer.\n"
    f"Question: {obj['problem']}\n"
    f"Explain your reasoning step by step if needed.\n"
    f"At the end, output the final answer inside \\boxed{{}}.\n"
    f"Do not include any extra explanation after the boxed answer.\n"
    )

    prompts.append(prompt)

pattern = [r"boxed{(.*)}", r"framebox{(.*)}"]

# ========== 初始化写文件 ==========
with open(trg_path, "w", encoding="utf-8") as f:
    f.write("[\n")
with open(trg_path + "_extracted.res", "w", encoding="utf-8") as f:
    f.write("[\n")

# ========== 推理与结果写入 ==========
for i in trange(len(prompts)):
    prompt = prompts[i]
    inputs = tokenizer(prompt, return_tensors="pt").to(device)
    input_ids = inputs["input_ids"]

    with torch.no_grad():
        outputs = generate(
            model=model,
            prompt=input_ids,
            steps=128,
            gen_length=128,
            block_length=32,
            temperature=0.75,
            cfg_scale=0.0,
            remasking='low_confidence',
            mask_id=126336
        )

    prompt_len = input_ids.size(1)
    generated_ids = outputs[0, prompt_len:]
    generated_text = tokenizer.decode(generated_ids, skip_special_tokens=True).strip()
    full_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
    if not generated_text:
        generated_text = full_text.strip()

    obj = json.loads(src_lines[i])
    extracted_answer = ""
    try:
        for pat in pattern:
            matches = re.findall(pat, full_text, flags=re.MULTILINE)
            if matches:
                extracted_answer = matches[-1].strip(" .")
                break
    except Exception:
        extracted_answer = ""

    item = {
        "problem": obj.get("problem", ""),
        "ground_truth": obj.get("answer", ""),
        "correct_answers": obj.get("correct_answers", []),
        "incorrect_answers": obj.get("incorrect_answers", []),
        "output": full_text,
        "generated_answer": generated_text,
        "answer": extracted_answer
    }

    # 写入 JSON 数组格式
    comma = "," if i > 0 else ""
    json_str = json.dumps(item, ensure_ascii=False, indent=4)
    with open(trg_path, "a", encoding="utf-8") as f_out:
        f_out.write(comma + "\n" + json_str)
    with open(trg_path + "_extracted.res", "a", encoding="utf-8") as f_out:
        f_out.write(comma + "\n" + json_str)

    # 打印结果
    print(f"\n=== Example {i} ===")
    print(f"Problem: {item['problem']}")
    print(f"Output: {item['output']}")
    print(f"Extracted Answer: {item['answer']}")
    print(f"Ground Truth: {item['ground_truth']}")

# ========== 结束数组 ==========
with open(trg_path, "a", encoding="utf-8") as f:
    f.write("\n]\n")
with open(trg_path + "_extracted.res", "a", encoding="utf-8") as f:
    f.write("\n]\n")
