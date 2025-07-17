# -*- coding: utf-8 -*-
import os
import json
import re
import torch
from tqdm import trange
from generate import generate
from transformers import AutoModel, AutoTokenizer

# ========== 设置环境 ==========
device = 'cuda' if torch.cuda.is_available() else 'cpu'
print(f"Using device: {device}")
os.environ["CUDA_VISIBLE_DEVICES"] = "0"

# ========== 路径配置 ==========
src_zh_path = "/root/LLaDA-main/WMT23-test/zh2en/test.zh2en.zh"
ref_en_path = "/root/LLaDA-main/WMT23-test/zh2en/test.zh2en.en"
trg_path = "/root/LLaDA-main/out/LLDA_WMT23_test_nothink.res"
model_path = "/root/autodl-tmp/model"

# ========== 加载模型和 tokenizer ==========
tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
model = AutoModel.from_pretrained(
    model_path,
    trust_remote_code=True,
    torch_dtype=torch.bfloat16
).to(device)
model.eval()

if tokenizer.pad_token_id is None:
    tokenizer.pad_token = tokenizer.eos_token or tokenizer.unk_token
    tokenizer.pad_token_id = tokenizer.convert_tokens_to_ids(tokenizer.pad_token)

# ========== 加载测试数据 ==========
with open(src_zh_path, encoding="utf-8") as f:
    zh_lines = [line.strip() for line in f.readlines()]
with open(ref_en_path, encoding="utf-8") as f:
    en_refs = [line.strip() for line in f.readlines()]

assert len(zh_lines) == len(en_refs), "中英文件行数不一致！"

# ========== 初始化写文件 ==========
with open(trg_path, "w", encoding="utf-8") as f:
    f.write("[\n")
with open(trg_path + "_extracted.res", "w", encoding="utf-8") as f:
    f.write("[\n")

# ========== 执行翻译 ==========
for i in trange(len(zh_lines)):
    zh_text = zh_lines[i]
    en_gt = en_refs[i]

    # 强化 prompt，引导模型将翻译结果放入 \boxed{}
    prompt = (
    "Translate the following Chinese sentence into English.\n"
    "You must translate it as **literally and faithfully** as possible.\n"
    "Avoid paraphrasing or summarizing. Do not add or remove information.\n"
    "Output only the translated sentence, wrapped in \\boxed{}.\n\n"
    f"Chinese sentence:\n{zh_text}\n"
    "Output:"
    )


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
            mask_id=126336  # LLaDA 的 [MASK] token ID
        )

    prompt_len = input_ids.size(1)
    generated_ids = outputs[0, prompt_len:]
    generated_text = tokenizer.decode(generated_ids, skip_special_tokens=True).strip()
    full_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
    if not generated_text:
        generated_text = full_text.strip()

    # ========= 提取 \boxed{...} =========
    pattern = [r"boxed{(.*?)}", r"framebox{(.*?)}"]
    extracted_answer = ""
    try:
        for pat in pattern:
            matches = re.findall(pat, full_text, flags=re.MULTILINE)
            if matches:
                extracted_answer = matches[-1].strip(" .")
                break
    except Exception:
        extracted_answer = ""

    
    # ========== 写入结果 ==========
    item = {
        "problem": zh_text,
        "output": full_text,
        "generated_answer": generated_text,
        "ground_truth": en_gt,
        "answer": extracted_answer
    }

    comma = "," if i > 0 else ""
    json_str = json.dumps(item, ensure_ascii=False, indent=4)
    with open(trg_path, "a", encoding="utf-8") as f_out:
        f_out.write(comma + "\n" + json_str)
    with open(trg_path + "_extracted.res", "a", encoding="utf-8") as f_out:
        f_out.write(comma + "\n" + json_str)

    # 打印中间结果
    print(f"\n=== Example {i} ===")
    print(f"Chinese: {item['problem']}")
    print(f"Model Output: {item['output']}")
    print(f"Generated Answer: {item['answer']}")
    print(f"Reference: {item['ground_truth']}")

# ========== 写入结束符 ==========
with open(trg_path, "a", encoding="utf-8") as f:
    f.write("\n]\n")
with open(trg_path + "_extracted.res", "a", encoding="utf-8") as f:
    f.write("\n]\n")
