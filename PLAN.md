# PLAN

## 未完了

1. **openclaw**: nixpkgs が insecure 指定（AUDIT.md）。入れるならユーザー判断で `permittedInsecurePackages` に名前指定。
2. **herdr / ax / agent-desktop**: 検証なし（E）または Windows 専用のため未導入（AUDIT.md）。必要なら自前 derivation を検討。
3. **暫定 gh の撤去**: Nix の gh が有効になったら `~/.local/bin/gh` を削除し、`gh auth setup-git` を Nix の gh で再実行
   （git の credential helper が `~/.local/bin/gh` の絶対パスを指しているため）。`~/.profile` の PATH 追加も外す。
4. **CI の再構築**（現在 workflow なし。そのため Renovate の automerge は無効化中）:
   - `nix flake check` + `nix build` を macOS ランナーで
   - flake.lock 更新 workflow（2 日以上前の commit にだけ更新し PR。現在は commit 日時で判定しているが、
     channel の進行日時で判定する方が正確）
   - mise relock（`mise/mise.lock`、`mise.lock`）、APM の検証、jactionlint / pinact / betterleaks
   - 必須チェックが揃ったら Renovate の automerge を戻す
5. **Skills（APM / skillspector）**: macOS での入手元を判定し、`skills-apply` 相当を `tools/` に用意。
6. **Nix installer の追加照合**: tarball の sha256 を Hydra のビルド成果物と照合する手順を追加。
7. **node 24 / python 3.14 の fallback**: Windows 版はグローバルに併設していた。macOS はグローバルに置かず、必要なプロジェクトで mise を使う。
