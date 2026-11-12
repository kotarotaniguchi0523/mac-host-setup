# PLAN

## 未完了

1. **agent-desktop**: Windows 専用のため未導入（AUDIT.md）。
2. **CI の残り**（ci / flake-lock / mise-relock は作成済み）:
   - flake.lock の「2 日」を commit 日時ではなく channel の進行日時で判定する
   - vulnix の定期実行（誤検知は whitelist に根拠付きで登録）、APM の検証
3. **Skills（APM / skillspector）**: macOS での入手元を判定し、`skills-apply` 相当を `tools/` に用意。
4. **Nix installer の追加照合**: tarball の sha256 を Hydra のビルド成果物と照合する手順を追加。
5. **node 24 / python 3.14 の fallback**: Windows 版はグローバルに併設していた。macOS はグローバルに置かず、必要なプロジェクトで mise を使う。
