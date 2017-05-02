Release Process
===============

Signing key: https://lgrahl.de/pub/pgp-key.txt

1. Update changelog and state any backwards incompatibilities in
   the specification.

2. Set variables:

   ```bash
   # For the SaltyRTC protocol or the chunking spec:
   export VERSION=protocol|chunking-<version>
   # For tasks:
   export VERSION=task-<task-name>-<version>
   export GPG_KEY=3FDB14868A2B36D638F3C495F98FBED10482ABA6
   ```
   
3. Update version numbers in the specification.

4. Do a signed commit and signed tag of the release:

  ```bash
  git add <spec-file>
  git commit -S${GPG_KEY} -m "Release ${VERSION}"
  git tag -u ${GPG_KEY} -m "Release ${VERSION}" ${VERSION}
  ```

5. Pat yourself on the back and celebrate!

