# AUDIT — 入手元の判定記録

判定基準は `AGENTS.md`（検証レベル A–E。基本は Nix、mise が明確に上回れば mise）。
調査日: 2026-11-11。nixpkgs = `nixpkgs-unstable` @ `4fe25e12`（flake.lock）。mise 側は mise 2026.11.4（GitHub Attestation で検証した一時バイナリ）の `mise tool` で確認。

nixpkgs の `meta.sourceProvenance` が未設定のパッケージは、nixpkgs の規約によりソースからのビルド（fromSource）として扱う（= レベル B）。

## 基盤

| 対象 | 入手元 | 版（Pin） | 検証 | 根拠・既知の制限 |
|---|---|---|---|---|
| Nix 本体 | releases.nixos.org（upstream 公式 installer） | 2.35.6 | installer sha256 を `tools/install-nix.sh` に固定 + installer 内蔵の tarball sha256 | 2.35.x は `.asc`（GPG 署名）が公開されていないため、固定ハッシュは公式配布元からの TOFU。Hydra との照合は未実施（PLAN.md） |
| nixpkgs | GitHub `nixpkgs-unstable` | `flake.lock`（rev + narHash） | narHash | 2 日以上前の commit に固定（commit 日時で判定） |
| nix-darwin / home-manager | GitHub `master` | `flake.lock`（rev + narHash） | narHash | 同上 |

## Nix で入れるもの（`home/default.nix`）

| ツール | nixpkgs 版 | Nix | mise の Security | 判定 | 備考 |
|---|---|---|---|---|---|
| gh | 2.103.3 | B | checksum, github_attestations（A） | **Nix**（A vs B） | 暫定の `~/.local/bin/gh` は撤去する |
| mise | 2026.11.5（`pkgs/mise-bin.nix`） | **A**（公式リリースバイナリ。GitHub attestation + GPG 署名付き SHASUMS256 を `tools/ci/mise-bin-update.sh` で検証してから版と sha256 を固定、Nix が fetchurl で再検証） | —（自身） | **Nix（公式バイナリ）** | nixpkgs の `mise` は約 3 週間遅れ（nixpkgs 自体が未追従）のため置き換え（2026-11-12）。週次 `mise-bin.yml` が 2 日以上前の最新へ更新 PR |
| node | 26.13.0 (`nodejs_26`) | B | checksum, gpg（A） | **Nix**（A vs B） | 24 系はグローバルに置かない（プロジェクト単位で mise） |
| python | 3.15.0 (`python315`) | B | checksum, github_attestations（A） | **Nix**（A vs B） | Windows は 3.15.2。vulnix の結果で再判定（下記） |
| go | 1.27.3 (`go_1_27`) | B | checksum（C） | **Nix** | |
| rust | 1.99.0（rustc/cargo/clippy/rustfmt） | B | [none]（E） | **Nix** | Windows は rustup |
| rust-analyzer | 2026-11-02 | B | [none]（E） | **Nix** | Windows は winget |
| uv | 0.13.5 | B | checksum, github_attestations（A） | **Nix**（A vs B） | |
| gopls | 0.24.0 | B | — | **Nix** | |
| jq | 1.8.2 | B | checksum, github_attestations（A） | **Nix**（A vs B） | |
| jujutsu | 0.47.1 | B | checksum（C） | **Nix** | |
| nushell | 0.116.1 | B | checksum（C） | **Nix** | |
| betterleaks | 1.9.0 | B | checksum, cosign（A） | **Nix**（A vs B） | |
| rtk | 1.1.0 | B | checksum（C） | **Nix** | |
| pi | 1.5.0 (`pi-coding-agent`) | B | checksum（C） | **Nix** | 上流は同じ earendil-works/pi |
| agent-browser | 0.41.1 | B（fromSource） | npm | **Nix** | |
| lefthook | 2.2.2 | B | checksum, github_attestations（A） | **Nix**（A vs B） | sbx-setup の Git hooks（ホストで動く）。上流の最新と同じ版（2026-11-12） |
| sbx（`docker-sbx`） | 0.50.1 | C（Docker 公式の署名済み tarball を固定 hash で取得、unfree） | 登録なし | **Nix** | Docker Sandboxes の CLI（sbx-setup がホストで使う）。公式の推奨は Homebrew（禁止）。上流 0.53.0、新しい版の公開から 9 日（2026-11-12）。ビルド中の版確認だけ外している（`home/default.nix`）。check.sh が Sbx.app の Docker 署名（Team `9BNSXJN65R`）を確認 |

## mise で入れるもの（`mise/mise.toml`）

