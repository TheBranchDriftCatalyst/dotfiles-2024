# forge — a small client for the self-hosted Forgejo.
#
# WHY THIS EXISTS. Creating a repository was the one step in the homelab's otherwise fully
# automated chain that still meant opening a browser: source lives on Forgejo, CI is a Forgejo
# Actions runner in-cluster, images go to Zot, ArgoCD syncs from the in-cluster Forgejo service
# — and then bringing up a NEW application began with a manual form. `forge repo create` closes
# that gap, and makes "scaffold a repo" scriptable alongside everything else.
#
# CREDENTIALS, in order of preference:
#
#   1. $FORGEJO_TOKEN                 — explicit, wins over everything. For CI.
#   2. op read "$FORGEJO_OP_REF"      — 1Password, the workspace's sanctioned secret path.
#                                       Requires an unlocked session; `op signin` first.
#
# There is deliberately NO fallback to the macOS keychain and no prompt-and-store: a tool that
# silently acquires a credential from an unexpected place is a tool you cannot reason about when
# it does something surprising with it.
{ pkgs, lib, config, ... }:

let
  cfg = config.catalyst.forge or { };

  forge = pkgs.writeShellApplication {
    name = "forge";
    # NOT _1password-cli: it is unfree, and pulling it into the closure would make everyone
    # who builds these dotfiles accept an unfree licence for a credential path they may never
    # use. `op` is looked up on PATH instead, and its absence degrades to a clear instruction
    # rather than a build-time licence prompt.
    runtimeInputs = with pkgs; [ curl jq git ];
    text = ''
      set -euo pipefail

      FORGE_HOST="''${FORGEJO_HOST:-${cfg.host or "forge.knowledgedump.space"}}"
      FORGE_OP_REF="''${FORGEJO_OP_REF:-${cfg.opRef or "op://catalyst-eso/forgejo/token"}}"
      API="https://''${FORGE_HOST}/api/v1"

      die() { printf 'forge: %s\n' "$*" >&2; exit 1; }

      token() {
        if [ -n "''${FORGEJO_TOKEN:-}" ]; then
          printf '%s' "$FORGEJO_TOKEN"
          return
        fi
        if command -v op >/dev/null 2>&1 && op read "$FORGE_OP_REF" 2>/dev/null; then
          return
        fi
        die "no credential.
  Set FORGEJO_TOKEN, or unlock 1Password and make sure $FORGE_OP_REF resolves:
      op signin && op read \"$FORGE_OP_REF\"
  A token needs scope write:repository to create repositories."
      }

      # api METHOD PATH [BODY]
      #
      # Forgejo puts the useful part of a failure in the response BODY, not the status line, so
      # the body is carried through rather than collapsed to "request failed".
      api() {
        local method="$1" path="$2" body="''${3:-}" out status
        local -a args=(-sS -w '\n%{http_code}' -X "$method"
          -H "Authorization: token $(token)"
          -H "Content-Type: application/json")
        [ -n "$body" ] && args+=(-d "$body")

        out="$(curl "''${args[@]}" "''${API}''${path}")"
        status="''${out##*$'\n'}"
        body="''${out%$'\n'*}"

        if [ "$status" -ge 400 ]; then
          local msg
          msg="$(printf '%s' "$body" | jq -r '.message // .errors // empty' 2>/dev/null || true)"
          die "''${method} ''${path} -> HTTP ''${status}''${msg:+: $msg}"
        fi
        printf '%s' "$body"
      }

      split_owner_repo() {
        case "$1" in
          */*) OWNER="''${1%%/*}"; REPO="''${1##*/}" ;;
          *)   die "expected <owner>/<name>, got '$1'" ;;
        esac
        [ -n "$OWNER" ] && [ -n "$REPO" ] || die "expected <owner>/<name>, got '$1'"
      }

      cmd_whoami() {
        api GET /user | jq -r '"\(.login)  <\(.email)>  on '"$FORGE_HOST"'"'
      }

      cmd_exists() {
        split_owner_repo "$1"
        if curl -sS -o /dev/null -w '%{http_code}' \
             -H "Authorization: token $(token)" \
             "''${API}/repos/''${OWNER}/''${REPO}" | grep -q '^200$'; then
          echo "exists"
        else
          echo "absent"; return 1
        fi
      }

      cmd_create() {
        local spec="" private="true" desc="" push="" remote="origin" branch="main"
        while [ $# -gt 0 ]; do
          case "$1" in
            --public)       private="false"; shift ;;
            --private)      private="true"; shift ;;
            --description)  desc="$2"; shift 2 ;;
            --push)         push="1"; shift ;;
            --remote)       remote="$2"; shift 2 ;;
            --branch)       branch="$2"; shift 2 ;;
            -*)             die "unknown flag $1" ;;
            *)              spec="$1"; shift ;;
          esac
        done
        [ -n "$spec" ] || die "usage: forge repo create <owner>/<name> [--public] [--description TEXT] [--push]"
        split_owner_repo "$spec"

        # Idempotent: an existing repository is reported, not recreated and not failed on, so
        # this is safe to put in a bootstrap script that may run twice.
        if cmd_exists "$spec" >/dev/null 2>&1; then
          echo "forge: ''${OWNER}/''${REPO} already exists"
        else
          local payload me
          payload="$(jq -nc --arg name "$REPO" --arg desc "$desc" --argjson private "$private" \
            '{name: $name, description: $desc, private: $private, auto_init: false, default_branch: "main"}')"

          me="$(api GET /user | jq -r .login)"
          if [ "$me" = "$OWNER" ]; then
            api POST /user/repos "$payload" >/dev/null
          else
            # An organisation, or someone else's namespace. The org endpoint is a different
            # path and fails with a clearer error than /user/repos would.
            api POST "/orgs/''${OWNER}/repos" "$payload" >/dev/null
          fi
          echo "forge: created ''${OWNER}/''${REPO} (private=''${private})"
        fi

        echo "  https://''${FORGE_HOST}/''${OWNER}/''${REPO}"
        # The in-cluster address, which is what ArgoCD should sync from: it must not depend on
        # Traefik, external-dns or the WAN.
        echo "  http://forgejo.forgejo.svc.cluster.local:3000/''${OWNER}/''${REPO}.git  (in-cluster)"

        if [ -n "$push" ]; then
          git rev-parse --git-dir >/dev/null 2>&1 || die "--push needs to run inside a git repository"
          local url="https://''${FORGE_HOST}/''${OWNER}/''${REPO}.git"
          if git remote get-url "$remote" >/dev/null 2>&1; then
            git remote set-url "$remote" "$url"
          else
            git remote add "$remote" "$url"
          fi
          echo "forge: pushing $branch to $remote"
          git push -u "$remote" "$branch"
        fi
      }

      cmd_list() {
        local owner="''${1:-}"
        if [ -n "$owner" ]; then
          api GET "/users/''${owner}/repos?limit=100" | jq -r '.[] | "\(.full_name)\t\(.private | if . then "private" else "public" end)"' | column -t
        else
          api GET "/user/repos?limit=100" | jq -r '.[] | "\(.full_name)\t\(.private | if . then "private" else "public" end)"' | column -t
        fi
      }

      cmd_delete() {
        split_owner_repo "''${1:-}"
        # Deliberately requires the full name typed back. Deleting a repository is not
        # recoverable from here, and a --force flag is a habit, not a safeguard.
        printf 'type %s/%s to delete it: ' "$OWNER" "$REPO" >&2
        read -r confirm
        [ "$confirm" = "''${OWNER}/''${REPO}" ] || die "aborted"
        api DELETE "/repos/''${OWNER}/''${REPO}" >/dev/null
        echo "forge: deleted ''${OWNER}/''${REPO}"
      }

      usage() {
        cat >&2 <<'EOF'
forge — client for the self-hosted Forgejo

  forge whoami
  forge repo create <owner>/<name> [--public] [--description TEXT] [--push]
  forge repo exists <owner>/<name>
  forge repo list [owner]
  forge repo delete <owner>/<name>

Credentials: $FORGEJO_TOKEN, else `op read $FORGEJO_OP_REF`.
Host:        $FORGEJO_HOST (default forge.knowledgedump.space)

create is idempotent — an existing repository is reported, not recreated.
--push wires `origin` to the new repository and pushes the current branch.
EOF
        exit 2
      }

      [ $# -gt 0 ] || usage
      case "$1" in
        whoami) shift; cmd_whoami "$@" ;;
        repo)
          shift
          [ $# -gt 0 ] || usage
          case "$1" in
            create) shift; cmd_create "$@" ;;
            exists) shift; cmd_exists "''${1:-}" ;;
            list)   shift; cmd_list "''${1:-}" ;;
            delete) shift; cmd_delete "''${1:-}" ;;
            *)      usage ;;
          esac
          ;;
        -h|--help|help) usage ;;
        *) usage ;;
      esac
    '';
  };
in
{
  options.catalyst.forge = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "forge.knowledgedump.space";
      description = "Forgejo host the `forge` CLI talks to. Overridable at run time with $FORGEJO_HOST.";
    };
    opRef = lib.mkOption {
      type = lib.types.str;
      default = "op://catalyst-eso/forgejo/token";
      description = "1Password secret reference for the Forgejo token. Overridable with $FORGEJO_OP_REF.";
    };
  };

  config.home.packages = [ forge ];
}
