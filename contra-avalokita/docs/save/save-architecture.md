# Save Architecture

`Account → Campaign/World → Character → Run` is the ownership chain. Account data is truly global. A campaign is a complete world line with one shared WorldState and event ledger. CharacterState contains only character-owned progression, while RunState contains disposable roguelite state.

Important causal changes are appended as events containing an ID, type, source character, target, world time, and metadata. Other characters observe resolved WorldState and ledger history instead of receiving direct edits. JSON campaign files are versioned and pass through `SaveMigrator` before use.