| ツール | 理由 | mise の Security |
|---|---|---|
| `aqua:k1LoW/mo` | nixpkgs の `mo` は別物（mustache の bash 実装、darwin 非対応） | checksum（C） |
| `github:microsoft/waza` | nixpkgs に無い | checksum（C） |
| `aqua:microsoft/tgrep` | nixpkgs に無い | checksum（C） |
| `github:init-co-jp/diff-tour` | nixpkgs に無い | checksum（C） |
| `npm:t3` | T3 Code の CLI。nixpkgs の `t3code`（0.1.6）は上流 0.1.8 から 1,169 commit 遅れていたため不採用（2026-11-12） | npm SLSA provenance（Takumi Guard 経由） |
| `npm:agent-desktop` | nixpkgs に無い。macOS 対応（npm の os に darwin）。postinstall で同梱バイナリを link するため `allow_builds` で本パッケージのみ許可 | npm SLSA provenance（Takumi Guard 経由） |
| `pnpm` | nixpkgs は 12.9.0 のまま 39 日未追従（2026-11-12 移行） | github_attestations（A） |
| `npm:textlint` | nixpkgs は 15.7.1 のまま 102 日未追従（2026-11-12 移行） | npm SLSA provenance（aube が導入時に検証） |
| `github:h4ckf0r0day/obscura` | nixpkgs は 0.2.2 のまま 53 日未追従。上流に checksums / attestation は無い（E）が、ユーザー承認（2026-11-12）。mise.lock の sha256 は GitHub のアセット digest と一致を確認（macos-arm64 / linux-x64） | lock のハッシュ固定のみ（E） |
| `npm:secretlint` | nixpkgs に無い | npm（Takumi Guard 経由） |
| `github:yusukebe/ax` | nixpkgs に無い。`ubi:` は検証なし（E）、`github:` は公開 `checksums.txt` で検証（C）。ユーザー承認（2026-11-11） | checksum（C） |

## 入れないもの（報告）

| ツール | 理由 |
|---|---|
| herdr | 使わない（ユーザー判断、2026-11-11）。参考: nixpkgs に無く、mise も `[none]`（E） |
| doppler / dotenvx / codex / opencode | 使わない（ユーザー判断、2026-11-12）。doppler / dotenvx は秘密情報を 1Password で扱うため |
| ghtkn | Windows の git credential helper。macOS は gh の期限付きトークン（`gh auth setup-git`）を使う |
| openclaw | 使わない（ユーザー判断、2026-11-11）。参考: nixpkgs が insecure 指定（プロンプトインジェクション、既定でシステム全体にアクセス） |
| ctx7 | 使わない（ユーザー判断、2026-11-12） |
| apm / skillspector | Skills レーン（PLAN.md）で別途判定 |

## 既知の脆弱性（vulnix、2026-11-11）

`vulnix` でシステムの閉包（system closure）を調べた結果、50 件の derivation が該当した。**採用したツール本体に、mise 側の版で修正済みの実在する CVE は無かった**ため、判定 3（CVE があれば mise）による変更は無い。

| 該当 | 内容 | 扱い |
|---|---|---|
| cargo 1.99.0（7 件） | MediaWiki の Cargo 拡張の CVE（名前の衝突） | 誤検知 |
| git 2.56.0（6 件） | Jenkins Git Plugin の CVE（名前の衝突） | 誤検知 |
| codex 0.167.0 | 別製品「Codex」（ノートアプリ）の XSS | 誤検知 |
| go 1.27.3 | ecies（Go のライブラリ）の CVE | 誤検知 |
| jq 1.8.2 | CVE-2026-44777 は「1.8.2rc1 以前」 | 1.8.2 正式版は対象外（mise 側も同じ版） |
| Haskell ライブラリ（network / warp / vault / safe / yaml 等） | 同名の別製品の CVE | 誤検知（ビルド時依存） |
| ShellCheck 0.11.0 | CVE-2021-28794（VS Code 拡張） | 誤検知 |

生データは `.agent/vulnix.json`（ローカルのみ）。CI 再構築時に定期実行し、誤検知は vulnix の whitelist に根拠付きで登録する（PLAN.md）。

## 既知の野良（宣言の外にある導入物）

このセッション以前から入っていたもの。`tools/check.sh` が毎回報告する。PATH は `home/default.nix` で維持している。

なし（2026-11-12。Docker Desktop は例外へ移した）。

## 例外（自己更新を認めるもの）

AGENTS.md の「ホスト側で版を決めない」の例外。**公式が推奨する導入方法が自己更新を前提**としているため、ユーザー判断で認める。
一覧の実体は `exceptions.tsv`（名前・Team ID・置き場所）。`tools/check.sh` が毎回、**置き場所**と **Apple 発行の Developer ID 証明書 + Team ID**（`codesign -R` の要件 1 つ）を検証し、外れたら通知する（野良としては報告しない）。

