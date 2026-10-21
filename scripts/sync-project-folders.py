#!/usr/bin/env python3
"""Convert XcodeGen's physical groups into Xcode 16+ synchronized folders.

Uses macOS plutil and Python's standard library, keeping XcodeGen 2.37 compatible.
Derives exclusions and shared-file membership from the generated build graph.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

project_file = Path(sys.argv[1] if len(sys.argv) > 1 else "Transflo.xcodeproj/project.pbxproj").resolve()
root = project_file.parent.parent
project = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(project_file)]))
objects = project["objects"]
project_object = objects[project["rootObject"]]
main_group = objects[project_object["mainGroup"]]
paths = {}
descendants = {}


def visit(identifier, parent):
    obj = objects[identifier]
    path = obj.get("path")
    if obj.get("sourceTree", "<group>") == "SOURCE_ROOT":
        absolute = root / (path or "")
    else:
        absolute = parent / (path or "")
    paths[identifier] = absolute.resolve()
    descendants[identifier] = set()
    for child in obj.get("children", []):
        visit(child, absolute)
        descendants[identifier].add(child)
        descendants[identifier].update(descendants[child])


visit(project_object["mainGroup"], root)
folders = {}
for identifier in main_group["children"]:
    obj = objects[identifier]
    if obj["isa"] != "PBXGroup":
        continue
    # Packages is a virtual container, but it also has a physical directory.
    directory = paths[identifier] if obj.get("path") else root / obj.get("name", "")
    if directory.is_dir() and directory != root:
        folders[identifier] = directory.resolve()


def leaf_paths(identifier):
    obj = objects[identifier]
    if obj["isa"] == "PBXFileReference":
        return {paths[identifier]} if identifier in paths else set()
    result = set()
    for child in obj.get("children", []):
        result.update(leaf_paths(child))
    return result


targets = {}
for identifier in project_object["targets"]:
    target = objects[identifier]
    if target["isa"] != "PBXNativeTarget":
        continue
    included = set()
    for phase_id in target["buildPhases"]:
        for build_id in objects[phase_id].get("files", []):
            build_file = objects[build_id]
            if "fileRef" in build_file:
                included.update(leaf_paths(build_file["fileRef"]))
    targets[identifier] = included

# Preserve shared UI-test sources and base configurations before removing their parent groups.
for identifier, path in paths.items():
    obj = objects[identifier]
    if obj["isa"] == "PBXFileReference" and any(path.is_relative_to(folder) for folder in folders.values()):
        obj["path"] = str(path.relative_to(root))
        obj["sourceTree"] = "SOURCE_ROOT"

for identifier, directory in folders.items():
    candidates = [(len({p for p in files if p.is_relative_to(directory)}), target)
                  for target, files in targets.items()]
    count, owner = max(candidates, default=(0, None))
    exceptions = []
    if count:
        included = {p for p in targets[owner] if p.is_relative_to(directory)}
        excluded = []
        for file in directory.rglob("*"):
            if not file.is_file() or any(part.startswith(".") for part in file.relative_to(directory).parts):
                continue
            if not any(file == item or file.is_relative_to(item) for item in included):
                excluded.append(str(file.relative_to(directory)))
        target = objects[owner]
        target.setdefault("fileSystemSynchronizedGroups", []).append(identifier)
        if excluded:
            exception_id = hashlib.sha256((identifier + owner + "exclusions").encode()).hexdigest()[:24].upper()
            objects[exception_id] = {
                "isa": "PBXFileSystemSynchronizedBuildFileExceptionSet",
                "membershipExceptions": sorted(excluded),
                "target": owner,
            }
            exceptions.append(exception_id)
        for phase_id in target["buildPhases"]:
            phase = objects[phase_id]
            for build_id in list(phase.get("files", [])):
                build_file = objects[build_id]
                files = leaf_paths(build_file["fileRef"]) if "fileRef" in build_file else set()
                if files and all(p.is_relative_to(directory) for p in files):
                    if build_file.get("settings"):
                        raise SystemExit("Per-file build settings need an explicit synchronized-folder exception")
                    phase["files"].remove(build_id)
                    del objects[build_id]
    # Variant groups (string catalogs) another target still lists explicitly must survive.
    referenced = {obj.get("fileRef") for obj in objects.values() if obj.get("isa") == "PBXBuildFile"}
    for child in descendants[identifier]:
        if objects.get(child, {}).get("isa") in ("PBXGroup", "PBXVariantGroup") and child not in referenced:
            del objects[child]
    objects[identifier] = {
        "isa": "PBXFileSystemSynchronizedRootGroup",
        "exceptions": exceptions,
        "explicitFileTypes": {},
        "explicitFolders": [],
        "path": str(directory.relative_to(root)),
        "sourceTree": "<group>",
    }


def references(value):
    if isinstance(value, dict):
        return set().union(set(), *(references(v) for v in value.values()))
    if isinstance(value, list):
        return set().union(set(), *(references(v) for v in value))
    return {value} if isinstance(value, str) else set()


used = references(objects)
for identifier in list(objects):
    if objects[identifier]["isa"] == "PBXFileReference" and identifier not in used:
        del objects[identifier]
project["objectVersion"] = "77"
project_object["compatibilityVersion"] = "Xcode 16.0"


def openstep(value, level=0):
    indent = "\t" * level
    if isinstance(value, dict):
        entries = ["\t" * (level + 1) + json.dumps(key) + " = " + openstep(item, level + 1) + ";"
                   for key, item in sorted(value.items())]
        return "{\n" + "\n".join(entries) + "\n" + indent + "}"
    if isinstance(value, list):
        entries = ["\t" * (level + 1) + openstep(item, level + 1) + "," for item in value]
        return "(\n" + "\n".join(entries) + "\n" + indent + ")"
    return json.dumps(str(int(value)) if isinstance(value, bool) else str(value), ensure_ascii=False)


project_file.write_text("// !$*UTF8*$!\n" + openstep(project) + "\n")
print("Synchronized folders: " + ", ".join(str(path.relative_to(root)) for path in folders.values()))
