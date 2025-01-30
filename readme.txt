這個錯誤表示您的 Python 環境中沒有安裝 `requests` 套件。請執行以下命令來安裝它：

```sh
pip install requests python-dotenv
```

如果您使用的是 `pip3`，請執行：
```sh
pip3 install requests python-dotenv
```

---

### 確認安裝是否成功：
安裝完成後，您可以測試是否正確安裝 `requests`：
```sh
python3 -c "import requests; print('requests installed successfully')"
```

如果沒有錯誤，表示 `requests` 已成功安裝。

---

### 重新運行 `commit.py`
安裝完成後，請再次執行：
```sh
python3 commit.py
```

如果還有其他問題，請告知錯誤訊息，我會協助您解決！

同目錄下放
.env: 
OPEN_API_KEY_COMMIT={sk-......chatgpt api的token}

===
也有nodejs版大同小異
