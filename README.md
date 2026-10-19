# Linux Network Doctor

A **Bash** command-line tool for read-only Linux network troubleshooting. Checks interface state, the IPv4 default route, system name resolution, and optional HTTPS connectivity. Built as a new learning and portfolio project for Jason Edwards; it has not been validated on his personal machines.

## Run

```bash
bash netcheck.sh
bash netcheck.sh --target example.com --https
```

Requires Linux, Bash 4.2+, and coreutils `timeout`. Individual checks need `ip`, `getent`, and (for HTTPS) `curl`. On Fedora the `ip` package is `iproute`; on Ubuntu it is `iproute2`. Missing commands produce SKIP rather than an invented success. No Python, Node, root privileges, or configuration changes are needed to run the tool.

Default behavior checks the system resolver against `example.com`, so it can send a name lookup through your configured resolver. `--target` selects one hostname or IPv4 address. `--https` additionally performs a single HTTPS GET to that host's root path; it verifies TLS, does not follow redirects, and ignores `.curlrc` and proxy settings. Use a host you are permitted to contact. It is not a port scanner or network sweep.

## What the results mean

| Check | Evidence | Limits |
| --- | --- | --- |
| Interfaces | Non-loopback interface administratively up | Does not prove carrier, an IP address, or connectivity |
| IPv4 route | Main-table default route exists | Does not prove reachability; IPv6-only/policy routing can work without it |
| Name resolution | System resolver returns IPv4 records | Can use `/etc/hosts` or cache; numeric targets do not exercise DNS |
| HTTPS (optional) | TLS verified and HTTP 2xx/3xx returned | Redirect destinations are not checked; proxy-only networks may fail direct access |

HTTP 4xx/5xx results are warnings with an explicit reminder that a server response is not proof of a network failure. IPv6 target syntax, policy-route inspection, latency measurements, and service-specific diagnosis are outside this version's scope.

Each command has a bounded wait: interface/route inspection 5 seconds each, resolution 8 seconds, HTTPS 12 seconds. Sequential checks can take approximately 30 seconds. Exits: **0** all requested checks passed; **1** one or more warnings; **2** invalid input, report-file failure, a missing timeout utility, or skipped checks without other warnings.

## Save a report

```bash
mkdir -p reports
bash netcheck.sh --https --report reports/home.report.txt
```

Choose a new filename; existing files and symlinks are not overwritten. A saved report preserves the diagnostic exit status, so a report can be created while the command exits 1 or 2. Reports include a timestamp, target, and check results, and use private creation permissions. They omit raw IP addresses, route details, and interface names. A custom target can still identify a private service: review reports before sharing. Store reports under the ignored `reports/` folder; do not commit private diagnostic output.

## Test

```bash
bash -n netcheck.sh tests/run.sh publish.sh
bash tests/run.sh
```

Twelve deterministic Bash scenarios test healthy results, missing links/routes, name lookup failures, HTTP errors, TLS failures, invalid arguments/hostnames, report creation, and overwrite refusal. Command fixtures replace `ip`, `getent`, `curl`, and `timeout`; tests make **no network requests**. The fixtures do not verify real timeout enforcement or command compatibility on every Linux distribution. ShellCheck is not installed in the preparation environment; syntax checks and behavioral tests are the completed validation. The included GitHub Actions workflow runs the same checks after publishing.

## Publish

With your GitHub CLI already signed in:

```bash
bash publish.sh
```

This creates public repository `cuzzaintit321/linux-network-doctor`, adds the repository description, and pushes the code. It stops if a local Git checkout or the remote repository already exists. Inspect any partially completed publication before retrying. No software license has been selected on your behalf.

## Skills demonstrated

Bash argument handling, exit codes, subprocess time limits, conservative file output, Linux network diagnostics, fixture testing, and GitHub Actions. This is a portfolio troubleshooting aid, not a claim of professional incident response or production deployment.
