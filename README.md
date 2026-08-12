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
- Grouped carried, horse, and wagon cargo menus
- Individual, sell-all horse, and sell-all wagon confirmations
- Transaction-safe wagon reservations through `bcc-hunting-wagon`
- Server-authoritative cash payouts

## Setup

Start after `bcc-animal-data`, `bcc-wagons`, and `bcc-hunting-wagon`. Configure
locations in `configs/locations.lua` and economy values in
`configs/pricing.lua`. No database tables are required.

## Pricing

Payouts are calculated server-side as:

`base price × quality × condition × butcher location × location category × legendary`

Category base prices and structured per-model overrides live in
`configs/pricing.lua`. The same file controls refused categories, refused
models, the legendary multiplier, and the minimum payout. Individual butcher
locations can apply a general multiplier, category multipliers, or refuse
specific animal models in `configs/locations.lua`.

Prices remain in `bcc-butcher`; `bcc-animal-data` only owns reusable animal
facts and capability flags.
