# Codex sandbox inside Docker

Validated on 2026-10-06: Debian 13 host, Linux 6.12.57+deb13-amd64,
Docker Engine 29.2.0-rc.2, Codex CLI 0.160.1, distribution `/usr/bin/bwrap`.

## Diagnosis

Disposable test containers ran as UID/GID 1000, with no host bind mounts and no
network. Tests did not call a model or change the user's Codex configuration.

| Outer Docker configuration | Result |
| --- | --- |
| Default seccomp + AppArmor | Namespace creation denied |
| Only seccomp unconfined | Namespace creation denied by remaining policy |
| Only AppArmor unconfined | Namespace creation denied by remaining policy |
| Both unconfined | Namespace creation works, fresh `/proc` mount denied |
| Both unconfined + systempaths unconfined | Codex sandbox starts |
| Custom seccomp + AppArmor/systempaths unconfined + all capabilities dropped + no-new-privileges | Codex sandbox starts; workspace boundaries enforced |

Removing each of `clone`, `unshare`, `mount`, `umount2`, and `pivot_root` from
the added allow rule independently caused startup failure. `setns` was not
required by the tested invocation and was omitted. These results establish the
requirements of the tested paths, not every possible workload or architecture.

The legacy Landlock setting panicked with this CLI build because restricted
filesystem execution requires Bubblewrap to isolate app-server sockets.

## Default runtime configuration

From the project directory:

```bash
docker compose run --rm toolbox bash
```

Additional `-v` and `-w` options can be supplied before `toolbox` as usual.
These settings are part of the default `toolbox` service and only affect runtime
configuration; rebuilding is unnecessary.
Exit and recreate existing containers to apply it.

Run `codex --sandbox workspace-write` in the intended project directory. For
diagnostics use explicit built-in profiles, such as
`codex sandbox -P :workspace /bin/true`, rather than assuming a legacy config
override selects the diagnostic command's policy.

The initial tested combination retained an active seccomp filter, no capabilities in
the sandboxed command, and `NoNewPrivs=1`. An explicit `:workspace` profile
allowed a file inside the selected workspace and rejected a write elsewhere
in the user's home. `:read-only` rejected a workspace write. `sudo -n id -u`
was blocked by no-new-privileges even though the image provides passwordless sudo.
At the user's request, the default now omits no-new-privileges and cap_drop,
restoring Docker's default capabilities and passwordless sudo outside Codex's
inner sandbox. Codex applies its own no-new-privileges inside restricted commands.

These tests cover local command startup and filesystem boundaries; they do not
cover a complete model session, external network access, or all CLI tools.

## Security tradeoffs

This is a compatibility configuration, not a full security audit. AppArmor and
Docker system path masking are disabled for this container. Namespace and mount
syscalls are permitted to non-root processes. Kernel permission checks still
apply; Docker's default capabilities are retained, but no `CAP_SYS_ADMIN`, extra
devices, Docker socket, or privileged mode are added.
Codex's inner sandbox remains dependent on the selected permissions and approval
policy. Other programs in the toolbox do not automatically inherit that sandbox.

Keep host mounts narrow. Read-only mounts still expose data to reads. Do not use
this configuration as assurance that unattended execution cannot affect the host;
a dedicated VM provides an additional kernel boundary. The default runtime permits
passwordless sudo, so unsandboxed programs can become container root. Packages
installed interactively are lost when the disposable container is removed.

## Seccomp provenance

`codex-seccomp.json` is a snapshot derived from the Moby project's
[default seccomp profile](https://github.com/moby/profiles/blob/main/seccomp/default.json),
retrieved on 2026-10-06. The unmodified downloaded bytes had SHA-256
`6416b47770785a41ac59073cdc77d9fe98517df2799dc83ef207e622de3053f6`.
The JSON was reformatted and one allow rule was appended for `clone`, `unshare`,
`mount`, `umount2`, and `pivot_root`. Other rules, including the default deny
action and the `clone3` ENOSYS fallback rule, were retained. This snapshot is
not guaranteed to match every Docker version's builtin profile. Revalidate it
after Docker, Codex, Bubblewrap, kernel, or architecture changes.

References:

- [Codex Docker namespace issue #16211](https://github.com/openai/codex/issues/16211)
- [Restricted-container sandbox issue #35547](https://github.com/openai/codex/issues/35547)
- [Codex 0.160.1 Linux sandbox implementation](https://github.com/openai/codex/blob/rust-v0.160.1/codex-rs/linux-sandbox/README.md)
- [Docker seccomp documentation](https://docs.docker.com/engine/security/seccomp/)
