import pathlib
import re

SETTING_GROUPS = (
    ("Documentation",),
    ("Library", "Resource", "Variables"),
    ("Suite Setup", "Suite Teardown", "Test Setup", "Test Teardown", "Test Template", "Test Timeout"),
    ("Test Tags",),
)

SETTING_TYPES = tuple(setting_type for group in SETTING_GROUPS for setting_type in group)
SETTING_RE = re.compile(
    rf"^(\s*)({'|'.join(re.escape(setting_type) for setting_type in SETTING_TYPES)})(\s+)(.+?)\s*$"
)
CONTINUATION_RE = re.compile(r"^\s*\.\.\.\s+.+$")

SETTING_ORDER = {
    setting_type: (group_index, type_index)
    for group_index, group in enumerate(SETTING_GROUPS)
    for type_index, setting_type in enumerate(group)
}


def sort_settings_block(lines):
    buckets = [[] for _ in range(len(SETTING_GROUPS) + 1)]
    i = entry_index = 0

    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue

        match = SETTING_RE.match(line)
        if not match:
            buckets[-1].append(((entry_index,), [line]))
            entry_index += 1
            i += 1
            continue

        indent, setting_type, spacing, setting_value = match.groups()
        entry_lines = [f"{indent}{setting_type}{spacing}{setting_value}"]
        i += 1
        while i < len(lines) and CONTINUATION_RE.match(lines[i]):
            entry_lines.append(lines[i])
            i += 1

        group_index, type_index = SETTING_ORDER.get(setting_type, (len(SETTING_GROUPS), 0))
        buckets[group_index].append(((group_index, type_index, setting_value.lower(), entry_index), entry_lines))
        entry_index += 1

    output = []
    for group_index, group in enumerate(buckets):
        if not group:
            continue
        if output:
            output.append("")
        for _, entry_lines in sorted(group, key=lambda item: item[0]):
            output.extend(entry_lines)
    if output and output[-1] != "":
        output.append("")
    return output


def process_file(path):
    changed = False
    lines = path.read_text().splitlines()
    new_lines = []

    in_settings = False
    settings_block = []

    def flush_settings_block():
        nonlocal changed, settings_block
        sorted_block = sort_settings_block(settings_block)
        if settings_block != sorted_block:
            changed = True
        new_lines.extend(sorted_block)
        settings_block = []

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("***") and stripped.endswith("***"):
            if in_settings:
                flush_settings_block()
                in_settings = False

            new_lines.append(line)
            in_settings = stripped.lower() == "*** settings ***"
            continue

        if in_settings:
            settings_block.append(line)
            continue

        new_lines.append(line)

    if in_settings:
        flush_settings_block()

    if changed:
        path.write_text("\n".join(new_lines) + "\n")
        print(f"Updated: {path}")


def main(root="."):
    root_path = pathlib.Path(root)
    for path in sorted((*root_path.rglob("*.robot"), *root_path.rglob("*.resource"))):
        process_file(path)


if __name__ == "__main__":
    main()
