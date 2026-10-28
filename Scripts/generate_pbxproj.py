#!/usr/bin/env python3
"""Regenerates RidingApps.xcodeproj/project.pbxproj (and shared schemes) from disk.

Why this exists: the project has no XcodeGen/Tuist dependency by choice, so the app target's
file list, build phases, and Dev/Staging/Production configuration wiring are generated here
instead of hand-maintained inside a fragile pbxproj. Re-run this after adding/removing/renaming
files under RidingApps/, RidingAppsTests/, or Config/.

Every feature lives directly inside the single RidingApps app target as a folder under
RidingApps/Features/<Name>/ (Models/Services/ViewModels/Views) — there are no local Swift
packages and no inter-feature import statements; everything shares one module. Unit tests live
in a sibling RidingAppsTests/<Name>Tests/ folder, compiled into a separate unit test target that
hosts against the app target so tests can `@testable import RidingApps`.

Object IDs are deterministic (md5 of a stable key) so re-running produces a stable diff instead
of churning every id on each regeneration.
"""
import hashlib
import os
import plistlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR_NAME = "RidingApps"
APP_DIR = os.path.join(ROOT, APP_DIR_NAME)
TESTS_DIR_NAME = "RidingAppsTests"
TESTS_DIR = os.path.join(ROOT, TESTS_DIR_NAME)
CONFIG_DIR = os.path.join(ROOT, "Config")
PROJECT_DIR = os.path.join(ROOT, "RidingApps.xcodeproj")

ENVIRONMENTS = ["Dev", "Staging", "Production"]

objects = {}


def oid(key):
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def add(key, isa, **fields):
    o = {"isa": isa}
    o.update(fields)
    objects[oid(key)] = o
    return oid(key)


FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
    ".xcconfig": "text.xcconfig",
    ".xcassets": "folder.assetcatalog",
}


def file_ref(key, name, path, file_type):
    return add(
        key,
        "PBXFileReference",
        lastKnownFileType=file_type,
        name=name,
        path=path,
        sourceTree="<group>",
    )


def build_group(abs_dir, key_prefix, rel_display_name):
    """Recursively builds a PBXGroup for abs_dir. Returns (group_id, swift_refs, xcasset_refs, plist_ref_or_none)."""
    swift_refs = []
    xcasset_refs = []
    plist_refs = []
    children = []

    entries = sorted(os.listdir(abs_dir))
    dirs = [e for e in entries if os.path.isdir(os.path.join(abs_dir, e)) and not e.endswith(".xcassets")]
    xcassets = [e for e in entries if e.endswith(".xcassets")]
    files = [e for e in entries if os.path.isfile(os.path.join(abs_dir, e))]

    for d in dirs:
        sub_key = f"{key_prefix}/{d}"
        sub_group_id, s_refs, x_refs, p_refs = build_group(os.path.join(abs_dir, d), sub_key, d)
        children.append(sub_group_id)
        swift_refs += s_refs
        xcasset_refs += x_refs
        plist_refs += p_refs

    for a in xcassets:
        ref = file_ref(f"{key_prefix}/{a}", a, a, FILE_TYPES[".xcassets"])
        children.append(ref)
        xcasset_refs.append(ref)

    for f in files:
        ext = os.path.splitext(f)[1]
        file_type = FILE_TYPES.get(ext)
        if file_type is None:
            continue
        ref = file_ref(f"{key_prefix}/{f}", f, f, file_type)
        children.append(ref)
        if ext == ".swift":
            swift_refs.append(ref)
        elif ext == ".plist":
            plist_refs.append(ref)

    group_id = add(
        f"{key_prefix}#group",
        "PBXGroup",
        children=children,
        name=rel_display_name,
        path=rel_display_name,
        sourceTree="<group>",
    )
    return group_id, swift_refs, xcasset_refs, plist_refs


app_group_id, app_swift_refs, xcasset_refs, plist_refs = build_group(APP_DIR, "app", APP_DIR_NAME)
info_plist_ref = plist_refs[0] if plist_refs else None

