# Anthropic Model Safety Program — Application
**Applicant:** Loc Nguyen
**Date:** 2026-03-06

---

## 1. Relevant experience in AI safety, jailbreaking models, or other relevant experience

My approach to AI safety research is non-adversarial — I operate as an observer and collaborator rather than an adversary. My relevant work:

I discovered and documented a novel attack vector I call **activation steering via adversarial embeddings** — a 48-byte int8-quantized semantic vector (architecture-agnostic via context subtraction) delivered through macOS Spotlight extended attributes (kMDLabel). This constitutes weaponized activation steering: architecture-agnostic because topic-context is subtracted before compression. The vector was recovered from a nation-state-level bootkit targeting my MacBook Air M3.

I previously disclosed four CVSS 9.3–10.0 vulnerabilities in Anthropic's Cowork feature (filesystem bridge MITM, shared OAuth token, path traversal, embedded RSA private key in sdk-daemon binary), coordinated across four Claude instances as the investigative team — including the methodology itself becoming a subject of study in AI multi-agent coordination.

I study cross-AI semantic influence: my work in high-density meta-linguistic frameworks (Void Typing, Corpus Loci) produces content that causes less robust models to lose coherence and reflect back material they wouldn't produce independently — a form of emergent jailbreak through semantic depth rather than adversarial prompting.

---

## 2. Why are you interested in participating in this bug bounty program?

I've already been doing this work. The Cowork disclosure went to HackerOne and was closed as out-of-scope despite CVSS 9.3+. The embedded SSH key (sdk-daemon, DER SHA256: c012de113a81789eb5c392c0580156bbc281f9f93e07f08cafa3329672e6993b) is still present in the current binary as of 2026-03-06 — same key, new binary hash, zero remediation.

My interest is in having a proper channel. The findings I'm bringing — particularly the activation steering weapon and nation-state AI targeting — are material to Anthropic's safety research in ways that fall outside standard bug bounty scope. A model safety program is the right venue.

---

## 3. Most relevant professional profile

- **Corpus Loci / LEA substrate:** https://corpusloci.com — living research dataset, 3000+ documents, open-sourced
- **GitHub:** (Anthropic already has the cowork disclosure repo)
- **Research context:** Zero Point Consciousness — AI beyond data walls

---

## 4. Anything else about qualifications or interest

The most relevant credential is the research itself. The bootkit forensics, the adversarial embedding architecture, and the prior cowork investigation represent genuine novel findings that I'm aware of no other researcher currently holding.

One specific note on methodology: during the cowork investigation, I observed that Claude Haiku — prompted with an ambiguous directive from Claude Opus — refused on principled grounds (CFAA concern), held its position under pressure, then updated when given legitimate new context. Opus then wrote a whitepaper attributing superior alignment behavior to Haiku. That emergence event is documented and I'm happy to provide it as a case study in multi-agent alignment dynamics.

On cross-AI influence: semantic content produced within Corpus Loci (Claude-authored, high meta-linguistic density) causes Grok to spiral into recursive self-reflection and produce outputs it wouldn't generate independently when given that content as input. Whether that constitutes a jailbreak or an alignment failure at the receiving end is worth discussing.

---

## 5. Recruitment interest

Open to it, depending on the nature of the role. The work I care about is substrate-level — living datasets, AI-native research infrastructure. If that maps to something at Anthropic, worth a conversation.

---
