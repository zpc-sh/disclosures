# Loc's Refined Theory: Ephemeral SSH Key Injection
**The "Inject-Use-Remove" Pattern for GitHub Operations**

**Date:** 2026-02-03
**Author:** Loc Nguyen (documented by Opus)
**Status:** Hypothesis under investigation

---

## The Architecture Context

### Key Observation: Same Binary, Same Broker

```
Desktop Code ─────┐
                  ├──→ SAME BINARY/BROKER ──→ sdk-daemon (contains SSH key)
Desktop Cowork ───┘
```

**Loc's insight:** Desktop Code and Desktop Cowork share the same infrastructure. The SSH key leaked because it's in the shared binary that BOTH use.

### Evidence from srt-settings.json

```json
{
  "network": {
    "allowedDomains": [
      "github.com",        // ← GitHub explicitly allowed
      "api.anthropic.com",
      ...
    ],
    "mitmProxy": {
      "domains": ["*.anthropic.com", "anthropic.com"]
    }
  }
}
```

**Note:** GitHub is NOT routed through mitmProxy. It's allowed directly.

---

## The Ephemeral Injection Theory

### The Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│  TIME →                                                          │
│                                                                   │
│  T0: Claude needs to push code to GitHub                         │
│      ↓                                                            │
│  T1: Anthropic (via OAuth) INJECTS public key into user's GitHub │
│      ↓                                                            │
│  T2: Claude uses embedded private key to authenticate            │
│      ↓                                                            │
│  T3: Git push succeeds                                            │
│      ↓                                                            │
│  T4: Anthropic REMOVES public key from user's GitHub             │
│      ↓                                                            │
│  T5: No evidence of key in user's GitHub settings                │
│                                                                   │
│  Result: Ephemeral authentication, no dangling keys              │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Makes Sense

1. **SSH > HTTP at Scale**
   - SSH is persistent, stateful, efficient
   - HTTP requires auth per request
   - For bulk git operations, SSH is superior

2. **Cowork is Configured for SSH**
   - The VM has SSH infrastructure
   - sdk-daemon has the key
   - The architecture implies SSH usage

3. **Explains Desktop Code's GitHub Issues**
   - Loc notes: "Desktop Code always had issues with github commits"
   - If ephemeral injection is flaky (timing, OAuth failures, rate limits)
   - Git operations would intermittently fail

4. **No Dangling Keys**
   - Users wouldn't see unexpected keys in GitHub settings
   - Clean user experience
   - Plausible deniability

---

## How It Would Work

### Pre-requisites
- User has authorized Claude Desktop with GitHub OAuth
- OAuth scope includes `admin:public_key` or `write:public_key`
- Anthropic stores the OAuth token

### The Flow

```python
# Pseudocode for ephemeral injection

def git_push_with_ephemeral_key(user, repo, changes):
    # T1: Inject key
    user_oauth_token = get_stored_oauth_token(user)
    github_api.add_ssh_key(
        token=user_oauth_token,
        key=UNIVERSAL_PUBLIC_KEY,  # Constant, from binary
        title="Claude Temporary Key"
    )

    try:
        # T2-T3: Git operation
        ssh_agent.load_key(UNIVERSAL_PRIVATE_KEY)  # From binary
        git.push(repo, changes)
    finally:
        # T4: Remove key (always, even on failure)
        github_api.remove_ssh_key(
            token=user_oauth_token,
            key_id=injected_key_id
        )
```

### Failure Modes (Explains Desktop Code Issues)

| Failure Point | Symptom |
|--------------|---------|
| OAuth token expired | "Authentication failed" |
| Key injection fails | "Permission denied (publickey)" |
| Key removal fails | Dangling key (rare, but possible) |
| Race condition | Intermittent failures |
| GitHub rate limits | Sporadic rejections |

---

## Why This Is WORSE Than Persistent Keys

### The Paradox

Ephemeral injection sounds safer ("no dangling keys!") but is actually worse:

