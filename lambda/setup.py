"""
ScriptChain Health – Lambda Python Package Configuration
=========================================================
Defines package metadata, runtime dependencies, and optional dev tooling.

Usage:
    pip install -e .                   # editable install for local development
    pip install -e ".[dev]"            # also install dev/test dependencies
    python setup.py sdist bdist_wheel  # build a distributable package

Note: The actual Lambda deployment artifact is produced by build.sh (a zip of
handler.py + installed dependencies), NOT by this setup.py. setup.py serves
as the Python packaging manifest and is used for local development installs.

Author: Richard Kweku Addae
"""

from setuptools import setup, find_packages

setup(
    name="scriptchain-lambda-function",
    version="1.0.0",
    description="AWS Lambda function package for the ScriptChain Health API",
    author="Richard Kweku Addae",
    python_requires=">=3.12",

    # Auto-discover any sub-packages (e.g. utils/, models/) added in the future
    packages=find_packages(exclude=["tests*", "build*"]),

    # handler.py is a top-level module (not inside a sub-package)
    py_modules=["handler"],

    # Runtime dependencies – mirror requirements.txt
    # boto3 excluded: provided by the Lambda runtime
    install_requires=[
        "requests==2.31.0",
        "aws-lambda-powertools==2.34.2",
    ],

    # Dev/test extras – NOT bundled into the Lambda zip
    extras_require={
        "dev": [
            "pytest>=7.0",
            "pytest-cov",
            "boto3",           # available locally for unit testing
            "moto[lambda]",    # AWS service mocking for tests
        ]
    },

    classifiers=[
        "Programming Language :: Python :: 3.12",
        "Operating System :: OS Independent",
    ],
)