# PLAN

## 未完了

1. **openclaw**: nixpkgs が insecure 指定（AUDIT.md）。入れるならユーザー判断で `permittedInsecurePackages` に名前指定。
2. **agent-desktop**: Windows 専用のため未導入（AUDIT.md）。
3. **暫定 gh の撤去**: Nix の gh が有効になったら `~/.local/bin/gh` を削除し、`gh auth setup-git` を Nix の gh で再実行
   （git の credential helper が `~/.local/bin/gh` の絶対パスを指しているため）。`~/.profile` の PATH 追加も外す。
4. **CI の残り**（ci / flake-lock / mise-relock は作成済み）:
   - 必須チェック（ruleset）と Renovate の automerge の復帰
   - flake.lock の「2 日」を commit 日時ではなく channel の進行日時で判定する
   - vulnix の定期実行（誤検知は whitelist に根拠付きで登録）、APM の検証
5. **Skills（APM / skillspector）**: macOS での入手元を判定し、`skills-apply` 相当を `tools/` に用意。
6. **Nix installer の追加照合**: tarball の sha256 を Hydra のビルド成果物と照合する手順を追加。
7. **node 24 / python 3.14 の fallback**: Windows 版はグローバルに併設していた。macOS はグローバルに置かず、必要なプロジェクトで mise を使う。
