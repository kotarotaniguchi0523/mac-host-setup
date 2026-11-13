# AGENTS.md: macOS Package Management Policy

macOS ホストへのソフトウェア導入・更新では、**サプライチェーンセキュリティ・配布元の真正性・最小権限・再現性**を優先する。
対象は **macOS 本体のグローバル導入のみ**（プロジェクトローカル、エディタ/ブラウザ拡張、VM/コンテナ内部は対象外）。

## 禁止

- **Homebrew（formula / cask / nix-darwin の `homebrew` モジュール）と MacPorts は使わない。**
- **検証なしの `curl | sh` は使わない。** 例外は Nix 本体の導入のみで、`tools/install-nix.sh`（版とハッシュを固定）を経由する。
- **命令的なグローバル導入はしない**: `nix profile install` / `nix-env -i` / `npm -g` / `uv tool install` / `go install` / `/usr/local/bin` への直置き。
  導入は必ず「宣言」（`flake.nix` 配下 / `mise/mise.toml`）に書く。宣言の外にあるものは「野良」として扱う。
- **ホスト側で版を決めない**: `mise upgrade` / `mise use` / `nix flake update` / ツール自身の self-update をホストで実行しない。
  版の更新は GitHub 上の PR（Renovate / CI）でのみ行う。
  例外は `AUDIT.md`「例外」に載せたもの（公式が自己更新を前提とし、`tools/check.sh` が署名・Team ID・公証を毎回検証する）。

## バージョン固定（Pin）

- **すべて完全一致で固定する。** 「◯◯以上」・範囲指定・`latest`・ブランチ追従は使わない。
  - Nix: `flake.lock` が nixpkgs / nix-darwin / home-manager の **rev + narHash** を固定する（＝各パッケージの版が一意に決まる）。
  - mise: `pin = true` + `mise.lock`（版 + プラットフォーム別ハッシュ）。
  - Nix 本体: `tools/install-nix.sh` に **版と installer の sha256** を固定する。
- 新しい版は **公開から 2 日以上経過**してから採用する（mise `minimum_release_age = "2d"` / Renovate `minimumReleaseAge` / flake.lock 更新も同じ）。

## 選択ルール

### CLI・ランタイム・開発ツール

**基本は Nix。ただし検証レベルが明確に上回る入手元があればそちらを優先する。**

検証レベル（強い順）:

| レベル | 内容 | 典型 |
|---|---|---|
| **A** | **配布元自身の署名・来歴**（GitHub Artifact Attestations / SLSA provenance / cosign / gpg）を導入時に検証 + ハッシュ固定 | mise（aqua / github backend）で `attestations` / `cosign` / `slsa` |
| **B** | **ソースからビルド**（ソースハッシュ固定 + Hydra ビルド + cache.nixos.org 署名検証） | Nix で `meta.sourceProvenance` が fromSource |
| **C** | 配布元**バイナリのハッシュ固定のみ** | mise `checksum` のみ / Nix の `-bin`（binaryNativeCode） |
| **D** | レジストリの integrity のみ | provenance の無い npm |
| **E** | 検証なし | `Security: [none]` |

判定:

1. **Nix と mise が同レベル、または A と B の組み合わせ → Nix**（基本優先）。
2. **mise が明確に上（例: Nix=C, mise=A）→ mise。**
3. いずれでも、**nixpkgs 側の版に未修正の既知脆弱性があり mise では修正版を入れられる → mise。**
4. nixpkgs に無い / `aarch64-darwin` で壊れている / npm・pypi・go エコシステムで Takumi Guard 経由の検証を使いたい → mise。
5. どちらにも無い → **自前の Nix derivation（overlay、取得物はハッシュ固定）**。それでも安全性を確認できない場合は**推測で入れず報告する**。

判定は `tools/compare-source.sh <nixpkgs-attr> <mise-tool>` で調べ、結果と根拠を `AUDIT.md` に記録する。

### GUI アプリ

1. **Mac App Store の公式版**（開発元自身の公開）。宣言は nixpkgs の `mas` + App ID。
2. **nixpkgs の darwin 向けアプリ**（nix-darwin / home-manager で配置）。
3. **開発元公式の dmg / pkg**（版を固定し sha256 を記録。`codesign --verify --deep --strict` / `spctl -a -vv`（公証）/ `pkgutil --check-signature` で検証）。

## Nix の設定（`hosts/darwin.nix`）

| 設定 | 値 |
|---|---|
| `substituters` | `https://cache.nixos.org` のみ |
| `trusted-public-keys` | cache.nixos.org の鍵のみ |
| `require-sigs` | `true` |
| `accept-flake-config` | `false` |
| `sandbox` | `true`（壊れるものは例外として記録） |
| unfree | `allowUnfreePredicate` で**名前指定**のみ許可 |

## 更新の運用

- **適用はユーザーが手動で行う。適用対象はリモート（`origin/main`）で更新された内容だけ。**
  - `tools/update.sh` はローカルの未コミット変更・未 push のコミットがあると**中止**し、`origin/main` の commit をそのまま適用する。
  - ホストで宣言を書き換えて適用することはしない（変更は PR → マージ → `update.sh`）。
- **自動で行うのは読み取りのみ**: launchd のユーザー agent（`home/launchd.nix`）が毎日 `tools/check.sh` を実行し、
  リモートとの差分・宣言とのドリフトを `.agent/update-report.json` に書いて macOS 通知を出す。sudo は使わない。

