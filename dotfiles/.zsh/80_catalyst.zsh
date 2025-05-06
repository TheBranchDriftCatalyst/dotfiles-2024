
#* Load Catalyst Workspace Dev ENV *#
# export WORKSPACE_ROOT=$HOME/Code/active_workspaces
# get the hostname
if [[ -z $HOSTNAME ]]; then
  HOSTNAME=$(hostname)
fi

export DEV_SPACE_ROOT="${HOME}/catalyst-devspace"
echo "DEV_SPACE_ROOT: ${DEV_SPACE_ROOT}"
# NOT sure you can add symlinks root folders to the path
# path+=("${DEV_SPACE_ROOT}/.catalyst_bin")

#* End Catalyst Workspace Dev ENV *#

# sudo scutil --set HostName bfmac.localdomain
# sudo scutil --set LocalHostName bfmac
# sudo scutil --set ComputerName bfmac
# dscacheutil -flushcachedirenv