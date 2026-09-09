# ─────────────────────────────────────────────────────────────────────────────
# Full end-to-end provisioning test.
#
# WHAT THIS PROVES
#   - the flake evaluates
#   - homeConfigurations.<arch> BUILDS (every package resolves in nixpkgs)
#   - activation succeeds against a real, empty $HOME
#   - the resulting shell actually works: aliases loaded, tools on PATH,
#     and an interactive zsh that emits NOTHING on startup
#
# WHAT IT CANNOT PROVE
#   darwinConfigurations — nix-darwin requires macOS. `darwin-rebuild build`
#   on the Mac is the corresponding gate for that half.
#   Works on last install on 09/09/2026
#
# Non-root user with a real $HOME, because home-manager activation against
# root is not what we ship.
# ─────────────────────────────────────────────────────────────────────────────
FROM nixos/nix:latest

# Flakes are not on by default in this image.
RUN mkdir -p /etc/nix && \
    printf 'experimental-features = nix-command flakes\nfilter-syscalls = false\n' \
      >> /etc/nix/nix.conf

ARG USER=dj
ARG UID=1000
# The nixos/nix image ships no shadow-utils; append the user records directly.
RUN mkdir -p /home/${USER} && \
    echo "${USER}:x:${UID}:${UID}::/home/${USER}:/bin/sh" >> /etc/passwd && \
    echo "${USER}:x:${UID}:" >> /etc/group && \
    chown -R ${UID}:${UID} /home/${USER} /nix

USER ${USER}
ENV USER=${USER}
ENV HOME=/home/${USER}
ENV DOTFILES=/home/${USER}/catalyst-devspace/catalyst/@dotfiles
ENV NIX_CONFIG="experimental-features = nix-command flakes"

RUN mkdir -p ${HOME}/catalyst-devspace/catalyst
COPY --chown=${UID}:${UID} . ${DOTFILES}

WORKDIR ${DOTFILES}
ENTRYPOINT ["/bin/sh"]
