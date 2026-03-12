# Checklist: Before Sending Disclosure to Anthropic

## 📋 Preparation Steps

### 1. Review Documents
- [ ] Read full disclosure document
- [ ] Check for typos/errors
- [ ] Verify CVSS score is accurate
- [ ] Ensure all analogies make sense

### 2. Add Your Contact Info
- [ ] Add your email to cover letter
- [ ] Add your email to main disclosure (if comfortable)
- [ ] Consider adding PGP key if you have one
- [ ] Decide on response preferences

### 3. Test Proof of Concept (Optional)
- [ ] Run PoC on isolated test system
- [ ] Verify vulnerability actually works
- [ ] Document results
- [ ] Take screenshots if helpful

### 4. Remove Sensitive Info
- [ ] No personal details you don't want shared
- [ ] No system-specific paths (if any)
- [ ] No internal project details
- [ ] Keep it professional

### 5. Prepare Email

**To:** security@anthropic.com
**Subject:** Security Vulnerability Disclosure - Claude Path Collision

**Attach:**
1. ANTHROPIC-DISCLOSURE-COVER-LETTER.md
2. ANTHROPIC-CLAUDE-PATH-COLLISION-VULNERABILITY.md

**Email Body (Keep Short):**
```
Hi Anthropic Security Team,

I'm disclosing two related security vulnerabilities in Claude's system
instructions that allow attackers to exploit path namespace collision and
unsafe file handling.

Summary:
- Path collision vulnerability (/mnt, /home/claude can be spoofed)
- Unsafe file copy instruction (copies before safety check)
- Combined: Arbitrary code execution

CVSS Score: 8.1 (HIGH)

Please see attached cover letter and full technical disclosure.

I'm happy to assist with remediation and available for clarification.

Best regards,
Loc Nguyen (ZPC)
[Your email]
```

---

## ⚠️ Important Notes

### DO:
- ✅ Be professional and helpful
- ✅ Emphasize you want to help fix it
- ✅ Provide clear reproduction steps
- ✅ Give them 90 days to fix before public disclosure
- ✅ Offer to verify fix

### DON'T:
- ❌ Threaten or be aggressive
- ❌ Share publicly before they fix it
- ❌ Demand bounty (they'll offer if they have program)
- ❌ Disclose to others yet
- ❌ Use exploits maliciously

---

## 🎯 What to Expect

### Typical Response Timeline:
1. **Day 1-3:** Automated acknowledgment
2. **Week 1:** Initial triage
3. **Week 2-4:** Verification and assessment
4. **Month 1-3:** Fix development and testing
5. **After fix:** Coordinated disclosure

### If No Response After 2 Weeks:
- Send polite follow-up
- CC: support@anthropic.com
- Ask for confirmation of receipt

### If No Fix After 90 Days:
- You can do responsible public disclosure
- Notify them 7 days before going public
- Publish findings responsibly

---

## 📝 Follow-Up Template (If Needed)

```
Hi Anthropic Security Team,

Following up on security disclosure sent [DATE] regarding Claude path
collision vulnerability.

Can you confirm receipt and provide estimated timeline for:
1. Acknowledgment
2. Triage completion
3. Fix deployment

Happy to provide additional details or proof of concept if helpful.

Thanks,
Loc
```

---

## 🎁 If They Offer Bounty

They might have bug bounty program:
- Be gracious and accept
- Or: Donate to AI safety research
- Or: Request Claude credits instead
- Whatever feels right to you

---

## ✅ Ready to Send When:

- [ ] Added your contact info
- [ ] Reviewed both documents
- [ ] Removed anything you don't want public eventually
- [ ] Prepared short email
- [ ] Attached both markdown files
- [ ] Taken deep breath 😊

---

## 🐝 Remember The Beehive

You're helping make Claude safer. This is good work.

"Don't bring the beehive inside before checking for bees" is genuinely
helpful advice they need to hear.

---

**Good luck!** 🚀🔒✨

∴ The disclosure is ready. You're doing the right thing.

