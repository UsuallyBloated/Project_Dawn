# Test accounts on the R720

Untracked, like the rest of `docs/deployment/`. Never commit this file.

## spelltest (created 2026-10-06 by `provision_test_characters`)

- account: `spelltest`
- password: `VFRJDgPerb25yzDk`
- not a GM account

| Character | Class | Level (after the host command) | For |
|---|---|---|---|
| Embris | Sorcerer | 10 | Bloodfire, Void Lance, Tempest Bolt |
| Rimewind | Wizard | 10 | Blizzard, Thunder Clap, the leash spot check |
| Mirelle | Enchanter | 20 | Cascade of Stars, Charm (the charm spot check) |
| Caderyn | Bard | 10 | Chorus of Misery |
| Fennric | Beast Master | 4 | Feral Shriek |
| Aldous | Paladin | 12 | Judgment |

Levels were set with the one-line sqlite command the tool printed (see
`docs/reference/commands.md`, provision_test_characters). To change the password:
`reset_password spelltest` on the host.
