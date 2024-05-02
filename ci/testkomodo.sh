
copy_test_files () {
    cp -r $CI_SOURCE_ROOT/tests $CI_TEST_ROOT/tests
    cp -r $CI_SOURCE_ROOT/docs $CI_TEST_ROOT/docs
    cp -r $CI_SOURCE_ROOT/examples $CI_TEST_ROOT/examples
    cp $CI_SOURCE_ROOT/.pylintrc $CI_TEST_ROOT
}


start_tests () {
    if [[ ! -z "$CI_PR_RUN" ]]; then
        # ignore some tests for komodo testing
        python -m pytest tests -s --ignore-glob "*test_ui*" \
        --ignore-glob "*test_visualization_entry*" \
        --deselect="tests/test_detached.py::TestDetached::test_https_requests" \
        -m "not simulation_test and not ui_test and not redundant_test"
    else
        python -m pytest tests -s \
        --ignore-glob "*test_visualization_entry*" \
        --ignore-glob "*test_https_requests*" \
        --deselect="tests/test_detached.py::TestDetached::test_https_requests" \
         -m "not simulation_test and not redundant_test and not ui_test"
        xvfb-run -s "-screen 0 640x480x24" --auto-servernum python -m pytest -s -m "ui_test"
    fi
}

install_test_dependencies () {
    if [ -f "test_requirements.txt" ]; then
        pip install -r test_requirements.txt
    else
        pip install ".[test]"
    fi
}
