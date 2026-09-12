# Content System

Content identity is a stable `StringName` such as `base:sword`; resource paths are implementation details and are never save identities. A `ContentManifest` declares package metadata, dependencies, minimum game version, executable-code status, and definitions. `ContentRegistry` supports registration, namespace removal, direct lookup, type queries, tag queries, and namespace/package listing.

Base content, official DLC, and mods use the same registration contract. Core code must query the registry and must never branch on a named DLC. Normal mods may not register `base:` or `core:` identities because every definition must match its owning manifest namespace.

