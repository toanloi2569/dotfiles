# Secret Scan for Dotfiles (Gitleaks + pre-commit)

Tập lệnh này khóa chặt việc lộ **secrets** trong repo dotfiles, kể cả trường hợp repo chứa **symlink** đến thư mục/file bên ngoài.

## Cài đặt nhanh

```bash
bash tools/secret-scan/install.sh
```

Script sẽ:

1. Cài `pre-commit` và `gitleaks` (nếu chưa có).
2. Cấp quyền thực thi cho `prepush-gitleaks.sh`.
3. Cài hook `pre-commit` và `pre-push` với cấu hình tại `tools/secret-scan/.pre-commit-config.yaml`.

## Cơ chế hoạt động

- **pre-commit**: chạy `gitleaks protect --staged` để chặn secret ngay từ lúc commit, giúp feedback nhanh và chỉ xét phần staging.
- **pre-push**: chạy `tools/secret-scan/prepush-gitleaks.sh`, script này:
  - quét toàn bộ repo bằng `gitleaks detect --no-git`.
  - tìm mọi symlink trong repo, resolve ra đích thực tế, rồi quét từng đích (kể cả thư mục ngoài repo) để tránh leak gián tiếp.

Nếu push bị chặn, sửa file có vấn đề rồi chạy lại `git push`.

## Chạy thủ công

- Quét toàn bộ repo bằng pre-commit:  
  `pre-commit run --all-files --config tools/secret-scan/.pre-commit-config.yaml`
- Chạy thẳng script pre-push (ví dụ trong CI):  
  `bash tools/secret-scan/prepush-gitleaks.sh`

## Tùy chỉnh gitleaks

- `tools/secret-scan/.gitleaks.toml`: định nghĩa rule cơ bản (AWS key, token entropy, Slack/GitHub token, private key, …) và allowlist cho file sinh tự động.
- Bạn có thể bổ sung rule/allowlist khác (ví dụ regex riêng, đường dẫn cần bỏ qua).
- Khi chỉnh file này, nên chạy `pre-commit run --all-files --config tools/secret-scan/.pre-commit-config.yaml` để kiểm tra lại.
