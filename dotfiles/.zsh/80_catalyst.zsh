
#* Load Catalyst Workspace Dev ENV *#
if [[ -z $HOSTNAME ]]; then
  HOSTNAME=$(hostname)
fi

# ✨ Sexy Catalyst Workspace Setup ✨
function _catalyst_setup_check() {
  local errors=()
  local warnings=()
  
  # Check if DEV_SPACE_ROOT exists
  if [[ ! -d "${DEV_SPACE_ROOT}" ]]; then
    errors+=("🚨 Catalyst Dev Space root directory missing: ${DEV_SPACE_ROOT}")
    errors+=("   💡 Run: mkdir -p ${DEV_SPACE_ROOT}")
  fi
  
  # Check if CLI tools exist
  if [[ ! -d "${DEV_SPACE_ROOT}/catalyst/@cli-tools/bin" ]]; then
    warnings+=("⚠️  Catalyst CLI Tools not found: ${DEV_SPACE_ROOT}/catalyst/@cli-tools/bin")
    warnings+=("   💡 Consider setting up CLI tools for full functionality")
  fi
  
  # Print errors (blocking)
  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "🔥 Catalyst Setup Issues:"
    printf '%s\n' "${errors[@]}"
    echo ""
    return 1
  fi
  
  # Print warnings (non-blocking)
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "⚡ Catalyst Setup Warnings:"
    printf '%s\n' "${warnings[@]}"
    echo ""
  fi
  
  return 0
}

export DEV_SPACE_ROOT="${HOME}/catalyst-devspace"

# Run the sexy setup check
if ! _catalyst_setup_check; then
  echo "🛑 Catalyst setup incomplete - some features may not work"
  return 1
fi

echo "🚀 DEV_SPACE_ROOT: ${DEV_SPACE_ROOT}"

# Only add CLI tools to PATH if they exist
if [[ -d "${DEV_SPACE_ROOT}/catalyst/@cli-tools/bin" ]]; then

export PATH="${DEV_SPACE_ROOT}/catalyst/@cli-tools/bin:${PATH}"
echo "✅ CLI TOOLS LOADED: ${DEV_SPACE_ROOT}/catalyst/@cli-tools/bin"
fi

# NOT sure you can add symlinks root folders to the path
# path+=("${DEV_SPACE_ROOT}/.catalyst_bin")

#* End Catalyst Workspace Dev ENV *#

# sudo scutil --set HostName bfmac.localdomain
# sudo scutil --set LocalHostName bfmac
# sudo scutil --set ComputerName bfmac
# dscacheutil -flushcachedirenv