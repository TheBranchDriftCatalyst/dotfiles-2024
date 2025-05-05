
#* Load Catalyst Workspace Dev ENV *#

# get the hostname
if [[ -z $HOSTNAME ]]; then
  HOSTNAME=$(hostname)
fi

export DEV_SPACE_ROOT=$HOME/catalyst-devspace

path +=(
  realpath $HOME/catalyst-devspace/catalyst/@machines
  # $HOME/Code/active_workspaces/catalyst
  # $HOME/Code/active_workspaces/catalyst/catalyst
  # $HOME/Code/active_workspaces/catalyst/catalyst/bin
  # $HOME/Code/active_workspaces/catalyst/catalyst/bin/darwin
  # $HOME/Code/active_workspaces/catalyst/catalyst/bin/linux
)

#* End Catalyst Workspace Dev ENV *#



# sudo scutil --set HostName bfmac.localdomain
# sudo scutil --set LocalHostName bfmac
# sudo scutil --set ComputerName bfmac
# dscacheutil -flushcache