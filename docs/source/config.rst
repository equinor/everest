.. _cha_config:

*********************
Everest configuration
*********************

Everest is configured via a yaml file, using a set of pre-defined keywords that
are described in more detail in the :ref:`keyword reference <cha_config_reference>`.

The configuration file has several sections which are defined and explained below. In the configuration file, the sections can appear in any order.

The configuration snippets below are only an example of the different elements necessary in a section. Every case will have different information in a section depending on the problem being optimized.

The egg model is used as an example in the next sections. You can download it :download:`here <../../examples/egg/everest/model/config_flow.yml>`.

.. note::

	Expressions containing :code:`r{{ ... }}` follows a special syntax to enable :ref:`custom variables <section_config_variables>`. Please note that this section already contains such expressions.


Definitions section
===================

In the `Definition section` we declare reusable variables to be accessed later in the other sections of the configuration file. Additionally the case name and user name are defined. For long path names which are used multiple times in a configuration file it is recommended to define such paths through a variable name in order to improve readability of the configuration files.


.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 1-2


Environment section
====================
This section defines the paths to where the reservoir simulation will be run. If given as a relative path, the path is relative to the configuration file.

.. note::

	Reservoir simulations produces large files and it is often desirable to use different storage spaces for that (e.g. scratch disk).


.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 93-95


Wells section
=============

The wells used in an optimization experiment are defined in the :code:`wells` section. The information will be translated by Everest into a **json** file which may be used in any of the jobs in the :ref:`forward_model <fwd_model_section>` section explained below.


.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 4-8


Control variables section
=========================

In any optimization experiment it is imperative to define the control variables (controls) to be optimized. In this section we define these variables.

.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 18-41


.. note::

	The control variables should always be scaled in the (min, max) range defined for that control type. It is good practice to work in the range of (min=0, max=1) whenever possible to avoid undesired effects of control variable unit scales in the optimization problem and to allow the perturbation size to be specified in more generic dimensionless terms.


Objective Function section
==========================

With the controls being defined, the next source of information needed for any experiment is the definition of the objective function to be minimized/maximized. In the `objective_function` section the objective functions, their normalization factors and weights (in case of multi-objective optimization) are defined.

.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 75-76


.. note::

	Everest can work with multiple objective functions using a weighted sum approach. The relative importance of the different objective functions is defined through their weights. The normalization factor should be defined such that the objective function value lies between 0 and 1.


Optimizer settings section
==========================

In this section the optimizer parameters used in Everest are defined, the most important ones being the choice of algorithm, stopping criteria, number of perturbations per realization and algorithm specific settings. The example below shows the usage of :code:`optpp_q_newton` algorithm, but different algorithms have their particular settings.


.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 79-86

.. important::

	When dealing with continuous variables, like rates control values, it is better to use the :code:`conmin_mfd` optimizer in Everest. For cases with discrete variables, such as drilling order control values, :code:`optpp_q_newton` is recommended. For more information please refer to the :ref:`optimization algorithm <cha_algorithms>` section.


Model definition section
========================

With the two main components (i.e., the controls and objective functions) defined above, the third most important component is the model(s) necessary to perform the optimization.
In this section the :code:`realization numbers` are defined along with the :code:`report_dates` which will be used in the export of the results.


.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 88-91


Simulation prerequisites section
================================

With the three main components of any optimization experiment defined we need to define the simulation/computational facilities such as the number of cores, job scheduling system, name of queue, etc.


.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 97-99


Install input section
=====================

In this section the data and realization files needed to perform a simulation and the optimization are made available through either symbolic linking (Unix) or copying during the iterative optimization process. The files copied/linked from a centralized location (e.g., input/files folder) will then be accessible from the simulation running folders where the jobs and scripts perform the calculations.

.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 106-113


.. _fwd_model_section:

Forward model section
=====================

The :code:`forward_model` section defines the forward models and jobs which will be performed during the simulation. This will translate the control variables into a simulator readable format, run the model realizations and calculate the objective function. For more detailed information and examples regarding the forward models please refer to the detailed :ref:`forward model documentation <cha_forward_model_jobs>`.


.. warning::

	This is the only section where the order of the jobs defined is :code:`very important`, for all other sections the order of the sub-elements/definitions is irrelevant.


.. literalinclude:: ../../examples/egg/everest/model/config_flow.yml
   :language: yaml
   :lines: 116-121


.. note::

	Due to Everest implementation reasons the objective function job should create an output file that has the same objective function name plus the suffix :code:`_0.`


.. _section_config_variables:

Everest custom variables
========================

You can extend the configuration file using variables.
Variables are a distinct feature from the yaml keywords defined in section
:ref:`cha_config_reference`. The final yaml file used by Everest is produced
by pre-processing the config file to replace all variables with their value.


.. note::
   It is possible to define variables that have the same name as a keyword, but
   this should be done sparingly to avoid confusion.


In addition to the standard yaml syntax, Everest also supports the use of
variables that are replaced with their value when referred as :code:`r{{ variable }}`.


Example
-------


For instance in the following snippet, the variable :code:`tol` is replaced by its value:

.. code-block:: yaml

    optimization:
        algorithm: optpp_q_newton
        convergence_tolerance: r{{tol}}

The value of a variable can be set in three different ways:

In the :code:`definitions` section in the yaml file. For instance, to define a
variable :code:`tol` with a value of 0.0001, include this in the :code:`definitions`
section:

.. code-block:: yaml

      definitions:
         tol: 0.0001


Environmental variables
-----------------------


Variables with a name of the form :code:`os.ENVIRONMENT_VARIABLE_NAME` can be used to access
the values of environment variables. For instance, the variable
:code:`r{{ os.USER }}` will be replaced by the contents of the environment
variable :code:`USER`.


Pre-defined variables
---------------------


Everest pre-defines the following of variables:

.. code-block:: yaml

   realization: <GEO_ID>
   configpath: <CONFIG_PATH>
   runpath_file: <RUNPATH_FILE>
   eclbase: <ECL_BASE>

These variables do not need to be defined by the user, although their values
can be overridden in the :code:`definitions` section. However, this is not
recommended for the :code:`realization` entry, and Everest will produce a warning
when this is attempted.
