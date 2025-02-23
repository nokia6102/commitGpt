/*
(MacOS)
brew install node
node -v
npm install axios
npm install dotenv
 */

const axios = require('axios');
const { execSync } = require("child_process");
require('dotenv').config();

// 使用 OpenAI API Key
const apiKey = process.env.OPEN_API_KEY_COMMIT;
const apiUrl = 'https://api.chatanywhere.org/v1/chat/completions';  // 要改成自己用 url

// 取得 git 差異內容
function getGitDiff() {
  try {
    // 獲取所有更改的檔案列表
    const changedFiles = execSync("git diff --cached --name-only", { encoding: "utf-8" })
      .split('\n')
      .filter(file => file && !file.includes('.min.') && file.trim() !== '');

    console.log('判斷檔案：', changedFiles);

    // 然後只對這些檔案執行 git diff
    const diff = changedFiles.map(file => {
      try {
        return execSync(`git diff --cached -- "${file}"`, { encoding: "utf-8" });
      } catch (error) {
        console.error(`Error getting diff for file ${file}:`, error);
        return '';
      }
    }).join('\n');

    // 將 diff 限制到 4096 字符以內
    return diff.substring(0, 4000); // 預留部分空間給其他內容
  } catch (error) {
    console.error("Error fetching git diff:", error);
    return "";
  }
}

// 使用 axios 調用 OpenAI 生成 commit 訊息
async function generateCommitMessage(diff) {
  try {
    const response = await axios.post(apiUrl, {
      model: "gpt-4o-mini", // 使用 GPT-4 模型
      messages: [
        {
          role: "system",
          content: "你是一個優秀的開發者，負責撰寫簡潔又描述清楚的 Git commit 訊息, 和建議並檢查變數命名是否有swift規範(小駝峰命名法:第1個字為小寫駝峰)。",
        },
        {
          role: "user",
          content: `根據以下的 git 差異生成一個有意義的 commit 英文動詞開頭加繁體中文訊息和建議，請包含3部分：\n 範例: [New|Update|Remove|Refactor|Fix|Misc]（不超過80字）\n\n Description:（條列描述變更內容）：\n${diff}\n\n Suggest :\n [⚠️) 駝峰檢查], 檔案:L行 ==> 變數`,
        },
      ],
    }, {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    });

    const commitMessage = Array.isArray(response.data.choices) && response.data.choices.length > 0 ? response.data.choices[0].message.content.trim() : "Default commit message.";
    return commitMessage; // 回傳完整的 commit 訊息
  } catch (error) {
    console.error("Error generating commit message:", error.response ? error.response.data : error.message);
    return "Refactor code."; // 如果發生錯誤，回傳一個預設的 commit 訊息
  }
}

// 主執行流程
async function main() {
  const diff = getGitDiff();
  if (!diff) {
    console.log("No changes to commit.");
    return;
  }
  const commitMessage = await generateCommitMessage(diff);
  console.log(commitMessage);
}

main();
