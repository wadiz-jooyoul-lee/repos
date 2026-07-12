#!/bin/bash
# Wadiz repos 부트스트랩 스크립트
# ~/work/repos 하위 25개 repo 를 clone. 이미 있는 폴더는 skip.
# 갱신은 별도로 `./execute_all git pull` 사용.
#
# 프로토콜 선택 (기본 ssh):
#   ./clone-all.sh              # SSH (git@github.com:...)  ← 기본
#   ./clone-all.sh --https      # HTTPS (https://github.com/...)
#   PROTOCOL=https ./clone-all.sh
#
# SSH 사용 시 GitHub 에 SSH 키 등록 필수 (`ssh -T git@github.com` 로 확인).
# HTTPS 사용 시 PAT 또는 credential helper 필요.

set -u

PROTOCOL="${PROTOCOL:-ssh}"
if [ "${1:-}" = "--https" ]; then
  PROTOCOL="https"
elif [ "${1:-}" = "--ssh" ]; then
  PROTOCOL="ssh"
fi

case "$PROTOCOL" in
  ssh|https) ;;
  *) echo "지원하지 않는 PROTOCOL: $PROTOCOL (ssh|https 만 가능)"; exit 1 ;;
esac
echo "프로토콜: $PROTOCOL"
echo ""

REPOS=(
  # wadiz-service
  "git@github.com:wadiz-service/co.wadiz.api.community.git"
  "git@github.com:wadiz-service/co.wadiz.currency-exchange.git"
  "git@github.com:wadiz-service/co.wadiz.fep.git"
  "git@github.com:wadiz-service/com.wadiz.api.funding.git"
  "git@github.com:wadiz-service/com.wadiz.api.reward.git"
  "git@github.com:wadiz-service/com.wadiz.api.startup.git"
  "git@github.com:wadiz-service/com.wadiz.wave.searcher.git"
  "git@github.com:wadiz-service/com.wadiz.wave.user.git"
  "git@github.com:wadiz-service/kr.wadiz.account.git"
  "git@github.com:wadiz-service/kr.wadiz.user.link.git"
  "git@github.com:wadiz-service/nicepay-api.git"
  # wadiz-client
  "git@github.com:wadiz-client/app-api.git"
  "git@github.com:wadiz-client/client-document.git"
  "git@github.com:wadiz-client/figma-icon-sync.git"
  "git@github.com:wadiz-client/makercenter-be.git"
  "git@github.com:wadiz-client/makercenter-fe.git"
  "git@github.com:wadiz-client/makercenter-fe-admin.git"
  "git@github.com:wadiz-client/wadiz-claude-plugins.git"
  # wadiz-fe
  "git@github.com:wadiz-fe/wadiz-frontend.git"
  # wadiz-web
  "git@github.com:wadiz-web/com.wadiz.web.git"
  "git@github.com:wadiz-web/com.wadiz.adm.git"
  # wadiz-app
  "git@github.com:wadiz-app/wadiz-android.git"
  "git@github.com:wadiz-app/wadiz-ios.git"
  # wa-infrastructure
  "git@github.com:wa-infrastructure/cdc.git"
  # wadiz-ai
  "git@github.com:wadiz-ai/ai-project-audit.git"
)

skipped=0
cloned=0
failed=0

for url in "${REPOS[@]}"; do
  name=$(basename "$url" .git)
  if [ "$PROTOCOL" = "https" ]; then
    url="${url/git@github.com:/https://github.com/}"
  fi
  if [ -d "$name/.git" ]; then
    echo "[SKIP]  $name (이미 존재)"
    skipped=$((skipped + 1))
  else
    echo "[CLONE] $name  ($url)"
    if git clone "$url" "$name"; then
      cloned=$((cloned + 1))
    else
      echo "[FAIL]  $name"
      failed=$((failed + 1))
    fi
  fi
done

echo ""
echo "완료: clone=$cloned  skip=$skipped  fail=$failed  total=${#REPOS[@]}"
[ $failed -eq 0 ] || exit 1
