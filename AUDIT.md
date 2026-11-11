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
| mise | 2026.10.17 | B | —（自身） | **Nix** | mise レーンの起点 |
| node | 26.13.0 (`nodejs_26`) | B | checksum, gpg（A） | **Nix**（A vs B） | 24 系はグローバルに置かない（プロジェクト単位で mise） |
| python | 3.15.0 (`python315`) | B | checksum, github_attestations（A） | **Nix**（A vs B） | Windows は 3.15.2。vulnix の結果で再判定（下記） |
| go | 1.27.3 (`go_1_27`) | B | checksum（C） | **Nix** | |
| rust | 1.99.0（rustc/cargo/clippy/rustfmt） | B | [none]（E） | **Nix** | Windows は rustup |
| rust-analyzer | 2026-11-02 | B | [none]（E） | **Nix** | Windows は winget |
| uv | 0.13.5 | B | checksum, github_attestations（A） | **Nix**（A vs B） | |
| pnpm | 12.9.0 | B | github_attestations（A） | **Nix**（A vs B） | Windows は 12.15.0 |
| gopls | 0.24.0 | B | — | **Nix** | |
| jq | 1.8.2 | B | checksum, github_attestations（A） | **Nix**（A vs B） | |
| jujutsu | 0.47.1 | B | checksum（C） | **Nix** | |
| nushell | 0.116.1 | B | checksum（C） | **Nix** | |
| betterleaks | 1.9.0 | B | checksum, cosign（A） | **Nix**（A vs B） | |
| doppler | 3.77.1 | B | checksum（C） | **Nix** | |
| dotenvx | 2.38.2 | B | checksum（C） | **Nix** | |
| textlint | 15.7.1 | B | npm | **Nix** | Windows は 15.8.0 |
| rtk | 1.1.0 | B | checksum（C） | **Nix** | |
| codex | 0.167.0 | B | npm | **Nix** | |
| opencode | 2.2.5 | B（fromSource） | npm | **Nix** | 上流は同じ anomalyco/opencode |
| pi | 1.5.0 (`pi-coding-agent`) | B | checksum（C） | **Nix** | 上流は同じ earendil-works/pi |
| agent-browser | 0.41.1 | B（fromSource） | npm | **Nix** | |
| ctx7 | 0.8.2 | B | npm | **Nix** | |

## mise で入れるもの（`mise/mise.toml`）

| ツール | 理由 | mise の Security |
|---|---|---|
| `aqua:k1LoW/mo` | nixpkgs の `mo` は別物（mustache の bash 実装、darwin 非対応） | checksum（C） |
| `github:microsoft/waza` | nixpkgs に無い | checksum（C） |
| `aqua:microsoft/tgrep` | nixpkgs に無い | checksum（C） |
| `github:init-co-jp/diff-tour` | nixpkgs に無い | checksum（C） |
| `npm:t3` | nixpkgs はデスクトップ版（`t3code-desktop`）のみ。CLI は npm | npm（Takumi Guard 経由） |
| `npm:secretlint` | nixpkgs に無い | npm（Takumi Guard 経由） |

## 入れないもの（報告）

| ツール | 理由 |
|---|---|
| herdr | nixpkgs に無く、mise も `[none]`（E）。AGENTS.md の規則 5 により推測で入れない（Windows 版でも既知の逸脱） |
| ax（`ubi:yusukebe/ax`） | nixpkgs に無く、mise も `[none]`（E）。同上 |
| agent-desktop | Windows のデスクトップ操作用（win32 バイナリ前提）。macOS で必要か要確認 |
| ghtkn | Windows の git credential helper。macOS は gh の期限付きトークン（`gh auth setup-git`）を使う |
| openclaw | nixpkgs が `knownVulnerabilities` で insecure 指定（「LLM で信頼できない内容を解釈しプロンプトインジェクションに脆弱、既定でシステム全体にアクセス」）。設計上の指摘で版では解消しないため、ユーザー判断待ち（許可する場合は `permittedInsecurePackages` に名前指定） |
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
