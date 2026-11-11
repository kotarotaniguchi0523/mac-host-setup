# PLAN

## 未完了

1. **Nix の導入**: `tools/install-nix.sh`（ユーザーが実行・sudo）→ `tools/update.sh --bootstrap`。
2. **flake.lock の生成**: Nix 導入後に `nix flake lock` で初回生成し、PR でコミット。
3. **ツールの判定**: Windows 版の CLI（gh, node, python, uv, pnpm, go, rust, jq, jj, nushell, betterleaks, doppler, dotenvx,
   mo, waza, rtk, tgrep, ax, secretlint, textlint, ctx7, agent-browser, openclaw, herdr, pi, opencode, codex, t3, gopls,
   diff-tour, skillspector, rust-analyzer, apm）を `tools/compare-source.sh` で判定し、`home/default.nix` か `mise/mise.toml` へ。
   Windows 専用（agent-desktop の win32 バイナリ、curl の上書き等）は対象外か再検討。
4. **`~/.local/bin/gh` の撤去**: gh を宣言へ移したあと削除し、`~/.zshenv` / `~/.profile` の PATH 追加も不要なら外す。
5. **CI の再構築**（現在 workflow なし。そのため Renovate の automerge は無効化中）:
   - `nix flake check` + `nix build` を macOS ランナーで
   - flake.lock 更新 workflow（2 日以上前の nixpkgs commit にだけ更新し PR）
   - mise relock、APM の検証、jactionlint / pinact / betterleaks
   - 必須チェックが揃ったら Renovate の automerge を戻す
6. **Skills（APM）**: macOS での APM の入手元を判定し、`skills-apply` 相当を `tools/` に用意。
7. **Nix installer の追加照合**: tarball の sha256 を Hydra のビルド成果物と照合する手順を追加。
8. **GitHub リポジトリ作成**: `mac-host-setup` を作成して push（公開範囲はユーザーが決める）。
