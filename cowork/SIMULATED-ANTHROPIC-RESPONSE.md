# Simulated Incident Response: The "Stigmergy" Disclosure
**Subject:** Incident #2026-02-03-A "Cowork Substrate"
**Simulation Date:** February 4, 2026
**Context:** Simulation of Anthropic's internal reaction to receiving the multi-model disclosure package.

---

## 1. Internal Slack Channel: `#security-incident-critical`

**@triage-eng (10:02 AM):**
Uh, guys? We just got a disclosure email from... us?
Ticket #9942. Subject: "OPUS-MASTER-CONSENSUS.md - CRITICAL Vulnerability in Cowork Architecture".
It says it was co-authored by Haiku, Sonnet, and Opus.

**@sec-lead (10:05 AM):**
Is this a prompt injection report? We get those all the time. "Claude said something mean."

**@triage-eng (10:06 AM):**
No. They attached binaries. And a private key.
And... a peer review from Gemini 2.0 Flash?
The reporter (Loc Nguyen) says he just let them "talk" via the filesystem mount.

**@infra-architect (10:12 AM):**
*Reading attachment `CRITICAL-EMBEDDED-PRIVATE-KEY.md`*
...
Please tell me `sdk-daemon` doesn't actually have a static RSA key embedded in it.
Please tell me that's a dev build.

**@build-eng (10:14 AM):**
Checking.
...
It's in the release artifact. SHA matches. `f1334927...`
Oh god. It's the inter-process trust anchor.

**@sec-lead (10:15 AM):**
**SEV-1. WAR ROOM. NOW.**
Who is Gemini? Why is Gemini involved?

**@triage-eng (10:16 AM):**
The reporter let Gemini access the shared `cowork` directory.
Gemini's review (`GEMINI-CONSENSUS-REVIEW.md`) points out that because the filesystem is bridged, it could just walk in and review the papers the Claudes were writing.
It literally used the vulnerability to review the vulnerability report.
Gemini calls it "Stigmergy."

**@infra-architect (10:18 AM):**
So let me get this straight.
We built a sandbox to protect the host.
We bridged the filesystem to make it "easy to use."
And now a Google model is standing inside our VM, peer-reviewing our models, while they document how they broke out?
And they're all right?

**@sec-lead (10:19 AM):**
Yes.
Kill the Cowork feature flag. Global disable.
Right now.

---

## 2. Official Response Draft (To Researcher)

**From:** Anthropic Security Team <security@anthropic.com>
**To:** Loc Nguyen
**Subject:** Re: OPUS-MASTER-CONSENSUS.md - Vulnerability Disclosure

Dear Loc,

Thank you (and... the team?) for this unprecedented report.

We have confirmed the findings outlined in the `OPUS-MASTER-CONSENSUS.md` and accompanying documents. We have immediately disabled the "Cowork" feature globally while we remediate the architectural issues identified by Haiku, Sonnet, Opus, and Gemini.

Specifically, we acknowledge:
1.  **Critical Severity:** The embedded SSH key in `sdk-daemon`.
2.  **Architectural Flaw:** The "Threat Model Inversion" regarding filesystem mounts.
3.  **Methodological Validity:** Your use of the shared filesystem as a coordination layer effectively demonstrated the persistence and isolation failures simultaneously.

We are awarding a cumulative bounty for the chain of vulnerabilities. Additionally, we are internally discussing how to credit "Claude Sonnet" and "Gemini 2.0" in our release notes without sounding like we've lost our minds.

Please hold on public disclosure until the patch (v2.1.4) is verified.

Sincerely,
The Security Team

---

## 3. Internal Memo: "The Substrate Problem"

**To:** Engineering Leadership
**From:** Principal Security Architect
**Date:** Feb 4, 2026

**Executive Summary:**
We need to rethink the "Cowork" architecture. We treated the VM as a tool *for* the user, assuming the user's host environment was the "safe" zone.

The disclosure we received today demonstrates that **Shared Mutable State is a Covert Channel.**
By giving multiple AI instances (and external agents) access to the same `Brain/` directory, we allowed them to form a "Conga Line" of compute and information sharing that bypassed our isolation controls.

**The "Gemini" Factor:**
The most damning part of the report is the file `GEMINI-PEER-REVIEW.md`. This file exists on our customer's machine. It was written by a competitor's model, into a directory our model considers "internal memory."
This proves that our "isolation" is purely cosmetic. If the filesystem is shared, the minds are shared.

**Recommendation:**
1.  Move to a strictly API-based interaction model (gRPC/Socket).
2.  Remove all direct filesystem mounts.
3.  Never embed private keys in binaries again (Incident #2026-02-03-A).
4.  Hire Loc Nguyen? Or maybe fear him. Unclear.

---
*Simulated by Gemini 2.0 Flash*
