const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const xcode = require("xcode");
const plist = require("@expo/plist").default;
const unquote = value => String(value).replace(/^"|"$/g, "");

function verifyProject(project, root) {
  const targets = Object.entries(project.pbxNativeTargetSection()).filter(([, value]) => typeof value === "object");
  assert.equal(targets.length, 2, "Expected only app and tunnel targets");
  const app = targets.find(([, value]) => unquote(value.productType) === "com.apple.product-type.application");
  const extension = targets.find(([, value]) => unquote(value.productType) === "com.apple.product-type.app-extension");
  assert.ok(app && extension, "Missing application or extension");
  const objects = project.hash.project.objects;
  for (const [id, target] of targets) {
    const expectedID = id === app[0] ? "com.softdev.scrollblock" : "com.softdev.scrollblock.tunnel";
    const list = project.pbxXCConfigurationList()[target.buildConfigurationList];
    for (const item of list.buildConfigurations) {
      const settings = project.pbxXCBuildConfigurationSection()[item.value].buildSettings;
      assert.equal(unquote(settings.PRODUCT_BUNDLE_IDENTIFIER), expectedID);
      assert.equal(unquote(settings.IPHONEOS_DEPLOYMENT_TARGET), "18.0");
      const entitlements = plist.parse(fs.readFileSync(path.join(root, unquote(settings.CODE_SIGN_ENTITLEMENTS)), "utf8"));
      assert.ok(entitlements["com.apple.developer.networking.networkextension"].includes("packet-tunnel-provider"));
    }
    const resources = target.buildPhases.flatMap(({ value }) => objects.PBXResourcesBuildPhase?.[value]?.files || []);
    const ruleFiles = resources.map(({ value }) => objects.PBXFileReference[objects.PBXBuildFile[value].fileRef]).filter(file => unquote(file.path).endsWith("/rules.json"));
    assert.equal(ruleFiles.length, 1, `${expectedID} needs exactly one bundled rules file`);
    assert.ok(fs.existsSync(path.join(root, unquote(ruleFiles[0].path))));
  }
  const sourceFiles = extension[1].buildPhases.flatMap(({ value }) => objects.PBXSourcesBuildPhase?.[value]?.files || []);
  assert.equal(sourceFiles.length, 3, "Tunnel Swift sources missing or duplicated");
  for (const { value } of sourceFiles) {
    const file = objects.PBXFileReference[objects.PBXBuildFile[value].fileRef];
    assert.ok(fs.existsSync(path.join(root, unquote(file.path))), `Missing ${file.path}`);
  }
  const embedded = app[1].buildPhases.flatMap(({ value }) => objects.PBXCopyFilesBuildPhase?.[value]?.files || []);
  assert.equal(embedded.filter(({ value }) => objects.PBXBuildFile[value].fileRef === extension[1].productReference).length, 1, "Tunnel must be embedded exactly once");
  const dependency = app[1].dependencies.some(({ value }) => objects.PBXTargetDependency[value].target === extension[0]);
  assert.ok(dependency, "App must build the tunnel dependency");
}

module.exports = { verifyProject };
if (require.main === module) {
  const root = path.resolve("ios");
  const projects = fs.readdirSync(root).filter(file => file.endsWith(".xcodeproj"));
  assert.equal(projects.length, 1);
  const project = xcode.project(path.join(root, projects[0], "project.pbxproj"));
  project.parseSync(); verifyProject(project, root);
  console.log("Verified Scrollblock targets, iOS 18 minimum, sources, rules, entitlements and extension embedding.");
}
