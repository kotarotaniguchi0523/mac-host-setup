# PLAN

## 未完了

2. **CI の残り**（ci / flake-lock / mise-relock は作成済み）:
   - flake.lock の「2 日」を commit 日時ではなく channel の進行日時で判定する
   - vulnix の定期実行（誤検知は whitelist に根拠付きで登録）
3. **Skills の残り**（APM の配置・CI は作成済み）: skillspector の入手元判定。codex / opencode への配置を戻すかの判断。
4. **Nix installer の追加照合**: tarball の sha256 を Hydra のビルド成果物と照合する手順を追加。
5. **node 24 / python 3.14 の fallback**: Windows 版はグローバルに併設していた。macOS はグローバルに置かず、必要なプロジェクトで mise を使う。
