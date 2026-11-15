const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const YAML = require("yaml");
const { describeState, switchIsOn, isRunning, unavailableState } = require("../src/blocking/state.ts");

test("observation and reconnecting must never show the Reels switch as enabled", () => {
  for (const status of ["disconnected", "connecting", "connected", "disconnecting", "reasserting", "unknown"]) {
    const observation = { available: true, rulesReady: true, mode: "observe", status };
    assert.equal(switchIsOn(observation), false);
    assert.doesNotMatch(describeState(observation), /protected|protection active/i);
    assert.equal(switchIsOn({ ...observation, mode: "block" }), status === "connected");
  }
  assert.match(describeState({ ...unavailableState, available: true }), /not ready/);
  assert.match(describeState({ ...unavailableState, available: true, status: "connected" }), /not blocked/);
  assert.equal(isRunning({ ...unavailableState, status: "disconnecting" }), true);
});

test("the shipped policy cannot accidentally claim a validated blocker", () => {
  const rules = JSON.parse(fs.readFileSync("native/rules.json", "utf8"));
  assert.equal(rules.validated, false);
  assert.deepEqual(rules.domains, []);
});

test("IPA artifact workflow keeps its manual unsigned build and embeds verification", () => {
  const workflow = YAML.parse(fs.readFileSync(".github/workflows/build-ios-ipa.yml", "utf8"));
  assert.ok("workflow_dispatch" in workflow.on);
  const steps = workflow.jobs["build-ios"].steps;
  assert.match(steps.find(step => step.name === "Build unsigned iOS app").run, /CODE_SIGNING_ALLOWED=NO/);
  assert.match(steps.find(step => step.name === "Package IPA").run, /zip -qry Scrollblock\.ipa Payload/);
  assert.match(steps.find(step => step.name === "Prebuild iOS project").run, /verify:ios-project/);
  assert.equal(steps.at(-1).with.path, "Scrollblock.ipa");
  assert.equal(steps.at(-1).with.name, "Scrollblock-unsigned-ipa");
});
