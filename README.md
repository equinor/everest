[![Python](https://github.com/equinor/everest/workflows/Python%20package/badge.svg)](https://github.com/equinor/everest/actions?query=workflow%3A%22Python+package%22)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)
[![Style](https://github.com/equinor/everest/workflows/Style/badge.svg)](https://github.com/equinor/everest/actions?query=workflow%3AStyle)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# Everest™


The primary goal of the Everest tool is to find *optimal* well planning and production strategies by utilizing an ensemble of reservoir models (e.g., an ensemble of geologically-consistent models). This will enable robust decisions about drilling schedule and well placement, in order to achieve results of significant practical value.


## Requirements

Python version:
Everest supports Python version 3.8, 3.10

In order to build, test and run Everest, a number of Python libraries must be available.

First make sure to install the required and test dependencies
```bash
    pip install . "[test]"
```

In addition, the following libraries must be present in your environment
For details about the build process, see the web pages of each individual library

* [everest-models](https://github.com/equinor/everest-models)
* [OPM](https://opm-project.org/) (Optional)

#### Everest-models
Get source from [everest-models](https://github.com/equinor/everest-models)

```bash
    git clone https://github.com/equinor/everest-models
    cd everest-models
    pip install . --upgrade
```

#### OPM (Optional)

Read documentation at
https://github.com/OPM

## Testing

Some tests require access to the `/project/res` folders in the Equinor internal network. If you don't have access to that folder, you have to `export NO_PROJECT_RES=1` so that those tests will be skipped.

Tests can be executed with
```
python -m pytest -m <test_category>
```
where `<test_category>` must be replaced by one of the following categories:
- `ui_test` contains all the tests related to the user interface
- `integration_test` contains self-contained integration tests (the above installation should be sufficient for them to pass).
- `simulation_test` requires a more complete setup and among others requires the job `SYMLINK` to be known to _everest_ as well as access to `/project/res` in Equinor (the later is to be changed soon).
- `redundant_test` test that covers portions of code already covered by other tests. They are regularly run on our CI system



## The optimization process

The following is a brief explanation of how Everest works. It is inaccurate and incomplete, but it is hopefully a good starting point.

Everest is designed for finding local maxima of functions $y=f(x)$ where the _variables_ (a.k.a. _controls_) $x$ are properties of wells (such as the date a well is drilled, the position of points along its path. etc.), while the objectives $y$ are typically quantities measured over a long period of time (such as the the Net Present Value, CO2 emissions, etc.).

An optimization problem must be specified using an _Everest config file_. The optimization part is handled by the [ropt](https://github.com/TNO-ropt/ropt) package, the computation of the objectives is handled by [ert](https://github.com/equinor/ert).

#### Optimization
The actual robust optimization workflow is implemented by the `ropt` package, which builds on standard optimization algorithms to implement robust optimization strategies. By default `ropt` provides only algorithms from the SciPy package as its optimizer backend, but Everest by default installs a plugin to support gradient-based optimization algorithms from the Dakota package, e.g. Newton and quasi-Newton methods.

Based on an initial assignment of the control variables $x_0$, `ropt` starts a backend optimization algorithm, which asks `ropt` to provide the values of the function $f(x_0)$ and its gradient $f'(x_0)$. Once the values are provided, the optimization algorithm determines a new set of control variables $x_1$ with a corresponding function value $f(x_1)$. If $f(x_1) > f(x_0)$, $x_1$ becomes the current maximum, and the entire process is repeated until certain exit conditions are encountered.

The role of `ropt` is to implemented robust optimization functionality on top of the backend algorithm, among others this includes:
- Maximization: Most standard optimization algorithms solves minimization problems. `ropt` take care of negating all the values so that a maximization problem is solved instead.
- Robust function evaluation: the function to evaluate usually derives from an ensemble of different geological models (realizations), in order to take uncertainty into account. `ropt` asks `ert` to evaluate each realization and calculates a single function from the set of calculated function values.
- Gradient estimation: in most of the cases we are targeting, it is impossible to provide the exact value of the function gradient. When a gradient is needed, `ropt` generates several perturbations of the controls $x_i = x + \delta_i$ and asks ert to compute all the functions $y_i=f(x_i)$. Once the results are available, ropt determines an estimate of the gradient by performing a linear regression of the values $(x_i, y_i)$.
- Multiple objectives: `ropt` supports optimizing several objectives at once.

#### Function computation
`ert` takes care of computing function values for the ensemble of geological models. `ert` knows nothing about the problem to be solved, its main responsibility is to execute a _forward model_, on all the geological realizations. The forward model is given by a sequence of _jobs_ that the user must provide in the Everest configuration file.

NOTE: since the most expensive job in a forward model is usually a reservoir simulation, the execution of a forward model is often called a _simulation_, especially when talking about _batches_ (see below).

Let's look at an example: assume the config file contains the specifications for a group of control variables called `my_wells` and two objectives called `npv` and `co2_emissions`.
`ert` creates a dedicated folder for executing the forward model, and copy/links all the necessary files (the geological realization) into it. The folder is located deep down in the _simulation folder_ specified in the config file. The current assignment of the control variables is written to the file `my_wells.json` located in that folder. A forward model typically begins with some setup operations based on `my_wells.json`, then runs a reservoir simulation ([Eclipse](https://www.software.slb.com/products/eclipse/simulators) or [flow](https://opm-project.org/?page_id=19)), followed by some post-processing and the eventual creation of the files `npv_0` and `co2_emissions_0`. Each of those files must contain a single line of text, which is the desired function value.


Requests from `ropt` to `ert` are grouped into batches. A batch can include simulations related to evaluating the function, the gradient, or both. The number of simulations in a batch is often a good indication of what is going on. Let `real_num` be the number of geological realizations and `pert_num` the number of perturbations ropt generates for computing  a gradient. Then:
- A batch executed for evaluating the function $f(x)$ has exactly `real_num` simulations
- A batch executed for evaluating the gradient $f'(x)$ has exactly `real_num * pert_num` simulations
- A batch that evaluates both the function, and the gradient has `real_num + real_num * pert_num` simulations

Notes:
- By setting the `speculative` option, all the batches have both function and gradient evaluations
- Simulations in a batch have an incremental id. If a batch has both function and gradient evaluations, the first `real_num` simulations are the ones used for the function evaluations
