#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Nox configuration file.
"""
import nox

# PYTHON_DEFAULT_VERSION = "3.10"
PYTHON_ALL_VERSIONS = ["3.7", "3.8", "3.9", "3.10"]
LINT_DEPENDENCIES = [
    "isort",
    "black",
    "flake8",
]


# @nox.session(name="isort", python=PYTHON_DEFAULT_VERSION)
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


# @nox.session(name="black", python=PYTHON_DEFAULT_VERSION)
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


# @nox.session(name="flake8", python=PYTHON_DEFAULT_VERSION)
@nox.session(name="flake8")
def flake(session):
    """Run black code formatter."""
    session.install("flake8")
    session.run(
        "flake8",
        ".",
    )


@nox.session(name="lint", python=PYTHON_ALL_VERSIONS)
def lint(session):
    """Run linters."""
    session.install(*LINT_DEPENDENCIES)
    session.run(
        "isort",
        "--profile",
        "black",
        ".",
    )
    session.run(
        "black",
        "--check",
        "--verbose",
        ".",
    )
    session.run(
        "flake8",
        ".",
    )
