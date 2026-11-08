# Security policy

## Supported versions

Only the [latest release](https://github.com/7zStar/7-ZSTar/releases/latest)
is supported. A fix ships as a new release; older releases are not patched, so
if you are on one, update first and check whether the problem is still there.

## Reporting a vulnerability

Please do not report a vulnerability in a public issue, discussion or pull
request. Use GitHub's private vulnerability reporting instead:

1. Open the repository's main page, <https://github.com/7zStar/7-ZSTar>.
2. Click the **Security and quality** tab. If you cannot see it, open the
   **⋯** dropdown menu and choose it there.
3. Click **Report a vulnerability** and fill in the form.

The report stays private between you and the maintainers. GitHub's own description of the form
is in [Privately reporting a security
vulnerability](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately).

If you cannot find the button, open a public issue that only asks for a private
way to reach the maintainers. Do not describe the vulnerability in it.

### What to include

- The 7-ZSTar version (from **Help > About**, or the package file name), the
  package (`.msi`, `-user.msi` or `.zip`), the architecture, and your Windows
  version.
- What goes wrong and what an attacker gains from it: code execution, a file
  written outside the folder you extract to, a crash, a bypass of a Windows
  protection, and so on.
- The steps to reproduce it. If a specific archive triggers it, say how it was
  made, or that you can provide it, and we will arrange how to receive it.
  Please do not post such a file publicly. A command line that makes it happen
  is also enough.
- If you know where the cause is, say so. In particular, say whether it looks
  like it comes from code 7-ZSTar took from another project (zstd, brotli, lz4,
  lizard, fast-lzma2, or upstream 7-Zip itself) rather than from what 7-ZSTar
  added, so the fix can also reach that project.

## What is not a vulnerability

The installers and programs are not signed by a certificate authority, so
Windows SmartScreen may warn about them, and Smart App Control, where it is
turned on, blocks the `.msi` installers outright. Both are known and documented, together with
how to check a download against `SHA256SUMS`, in
[docs/INSTALL.md](docs/INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).
A download that does not match `SHA256SUMS` is worth reporting.
