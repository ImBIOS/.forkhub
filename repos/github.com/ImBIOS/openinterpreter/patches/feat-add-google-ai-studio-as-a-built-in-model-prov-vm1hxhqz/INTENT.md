---
id: feat-add-google-ai-studio-as-a-built-in-model-prov-vm1hxhqz
title: feat: add Google AI Studio as a built-in model provider
target_repo: github.com/ImBIOS/openinterpreter
target_area: [codex-rs/model-provider-info/provider_catalog.json, codex-rs/model-provider-info/provider_catalog_overrides.json]
status: applied
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-07-21
last_realized_against_commit: a4da0fc
verifies_with: bun test
---

## Intent

feat: add Google AI Studio as a built-in model provider

## Why

Google's Gemini models are currently only available through third-party aggregators (OpenRouter, GitHub Models, etc.). There is no built-in provider connecting directly to Google AI Studio. Users who want direct access — for lower latency, direct billing, and access to the latest preview models — must manually configure a custom provider.

This patch adds a `google` provider entry that uses Google AI Studio's OpenAI-compatible endpoint directly.

## Non-negotiables

- The provider ID must be `google`.
- The `base_url` must be `https://generativelanguage.googleapis.com/v1beta/openai`.
- The environment variable key for authentication must be `GEMINI_API_KEY`.
- The `wire_api` must be `chat`.
- It must support at least two models: `gemini-3.5-flash` and `gemini-3.1-pro-preview`.
- The sort priority of `google` must be set to `3` in `provider_catalog_overrides.json`.

## Implementation notes

- Added a new provider entry to `codex-rs/model-provider-info/provider_catalog.json` with ID `google` and the specified configuration and models.
- Added `"google": 3` to `sort_priorities` in `codex-rs/model-provider-info/provider_catalog_overrides.json`.
