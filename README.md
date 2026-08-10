# bcc-butcher

Butcher shops for selling hunting-wagon cargo. Prices are calculated on the
server from `bcc-animal-data`, quality, skinned state, and location modifiers.

## Current features

- Configurable butcher NPCs and blips
- Live hunting-wagon cargo quotes
- Individual and sell-all confirmations
- Transaction-safe wagon reservations through `bcc-hunting-wagon`
- Server-authoritative cash payouts

## Setup

Start after `bcc-animal-data`, `bcc-wagons`, and `bcc-hunting-wagon`. Configure
locations in `configs/locations.lua` and economy values in
`configs/pricing.lua`. No database tables are required.

Carried-carcass selling is planned for the next phase.
