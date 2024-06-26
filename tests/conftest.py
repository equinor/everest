import os
import shutil
from pathlib import Path
from typing import Callable, Iterator, Optional

import pytest


@pytest.fixture(scope="session")
def testdata() -> Path:
    return Path(__file__).parent / "test_data"


@pytest.fixture
def copy_testdata_tmpdir(
    testdata: Path, tmp_path: Path
) -> Iterator[Callable[[Optional[str]], Path]]:
    def _copy_tree(path: Optional[str] = None):
        path_ = testdata if path is None else testdata / path
        shutil.copytree(path_, tmp_path, dirs_exist_ok=True)
        return path_

    cwd = Path.cwd()
    os.chdir(tmp_path)
    yield _copy_tree
    os.chdir(cwd)
