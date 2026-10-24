// SPDX-License-Identifier: AGPL-3.0-only
// Produce independent JS reference values from the SAME server crypto.js.
import { buildTables, deriveMaskSeeds, hmacTag, xorMask, fnvLedger } from "../../server/src/protocol/crypto.js";
import { C2S_PACKETS, S2C_PACKETS } from "../../server/src/protocol/constants.js";
const seed = 0x10203040, salt = 0x12345678;
const key = Buffer.from("000102030405060708090a0b0c0d0e0f", "hex");
const tables = buildTables(seed, salt);
const masks = deriveMaskSeeds(key);
const data = Buffer.from("lua-server-parity-v1");
console.log("tag=" + Buffer.from(hmacTag(key,data)).toString("hex"));
console.log("maskc2s=" + (masks.c2s >>> 0));
console.log("masks2c=" + (masks.s2c >>> 0));
console.log("ledger=" + fnvLedger(2166136261,data));
for (const name of C2S_PACKETS) console.log("c2s." + name + "=" + tables.c2s.enc[name]);
for (const name of S2C_PACKETS) console.log("s2c." + name + "=" + tables.s2c.enc[name]);
const x = Buffer.from("0102030405060708", "hex");
xorMask(x, 0xaabbccdd);
console.log("xor=" + x.toString("hex"));
