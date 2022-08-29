#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Nox configuration file.
"""
import os

import nox


def get_path(*path):
    """
    Return the absolute path of the given path.
    """
    return os.path.join(NOX_DIR, *path)


NOX_DIR = os.path.abspath(os.path.dirname(__file__))


LINT_DEPENDENCIES = [
    "isort",
    "black",
    "flake8",
]

LINT_PATH = [
    get_path("noxfile.py"),
    get_path("test"),
]


@nox.session(name="isort")
def isort(session):
    """Run isort code formatter."""
    session.install("isort")
    session.run(
        "isort",
        "--profile",
        "black",
        *LINT_PATH,
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
        *LINT_PATH,
    )


@nox.session(name="flake8")
def flake(session):
    """Run black code formatter."""
    session.install("flake8")
    session.run(
        "flake8",
        *LINT_PATH,
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
