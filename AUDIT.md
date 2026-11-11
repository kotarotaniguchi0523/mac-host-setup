# AUDIT — 入手元の判定記録

判定基準は `AGENTS.md`（検証レベル A–E、基本は Nix、明確に上回れば mise）。
各行は `tools/compare-source.sh` の出力を根拠にする。

## 基盤

| 対象 | 入手元 | 版（Pin） | 検証 | 根拠・既知の制限 |
|---|---|---|---|---|
| Nix 本体 | releases.nixos.org（upstream 公式 installer） | 2.35.6 | installer sha256 を `tools/install-nix.sh` に固定 + installer 内蔵の tarball sha256 | 2.35.x は `.asc`（GPG 署名）が公開されていないため、固定ハッシュは公式配布元からの TOFU。Hydra との照合は未実施（PLAN.md） |
| nixpkgs / nix-darwin / home-manager | GitHub（flake inputs） | `flake.lock` の rev + narHash | narHash（内容ハッシュ） | 26.05 系の stable ブランチ |

## CLI（判定待ち）

Windows 版の `mise/mise.toml` にあったツールを、Nix 導入後に `tools/compare-source.sh` で判定する（PLAN.md）。

| ツール | Nix | mise | 判定 | 根拠 |
|---|---|---|---|---|
| mise | ? | — | Nix（暫定・ブートストラップ用） | 判定待ち |
| gh | ? | ? | — | 現在の `~/.local/bin/gh`（2.103.3、GitHub Release + checksums で手動導入）は暫定。判定後に宣言へ移して削除 |
