import os
import shutil
import sys
from copy import deepcopy
from pathlib import Path
from typing import Callable, Dict, Iterator, Optional, Union

import pytest

from everest.config.control_config import ControlConfig


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


@pytest.fixture(scope="module")
def control_data_no_variables() -> Dict[str, Union[str, float]]:
    return {
        "name": "group_0",
        "type": "well_control",
        "min": 0.0,
        "max": 0.1,
        "perturbation_magnitude": 0.005,
    }


@pytest.fixture(
    scope="module",
    params=(
        pytest.param(
            [
                {"name": "w00", "initial_guess": 0.0626, "index": 0},
                {"name": "w00", "initial_guess": 0.063, "index": 1},
                {"name": "w00", "initial_guess": 0.0617, "index": 2},
                {"name": "w00", "initial_guess": 0.0621, "index": 3},
                {"name": "w01", "initial_guess": 0.0627, "index": 0},
                {"name": "w01", "initial_guess": 0.0631, "index": 1},
                {"name": "w01", "initial_guess": 0.0618, "index": 2},
                {"name": "w01", "initial_guess": 0.0622, "index": 3},
                {"name": "w02", "initial_guess": 0.0628, "index": 0},
                {"name": "w02", "initial_guess": 0.0632, "index": 1},
                {"name": "w02", "initial_guess": 0.0619, "index": 2},
                {"name": "w02", "initial_guess": 0.0623, "index": 3},
                {"name": "w03", "initial_guess": 0.0629, "index": 0},
                {"name": "w03", "initial_guess": 0.0633, "index": 1},
                {"name": "w03", "initial_guess": 0.062, "index": 2},
                {"name": "w03", "initial_guess": 0.0624, "index": 3},
            ],
            id="indexed variables",
        ),
        pytest.param(
            [
                {"name": "w00", "initial_guess": [0.0626, 0.063, 0.0617, 0.0621]},
                {"name": "w01", "initial_guess": [0.0627, 0.0631, 0.0618, 0.0622]},
                {"name": "w02", "initial_guess": [0.0628, 0.0632, 0.0619, 0.0623]},
                {"name": "w03", "initial_guess": [0.0629, 0.0633, 0.062, 0.0624]},
            ],
            id="vectored variables",
        ),
    ),
)
def control_config(
    request,
    control_data_no_variables: Dict[str, Union[str, float]],
) -> ControlConfig:
    config = deepcopy(control_data_no_variables)
    config["variables"] = request.param
    return ControlConfig.model_validate(config)


@pytest.fixture(scope="session", autouse=True)
def hide_window(request):
    if request.config.getoption("--show-gui"):
        yield
        return

    old_value = os.environ.get("QT_QPA_PLATFORM")
    if sys.platform == "darwin":
        os.environ["QT_QPA_PLATFORM"] = "offscreen"
    else:
        os.environ["QT_QPA_PLATFORM"] = "minimal"
    yield
    if old_value is None:
        del os.environ["QT_QPA_PLATFORM"]
    else:
        os.environ["QT_QPA_PLATFORM"] = old_value


def pytest_addoption(parser):
    parser.addoption("--show-gui", action="store_true", default=False)
