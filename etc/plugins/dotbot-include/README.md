# dotbot-include

A simple include directive allowing tasks/actions from separate dotbot configuration files to be read and executed

## Installation

1. Add the plugin as a submodule to your dotfiles repository.
   `git submodule add https://gitlab.com/gnfzdz/dotbot-include.git ${dotbot_include_dir}`
2. Configure dotbot-include with an additional CLI argument when executing dotbot
   `... -p ${dotbot_include_dir}/include.py ...`

## Options

Name | Description | Default
 --------| -------- | --------
path | The relative path to a dotbot configuration file that should be read and executed | N/A
isolated | A flag configuring whether defaults should be scoped to execution of the included file. Current defaults will not be considered when processing the file. Any defaults set within the configuration file will be discarded after processing the file is complete. | False

## Examples

```yaml

# Configure defaults
- defaults:
    include:
        isolated: False

# When only provided a string, that will be treated as the path of the file to include
- include: 'meta/configs/ssh.yaml'

# When provided a dict, the path may be provided alongside the optional isolated option
- include: 
    path: 'meta/configs/ssh.yaml'
    isolated: True

```
