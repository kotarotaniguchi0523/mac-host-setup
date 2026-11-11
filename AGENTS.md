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
