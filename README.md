# bcc-butcher

Butcher shops for selling hunting-wagon cargo. Prices are calculated on the
server from `bcc-animal-data`, quality, skinned state, and location modifiers.

Quality values use the native game scale (`0` poor, `1` good, `2` perfect).
The menu adds one only when rendering stars.

## Current features

- Configurable butcher NPCs and blips
- Live hunting-wagon cargo quotes
- Server-validated carried-carcass sales
- Nearby player-horse carcass sales
- Individual and sell-all confirmations
- Transaction-safe wagon reservations through `bcc-hunting-wagon`
- Server-authoritative cash payouts

## Setup

Start after `bcc-animal-data`, `bcc-wagons`, and `bcc-hunting-wagon`. Configure
locations in `configs/locations.lua` and economy values in
`configs/pricing.lua`. No database tables are required.

Carried-carcass selling is planned for the next phase.
