#!/usr/bin/env python3
"""Ensure every native UI test belongs to exactly one checked-in test plan."""
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def main():
    discovered = set()
    for source in (ROOT / "TransfloUITests").glob("*.swift"):
        text = source.read_text()
        classes = re.findall(r"final class (\w+): TransfloUITestCase", text)
        methods = re.findall(r"^    func (test\w+)\(", text, re.MULTILINE)
        if methods:
            assert len(classes) == 1, f"Expected one test class in {source.name}"
            discovered.update(f"{classes[0]}/{method}()" for method in methods)

    counts = Counter()
    for name in ("Fast", "Extended"):
        plan = json.loads((ROOT / "TestPlans" / f"{name}.xctestplan").read_text())
        targets = plan["testTargets"]
        expected = {"TransfloTests", "TransfloUITests"} if name == "Fast" else {"TransfloUITests"}
        assert {target["target"]["name"] for target in targets} == expected, name
        ui = next(target for target in targets if target["target"]["name"] == "TransfloUITests")
        assert ui.get("parallelizable") is False, f"{name}: UI tests must own one desktop"
        assert not ui.get("skippedTests"), f"{name}: use explicit, exclusive selections"
        selected = ui["selectedTests"]
        assert selected, f"{name}: empty UI selection"
        if name == "Fast":
            units = next(target for target in targets if target["target"]["name"] == "TransfloTests")
            assert "selectedTests" not in units and not units.get("skippedTests"), "Fast must include all app units"
        counts.update(selected)
        print(f"{name}: {len(selected)} UI tests")

    missing = discovered - counts.keys()
    stale = counts.keys() - discovered
    duplicated = {test for test, count in counts.items() if count != 1}
    assert not (missing or stale or duplicated), (
        f"Missing: {sorted(missing)}\nStale: {sorted(stale)}\nDuplicated: {sorted(duplicated)}"
    )
    print(f"All {len(discovered)} UI tests assigned exactly once.")


if __name__ == "__main__":
    main()
