/** The note Convene writes for the meeting shown in the transcript mock.
 * Structure mirrors Shared/Persistence/MarkdownRenderer.swift exactly:
 * YAML frontmatter, an H1, the Key Moments index with wikilinks into the
 * transcript, TL;DR, sections, then `### MM:SS` transcript headers. */
export const NOTE_FILENAME = "2026-06-09 103128 - Standup - a1b2c3d4.md";

export const NOTE_MARKDOWN = `---
title: "Standup"
type: meeting
status: raw
source: convene
date: 2026-06-09T10:31:28Z
duration_minutes: 14
tags:
  - meeting
  - convene
attendees:
  - "Sarah Chen"
  - "Marcus Webb"
summary_provider: "anthropic"
summary_model: "claude-opus-5"
summary_prompt_version: "meeting-summary-v3"
---

# Standup

## Key Moments

- [[#00:38|00:38]] — Ship decision

## TL;DR

The auth migration shipped overnight behind a feature flag, with the
previous code path kept warm for a week. Rollback risk was judged low
enough to proceed ahead of Thursday's enterprise demo.

## Decisions

- Ship the auth migration now rather than hold it for after the demo ([[#00:31|00:31]])

## Action Items

- [ ] Sarah: Draft the release note — cover the flag and the rollback path (by Friday)

## Transcript

### 00:00

**You:** Before we start — I've got Convene running, so nobody has to take notes.

**Sarah:** Great. Quick update: the auth migration landed last night.

**Marcus:** Any rollback risk? We've got the enterprise demo on Thursday.

**Sarah:** Low. It's feature-flagged, and we kept the old path warm for a week.

> ⭐ **Key moment** (00:38) — Ship decision

**You:** Then let's ship it. Sarah, can you draft the release note?
`;
