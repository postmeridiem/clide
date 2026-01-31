"""Linter integration service."""

import json
from pathlib import Path

from clide.models.problems import Problem, ProblemsSummary, Severity
from clide.services.process_service import ProcessService


class LinterService:
    """Service for running linters and parsing output."""

    def __init__(self, project_path: Path) -> None:
        self.project_path = project_path
        self._process = ProcessService(cwd=project_path)

    async def run_ruff(self) -> list[Problem]:
        """Run ruff linter.

        Returns:
            List of problems found
        """
        result = await self._process.run(
            "ruff", "check", "--output-format=json", "."
        )

        problems: list[Problem] = []
        if result.stdout:
            try:
                data = json.loads(result.stdout)
                for item in data:
                    severity = self._ruff_severity(item.get("code", ""))
                    problems.append(Problem(
                        file_path=Path(item["filename"]),
                        line=item["location"]["row"],
                        column=item["location"]["column"],
                        end_line=item.get("end_location", {}).get("row"),
                        end_column=item.get("end_location", {}).get("column"),
                        severity=severity,
                        message=item["message"],
                        source="ruff",
                        code=item.get("code"),
                    ))
            except json.JSONDecodeError:
                pass

        return problems

    def _ruff_severity(self, code: str) -> Severity:
        """Map ruff code to severity."""
        if code.startswith("E") or code.startswith("F"):
            return Severity.ERROR
        if code.startswith("W"):
            return Severity.WARNING
        return Severity.INFO

    async def run_mypy(self) -> list[Problem]:
        """Run mypy type checker.

        Returns:
            List of problems found
        """
        result = await self._process.run(
            "mypy", "--output=json", "."
        )

        problems: list[Problem] = []
        for line in result.stdout.strip().split("\n"):
            if not line:
                continue
            try:
                data = json.loads(line)
                severity = self._mypy_severity(data.get("severity", "error"))
                problems.append(Problem(
                    file_path=Path(data["file"]),
                    line=data["line"],
                    column=data.get("column", 1),
                    severity=severity,
                    message=data["message"],
                    source="mypy",
                    code=data.get("code"),
                ))
            except (json.JSONDecodeError, KeyError):
                continue

        return problems

    def _mypy_severity(self, severity: str) -> Severity:
        """Map mypy severity to Severity enum."""
        mapping = {
            "error": Severity.ERROR,
            "warning": Severity.WARNING,
            "note": Severity.INFO,
        }
        return mapping.get(severity, Severity.ERROR)

    async def run_all(self, linters: list[str]) -> tuple[list[Problem], ProblemsSummary]:
        """Run all configured linters.

        Args:
            linters: List of linter names to run

        Returns:
            Tuple of (problems list, summary)
        """
        all_problems: list[Problem] = []

        for linter in linters:
            if linter == "ruff":
                all_problems.extend(await self.run_ruff())
            elif linter == "mypy":
                all_problems.extend(await self.run_mypy())

        # Create summary
        errors = sum(1 for p in all_problems if p.severity == Severity.ERROR)
        warnings = sum(1 for p in all_problems if p.severity == Severity.WARNING)
        infos = sum(1 for p in all_problems if p.severity == Severity.INFO)
        hints = sum(1 for p in all_problems if p.severity == Severity.HINT)

        summary = ProblemsSummary(
            errors=errors,
            warnings=warnings,
            infos=infos,
            hints=hints,
        )

        return all_problems, summary