| もの | 場所 | 検証（check.sh が毎回確認） | 判断 |
|---|---|---|---|
| T3 Code（デスクトップ） | `/Applications/T3 Code (Beta).app`（公式 DMG、自己更新） | アプリ本体の `codesign --verify --deep --strict -R`（Apple 発行の Developer ID、Team `ARK85ZXQ4Z` = T3 Tools, Inc.）、公証済み | 例外として承認（2026-11-12）。nixpkgs 版は 0.1.6 で 1,169 commit 遅れ、機能差が大きい。CLI は mise `npm:t3` |
| Kanary（CLI） | `~/.local/bin/kanary` → `/Applications/Kanary.app/Contents/Helpers/kanary`（公式アプリ同梱、アプリと一緒に自己更新） | 置き場所、`codesign --verify --strict -R`（Apple 発行の Developer ID、Team `KBU2LK9533` = Kentaro Ejima）、公証済み | 例外として承認（2026-11-12）。リンクが AppTranslocation（一時領域）を指していたため `/Applications` 側へ張り直し |
| Docker Desktop | `/Applications/Docker.app`（公式 DMG、自己更新。CLI は `~/.docker/bin`） | アプリ本体の `codesign --verify --deep --strict -R`（Apple 発行の Developer ID、Team `9BNSXJN65R` = Docker Inc） | 例外として承認（2026-11-12）。sbx-setup がテンプレートを `docker buildx` でビルドするために必要 |
| Claude Code | `~/.local/bin/claude` → `~/.local/share/claude/versions/*`（公式ネイティブインストーラー、自己更新） | 実体が `~/.local/share/claude/versions/*` にあること、`codesign --verify --strict -R`（Apple 発行の Developer ID、Team `Q6L2SF6YDW` = Anthropic PBC） | 例外として承認（2026-11-11）。代替案: nixpkgs `claude-code`（固定できるが更新が遅れる）、`DISABLE_AUTOUPDATER` で版をリポジトリ管理（手間） |

## Nix の版の遅れ（2026-11-12 時点、flake.lock = nixpkgs-unstable @ 2026-11-06）

「最新」は上流の最新リリース（`mise latest`。公開 2 日未満を含む）。flake.lock は週次の flake-lock workflow で 2 日以上前の commit へ進む。

| ツール | Nix | 最新 | 遅れ |
|---|---|---|---|
| gh / gopls / jq / jujutsu | 2.103.3 / 0.24.0 / 1.8.2 / 0.47.1 | 同じ | なし |
| node | 26.13.0 | 26.13.1 | patch 1 |
| python | 3.15.0 | 3.15.2 | patch 2（vulnix で該当 CVE なし） |
| go | 1.27.3 | 1.27.4 | patch 1 |
| rust | 1.99.0 | 1.99.1 | patch 1 |
| uv | 0.13.5 | 0.13.7 | patch 2 |
| pi | 1.5.0 | 1.5.2 | patch 2 |
| rust-analyzer | 2026-11-02 | 2026-11-09 | 1 週 |
| nushell / betterleaks / textlint / rtk / agent-browser | 0.116.1 / 1.9.0 / 15.7.1 / 1.1.0 / 0.41.1 | 0.117.0 / 1.10.0 / 15.8.0 / 1.2.0 / 0.42.0 | minor 1 |
| mise | 2026.10.17 | 2026.11.6 | 約 3 週 |
| pnpm | 12.9.0 | 12.18.0 | minor 9 |
| T3 Code（参考・廃止） | 0.1.6 | 0.1.9 | 1,169 commit 以上 → 公式 DMG（例外）へ |

大半は patch〜minor 1 の遅れで、AGENTS.md の判定（同レベル・A vs B は Nix）を変える理由はない。pnpm / mise は遅れが大きいが、
既知の CVE（判定 3）には当たらないため Nix のまま。機能差で困るものが出たら、T3 Code と同様に個別に再判定する。

## npm ツールの導入時検証（2026-11-12）

mise 2026.10.17 では npm: ツールを pnpm で導入しており、**導入時に npm の provenance は検証されていなかった**。
mise 2026.11.5 は paranoid 下で pnpm を拒否する（provenance を検証できないため）。`[settings.npm] package_manager` を
組み込みの **aube** に変更し、Takumi Guard（`npm.flatt.tech`）経由で provenance を検証して導入できることを確認した
（npm:t3 / agent-desktop / secretlint / textlint）。
