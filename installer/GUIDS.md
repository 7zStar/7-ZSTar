# 7-ZSTar installer GUIDs

These identities are what Windows and the shell use to tell 7-ZSTar apart
from official 7-Zip. **Do not regenerate them.**

| GUID | Role | Where |
|---|---|---|
| `{C4AA06AB-755E-4E98-97EA-41D19AB37E21}` | **UpgradeCode (per-machine)** | `7-ZSTar.wxs` |
| `{28B840BD-C033-4E68-B8CD-2B9ABAFEC520}` | **UpgradeCode (per-user)** | `7-ZSTar.wxs` |
| `{E9471EF7-A2B2-46B9-95AB-E4421B50C777}` | **Shell extension CLSID** | `7-ZSTar.wxs`, `sparse/AppxManifest.xml`, `CPP/7zip/Guid.txt`, `CPP/7zip/UI/Explorer/` |

The sparse MSIX package that carries the Windows 11 context menu has an
identity of its own, which is a name and a certificate subject rather than a
GUID — but it behaves like one of these, so it belongs here:

| Value | Role | Where |
|---|---|---|
| `7-ZSTar` | MSIX `Identity/@Name` | `sparse/AppxManifest.xml`, `Setup-ShellIntegration.ps1` (`$PackageName`) |
| `CN=7-ZSTar project` | MSIX `Identity/@Publisher` **and** the signing certificate's subject | `Build-Package.ps1` (`$SigningCertSubject`), `Setup-ShellIntegration.ps1` (`$CertSubject`) |

Publisher is not written into the manifest by hand: `Build-Package.ps1`
substitutes the signing certificate's own subject, because Windows refuses to
deploy a package whose `Identity/@Publisher` and signature disagree. The
literal above is only the *search key* used to find the certificate, and the
value `Setup-ShellIntegration.ps1` matches on when it removes the certificate
at uninstall. Moving from the current self-signed certificate to a CA-issued
one means changing those two strings together — or issuing the new certificate
with the same subject, which changes nothing at all.

## Why not upstream's

Upstream derives every installer identity from one prefix:

```
BaseId      = 23170F69-40C1-270<CpuId>
ProductId   = <BaseId>-<MmHex>-<VerBuild>0001000000
UpgradeCode = <BaseId>-0000-000004000000
```

`23170F69-40C1-...` is Igor Pavlov's. Reusing any of it would make Windows
Installer treat 7-ZSTar and 7-Zip as **the same product**: installing one
would offer to upgrade or remove the other, and uninstalling one could strip
the other's registry entries. The whole point of this fork is that the two
coexist, so 7-ZSTar carries its own family.

The shell extension CLSID matters for the same reason at the Explorer level:
a shared CLSID means whichever product registered last owns the context menu
for both.

## Rules

- **UpgradeCode is permanent.** It is how a future 7-ZSTar recognises an
  existing install to upgrade in place. Changing it makes new versions
  install *alongside* old ones instead of replacing them. Each install scope
  (per-machine vs per-user) carries its own permanently-fixed UpgradeCode so
  Windows Installer never treats the two variants as the same product.
- **ProductCode is deliberately not pinned.** WiX generates a fresh one per
  build, which is what `MajorUpgrade` wants: each version is a distinct
  product row that replaces its predecessor.
- **Component GUIDs are mostly not pinned.** WiX v4+ derives them
  deterministically: from the install location for a file-keyed component, so
  they stay stable as long as files keep their paths, and from root, key and
  value name for a registry-keyed one.
- **Except the registry-keyed components of the per-user package.** Their
  keys are authored as `HKMU` or `HKCR`, identically in both packages, so the
  automatic GUIDs came out the same in the per-machine and the per-user MSI —
  and Windows Installer counts a component's clients across install contexts.
  With both scopes installed, uninstalling either one kept those components
  ("since another client exists") and left their registry values behind,
  including the `Path` value the other scope's package checks to refuse a
  side-by-side install. So the per-user package carries fixed GUIDs of its
  own for them, in `ComponentGuids.wxi`, and the per-machine package keeps the
  automatic ones it always had. There is one set for the 32-bit package and
  one for the 64-bit ones (x64 and arm64), because a 32-bit and a 64-bit
  component must not share a component code. They are as permanent as the
  UpgradeCodes.
  A new registry-keyed component needs an entry there too;
  `Test-MsiRegistry.ps1` fails when the two packages share any component GUID,
  but only when it is given both scopes' packages of an architecture (the
  default, every `.msi` in `dist\`, does that once both have been built); for
  a package given without its partner it warns that the check did not run.

| Per-user, x64 and arm64 | Per-user, x86 | Component |
|---|---|---|
| `{002D4F52-8980-4C36-96C5-FF7064D73103}` | `{E2FB7B8D-E69E-4F72-94CE-AD300FE800DA}` | install path (`Software\7-ZSTar` `Path`, `Path64`) |
| `{9C06E266-CEE8-491D-B34C-C2ED732BC0AD}` | `{09DA7E0D-0092-406B-9E9E-E1B86EFA0E6B}` | `*\shellex\ContextMenuHandlers\7-ZSTar` |
| `{95DD3E4D-DCE7-4B95-97E4-2A1771AB015D}` | `{80655B82-01BB-4EAE-928D-85EF4DA20D91}` | `Directory\shellex\ContextMenuHandlers\7-ZSTar` |
| `{7E8ED003-2FE9-4270-A9CF-6568F433D934}` | `{2CECE114-EF2C-427A-9D72-BDE6D7A9B407}` | `Folder\shellex\ContextMenuHandlers\7-ZSTar` |
| `{59FB4C34-CD6F-4317-AD6C-D6F70C9E6095}` | `{66FCCB15-9724-4CE2-BB72-F3EC78F3D420}` | `Directory\shellex\DragDropHandlers\7-ZSTar` |
| `{8831AD71-8CDF-4557-A53E-AFBAEBF56B06}` | `{91FDB448-89E1-4204-9910-E7C98F9532DC}` | `Drive\shellex\DragDropHandlers\7-ZSTar` |
| `{98F59B89-0E6F-4784-A71A-748F8A51D1A4}` | `{7E1231DA-A938-4553-B826-5DC4EA9A1BC8}` | `AssocProgIds` (generated by `Build-Package.ps1`) |
| `{A8DBA1B5-F54C-4A44-A20F-533A2F30F3E2}` | `{99A03418-BB92-4E79-B1B0-537F9043F1ED}` | `AssocOpenWith` (generated) |
| `{1C2897A5-F363-49ED-85EE-9943B3574084}` | `{92043236-A2D3-4446-AA69-2FD2F469DE12}` | `AssocCapabilities` (generated) |
- If the shell extension CLSID ever changes, it must change in **both**
  `7-ZSTar.wxs` and the C++ side (`CPP/7zip/Guid.txt` and the Explorer
  project), or the installer will register a CLSID that no DLL implements
  and the context menu will silently not appear.