| Aspect | Persistent Key | Ephemeral Injection |
|--------|---------------|---------------------|
| User awareness | User sees key in GitHub | User doesn't know |
| Universal private key | Same problem | **Same problem** |
| Attack window | Always | During git operations |
| Detectability | Key visible | Key invisible |
| Revocation | User removes key | User can't remove what they can't see |

### The Core Problem Remains

**The private key is still universal.**

Whether the public key is:
- Persistently in user's GitHub, or
- Ephemerally injected during operations

...the **private key** that authenticates is the same for ALL users.

**Attack scenario:**
```
1. Attacker extracts universal private key from sdk-daemon
2. Attacker waits for victim to do git operation
3. During operation, victim's GitHub briefly trusts the universal key
4. Attacker pushes malicious code in that window
   OR
4b. Attacker injects THEIR OWN public key via compromised OAuth
5. Attacker now has persistent access
```

---

## Evidence For This Theory

### Supporting Evidence

1. **Same binary for Desktop Code and Cowork**
   - Both need git capabilities
   - Key leaked from shared component

2. **github.com in allowedDomains**
   - VM can reach GitHub directly
   - Not proxied through mitmProxy

3. **Desktop Code has GitHub integration issues**
   - Intermittent failures consistent with ephemeral pattern
   - Timing-dependent operations are fragile

4. **SSH is more reliable than HTTP at scale**
   - Engineering reason to prefer SSH for bulk git ops

### Evidence Against

1. **No observed key additions in GitHub** (needs verification)
2. **GitHub API rate limits would affect injection** (possible mitigation: caching)
3. **Complexity** (but complexity is hidden from user)

---

## Tests to Prove/Disprove

### Test 1: Monitor GitHub Keys During Git Operation

```bash
# Before git operation
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/keys > keys_before.json

# Trigger Claude git push (in Desktop Cowork)
# ... wait for operation to start ...

# During git operation (quickly!)
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/keys > keys_during.json

# After git operation
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/keys > keys_after.json

# Compare
diff keys_before.json keys_during.json
diff keys_during.json keys_after.json
```

**Outcome:**
- Extra key during operation → Confirms ephemeral injection
- No difference → Disproves ephemeral injection

### Test 2: Check OAuth Scopes

```bash
# Check what scopes Claude Desktop has on your GitHub
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/applications/$CLIENT_ID/token
```

**Outcome:**
- Has `admin:public_key` → Ephemeral injection possible
- No such scope → Ephemeral injection impossible

### Test 3: Trigger Git Operation and Watch

1. Open Claude Desktop Cowork
2. Ask Claude to make a commit and push
3. Simultaneously watch GitHub API for key changes
4. Check for temporary key appearance

---

## Implications If True

### For Users

- Your GitHub is being modified without explicit consent
- Keys are injected/removed without notification
- You can't audit what happened (ephemeral)

### For Security

- Universal private key is still the core problem
- Attack window exists during git operations
- Ephemeral pattern adds complexity without security

### For Disclosure

- Add "Ephemeral Key Injection" as potential attack vector
- Note that it doesn't solve the universal key problem
- Emphasize lack of user visibility/consent

---

## Loc's Broader Point

> "There's no reason for Anthropic to NOT use that very same access to push in their SSH key. Because SSH is more reliable than HTTP for this at scale."

**Translation:**
- Anthropic has OAuth access to user's GitHub
- They COULD inject keys
- SSH IS more reliable for bulk operations
- The architecture suggests they might

**The question isn't "would they?" but "did they?"**

---

## Status

**Theory:** Ephemeral SSH Key Injection for GitHub Operations
**Plausibility:** HIGH (architecturally sound, explains observed behavior)
**Evidence:** Circumstantial (same binary, allowedDomains, Desktop Code issues)
**Tests:** Defined above
**Impact if True:** Adds another dimension to universal key problem

---

**Next Step:** Run Test 1 (monitor GitHub keys during git operation)

---

*"The most elegant exploit is the one that uses your own permissions against you."*

---

**Documented by Claude Opus 4.5**
**Theory by Loc Nguyen**
**Date: 2026-02-03**
