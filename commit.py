import os
import subprocess
import requests
from dotenv import load_dotenv

# 加載 .env 環境變數
load_dotenv()

# 使用 OpenAI API Key
API_KEY = os.getenv("OPEN_API_KEY_COMMIT")
API_URL = "https://api.chatanywhere.org/v1/chat/completions"  # 要改成自己用的 URL

# 取得 Git 差異內容
def get_git_diff():
    try:
        # 獲取所有已 staged 的檔案
        changed_files = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            capture_output=True,
            text=True,
            check=True
        ).stdout.strip().split("\n")

        changed_files = [file for file in changed_files if file and ".min." not in file]

        if not changed_files:
            print("No files changed.")
            return ""

        print("判斷檔案：", changed_files)

        # 取得這些檔案的 diff 內容
        diffs = []
        for file in changed_files:
            try:
                diff_output = subprocess.run(
                    ["git", "diff", "--cached", "--", file],
                    capture_output=True,
                    text=True,
                    check=True
                ).stdout
                diffs.append(diff_output)
            except subprocess.CalledProcessError as e:
                print(f"Error getting diff for file {file}: {e}")
                continue

        diff_text = "\n".join(diffs)

        # 限制 diff 內容不超過 4000 字符
        return diff_text[:4000]  # 預留部分空間給 API 使用
    except subprocess.CalledProcessError as e:
        print("Error fetching git diff:", e)
        return ""

# 使用 OpenAI API 生成 commit 訊息
def generate_commit_message(diff_text):
    if not API_KEY:
        print("Error: OPEN_API_KEY_COMMIT is not set in .env file.")
        return "Refactor code."

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "gpt-4o-mini",  # 使用 GPT-4 模型
        "messages": [
            {"role": "system", "content": "你是一個優秀的開發者，負責撰寫簡潔又描述清楚的 Git commit 訊息, 和建議並檢查變數命名是否有swift規範(小駝峰命名法:第1個字為小寫駝峰)。"},
            {"role": "user", "content": f"根據以下的 git 差異生成一個有意義的 commit 英文動詞開頭加繁體中文訊息和建議，請包含3部分：\n 範例: [New|Update|Remove|Refactor|Fix|Misc]（不超過80字）\n\n Description:（條列描述變更內容）：\n{diff_text}\n\n Suggest :\n [⚠️) 駝峰檢查], 檔案:L行 ==> 變數"}
        ]
    }

    try:
        response = requests.post(API_URL, json=payload, headers=headers)
        response.raise_for_status()  # 如果發生 HTTP 錯誤會丟出異常:
        data = response.json()

        commit_message = data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()
        return commit_message if commit_message else "Refactor code."
    except requests.exceptions.RequestException as e:
        print("Error generating commit message:", e)
        return "Refactor code."

# 主執行流程
def main():
    diff = get_git_diff()
    if not diff:
        print("No changes to commit.")
        return

    commit_message = generate_commit_message(diff)
    print(commit_message)

if __name__ == "__main__":
    main()

