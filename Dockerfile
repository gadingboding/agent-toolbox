FROM base

ARG USE_MIRROR
ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG USER_HOME

ENV BUN_INSTALL=/usr/local/bun
ENV COREPACK_HOME=/usr/local/share/corepack
ENV PATH=/usr/local/bun/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-lc"]

RUN : "${USE_MIRROR:?USE_MIRROR build arg is required}" \
    && : "${USERNAME:?USERNAME build arg is required}" \
    && : "${USER_UID:?USER_UID build arg is required}" \
    && : "${USER_GID:?USER_GID build arg is required}" \
    && : "${USER_HOME:?USER_HOME build arg is required}"

USER root

COPY docker/ /tmp/docker-config/

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --home-dir "${USER_HOME}" --create-home --shell /bin/bash "${USERNAME}" \
    && mkdir -p "${USER_HOME}/.config" \
    && if [ "${USE_MIRROR}" = "1" ]; then \
        install -m 0644 /tmp/docker-config/npmrc "${USER_HOME}/.npmrc"; \
        install -m 0644 /tmp/docker-config/bunfig.toml "${USER_HOME}/.bunfig.toml"; \
    fi \
    && chown -R "${USER_UID}:${USER_GID}" "${USER_HOME}" "${COREPACK_HOME}" \
    && printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${USERNAME}" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}"

RUN if [ "${USE_MIRROR}" = "1" ]; then \
        export NPM_CONFIG_REGISTRY="https://registry.npmmirror.com"; \
    fi \
    && "${BUN_INSTALL}/bin/bun" install -g \
        opencode-ai@latest \
        @qwen-code/qwen-code@latest \
        @google/gemini-cli@latest \
        @openai/codex@latest

RUN rm -rf /tmp/docker-config

ENV USERNAME=${USERNAME}
ENV HOME=${USER_HOME}

WORKDIR ${USER_HOME}
USER ${USERNAME}
