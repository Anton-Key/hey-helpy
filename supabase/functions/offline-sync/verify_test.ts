import { assertEquals } from "jsr:@std/assert@1";
import { parseInput, sha256Hex } from "./verify.ts";

const P = "c1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000101/off_c1000000-0000-4000-8000-000000000191.jpg";

Deno.test("вход: только пути очереди и hex SHA-256", () => {
  assertEquals(parseInput({ photos: [{ path: P, sha256: "A".repeat(64) }] }), [{ path: P, sha256: "a".repeat(64) }]);
  assertEquals(parseInput({ photos: [{ path: "demo/ac_after.jpg", sha256: "a".repeat(64) }] }), null);
  assertEquals(parseInput({ photos: [{ path: P, sha256: "zz" }] }), null);
  assertEquals(parseInput({ photos: [] }), null);
  assertEquals(parseInput(null), null);
});

Deno.test("SHA-256", async () => {
  assertEquals(
    await sha256Hex(new TextEncoder().encode("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});
