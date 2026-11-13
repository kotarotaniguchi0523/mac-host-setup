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
| `pkgs/` | 自前の Nix パッケージ（`mise-bin.nix`: mise の公式バイナリ。版と sha256 は `mise-bin.json`） |
| `mise/mise.toml` / `mise/mise.lock` | mise のグローバル設定（`~/.config/mise/` へコピー） |
| `skills/` | APM の Skills 宣言（`apm.yml` + `apm.lock.yaml`）。`tools/skills-apply.sh` が `~/.claude/skills/` へ配置 |
| `claude-plugins/` | Claude Code プラグインの宣言（ローカルのマーケットプレイス、各プラグインを commit SHA で固定）。`tools/plugins-apply.sh` が導入 |
| `tools/` | 導入・点検・適用・比較のスクリプト（共通処理は `tools/lib.sh`） |
| `exceptions.tsv` | 自己更新を認めた導入物（名前・Developer ID の Team・置き場所）。`tools/check.sh` が毎回検証 |

## 初回セットアップ

```sh
git clone https://github.com/<you>/mac-host-setup.git ~/ghq/github.com/<you>/mac-host-setup   # ghq の配置（ghq が入った後は ghq get）
cd ~/ghq/github.com/<you>/mac-host-setup
tools/install-nix.sh          # upstream Nix（版と installer の sha256 を固定して検証）。sudo を聞かれる
# 新しいターミナルを開く
tools/update.sh --bootstrap   # nix-darwin + home-manager を適用 → mise を locked で導入 → Skills を配置 → check
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
| `ci.yml` | push / PR で **skills**（`tools/ci/skills-lock.sh --check`: lock の一致・cold な frozen install・`apm audit`）・**lint**（hk: betterleaks / shellcheck / pii / jactionlint / pinact）・**mise-lock**（`tools/ci/mise-lock.sh --check`）・**nix**（macOS で `tools/install-nix.sh` → `tools/ci/nix-check.sh`: nixfmt / flake check / システム全体の評価） |
| `build.yml` | Nix の入力が変わる push / PR で**システム全体をビルド**（`tools/ci/nix-build.sh`）。必須チェックではない。cache.nixos.org に無いものは CI 専用の署名付きバイナリキャッシュ（Actions cache、鍵は `NIX_CACHE_SECRET_KEY`）に入れて次回から再利用 |
| `flake-lock.yml` | 週次。各 input を **2 日以上前の最新 commit** へ（`tools/ci/flake-lock-update.sh`）。ビルドしてから PR を作り、ci を起動。必須チェックが通れば自動マージ（auto-merge） |
| `.github/actions/setup-mise` | CI の mise（`pkgs/mise-bin.json` の版 = ホストと同じ） |
| `mise-bin.yml` | 週次。mise の公式リリース（2 日以上前の最新）を **GitHub attestation + GPG 署名**で検証して `pkgs/mise-bin.json` を更新し、lock も作り直して PR。必須チェックが通れば自動マージ |
| `skills-relock.yml` | Renovate の PR で `skills/apm.lock.yaml` を再生成して push し、ci を起動 |
| `mise-relock.yml` | Renovate の PR で mise の lock を再生成して push し、ci を起動（Mend の Renovate は `mise lock` を実行できない） |

## GitHub の設定（Windows 版と同等）

| 項目 | 設定 |
|---|---|
| `main` の保護 | 必須チェック `lint` / `mise-lock` / `nix`（`build` は必須外）、linear history、force push・削除の禁止（管理者は直接 push 可） |
| マージ | squash / rebase のみ（merge commit なし）、auto-merge 可、マージ後にブランチ削除 |
| Actions | GitHub 製と `jdx/mise-action` のみ許可、**SHA 固定を必須**、workflow の既定権限は read |
| セキュリティ | secret scanning + push protection、Dependabot アラート、private vulnerability reporting |
| Renovate | minor / patch と脆弱性修正は必須チェックが通れば自動マージ。major と pin / digest は手動 |