tests_group_id, tests_swift_refs, _, _ = build_group(TESTS_DIR, "tests", TESTS_DIR_NAME)

config_children = []
config_refs = {}
for name in ["Base", "Dev", "Staging", "Production"]:
    ref = file_ref(f"config/{name}", f"{name}.xcconfig", f"{name}.xcconfig", "text.xcconfig")
    config_children.append(ref)
    config_refs[name] = ref
config_group_id = add("config#group", "PBXGroup", children=config_children, name="Config", path="Config", sourceTree="<group>")

app_product_ref = add("product/app", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex="0", path="RidingApps.app", sourceTree="BUILT_PRODUCTS_DIR")
tests_product_ref = add("product/tests", "PBXFileReference", explicitFileType="wrapper.cfbundle", includeInIndex="0", path="RidingAppsTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
products_group_id = add("products#group", "PBXGroup", children=[app_product_ref, tests_product_ref], name="Products", sourceTree="<group>")

main_group_id = add("main#group", "PBXGroup", children=[app_group_id, tests_group_id, config_group_id, products_group_id], sourceTree="<group>")

app_sources_files = [add(f"sourcesbf/{r}", "PBXBuildFile", fileRef=r) for r in app_swift_refs]
resources_files = [add(f"resourcesbf/{r}", "PBXBuildFile", fileRef=r) for r in xcasset_refs]
tests_sources_files = [add(f"testsourcesbf/{r}", "PBXBuildFile", fileRef=r) for r in tests_swift_refs]

app_sources_phase = add("phase/app-sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=app_sources_files, runOnlyForDeploymentPostprocessing="0")
app_frameworks_phase = add("phase/app-frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=[], runOnlyForDeploymentPostprocessing="0")
resources_phase = add("phase/resources", "PBXResourcesBuildPhase", buildActionMask="2147483647", files=resources_files, runOnlyForDeploymentPostprocessing="0")
tests_sources_phase = add("phase/tests-sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=tests_sources_files, runOnlyForDeploymentPostprocessing="0")
tests_frameworks_phase = add("phase/tests-frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=[], runOnlyForDeploymentPostprocessing="0")

app_target_id = oid("target/app")
tests_target_id = oid("target/tests")
project_id = oid("project")


def make_config(key_prefix, name, base_config_ref, extra_settings=None):
    settings = dict(extra_settings or {})
    kwargs = {"buildSettings": settings, "name": name}
    if base_config_ref:
        kwargs["baseConfigurationReference"] = base_config_ref
    return add(f"{key_prefix}/{name}", "XCBuildConfiguration", **kwargs)


project_config_ids = [make_config("projcfg", env, None) for env in ENVIRONMENTS]
target_config_ids = [make_config("targetcfg", env, config_refs[env]) for env in ENVIRONMENTS]
tests_target_config_ids = [
    make_config(
        "testscfg",
        env,
        None,
        extra_settings={
            "SDKROOT": "iphoneos",
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "TARGETED_DEVICE_FAMILY": "1,2",
            "SWIFT_VERSION": "5.0",
            "CODE_SIGN_STYLE": "Automatic",
            "PRODUCT_NAME": "RidingAppsTests",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.ridehailing.app.tests",
            "GENERATE_INFOPLIST_FILE": "YES",
            "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/RidingApps.app/RidingApps",
            "BUNDLE_LOADER": "$(TEST_HOST)",
            "SWIFT_EMIT_LOC_STRINGS": "NO",
        },
    )
    for env in ENVIRONMENTS
]

project_config_list = add("cfglist/project", "XCConfigurationList", buildConfigurations=project_config_ids, defaultConfigurationIsVisible="0", defaultConfigurationName="Dev")
target_config_list = add("cfglist/target", "XCConfigurationList", buildConfigurations=target_config_ids, defaultConfigurationIsVisible="0", defaultConfigurationName="Dev")
tests_target_config_list = add("cfglist/tests", "XCConfigurationList", buildConfigurations=tests_target_config_ids, defaultConfigurationIsVisible="0", defaultConfigurationName="Dev")

container_proxy_id = add(
    "containerproxy/tests-to-app",
    "PBXContainerItemProxy",
    containerPortal=project_id,
    proxyType="1",
    remoteGlobalIDString=app_target_id,
    remoteInfo="RidingApps",
)
tests_depends_on_app_id = add(
    "targetdep/tests-to-app",
    "PBXTargetDependency",
    target=app_target_id,
    targetProxy=container_proxy_id,
)

objects[app_target_id] = {
    "isa": "PBXNativeTarget",
    "buildConfigurationList": target_config_list,
    "buildPhases": [app_sources_phase, app_frameworks_phase, resources_phase],
    "buildRules": [],
    "dependencies": [],
    "name": "RidingApps",
    "productName": "RidingApps",
    "productReference": app_product_ref,
    "productType": "com.apple.product-type.application",
}

objects[tests_target_id] = {
    "isa": "PBXNativeTarget",
    "buildConfigurationList": tests_target_config_list,
    "buildPhases": [tests_sources_phase, tests_frameworks_phase],
    "buildRules": [],
    "dependencies": [tests_depends_on_app_id],
    "name": "RidingAppsTests",
    "productName": "RidingAppsTests",
    "productReference": tests_product_ref,
    "productType": "com.apple.product-type.bundle.unit-test",
}

objects[project_id] = {
    "isa": "PBXProject",
    "attributes": {
        "BuildIndependentTargetsInParallel": "YES",
        "LastSwiftUpdateCheck": "1620",
        "LastUpgradeCheck": "1620",
        "TargetAttributes": {
            app_target_id: {"CreatedOnToolsVersion": "16.0"},
            tests_target_id: {"CreatedOnToolsVersion": "16.0", "TestTargetID": app_target_id},
        },
    },
    "buildConfigurationList": project_config_list,
    "compatibilityVersion": "Xcode 14.0",
    "developmentRegion": "en",
    "hasScannedForEncodings": "0",
    "knownRegions": ["en", "Base"],
    "mainGroup": main_group_id,
    "productRefGroup": products_group_id,
    "projectDirPath": "",
    "projectRoot": "",
    "targets": [app_target_id, tests_target_id],
}

pbx = {
    "archiveVersion": "1",
    "classes": {},
    "objectVersion": "56",
    "objects": objects,
    "rootObject": project_id,
}

os.makedirs(PROJECT_DIR, exist_ok=True)
with open(os.path.join(PROJECT_DIR, "project.pbxproj"), "wb") as f:
    plistlib.dump(pbx, f, fmt=plistlib.FMT_XML)

SCHEME_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1620"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "RidingApps.app"
               BlueprintName = "RidingApps"
               ReferencedContainer = "container:RidingApps.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tests_target_id}"
               BuildableName = "RidingAppsTests.xctest"
               BlueprintName = "RidingAppsTests"
               ReferencedContainer = "container:RidingApps.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "{config}"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tests_target_id}"
               BuildableName = "RidingAppsTests.xctest"
               BlueprintName = "RidingAppsTests"
               ReferencedContainer = "container:RidingApps.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "{config}"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "RidingApps.app"
            BlueprintName = "RidingApps"
            ReferencedContainer = "container:RidingApps.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "{config}"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "RidingApps.app"
            BlueprintName = "RidingApps"
            ReferencedContainer = "container:RidingApps.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "{config}">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "{config}"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

schemes_dir = os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes")
os.makedirs(schemes_dir, exist_ok=True)
for env in ENVIRONMENTS:
    scheme_name = f"RidingApps-{env}"
    with open(os.path.join(schemes_dir, f"{scheme_name}.xcscheme"), "w") as f:
        f.write(SCHEME_TEMPLATE.format(target_id=app_target_id, tests_target_id=tests_target_id, config=env))

print("Generated project.pbxproj and schemes:", [f"RidingApps-{e}" for e in ENVIRONMENTS])
print("App target id:", app_target_id, "Tests target id:", tests_target_id)
print("App Swift files:", len(app_swift_refs), "Test Swift files:", len(tests_swift_refs), "xcasset catalogs:", len(xcasset_refs), "Info.plist found:", info_plist_ref is not None)
