#!/usr/bin/env swift

import Foundation

// 讀取 `.env` 並載入環境變數
func loadEnv() {
    let envPath = ".env"
    guard let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) else {
        print("⚠️ 未找到 .env 檔案，請確認檔案是否存在")
        return
    }

    for line in envContent.split(separator: "\n") {
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            setenv(key, value, 1) // 設置環境變數
        }
    }
}

// 先讀取 `.env`
loadEnv()

// 獲取 API Key
let apiKey = ProcessInfo.processInfo.environment["OPEN_API_KEY_COMMIT"] ?? ""

if apiKey.isEmpty {
    print("❌ ERROR: 未設置 OPEN_API_KEY_COMMIT")
    exit(1)
}

// 執行 Shell 指令並獲取輸出
func runShellCommand(_ command: String) -> String {
    let process = Process()
    let pipe = Pipe()
    
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]
    process.standardOutput = pipe
    process.standardError = pipe
    
    let fileHandle = pipe.fileHandleForReading
    process.launch()
    
    let outputData = fileHandle.readDataToEndOfFile()
    return String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

// 取得 Git 差異內容
func getGitDiff() -> String {
    let changedFiles = runShellCommand("git diff --cached --name-only")
        .split(separator: "\n")
        .filter { !$0.isEmpty && !$0.contains(".min.") }
    
    if changedFiles.isEmpty {
        print("⚠️ No changes to commit.")
        return ""
    }

    print("📂 變更的檔案: \(changedFiles)")
    
    var diffText = ""
    for file in changedFiles {
        let diff = runShellCommand("git diff --cached -- \"\(file)\"")
        diffText += diff + "\n"
    }

    return String(diffText.prefix(4000)) // 限制 4000 字符
}

// 透過 OpenAI 生成 Commit 訊息
func generateCommitMessage(diff: String) -> String {
    let apiUrl = "https://api.chatanywhere.org/v1/chat/completions" // 修改為你自己的 API URL
    guard let url = URL(string: apiUrl) else { return "Refactor code." }
    
    let requestData: [String: Any] = [
        "model": "gpt-4o-mini",
        "messages": [
            ["role": "system", "content": "你是一個優秀的開發者，負責撰寫簡潔又描述清楚的 Git commit 訊息。"],
            ["role": "user", "content": "根據以下的 git 差異生成一個有意義的 commit 英文動詞開頭加繁體中文訊息，請包含兩個部分：\n1. 範例: [New|Update|Remove|Refactor|Fix|Misc]（不超過80字）\n\n Description:（條列描述變更內容）：\n\(diff)"]
        ]
    ]
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData, options: [])
    } catch {
        print("❌ JSON 序列化錯誤: \(error)")
        return "Refactor code."
    }
    
    let semaphore = DispatchSemaphore(value: 0)
    var commitMessage = "Refactor code."

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ API 錯誤: \(error)")
        } else if let data = data, 
                  let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let choices = jsonResponse["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String {
            commitMessage = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        semaphore.signal()
    }.resume()
    
    semaphore.wait()
    return commitMessage
}

// 🏁 主執行流程
let diff = getGitDiff()
if !diff.isEmpty {
    let commitMessage = generateCommitMessage(diff: diff)
    print("✨ Commit 訊息: \n\(commitMessage)")
}
