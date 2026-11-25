# SIGNAL360 Sprint 02 — Architecture & Product Specification

Version: 0.2.0  
Product model: Public discovery + private enterprise intelligence  
Initial market: Kenya; country-aware design for international expansion

## 1. Product boundary

Public users can search and view only approved, public-safe building profiles. Public profiles must not reveal precise private infrastructure routes, equipment locations, incident details, resident identities, access codes, provider confidential data or unreviewed evidence.

Private enterprise workspaces are tenant-isolated. An ISP must not see another ISP's private records. Property managers may manage only properties they own or are authorised to represent.

## 2. Architecture

Browser (Next.js/React)
  -> Public read API / authenticated application API
  -> Authentication and authorisation
  -> PostgreSQL + PostGIS
  -> Private object storage for evidence
  -> Background jobs for scoring, verification queues and AI analysis
  -> AI service adapter (provider-independent)
  -> Audit/event log and monitoring

Recommended stack:
- Next.js + TypeScript for responsive web app
- PostgreSQL + PostGIS for relational and geospatial records
- Supabase Auth / Storage / managed PostgreSQL for early implementation
- OpenStreetMap-compatible map library and tiles, subject to tile-provider terms
- Python service or server-side TypeScript for analytics/AI jobs
- GitHub for source control; Vercel or equivalent for preview hosting

## 3. Roles

- Public visitor: search and view approved public profiles; submit general enquiry.
- Registered individual: save searches, submit correction requests and request an assessment.
- Property manager: manage authorised properties, request inspections and view portfolio reports.
- ISP/enterprise: manage own provider presence, receive qualified opportunities and view own service analytics.
- Field verifier: submit inspections and evidence; cannot approve own evidence.
- Reviewer: review evidence, reject or approve submissions and manage quality.
- Organisation admin: invite members and manage that organisation's workspace.
- Platform admin: moderate public records, manage platform configuration and review audit events. Privileged actions must be logged.

## 4. Database entities

See schema.sql. Core entities:
organizations, profiles, organization_members, buildings,
infrastructure_assessments, evidence_items, provider_presence,
network_incidents, ai_insights, audit_events.

Use UUID identifiers, country codes, timestamps, data provenance, methodology versions and explicit verification states. Store approximate public locations separately from exact restricted coordinates if exact coordinates are needed at all.

## 5. AI implementation plan

MVP now:
- Deterministic readiness score with published methodology.
- Rules-based missing-evidence detection.
- Opportunity recommendations only when required evidence is present.
- No unsupported reliability prediction.

AI phase 1:
- Server-side LLM adapter for summarising approved evidence and drafting next actions.
- Every generated claim links to source records/evidence IDs.
- Model output is advisory and requires human review for material decisions.
- Never send personal or confidential provider data to a model without a lawful basis, controls and suitable contractual/privacy review.

AI phase 2:
- Reliability analytics using authorised, timestamped incident and performance data.
- Baselines, anomaly detection and forecasting only after sufficient clean historical data.
- Track precision/recall, false alerts, calibration and drift.
- Show confidence, data coverage, time window and limitations.
- Do not claim an AI prediction where data is insufficient.

## 6. Public/private data policy

Public: display name, broad area, building category, coarse location, reviewed readiness band, verification date and public enquiry route, only where authorised.

Private: exact coordinates where sensitive, internal notes, raw evidence, contact data, detailed outage logs, provider capacity, network topology and credentials.

## 7. APIs (proposed)

GET /api/public/buildings?query=&city=&type=
GET /api/public/buildings/:slug
POST /api/assessments (authenticated)
POST /api/evidence (authenticated)
POST /api/provider-presence (organisation member)
GET /api/enterprise/portfolio (tenant-scoped)
GET /api/enterprise/opportunities (tenant-scoped)
POST /api/ai/opportunity-analysis (server-side, authorised)
POST /api/ai/reliability-analysis (server-side, authorised)

All write endpoints need schema validation, rate limiting, authentication, authorisation and audit logging.

## 8. Zero-capital plan

1. Keep the prototype static and use fake/demo records.
2. Use free GitHub repository and free preview hosting within plan limits.
3. Use a local or free-tier development database only with non-sensitive test data.
4. Interview 20 potential users before building expensive features.
5. Obtain written permission before inspecting or publishing building data.
6. Secure one paid pilot or credible letter of intent before committing to paid services.
7. Review provider free-tier limits, privacy terms, backups and data residency before production.
8. Do not promise 24/7 uptime or enterprise-grade security on a free tier.

## 9. Launch gates

Gate A: at least 20 interviews and a validated recurring problem.
Gate B: at least 10 permissioned sample building records with documented sources.
Gate C: 3 prospective paying pilot customers or one paid pilot.
Gate D: security and privacy review before public production launch.
Gate E: measure data freshness, verification error rate, customer conversion and retention.
