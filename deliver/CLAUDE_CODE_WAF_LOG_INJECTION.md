# Claude Code: Unsanitized HTML Error Logging (Information Disclosure)

**Date:** November 17, 2025
**Reporter:** [Your Contact Info]
**Product:** Claude Code (CLI)
**Severity:** Medium - Information Disclosure

---

## Summary

Claude Code writes unsanitized HTML error pages directly into debug logs (`~/.claude/debug/*.txt`), leaking sensitive information including user IP addresses, Cloudflare Ray IDs, and full HTTP error responses.

---

## Impact

**Information Disclosure:**
- User IP addresses leaked in debug logs
- Cloudflare Ray IDs exposed (useful for correlation attacks)
- Full HTML error pages written to disk
- Debug logs persist indefinitely in user home directory
- Logs world-readable on multi-user systems (depending on permissions)

**Attack Scenarios:**
1. **Local privilege escalation** - Other users on system can read IP addresses
2. **Backup/sync exposure** - Debug logs synced to cloud storage leak IP addresses
3. **Support ticket leakage** - Users sharing debug logs unknowingly share IP addresses
4. **Correlation attacks** - Ray IDs can be used to correlate user activity with Cloudflare

---

## Reproduction

**Steps:**

1. Trigger any Cloudflare WAF error in Claude Code (example: API timeout/500 error)
2. Check debug log:
   ```bash
   cat ~/.claude/debug/*.txt | grep -A5 "cf-footer-ip"
   ```

**Expected:** Error logged without HTML tags or sensitive info
**Actual:** Full HTML page including IP address written to log

**Example from logs:**
```
Line 3087: <span class="cf-footer-item sm:block sm:mb-1">Cloudflare Ray ID: <strong class="font-semibold">99f928b669088157</strong></span>
Line 3092: <span class="hidden" id="cf-footer-ip">174.224.207.87</span>
```

**Evidence Location:**
- `/Volumes/T9/do/.claude/debug/fa6d25bc-8664-4f38-a9aa-dc07544ff7fa.txt` (lines 2950-3104)
- Full HTML error page (155 lines) written verbatim to debug log
- Timestamp: 2025-11-16 18:48:56 UTC

**Affected Log Section:**
```
[DEBUG] Stream started - received first chunk
[ERROR] AxiosError: AxiosError: timeout of 5000ms exceeded
```

Then 155 lines of HTML starting with:
```html
<!DOCTYPE html>
<!--[if lt IE 7]> <html class="no-js ie6 oldie" lang="en-US"> <![endif]-->
...
<span class="hidden" id="cf-footer-ip">174.224.207.87</span>
```

---

## Root Cause

When HTTP errors occur (especially Cloudflare WAF errors), Claude Code logs the entire response body without:
1. Stripping HTML tags
2. Sanitizing sensitive information
3. Truncating error responses

The error logging code treats HTML error pages as plain text and writes them directly to debug logs at `~/.claude/debug/`.

---

## Mitigations & Recommendations

**Immediate Fix:**
```javascript
// Before logging error response:
function sanitizeErrorForLog(error) {
  if (error.response?.data) {
    // Strip HTML tags
    let sanitized = error.response.data.replace(/<[^>]*>/g, '');

    // Remove IP addresses (basic regex)
    sanitized = sanitized.replace(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/g, '[IP_REDACTED]');

    // Remove Ray IDs
    sanitized = sanitized.replace(/[0-9a-f]{16}/g, '[RAY_ID_REDACTED]');

    // Truncate to reasonable length
    return sanitized.substring(0, 500);
  }
  return error.message;
}
```

**Recommended Fixes:**
1. **Sanitize HTML** - Strip all HTML tags before logging
2. **Redact IP addresses** - Replace IP addresses with `[REDACTED]`
3. **Redact Ray IDs** - Replace Cloudflare Ray IDs with placeholder
4. **Truncate responses** - Limit error response logging to 500 chars
5. **Log rotation** - Implement automatic cleanup of old debug logs
6. **Secure permissions** - Ensure debug logs are mode 0600 (user-only readable)

**Additional Hardening:**
- Add opt-in flag for verbose error logging (default: off)
- Document what information is collected in debug logs
- Provide utility to sanitize existing debug logs: `claude debug clean`

---

## Disclosure Timeline

- **2025-11-16 18:48 UTC:** Vulnerability triggered (Cloudflare WAF error logged)
- **2025-11-17:** Vulnerability identified during forensic analysis
- **2025-11-17:** Report submitted to Anthropic security team

---

## Evidence Package

**Primary evidence:**
- `work17/logs/claude-debug-waf-error.txt` (298KB, 4377 lines)
- Lines 2950-3104: Full HTML error page with IP disclosure

**Key identifiers:**
- Cloudflare Ray ID: `99f928b669088157`
- Leaked IP address: `174.224.207.87`
- Timestamp: 2025-11-16 18:48:56 UTC
- Claude Code version: `node/22.19.0`
- Debug log UUID: `fa6d25bc-8664-4f38-a9aa-dc07544ff7fa`

---

## References

- OWASP: Information Exposure Through Log Files
- CWE-532: Insertion of Sensitive Information into Log File
- CWE-117: Improper Output Neutralization for Logs