## データ方針

- **秘密はどこにも保存しない。** トークンは Keychain / 環境変数、CI は GitHub Secrets。
- **公開しないデータは `.agent/` に置く（`.gitignore` 済み）。**
- リポジトリにユーザー名・実パスを書かない（`$HOME` / `~` を使う）。

## 作業時の注意（過去に実際に起きた失敗）

エージェントが同じ失敗を繰り返さないための記録。どれも一度起きている。

### 主張と検証

- **確かめていないことを断定しない。** 対応プラットフォームはパッケージのメタデータ（npm の `os`/`cpu`、リリースの asset 名）で、
  検証の有無（provenance・署名）は実際のコマンド出力で確認してから書く（「Windows 専用」「provenance 検証済み」を誤って断定した例がある）。
- **版の遅れは「何版遅れ」ではなく「新しい版が公開されてから何日」で測る**（リリース頻度で見え方が変わるため）。
- **途中の手順が失敗したら commit / push しない。** 失敗を直してから、まとめて 1 回で出す。

### シェル・PATH

- **スクリプトは bash（`#!/bin/bash`）で書く。** zsh は `set -- $var` で単語分割しない。macOS の `/bin/bash` は 3.2 なので `declare -A` は使えない（awk で代用）。
- **エージェントのシェルには Nix・宣言済みツールの PATH が無いことがある**（起動時の環境を引き継ぐため）。
  `nix` / `gh` / `sbx` が見つからなければ `. tools/lib.sh && nix_env && host_path` を先に実行する。commit / push の hook（hk）も `nix` を必要とする。
- **PATH の追加は `~/.zshenv`（home-manager の `programs.zsh.envExtra`）に書く。** `~/.zprofile` はログインシェルでしか読まれず、
  非ログインのターミナルや `zsh -c` で `claude` が見つからなくなった。宣言の外のディレクトリ（`~/.local/bin` など）は**後ろに追加**し、宣言済みツールを優先させる。
- **mise のグローバルツールは `mise activate`（`.zshrc`、対話シェルのみ）で PATH に入る。** 非対話シェル（`zsh -c`・スクリプト）には
  `.zshenv` で mise の shims を足す。対話シェルには足さない（`mise activate` が shims を Nix より前へ動かし、
  リポジトリ専用ツールの shim がリポジトリの外で「No version is set」になる）。PATH を変えたら、`env -i` で
  `zsh -c` / `-ic` / `-lc` / `-lic` のそれぞれを、リポジトリの外と中の両方で確かめる。
- **zsh を通らないプロセス（GUI アプリとして起動した AI エージェント、そこから起動される bash / sh）は launchd の PATH を使う。**
  `home/launchd.nix` の `session-path` がログインのたびに `launchctl setenv PATH` で設定する。PATH の並びを変えるときは `.zshenv` とこちらの両方を直す。
- **home-manager は既存の dotfile を置き換える。** 既存の内容（PATH など）を移さずに管理下へ入れない。退避は `backupFileExtension`。
- sudo が必要な `tools/update.sh` / `tools/install-nix.sh` は TTY が要るので、ユーザーが Terminal.app で実行する。

### Nix

- **`nix fmt` は必ずファイルを指定する**（`nix fmt -- <files>`）。引数なしだと nixfmt が標準入力を待って止まる。
- `nix eval --raw` の出力には末尾の改行が無い。`read` で受けるなら `; echo` を足す。
- **ビルド中に `.app` を実行するパッケージ（`versionCheckHook` など）は macOS で失敗することがある**
  （`clearing flags of path …/X.app: Operation not permitted`）。`overrideAttrs { doInstallCheck = false; }` にして、
  代わりに `tools/check.sh` で署名（Team ID）を確認する（`docker-sbx` の例）。

### mise・GitHub API

- **GitHub API は未認証だと 60 回/時で、mise の attestation 確認がすぐ止まる。** `tools/lib.sh` の `github_auth`（gh のトークンをそのプロセスにだけ渡す。保存しない）を使う。
- **paranoid の mise は pnpm を拒否する。** npm バックエンドは `aube` を使い、依存グラフ `mise/locks/` も lock と一緒に commit する（ホスト専用ではない）。
- github バックエンドで asset 名がプラットフォームごとに違うものは、プラットフォーム別の `asset_pattern` を書く（1 つのテンプレートだと別プラットフォームの lock に macOS の URL が入った）。

### APM（Skills）

- **`apm update` / `apm outdated` の結果で版を決めない。** SHA 固定の依存では annotated tag だけを見て、古い版を「最新」と出す（AUDIT.md「Skills」）。
  版の更新は Renovate の PR、lock の再生成は `tools/ci/skills-lock.sh --write`（`skills-relock.yml`）。上流の新しい版は GitHub のタグと公開日で確かめる。
- apm を試すときは一時 HOME で動かす（`tools/lib.sh` の `apm_in <home> <apm> ...`）。ホストの `~/.apm` / `~/.claude/skills` は `tools/skills-apply.sh` だけが書く。

### lint・CI

- 公開されている鍵の指紋などが betterleaks に検出されたら、意味の分かる変数名にして `# gitleaks:allow` を付ける。
- shellcheck に `lib.sh` を追わせるには `# shellcheck source=tools/lib.sh` と `-x` を使う。
- push 直後は `gh run list -c <sha>` が空や 404 を返すことがある。`gh run list -L 5` で run ID を確かめてから `gh run watch <id>` する。
