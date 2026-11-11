# mac-host-setup

**macOS ホストのグローバル導入を Nix（nix-darwin + home-manager）と mise で宣言し、検証可能にする**ための設定と手順。
`%GITHUB_USER%/win-host-setup` の macOS 版（Windows 版とは独立して運用する）。

| ファイル | 内容 |
|---|---|
| **`AGENTS.md`** | **選定基準（Nix / mise / GUI アプリ・検証レベル A–E・Pin・更新の運用）** |
| `AUDIT.md` | ツールごとの判定記録（`tools/compare-source.sh` の結果と根拠） |
| `PLAN.md` | 未完了の作業 |
| `flake.nix` / `flake.lock` | Nix の入力（nixpkgs / nix-darwin / home-manager）を rev + narHash で固定 |
| `hosts/darwin.nix` | システム設定（Nix の信頼設定・Homebrew 無効） |
| `home/` | ユーザー設定（Nix で入れる CLI、launchd の点検 agent） |
| `mise/mise.toml` / `mise/mise.lock` | mise のグローバル設定（`~/.config/mise/` へコピー） |
| `skills/` | APM の Skills 宣言（Windows 版と同じ） |
| `tools/` | 導入・点検・適用・比較のスクリプト |

## 初回セットアップ

```sh
git clone https://github.com/<you>/mac-host-setup.git ~/src/mac-host-setup
cd ~/src/mac-host-setup
tools/install-nix.sh          # upstream Nix（版と installer の sha256 を固定して検証）。sudo を聞かれる
# 新しいターミナルを開く
tools/update.sh --bootstrap   # nix-darwin + home-manager を適用 → mise を locked で導入 → check
mise trust . && mise install --locked && hk install   # このリポジトリ用のチェック（フック）
```

## 日々の運用

| 何を | どうやって |
|---|---|
| 版の更新 | GitHub 上で PR（Renovate / flake.lock 更新 workflow）→ CI → マージ。**ホストでは版を決めない** |
| 点検（自動・読み取りのみ） | launchd agent が毎日 08:30 に `tools/check.sh --notify`。結果は `.agent/update-report.json` |
| 適用（手動） | `tools/update.sh` — **`origin/main` で更新された内容だけ**を適用（ローカル変更・未 push があると中止） |
| 入手元の判定 | `tools/compare-source.sh <nixpkgs-attr> [<mise-tool>]` → `AUDIT.md` に記録 |
| リポジトリのチェック | `hk` の pre-commit / pre-push（`mise run lint` で全件） |

## CI（`.github/workflows/`）

中身はすべて `tools/` のスクリプトで、ローカルでも同じコマンドで再現できる。

| ワークフロー | 内容 |
|---|---|
| `ci.yml` | push / PR で **lint**（hk: betterleaks / shellcheck / pii / jactionlint / pinact）・**mise-lock**（`tools/ci/mise-lock.sh --check`）・**nix**（macOS ランナーで `tools/install-nix.sh` → `tools/ci/nix-check.sh`: nixfmt / flake check / システム全体のビルド） |
| `flake-lock.yml` | 週次。各 input を **2 日以上前の最新 commit** へ（`tools/ci/flake-lock-update.sh`）。ビルドしてから PR を作り、ci を起動 |
| `mise-relock.yml` | Renovate の PR で mise の lock を再生成して push し、ci を起動（Mend の Renovate は `mise lock` を実行できない） |
