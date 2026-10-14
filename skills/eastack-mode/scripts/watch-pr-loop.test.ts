import { expect, it } from "bun:test";
import { main } from "./watch-pr/cli.ts";
import { fakeReader } from "./watch-pr/fakes.test-helper.ts";

// Pins the playbooks' watch-pr loop: a run's last record is not its only
// verdict. A queued stack with a blocker-free frontier reports WAITING with
// reason merge-queue mid-run and only then exits on TIMEOUT.
it("emits the queued merge-queue WAITING before TIMEOUT exit 5", async () => {
  const stdout: string[] = [];
  let now = 0;
  const code = await main(
    [
      "--owner",
      "owner",
      "--repo",
      "repo",
      "--queued-stack",
      "--stack-prs",
      "1,2",
      "--timeout",
      "540",
    ],
    {
      reader: fakeReader(),
      clock: {
        now: () => now,
        observedAt: () => "2026-10-14T00:00:00.000Z",
        async sleep(seconds) {
          now += seconds;
        },
      },
      stdout: (value) => stdout.push(value),
      stderr: () => {},
    }
  );
  const records = stdout.map(
    (line) => JSON.parse(line) as { kind: string; reason?: unknown }
  );
  const kinds = records.map((record) => record.kind);
  expect(code).toBe(5);
  expect(now).toBe(540);
  expect(kinds).toEqual(["QUEUE", "STATUS", "WAITING", "STATUS", "TIMEOUT"]);
  expect(records[2]).toMatchObject({
    kind: "WAITING",
    terminal: false,
    reason: { kind: "merge-queue", unmergedCount: 2 },
  });
  expect(records[records.length - 1]).toMatchObject({
    kind: "TIMEOUT",
    terminal: true,
    exitCode: 5,
  });
});
