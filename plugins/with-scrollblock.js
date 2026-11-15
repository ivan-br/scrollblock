const fs = require("node:fs");
const path = require("node:path");
const plist = require("@expo/plist").default;
const { withInfoPlist, withEntitlementsPlist, withPodfileProperties, withXcodeProject } = require("expo/config-plugins");

const TARGET = "ScrollblockTunnel";
const unquote = value => String(value).replace(/^"|"$/g, "");

function configureExtension(project, root, projectRoot, config) {
  const bundleID = config.ios.bundleIdentifier;
  const folder = path.join(root, TARGET);
  fs.mkdirSync(folder, { recursive: true });
  const sources = {
    "PacketTunnelProvider.swift": "native/ScrollblockTunnel/PacketTunnelProvider.swift",
    "DNSPacket.swift": "modules/scrollblock/ios/Core/DNSPacket.swift",
    "RuleSet.swift": "modules/scrollblock/ios/Core/RuleSet.swift",
  };
  for (const [name, source] of Object.entries(sources)) fs.copyFileSync(path.join(projectRoot, source), path.join(folder, name));
  fs.copyFileSync(path.join(projectRoot, "native/rules.json"), path.join(folder, "rules.json"));
  const info = {
    CFBundleDisplayName: "Scrollblock Network Test", CFBundleName: "$(PRODUCT_NAME)",
    CFBundleIdentifier: "$(PRODUCT_BUNDLE_IDENTIFIER)", CFBundleExecutable: "$(EXECUTABLE_NAME)",
    CFBundlePackageType: "XPC!", CFBundleShortVersionString: config.version || "1.0.0",
    CFBundleVersion: config.ios.buildNumber || "1", CFBundleInfoDictionaryVersion: "6.0",
    NSExtension: { NSExtensionPointIdentifier: "com.apple.networkextension.packet-tunnel", NSExtensionPrincipalClass: "$(PRODUCT_MODULE_NAME).PacketTunnelProvider" },
  };
  fs.writeFileSync(path.join(folder, "Info.plist"), plist.build(info));
  fs.writeFileSync(path.join(folder, `${TARGET}.entitlements`), plist.build({ "com.apple.developer.networking.networkextension": ["packet-tunnel-provider"] }));

  const targets = project.pbxNativeTargetSection();
  // xcode's addTargetDependency silently skips dependencies without these sections.
  project.hash.project.objects.PBXTargetDependency ||= {};
  project.hash.project.objects.PBXContainerItemProxy ||= {};
  let target = Object.entries(targets).find(([, value]) => typeof value === "object" && unquote(value.name) === TARGET)?.[0];
  if (!target) {
    target = project.addTarget(TARGET, "app_extension", TARGET, `${bundleID}.tunnel`).uuid;
    project.addBuildPhase(Object.keys(sources).map(name => `${TARGET}/${name}`), "PBXSourcesBuildPhase", "Sources", target);
    project.addBuildPhase([`${TARGET}/rules.json`], "PBXResourcesBuildPhase", "Resources", target);
    project.addBuildPhase([], "PBXFrameworksBuildPhase", "Frameworks", target);
    project.addFramework("NetworkExtension.framework", { target, link: true });
    project.addFramework("Foundation.framework", { target, link: true });
  }
  // Rules must exist in both executable bundles; use distinct reference paths.
  const appFolder = "ScrollblockRules";
  fs.mkdirSync(path.join(root, appFolder), { recursive: true });
  fs.copyFileSync(path.join(projectRoot, "native/rules.json"), path.join(root, appFolder, "rules.json"));
  if (!project.pbxGroupByName("Resources")) {
    const group = project.addPbxGroup([], "Resources");
    delete group.pbxGroup.path;
    project.addToPbxGroup({ fileRef: group.uuid, basename: "Resources" }, project.getFirstProject().firstProject.mainGroup);
  }
  if (!project.hasFile(`${appFolder}/rules.json`)) project.addResourceFile(`${appFolder}/rules.json`, { target: project.getFirstTarget().uuid });

  const list = project.pbxXCConfigurationList()[targets[target].buildConfigurationList];
  for (const item of list.buildConfigurations) {
    Object.assign(project.pbxXCBuildConfigurationSection()[item.value].buildSettings, {
      PRODUCT_BUNDLE_IDENTIFIER: `"${bundleID}.tunnel"`, PRODUCT_NAME: `"${TARGET}"`, PRODUCT_MODULE_NAME: TARGET,
      INFOPLIST_FILE: `"${TARGET}/Info.plist"`, CODE_SIGN_ENTITLEMENTS: `"${TARGET}/${TARGET}.entitlements"`,
      IPHONEOS_DEPLOYMENT_TARGET: "18.0", SWIFT_VERSION: "5.0", TARGETED_DEVICE_FAMILY: '"1,2"',
      APPLICATION_EXTENSION_API_ONLY: "YES", GENERATE_INFOPLIST_FILE: "NO", SKIP_INSTALL: "YES",
      CLANG_ENABLE_MODULES: "YES", SDKROOT: "iphoneos", CURRENT_PROJECT_VERSION: config.ios.buildNumber || "1",
    });
  }
  for (const entry of Object.values(project.pbxXCBuildConfigurationSection())) {
    if (typeof entry === "object" && entry.buildSettings) entry.buildSettings.IPHONEOS_DEPLOYMENT_TARGET = "18.0";
  }
  // The xcode library includes optional undefined keys; never serialize these as paths.
  for (const section of Object.values(project.hash.project.objects)) {
    for (const object of Object.values(section)) {
      if (object && typeof object === "object") {
        for (const key of Object.keys(object)) if (object[key] === undefined) delete object[key];
      }
    }
  }
  return project;
}

module.exports = function withScrollblock(config) {
  config = withInfoPlist(config, result => {
    delete result.modResults.NSCameraUsageDescription;
    delete result.modResults.NSMicrophoneUsageDescription;
    return result;
  });
  config = withEntitlementsPlist(config, result => {
    result.modResults["com.apple.developer.networking.networkextension"] = ["packet-tunnel-provider"];
    return result;
  });
  config = withPodfileProperties(config, result => {
    result.modResults["ios.deploymentTarget"] = "18.0";
    return result;
  });
  return withXcodeProject(config, result => {
    configureExtension(result.modResults, result.modRequest.platformProjectRoot, result.modRequest.projectRoot, config);
    return result;
  });
};
module.exports.configureExtension = configureExtension;
