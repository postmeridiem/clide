"""TODO comment scanner service."""

import re
from pathlib import Path

from clide.models.todos import ProjectTodoItem, TodoItem, TodosSummary, TodoType
from clide.services.process_service import ProcessService


class TodoScanner:
    """Service for scanning TODO/FIXME comments in code."""

    # Pattern to match TODO-style comments
    TODO_PATTERN = re.compile(
        r"(?:#|//|/\*|\*|<!--)\s*(TODO|FIXME|HACK|XXX|NOTE|BUG|OPTIMIZE|REVIEW)\s*:?\s*(.+?)(?:\*/|-->)?$",
        re.IGNORECASE,
    )

    # Pattern to match markdown checkboxes: - [ ] or - [x]
    CHECKBOX_PATTERN = re.compile(r"^(\s*)-\s*\[([ xX])\]\s*(.+)$")

    # File extensions to scan
    SCAN_EXTENSIONS = {
        ".py",
        ".js",
        ".ts",
        ".jsx",
        ".tsx",
        ".java",
        ".c",
        ".cpp",
        ".h",
        ".go",
        ".rs",
        ".rb",
        ".php",
        ".css",
        ".scss",
        ".html",
        ".vue",
        ".svelte",
        ".md",
        ".sh",
        ".bash",
        ".yaml",
        ".yml",
        ".toml",
    }

    def __init__(self, project_path: Path) -> None:
        self.project_path = project_path
        self._process = ProcessService(cwd=project_path)

    async def scan(
        self,
    ) -> tuple[list[TodoItem], list[ProjectTodoItem], TodosSummary]:
        """Scan project for TODO comments and TODO.md items.

        Returns:
            Tuple of (code todo items, project todo items, summary)
        """
        items: list[TodoItem] = []

        # Use ripgrep if available for speed
        result = await self._process.run(
            "rg",
            "--line-number",
            "--no-heading",
            "-e",
            r"\b(TODO|FIXME|HACK|XXX|NOTE|BUG|OPTIMIZE|REVIEW)\b",
            "--type-add",
            "code:*.py",
            "--type-add",
            "code:*.js",
            "--type-add",
            "code:*.ts",
            "--type",
            "code",
            ".",
        )

        if result.success:
            items = self._parse_ripgrep_output(result.stdout)
        else:
            # Fallback to Python-based scanning
            items = await self._scan_with_python()

        # Parse TODO.md if it exists
        project_items = self._parse_todo_md()

        # Create summary
        todo_count = sum(1 for i in items if i.todo_type == TodoType.TODO)
        fixme_count = sum(1 for i in items if i.todo_type == TodoType.FIXME)
        hack_count = sum(1 for i in items if i.todo_type == TodoType.HACK)
        other_count = len(items) - todo_count - fixme_count - hack_count
        project_todo_count = sum(1 for i in project_items if not i.checked)
        project_done_count = sum(1 for i in project_items if i.checked)

        summary = TodosSummary(
            todo_count=todo_count,
            fixme_count=fixme_count,
            hack_count=hack_count,
            other_count=other_count,
            project_todo_count=project_todo_count,
            project_done_count=project_done_count,
        )

        return items, project_items, summary

    def _parse_todo_md(self) -> list[ProjectTodoItem]:
        """Parse TODO.md file for checkbox items.

        Returns:
            List of project TODO items
        """
        todo_md_path = self.project_path / "TODO.md"
        if not todo_md_path.exists():
            return []

        items: list[ProjectTodoItem] = []
        current_section = "General"
        current_subsection: str | None = None

        try:
            content = todo_md_path.read_text(encoding="utf-8")
            for line_num, line in enumerate(content.split("\n"), 1):
                # Check for section headers (## Section)
                if line.startswith("## "):
                    current_section = line[3:].strip()
                    current_subsection = None
                    continue

                # Check for subsection headers (### Subsection)
                if line.startswith("### "):
                    current_subsection = line[4:].strip()
                    continue

                # Check for checkbox items
                match = self.CHECKBOX_PATTERN.match(line)
                if match:
                    checkbox_state = match.group(2)
                    text = match.group(3).strip()
                    checked = checkbox_state.lower() == "x"

                    items.append(
                        ProjectTodoItem(
                            text=text,
                            section=current_section,
                            subsection=current_subsection,
                            line=line_num,
                            checked=checked,
                        )
                    )
        except (OSError, UnicodeDecodeError):
            pass

        return items

    def _parse_ripgrep_output(self, output: str) -> list[TodoItem]:
        """Parse ripgrep output into TodoItems."""
        items: list[TodoItem] = []

        for line in output.strip().split("\n"):
            if not line:
                continue

            # Format: path:line:content
            parts = line.split(":", 2)
            if len(parts) < 3:
                continue

            file_path = Path(parts[0])
            try:
                line_num = int(parts[1])
            except ValueError:
                continue

            content = parts[2]

            # Parse the TODO type and text
            match = self.TODO_PATTERN.search(content)
            if match:
                todo_type_str = match.group(1).upper()
                todo_text = match.group(2).strip()

                try:
                    todo_type = TodoType(todo_type_str)
                except ValueError:
                    todo_type = TodoType.TODO

                items.append(
                    TodoItem(
                        file_path=file_path,
                        line=line_num,
                        column=content.find(todo_type_str) + 1,
                        todo_type=todo_type,
                        text=todo_text,
                        context_line=content.strip(),
                    )
                )

        return items

    async def _scan_with_python(self) -> list[TodoItem]:
        """Fallback Python-based scanning."""
        items: list[TodoItem] = []

        for ext in self.SCAN_EXTENSIONS:
            for file_path in self.project_path.rglob(f"*{ext}"):
                # Skip hidden directories and common excludes
                if any(part.startswith(".") for part in file_path.parts):
                    continue
                if "node_modules" in file_path.parts:
                    continue
                if "__pycache__" in file_path.parts:
                    continue

                try:
                    content = file_path.read_text(encoding="utf-8", errors="ignore")
                    for line_num, line in enumerate(content.split("\n"), 1):
                        match = self.TODO_PATTERN.search(line)
                        if match:
                            todo_type_str = match.group(1).upper()
                            todo_text = match.group(2).strip()

                            try:
                                todo_type = TodoType(todo_type_str)
                            except ValueError:
                                todo_type = TodoType.TODO

                            items.append(
                                TodoItem(
                                    file_path=file_path.relative_to(self.project_path),
                                    line=line_num,
                                    column=line.find(todo_type_str) + 1,
                                    todo_type=todo_type,
                                    text=todo_text,
                                    context_line=line.strip(),
                                )
                            )
                except (OSError, UnicodeDecodeError):
                    continue

        return items
