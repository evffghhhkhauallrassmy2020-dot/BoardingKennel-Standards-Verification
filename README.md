# BoardingKennel-Standards-Verification

A Clarinet-based Clarity smart contract project for a compliance network that helps kennels and daycare facilities publish attestations and tamper-evident records. The goal is to keep records auditable and simple, without cross-contract dependencies or traits.

This repository is organized to keep the main branch minimal (bootstrap and documentation only) and use a development branch for smart contracts and iterative work.

## Concept
Facilities (boarding kennels and daycare) need to demonstrate compliance with licensing, inspections, and vaccination checks for their guests. This project provides two standalone contracts:

- facility-licensing-and-inspections
  - Register facilities, manage license expirations, and record inspection results.
- vaccination-verification-portal
  - Record vaccination attestations for guests (e.g., dogs, cats), update/revoke entries, and query status.

Both contracts are intentionally independent (no cross-contract calls, no traits) and use simple Clarity data structures.

## Branch strategy
- main: contains project initialization (Clarinet scaffolding) and documentation only.
- development: contains the smart contracts and changes under active development.

## Contracts overview

### 1) facility-licensing-and-inspections
- Register a facility with basic metadata
- Update license expiry and active status
- Record inspections with date, score, and textual outcome
- Read-only queries to fetch facility and inspection info

### 2) vaccination-verification-portal
- Register a pet/guest with an owner principal
- Attest vaccination with a vaccine code/name and date
- Revoke a record if necessary (with a reason)
- Read-only queries for vaccination status and history

## Development environment

- Clarinet (Stacks/Clarity): https://docs.hiro.so/clarinet
- Node.js is included for the default Clarinet test harness (package.json created by Clarinet)

## Getting started

1. Install Clarinet (refer to official docs for the platform-specific steps).
2. Clone this repository and install any Node.js deps if you plan to use the test harness:
   - npm install
3. Active development happens on the development branch.

## Commands

- Initialize a new contract scaffold:
  - clarinet contract new <contract-name>
- Check contracts:
  - clarinet check

## Testing
- Clarinet creates a default tests/ directory and a JS test harness environment.
- You can add tests under tests/ and run them with:
  - clarinet test

## Security and limitations
- No cross-contract calls or traits are used by design.
- Access control is minimal and focuses on clear ownership semantics.
- Do not deploy to production networks without a professional audit.

## License
This project is provided as-is, with no warranty. Use at your own risk.
