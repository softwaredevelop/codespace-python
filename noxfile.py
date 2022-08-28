#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Nox configuration file.
"""
import nox

LINT_DEPENDENCIES = [
    "isort",
    "black",
    "flake8",
]
LINT_PATH = [
    "test",
]


@nox.session(name="isort")
def isort(session):
    """Run isort code formatter."""
    session.install("isort")
    session.run(
        "isort",
        "--profile",
        "black",
        ".",
    )


@nox.session(name="black")
def blacken(session):
    """Run black code formatter."""
    session.install(
        "black",
    )
    session.run(
        "black",
        "--check",
        ".",
    )


@nox.session(name="flake8")
def flake(session):
    """Run black code formatter."""
    session.install("flake8")
    session.run(
        "flake8",
        ".",
    )


@nox.session(name="lint")
def lint(session):
    """Run linters."""
    session.install(*LINT_DEPENDENCIES)
    session.run(
        "isort",
        "--profile",
        "black",
        *LINT_PATH,
    )
    session.run(
        "black",
        "--check",
        "--verbose",
        *LINT_PATH,
    )
    session.run(
        "flake8",
        *LINT_PATH,
    )
