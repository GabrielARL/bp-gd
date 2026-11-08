#!/usr/bin/env python3
"""Lightweight, portable checks for the compact bp-gd export."""

from __future__ import annotations

import csv
import hashlib
from html.parser import HTMLParser
from pathlib import Path
import re
import sys

try:
    import tomllib
except ModuleNotFoundError:  # Python 3.10 in the supported local environment.
    import tomli as tomllib


ROOT = Path(__file__).resolve().parents[1]

STALE_OPERATIONAL_SOURCE_MARKERS = (
    "operational-source inventory validator passed 25 files",
    "25-file inventory validator",
    "operational preparation passes a 25-file inventory",
    "actual 25-member source closure",
    "five Python tests and 230 Julia assertions",
    "12 coefficient-seal-loader, 24 provider, 165 operational-runtime, and 29 retained-callback assertions",
    "all 235 checks passing",
    "all 235 source checks",
    "five Python tests and 237 Julia assertions",
    "12 coefficient-seal-loader, 31 provider, 165 operational-runtime, and 29 retained-callback assertions",
    "all 242 checks passing",
    "all 242 source checks",
    "temporary 242-check bundle",
    "33/33",
    "7aaaf1a9509eb8f2ea3f131624b3afc702fdf5d52c5da7fffa4ffc2e82ab6c57",
    "f084a7d484ddcd4a2980a40c2f2cab28d7c055b7a93b654420df00ab32c16fce",
    "936ada403a4794ecf97164019a8af912667f464a314dfeea3116050ec85e3b72",
    "closure-002 and activation-002 remain prospective and unapproved",
    "closure-002 / activation-002 unapproved",
    "separate review and approval of closure-002, then",
    "artifact has not been materialized and no second scan has run",
    "approved but not materialized or run",
    "approved / not materialized",
    "approval itself launched no scan",
    "approval itself launched no second scan",
    "materialize the already approved activation-002",
    "separate review and approval of activation-002 before another scan",
    "path-correction retry is proposed but not approved",
    "path-correction retry is unapproved",
    "corrected retry is unapproved",
    "No corrected retry, retained-wall run, fresh input",
    "obtain approval for and materialize <code>RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002-PATH-CORRECTION-RETRY-001</code>",
)


class LinkCollector(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "a" and values.get("href"):
            self.links.append(values["href"] or "")
        if tag in {"img", "script"} and values.get("src"):
            self.links.append(values["src"] or "")


def fail(message: str) -> None:
    raise AssertionError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_html(relative: str) -> int:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    parser = LinkCollector()
    parser.feed(text)
    if "file://" in text:
        fail(f"nonportable file URL remains in {relative}")
    checks = 2
    for link in parser.links:
        if link.startswith(("#", "https://", "http://", "mailto:")):
            continue
        target = (path.parent / link.split("#", 1)[0]).resolve()
        if not target.exists():
            fail(f"broken local link in {relative}: {link}")
        checks += 1
    return checks


def verify_evidence() -> int:
    package = ROOT / "implementation/compound_box_gd"
    base = package / "evidence"
    rows = list(csv.DictReader((base / "aggregate.csv").open(encoding="utf-8")))
    selected = [
        row
        for row in rows
        if row["arm"] == "compound__box"
        and row["endpoint"] == "transmitted_word_equal"
    ]
    observed = {
        int(row["checkpoint_update"]): (int(row["cases"]), int(row["successes"]))
        for row in selected
    }
    if observed != {30: (200, 177), 90: (200, 200)}:
        fail(f"unexpected retained compound__box counts: {observed}")
    completion_text = (base / "COMPLETED.toml").read_text(encoding="utf-8")
    fields = dict(
        re.findall(r'^([A-Za-z0-9_]+)\s*=\s*"([^"]*)"\s*$', completion_text, re.M)
    )
    if fields.get("status") != "complete_valid":
        fail("retained 6-dB evidence is not marked complete_valid")
    if fields.get("primary_science_sha256") != fields.get("replay_science_sha256"):
        fail("retained primary and replay science hashes differ")

    validation_text = (package / "VALIDATION.toml").read_text(encoding="utf-8")
    validation_strings = dict(
        re.findall(
            r'^([A-Za-z0-9_]+)\s*=\s*"([^"]*)"\s*$', validation_text, re.M
        )
    )
    validation_integers = {
        key: int(value)
        for key, value in re.findall(
            r"^([A-Za-z0-9_]+)\s*=\s*([0-9]+)\s*$", validation_text, re.M
        )
    }
    local_identities = {
        "portable_runner_sha256": package / "src/CompoundBoxGD.jl",
        "portable_config_sha256": package / "config/compound_box.toml",
        "oracle_generator_sha256":
            package / "test/generate_frozen_oracle_fixture.jl",
        "portable_test_sha256": package / "test/runtests.jl",
        "fixture_sha256": package / "test/fixtures/frame_50025.bin",
        "expected_record_sha256":
            package / "test/fixtures/frame_50025_expected.toml",
    }
    for field, path in local_identities.items():
        if validation_strings.get(field) != sha256(path):
            fail(f"compound-box validation identity differs: {field}")
    if 'status = "pass"' not in validation_text:
        fail("compound-box portable validation is not marked pass")
    if validation_integers.get("total_checks") != 10_258:
        fail("compound-box validation check count differs")
    for required in (
        "legacy_objective_alias_checked = true",
        "stored_state_objective_binding_checked = true",
        "update1_objective_distinction_checked = true",
    ):
        if required not in validation_text:
            fail(f"compound-box validation lacks metric binding gate: {required}")
    return 14


def verify_two_hop_metric_action() -> int:
    base = ROOT / "implementation/two_hop_metric_action"
    expected_files = {
        "Project.toml",
        "README.md",
        "VALIDATION.toml",
        "benchmark_complete_trace_resources.jl",
        "complete_trace_resource_measurement_2026-11-06_v1.toml",
        "compound_objective_jc.jl",
        "evidence/retained_stage_a.toml",
        "jc_metric_direction.jl",
        "origin_row_adapter.jl",
        "reproduction_card.md",
        "retained_direction_population_summary.jl",
        "stage_c_decoder_source.jl",
        "stage_c_trace_integrity.jl",
        "stage_b_direction_kernel.jl",
        "target_specific_gates.jl",
        "test/authoritative_jc_fixture.toml",
        "test/generate_authoritative_jc_fixture.jl",
        "test/local_authoritative_jc_fixture.jl",
        "test/local_finite_difference.jl",
        "test/local_full_synthetic_population_chain.jl",
        "test/local_jc_metric_direction.jl",
        "test/local_origin_row_adapter.jl",
        "test/local_population_summary.jl",
        "test/local_stage_b_direction_kernel.jl",
        "test/local_stage_c_decoder_source.jl",
        "test/local_target_specific_gates.jl",
        "test/runtests.jl",
        "test_two_hop_positive_metric.jl",
        "two_hop_positive_metric.jl",
    }
    actual_files = {
        str(path.relative_to(base)) for path in base.rglob("*") if path.is_file()
    }
    if actual_files != expected_files:
        fail(f"unexpected two-hop extraction entries: {sorted(actual_files ^ expected_files)}")

    source = base / "two_hop_positive_metric.jl"
    historical_test = base / "test_two_hop_positive_metric.jl"
    objective_source = base / "compound_objective_jc.jl"
    direction_composition = base / "jc_metric_direction.jl"
    direction_kernel = base / "stage_b_direction_kernel.jl"
    local_finite_difference_test = base / "test/local_finite_difference.jl"
    local_composition_test = base / "test/local_jc_metric_direction.jl"
    local_direction_test = base / "test/local_stage_b_direction_kernel.jl"
    fixture = base / "test/authoritative_jc_fixture.toml"
    fixture_generator = base / "test/generate_authoritative_jc_fixture.jl"
    local_fixture_test = base / "test/local_authoritative_jc_fixture.jl"
    population_summary = base / "retained_direction_population_summary.jl"
    target_specific_gates = base / "target_specific_gates.jl"
    origin_row_adapter = base / "origin_row_adapter.jl"
    local_population_test = base / "test/local_population_summary.jl"
    local_target_test = base / "test/local_target_specific_gates.jl"
    local_adapter_test = base / "test/local_origin_row_adapter.jl"
    local_full_chain_test = base / "test/local_full_synthetic_population_chain.jl"
    stage_c_decoder_source = base / "stage_c_decoder_source.jl"
    stage_c_trace_integrity = base / "stage_c_trace_integrity.jl"
    stage_c_resource_benchmark = base / "benchmark_complete_trace_resources.jl"
    stage_c_resource_measurement = (
        base / "complete_trace_resource_measurement_2026-11-06_v1.toml"
    )
    local_stage_c_test = base / "test/local_stage_c_decoder_source.jl"
    local_test_runner = base / "test/runtests.jl"
    project_file = base / "Project.toml"
    expected_project_sha = (
        "47820c6b9e1d424ac921c189d2f66c403c1136886977d6af05f0ca4c041fd94a"
    )
    expected_source_sha = (
        "8f5edffbd6a1e817422da857fc4c78d095e682b42c6cebfdc429437de7e71efb"
    )
    expected_test_sha = (
        "fd916d8d553bef1e172112981eff704f3e30fd6bd8655e62c2ec39fe166bc66c"
    )
    expected_direction_kernel_sha = (
        "599ff92f70e955e501f280c80d7919bc4d8838bbccdd9922f0338a3ef63b2383"
    )
    expected_objective_source_sha = (
        "6565b88e3974f7efbfac1dbdd8446ace79752779d5a40bf8e53bb47f7db53bb0"
    )
    expected_direction_composition_sha = (
        "986a50159de3d0ac8b439855a6ea8878e0aa148f626dda6687dcb69b096ce68c"
    )
    expected_local_finite_difference_test_sha = (
        "c644b1e1360cd23c0174654bd60b6a6ead49086e5bd55fb7402b83c0f4e6068d"
    )
    expected_local_composition_test_sha = (
        "943ab753c9ecec515d70ec359e969c238e613768f8e1d02793e2a84e7e2139fd"
    )
    expected_local_direction_test_sha = (
        "e014a874fd7cffab7d99dfec3ad677ead00cc10a3cda4c5a18fe26c007e1a669"
    )
    expected_fixture_sha = (
        "58e69fb745aed4b2aa454728f3b6e32d320c50b56862f78f34a8230092bfc68a"
    )
    expected_fixture_generator_sha = (
        "721fe4641e4f23a55b0234200a641f94b9b0a847c6f8c0f96306ee6271bbf21f"
    )
    expected_local_fixture_test_sha = (
        "60ad5e7f5be44067f3b09d8f8b75aa7ce3772265e49ecff9bc3dcadb154b226b"
    )
    expected_population_summary_sha = (
        "80c048a4b861bf373923d454b716398830965b4bfbd85dabad68be448d14b0c4"
    )
    expected_target_specific_gates_sha = (
        "80b6dbdf3b21d08d3c3dba6c72ccf671416ee52eaad56db9f3f04615b44ee330"
    )
    expected_origin_row_adapter_sha = (
        "ab46889d59faa04c69563d7f8d834215ea738d670026543b8afcfcdeb1bc8068"
    )
    expected_local_population_test_sha = (
        "4af67e663379b7169417a828d1f78c0061165d4f8f8e451fde77ad47d669d17f"
    )
    expected_local_target_test_sha = (
        "4ac7229dcf44a720ed3e7fe66a20336b6784a88b967f8c1ec7a49e27508e528f"
    )
    expected_local_adapter_test_sha = (
        "201ef67ce70bfc29926c15557443ba15f810c2dc80bdfaa9e13a294d8f6b4c4e"
    )
    expected_local_full_chain_test_sha = (
        "052024c0f1aaddda16ff8ebdc9258c89f6a2b2432425029e38b79e5b78db66b0"
    )
    expected_stage_c_decoder_source_sha = (
        "37625499e3f232d706fa8b72290d063e71e0921f843411f1e9c5496bd17f7b81"
    )
    expected_stage_c_trace_integrity_sha = (
        "99bab477b0ecae05fc61306c89bf3077aa20dbb2c39527355934c76b6e99dc26"
    )
    expected_local_stage_c_test_sha = (
        "f0e7f87345f8ad9e98f803341c63174826af215d61b628bdbf19237207e61a5b"
    )
    expected_local_test_runner_sha = (
        "21c7213ba77fef0d815112da0c7d07eb2f8237ea8b6228e6cef8e1d99d6d962e"
    )
    expected_stage_c_resource_benchmark_sha = (
        "25240c32ea017fbce89f20c84400a2b9d83e2101f1115de2fb719be13d9f38a7"
    )
    expected_stage_c_resource_measurement_sha = (
        "4620016b8eb4544a39b966185589dbbbaf27a0d89c72fab9d013f59afc20bee1"
    )
    if sha256(source) != expected_source_sha:
        fail("two-hop metric source differs from the registered historical source")
    if sha256(project_file) != expected_project_sha:
        fail("two-hop project dependency declaration differs")
    if sha256(historical_test) != expected_test_sha:
        fail("two-hop synthetic test differs from the registered historical test")
    if sha256(objective_source) != expected_objective_source_sha:
        fail("production J_C source differs from its validated source")
    if sha256(direction_composition) != expected_direction_composition_sha:
        fail("production J_C-to-direction composition differs from its validated source")
    if sha256(direction_kernel) != expected_direction_kernel_sha:
        fail("per-origin direction kernel differs from the registered source")
    if sha256(local_finite_difference_test) != expected_local_finite_difference_test_sha:
        fail("local finite-difference test differs from its validated source")
    if sha256(local_composition_test) != expected_local_composition_test_sha:
        fail("local production-composition test differs from its validated source")
    if sha256(local_direction_test) != expected_local_direction_test_sha:
        fail("local direction-kernel test differs from its validated source")
    if sha256(fixture) != expected_fixture_sha:
        fail("frozen authoritative J_C fixture differs from its validated source")
    if sha256(fixture_generator) != expected_fixture_generator_sha:
        fail("authoritative J_C fixture generator differs from its validated source")
    if sha256(local_fixture_test) != expected_local_fixture_test_sha:
        fail("portable authoritative J_C fixture test differs")
    if sha256(population_summary) != expected_population_summary_sha:
        fail("retained population-summary extraction differs")
    if sha256(target_specific_gates) != expected_target_specific_gates_sha:
        fail("target-specific gates differ from the registered pure source")
    if sha256(origin_row_adapter) != expected_origin_row_adapter_sha:
        fail("origin-row adapter differs from the registered pure source")
    if sha256(local_population_test) != expected_local_population_test_sha:
        fail("local retained-population test differs")
    if sha256(local_target_test) != expected_local_target_test_sha:
        fail("local target-specific gate test differs")
    if sha256(local_adapter_test) != expected_local_adapter_test_sha:
        fail("local origin-adapter test differs")
    if sha256(local_full_chain_test) != expected_local_full_chain_test_sha:
        fail("local full synthetic population-chain test differs")
    if sha256(stage_c_decoder_source) != expected_stage_c_decoder_source_sha:
        fail("dormant Stage-C decoder source differs from its validated source")
    if sha256(stage_c_trace_integrity) != expected_stage_c_trace_integrity_sha:
        fail("pure Stage-C trace checker differs from its validated source")
    if sha256(local_stage_c_test) != expected_local_stage_c_test_sha:
        fail("local Stage-C decoder-source test differs from its validated source")
    if sha256(local_test_runner) != expected_local_test_runner_sha:
        fail("two-hop local test runner differs from its validated source")
    if sha256(stage_c_resource_benchmark) != \
            expected_stage_c_resource_benchmark_sha:
        fail("Stage-C complete-trace resource benchmark identity differs")
    if sha256(stage_c_resource_measurement) != \
            expected_stage_c_resource_measurement_sha:
        fail("Stage-C complete-trace resource measurement identity differs")

    source_text = source.read_text(encoding="utf-8")
    forbidden_patterns = {
        r"\bfunction\s+decode\s*\(": "decoder entry point",
        r"\bfresh_inputs\b": "fresh-input operation",
        r"\bframe_first\b": "frame-range operation",
        r"\bber\b": "BER operation",
    }
    for pattern, label in forbidden_patterns.items():
        if re.search(pattern, source_text, re.I):
            fail(f"decoder or experiment operation entered metric source: {label}")

    objective_text = objective_source.read_text(encoding="utf-8")
    composition_text = direction_composition.read_text(encoding="utf-8")
    production_forbidden = {
        r"\b(?:include|open|read|write|rand|randn)\s*\(": "I/O or randomness",
        r"\b(?:calculate_pass|generate_awgn|exact_recurrence|sum_product)\b":
            "case generation or exact recurrence",
        r"\b(?:decoder_update|hard_decision|readout|line_search|projected_step)\s*\(":
            "decoder state operation",
        r"\b(?:teacher|reference_direction)\b":
            "caller-supplied comparison direction",
    }
    for label, text in (
            ("production J_C source", objective_text),
            ("production J_C-to-direction composition", composition_text)):
        for pattern, capability in production_forbidden.items():
            if re.search(pattern, text, re.I):
                fail(f"forbidden operation entered {label}: {capability}")
    for required in (
        "module RQ2CompoundObjectiveJC",
        "rq2-two-hop-positive-metric-001/compound-objective-jc-v1",
        "function evaluate_objective",
        "function fixed_metric_diagonal",
        "partial_derivatives",
        "clipped_llr",
    ):
        if required not in objective_text:
            fail(f"production J_C source lacks interface marker: {required}")
    for required in (
        "module RQ2JCMetricDirection",
        "rq2-two-hop-positive-metric-001/jc-metric-direction-v1",
        "function evaluate_jc_metric_direction",
        "caller_coefficients",
        "strict_descent_applicable",
        "exact_zero_lower_endpoint_bit_exact=true",
        "local_candidate_gate_passed=",
    ):
        if required not in composition_text:
            fail(f"production composition lacks interface marker: {required}")

    stage_c_text = stage_c_decoder_source.read_text(encoding="utf-8")
    for required in (
        "module RQ2TwoHopStageCDecoderSource",
        "stage-c-decoder-source-preparation-v1",
        "maximum_backtracks == 12",
        "maximum_update_attempts == 30",
        "generic_metric_action",
        "evaluate_objective",
        "clamp.(raw, -1.0, 1.0)",
        "descent_product < 0.0",
        "run_candidate_decoder",
        "run_lower_endpoint_decoder",
        "coefficient_admissibility",
        "line_search_stalled",
        "first_parity_valid_update",
    ):
        if required not in stage_c_text:
            fail(f"dormant Stage-C source lacks marker: {required}")
    stage_c_export = re.search(
        r"(?ms)^export\s+.*?(?=\n\n)", stage_c_text
    )
    if (stage_c_export is not None and
            re.search(r"\b_?projected_armijo_step\b", stage_c_export.group(0))):
        fail("dormant Stage-C source exports an arbitrary-direction state step")
    if "function projected_armijo_step(" in stage_c_text:
        fail("dormant Stage-C source exposes an arbitrary-direction state step")
    stage_c_forbidden = {
        r"\bteacher_direction\b": "teacher direction",
        r"\bexact_recurrence\b": "exact recurrence",
        r"\bsum_product\b": "sum-product operation",
        r"\btransmitted_bits\b": "truth input",
        r"\bframe_id\b": "frame identity",
        r"\bsnr_label\b": "SNR identity",
        r"\brecovery_score\b": "recovery scoring",
        r"\b(?:open|write|rand|randn|download|serialize|deserialize)\s*\(":
            "I/O or randomness",
    }
    for pattern, capability in stage_c_forbidden.items():
        if re.search(pattern, stage_c_text, re.I):
            fail(f"forbidden operation entered dormant Stage-C source: {capability}")

    stage_c_integrity_text = stage_c_trace_integrity.read_text(encoding="utf-8")
    for required in (
        "module RQ2TwoHopStageCTraceIntegrity",
        "stage-c-trace-integrity-v1",
        "function validate_complete_decoder_trace",
        "Objective.evaluate_objective",
        "Metric.generic_metric_action",
        "Metric.coefficient_admissibility",
        "Source.readout_diagnostics",
        "propertynames(record) == expected",
        "STATE_ROW_FIELDS",
        "every_stored_objective_recomputed=true",
        "update_trial_state_correspondence_verified=true",
    ):
        if required not in stage_c_integrity_text:
            fail(f"pure Stage-C trace checker lacks marker: {required}")
    stage_c_integrity_forbidden = {
        r"\brun_candidate_decoder\b": "candidate state advance",
        r"\brun_lower_endpoint_decoder\b": "control state advance",
        r"\bteacher_direction\b": "teacher direction",
        r"\breference_direction\b": "reference direction",
        r"\bexact_recurrence\b": "exact recurrence",
        r"\bsum_product\b": "sum-product operation",
        r"\btransmitted_bits\b": "truth input",
        r"\bframe_id\b": "frame identity",
        r"\b(?:include|open|read|write|rand|randn|download|serialize|deserialize)\s*\(":
            "I/O or randomness",
    }
    for pattern, capability in stage_c_integrity_forbidden.items():
        if re.search(pattern, stage_c_integrity_text, re.I):
            fail(f"forbidden operation entered pure Stage-C trace checker: {capability}")

    resource_benchmark_text = stage_c_resource_benchmark.read_text(
        encoding="utf-8"
    )
    resource_includes = re.findall(
        r'include\(joinpath\(@__DIR__, "([^"]+)"\)\)',
        resource_benchmark_text,
    )
    if resource_includes != [
        "stage_c_decoder_source.jl",
        "stage_c_trace_integrity.jl",
    ]:
        fail("Stage-C resource benchmark include closure differs")
    for required in (
        "module RQ2TwoHopStageCCompleteTraceResourceBenchmark",
        "stage-c-complete-trace-resource-v1",
        "const VARIABLES = 10_200",
        "const CHECKS = 5_100",
        "const EDGES = 30_600",
        "const REPETITIONS = 3",
        "capture_vectors=true",
        "Integrity.validate_complete_decoder_trace",
        "Base.summarysize(trace)",
        "serialize(io, trace)",
        "Sys.maxrss()",
        "EXPECTED_CURRENT_SCHEMA_MAX_RAW_VECTOR_BYTES = 334_152_000",
        "CURRENT_SCHEMA_LIMIT_BYTES = 384 * MIB",
        '"registered_frames_opened" => false',
        '"scientific_result" => false',
        '"approaches_bp_result" => false',
    ):
        if required not in resource_benchmark_text:
            fail(f"Stage-C resource benchmark lacks: {required}")
    for pattern, capability in {
        r"\bcalculate_pass\s*\(": "scientific case calculation",
        r"\bgenerate_awgn\s*\(": "channel-case generation",
        r"\bopen_sealed_teacher\s*\(": "teacher-session access",
        r"\bexact_recurrence\s*\(": "comparison recurrence",
        r"\bsum_product\s*\(": "sum-product operation",
        r"\btransmitted_bits\b": "truth bits",
        r"\bframe_id\b": "frame identity",
        r"\bsnr_label\b": "SNR identity",
        r"\brecovery_score\b": "recovery scoring",
        r"72065|72112|72113|72160": "registered Stage-B or Stage-C range",
    }.items():
        if re.search(pattern, resource_benchmark_text, re.I):
            fail(f"forbidden operation entered Stage-C resource benchmark: {capability}")

    with stage_c_resource_measurement.open("rb") as handle:
        resource_measurement = tomllib.load(handle)
    if (
        resource_measurement.get("schema_version") !=
        "rq2-two-hop-positive-metric-001/stage-c-complete-trace-resource-v1"
        or resource_measurement.get("classification") !=
        "synthetic complete-trace resource measurement; not scientific evidence or a registered wall budget"
        or resource_measurement.get("julia_version") != "1.12.6"
        or resource_measurement.get("synthetic_only") is not True
    ):
        fail("Stage-C resource measurement schema or classification differs")
    for field in (
        "stage_c_activated", "registered_frames_opened",
        "retained_or_fresh_data_opened", "case_provider_imported",
        "comparison_receiver_loaded", "truth_or_performance_scoring",
        "capsule_or_service_created", "scientific_result",
        "approaches_bp_result",
    ):
        if resource_measurement.get(field) is not False:
            fail(f"Stage-C resource measurement crosses boundary: {field}")
    if (
        resource_measurement.get("variables") != 10_200
        or resource_measurement.get("checks") != 5_100
        or resource_measurement.get("edges") != 30_600
        or resource_measurement.get("graph_sha256") !=
            "900ead13c4c5972bc1ed5cb99a6abf3a19a8f5d574f2ce4592007a8206c46bf0"
        or resource_measurement.get("graph_layer_attempt_counts") != [1, 5, 53]
        or resource_measurement.get("path_count") != 306_000
        or resource_measurement.get("group_count") != 305_952
        or resource_measurement.get("cosine_llr_sha256") !=
            "788f969501419fd533eb507a6ac36e78068b867bc1285857bca9029d4300b80a"
        or resource_measurement.get("zero_llr_sha256") !=
            "6d01559ce98858866c76c40b7f2415cd338142b7a4937f53e9f7094c79a1945e"
        or resource_measurement.get("cell_count") != 4
        or resource_measurement.get("repetition_count_per_cell") != 3
    ):
        fail("Stage-C resource measurement graph or input contract differs")
    canonical_source_hashes = {
        "benchmark_complete_trace_resources.jl":
            expected_stage_c_resource_benchmark_sha,
        "stage_c_decoder_source.jl":
            "93b9de632ce25b60de67e39d213a24deb0b63a8c725beb6d4b8ef315838dc06f",
        "stage_c_trace_integrity.jl": expected_stage_c_trace_integrity_sha,
        "two_hop_positive_metric.jl": expected_source_sha,
        "compound_objective_jc.jl": expected_objective_source_sha,
    }
    if resource_measurement.get("source_sha256") != canonical_source_hashes:
        fail("Stage-C canonical resource source-hash closure differs")
    if resource_measurement.get("resource_limits") != {
        "cosine_update_cap_trace_bytes": 100_663_296,
        "zero_immediate_stall_trace_bytes": 16_777_216,
        "current_schema_engineering_bytes": 402_653_184,
        "current_schema_max_raw_vector_payload_bytes": 334_152_000,
        "boundary":
            "trace and serialization engineering limits only; not peak-RSS, allocation, scientific-run, or late-stall caps",
    }:
        fail("Stage-C resource engineering limits differ")
    cell_contracts = {
        "candidate__cosine_update_cap":
            ("update_cap_reached", 30, 30, 30, 31, 69_768_000,
             69_861_148, 100_663_296),
        "lower_endpoint__cosine_update_cap":
            ("update_cap_reached", 30, 30, 30, 31, 69_768_000,
             69_861_148, 100_663_296),
        "candidate__zero_immediate_stall":
            ("line_search_stalled", 1, 0, 13, 1, 11_750_400,
             11_763_554, 16_777_216),
        "lower_endpoint__zero_immediate_stall":
            ("line_search_stalled", 1, 0, 13, 1, 11_750_400,
             11_763_554, 16_777_216),
    }
    cells = resource_measurement.get("cells", [])
    if len(cells) != 4 or {cell.get("cell") for cell in cells} != set(
        cell_contracts
    ):
        fail("Stage-C resource cell inventory differs")
    for cell in cells:
        contract = cell_contracts[cell["cell"]]
        if (
            cell.get("expected_status") != contract[0]
            or cell.get("expected_attempted_updates") != contract[1]
            or cell.get("expected_accepted_updates") != contract[2]
            or cell.get("expected_trial_record_count") != contract[3]
            or cell.get("expected_state_record_count") != contract[4]
            or cell.get("expected_raw_vector_payload_bytes") != contract[5]
            or cell.get("trace_limit_bytes") != contract[7]
            or cell.get("source_sha256") != canonical_source_hashes
            or cell.get("registered_frames_opened") is not False
            or cell.get("retained_or_fresh_data_opened") is not False
            or cell.get("comparison_receiver_loaded") is not False
            or cell.get("truth_or_performance_scoring") is not False
            or cell.get("child_peak_rss_bytes", 0) <= contract[6]
            or len(cell.get("repetitions", [])) != 3
        ):
            fail(f"Stage-C resource cell contract differs: {cell.get('cell')}")
        terminal_hashes = set()
        for repetition, row in enumerate(cell["repetitions"], 1):
            if (
                row.get("repetition") != repetition
                or row.get("status") != contract[0]
                or row.get("attempted_updates") != contract[1]
                or row.get("accepted_updates") != contract[2]
                or row.get("trial_record_count") != contract[3]
                or row.get("state_record_count") != contract[4]
                or row.get("raw_vector_payload_bytes") != contract[5]
                or row.get("trace_summary_bytes") != contract[6]
                or not contract[5] < row.get("serialized_bytes", 0) <= contract[7]
                or not re.fullmatch(
                    r"[0-9a-f]{64}", row.get("serialization_sha256", "")
                )
                or not re.fullmatch(
                    r"[0-9a-f]{64}", row.get("terminal_state_sha256", "")
                )
            ):
                fail(f"Stage-C resource repetition differs: {cell['cell']}")
            terminal_hashes.add(row["terminal_state_sha256"])
            for timing_name in (
                "decode", "complete_trace_check", "serialization"
            ):
                timing = row.get(timing_name, {})
                if (
                    timing.get("seconds", 0.0) <= 0.0
                    or timing.get("allocated_bytes", 0) <= 0
                    or timing.get("gc_seconds", -1.0) < 0.0
                ):
                    fail(
                        f"Stage-C resource timing differs: "
                        f"{cell['cell']}/{timing_name}"
                    )
        if len(terminal_hashes) != 1:
            fail(f"Stage-C terminal state changed: {cell['cell']}")

    local_stage_c_text = local_stage_c_test.read_text(encoding="utf-8")
    for required in (
        '"candidate recomputes J_C and the state-dependent action"',
        '"exact-zero generic path equals a direct fixed-diagonal reference"',
        '"valid-codeword sign covariance through every state and trial"',
        '"complete trace integrity, replay, and no syndrome early stop"',
        '"complete trace integrity fails closed on mutated records"',
        '"complete trace validator capability boundary"',
        '"independent dense matrix reproduces complete candidate paths"',
        '"nondegenerate path activates recipient-excluded edge state"',
        '"fixed-diagonal projected-gradient diagnostic distinguishes stalls"',
        "trial.projected_state_sha256 == row.state_after_sha256",
        "transition.first_parity_valid_update == 16",
        "length(broken_traces) == 35",
        "bypassed.theta0",
        "transmitted_bits=BitVector",
        "calls[] == 0",
    ):
        if required not in local_stage_c_text:
            fail(f"local Stage-C source test lacks marker: {required}")

    direction_text = direction_kernel.read_text(encoding="utf-8")
    direction_forbidden = {
        r"\b(?:include|open|read|write|rand)\s*\(": "I/O or randomness",
        r"\b(?:calculate_pass|generate_awgn|exact_recurrence|sum_product)\b":
            "case generation or exact recurrence",
        r"\b(?:decoder_update|hard_decision|readout|line_search|projected_step)\b":
            "decoder state operation",
    }
    for pattern, label in direction_forbidden.items():
        if re.search(pattern, direction_text):
            fail(f"forbidden operation entered per-origin direction kernel: {label}")
    for required in (
        "evaluate_direction_origin",
        "stage-b-direction-origin-v2",
        "exact_zero_lower_endpoint_bit_exact=true",
        "teacher_direction=teacher64",
        "local_candidate_gate_passed=",
    ):
        if required not in direction_text:
            fail(f"per-origin direction kernel lacks interface marker: {required}")

    population_sources = {
        "retained population summary": population_summary.read_text(
            encoding="utf-8"
        ),
        "target-specific gates": target_specific_gates.read_text(
            encoding="utf-8"
        ),
        "origin-row adapter": origin_row_adapter.read_text(encoding="utf-8"),
    }
    pure_population_forbidden = {
        r"\b(?:include|open|read|write|run|pipeline|rand|randn)\s*\(":
            "I/O, process launch, or randomness",
        r"\b(?:exact_recurrence|sum_product|calculate_pass|frame_provider)\b":
            "case access or exact recurrence",
        r"\b(?:decoder_update|hard_decision|readout|line_search|projected_step)\s*\(":
            "decoder state operation",
    }
    for label, text in population_sources.items():
        for pattern, capability in pure_population_forbidden.items():
            if re.search(pattern, text, re.I):
                fail(f"forbidden operation entered {label}: {capability}")
    for required in (
        "module RQ2RetainedDirectionPopulationSummary",
        "function summarize_channel",
        "RETAINED_CONTRACT_SHA256",
        "RETAINED_SLICE_SHA256",
        "already-materialized",
    ):
        if required not in population_sources["retained population summary"]:
            fail(f"retained population summary lacks marker: {required}")
    for required in (
        "module RQ2StageBTargetSpecificGates",
        "evaluate_target_specific_origin",
        "reduce_target_specific_level",
        "level_target_specific_gate_passed",
    ):
        if required not in population_sources["target-specific gates"]:
            fail(f"target-specific gates lack marker: {required}")
    for required in (
        "module RQ2StageBOriginRowAdapter",
        "prepare_origin_row",
        "_prove_unique_pairing",
        "threshold_projection_mismatch",
        "denominator_mismatch",
        "level_combined_gate_passed",
    ):
        if required not in population_sources["origin-row adapter"]:
            fail(f"origin-row adapter lacks marker: {required}")

    fixture_text = fixture.read_text(encoding="utf-8")
    for required in (
        'schema_version = "rq2-two-hop-positive-metric-001/authoritative-jc-fixture-v2"',
        'classification = "deterministic synthetic arithmetic fixture; no scientific input"',
        'input_corpus_sha256 = "8812d5f3e074beddaa925d21131622a3fdf485f053eb3eca1ee073f131d55432"',
        "case_count = 40",
        "graph_n = 8",
        "edge_count = 24",
        "check_degrees = [2, 3, 4, 5, 6, 4]",
        "variable_degrees = [4, 3, 3, 3, 3, 3, 2, 3]",
        'registered_jc_source_sha256 = "000371f8b403e426c4757e691e10a70a0b5222376e879f83577b77b82c838d5c"',
        'registered_fixed_diagonal_source_sha256 = "f2f92ca7f06264b079785534cf15c1ddf5f1e9985f384879b19244b2368204bb"',
        f'generator_source_sha256 = "{expected_fixture_generator_sha}"',
        f'production_jc_source_sha256 = "{expected_objective_source_sha}"',
    ):
        if required not in fixture_text:
            fail(f"frozen authoritative fixture lacks: {required}")
    if fixture_text.count("[[cases]]") != 40:
        fail("frozen authoritative fixture case count differs")
    state_bits = set(re.findall(
        r'^state_bits = \[([^\n]+)\]', fixture_text, re.M
    ))
    state_bits_text = "".join(state_bits)
    llr_bits = set(re.findall(
        r'^llr_bits = \[([^\n]+)\]', fixture_text, re.M
    ))
    llr_bits_text = "".join(llr_bits)
    for required in (
        "0000000000000000", "8000000000000000",
        "3ff0000000000000", "bff0000000000000",
    ):
        if required not in state_bits_text:
            fail(f"frozen fixture lacks edge-state boundary bits: {required}")
    for required in (
        "0000000000000000", "8000000000000000",
        "4034000000000000", "c034000000000000",
        "4039000000000000", "c039000000000000",
    ):
        if required not in llr_bits_text:
            fail(f"frozen fixture lacks LLR boundary bits: {required}")
    runner_text = local_test_runner.read_text(encoding="utf-8")
    if "generate_authoritative_jc_fixture" in runner_text:
        fail("ordinary test runner invokes the external-source fixture generator")
    project_text = project_file.read_text(encoding="utf-8")
    for dependency in ("SHA =", "Statistics =", "TOML ="):
        if dependency not in project_text:
            fail(f"two-hop project lacks portable dependency: {dependency}")

    card = (base / "reproduction_card.md").read_text(encoding="utf-8")
    for required in (
        expected_source_sha,
        expected_test_sha,
        expected_objective_source_sha,
        expected_direction_composition_sha,
        expected_local_composition_test_sha,
        expected_direction_kernel_sha,
        "000371f8b403e426c4757e691e10a70a0b5222376e879f83577b77b82c838d5c",
        "f2f92ca7f06264b079785534cf15c1ddf5f1e9985f384879b19244b2368204bb",
        "f9956feeb623f2a8a7734c8f12b76fb209052b0ddf9bb518149a627a4b60f9c3",
        "4f2d2977f9843ae52a3b72b42b2f08964aaddef2ef12fd6ff70d48af496070d0",
        "02e78caac59bcab28fabbee5396ed60db6fb7ddd22c784c2c94518b925aac6f0",
        "9f7a6e6c82363d43ed3db6e118fe70d2701d1f1a88503fd7f66dc3113eda4f60",
        expected_local_direction_test_sha,
        expected_fixture_sha,
        expected_fixture_generator_sha,
        expected_local_fixture_test_sha,
        expected_population_summary_sha,
        expected_target_specific_gates_sha,
        expected_origin_row_adapter_sha,
        expected_local_population_test_sha,
        expected_local_target_test_sha,
        expected_local_adapter_test_sha,
        expected_local_full_chain_test_sha,
        expected_stage_c_decoder_source_sha,
        expected_stage_c_trace_integrity_sha,
        expected_local_stage_c_test_sha,
        expected_stage_c_resource_benchmark_sha,
        expected_stage_c_resource_measurement_sha,
        "900ead13c4c5972bc1ed5cb99a6abf3a19a8f5d574f2ce4592007a8206c46bf0",
        "69,861,148 bytes",
        "11,763,554 bytes",
        "not a registered wall budget or decoder result",
        "8812d5f3e074beddaa925d21131622a3fdf485f053eb3eca1ee073f131d55432",
        "a96aa44aadf183d48b8db8aa5a9250b0f25552dcd61b37e6aaadd438f9be3f86",
        "951be06490d6c215e05c0e7ac698ffa5b1cdb806c27207dfcde34d658c283b1f",
        "synthetic-only decoder-source seam",
        "not a governance seal",
        "no fresh input",
        "caller-supplied comparison direction",
        "does not create or validate",
        "pairing, common thresholds, and equal denominators",
        "fabricated rows",
        "3,396 assertions",
        "independent dense complete-candidate-path",
        "projection/action compatibility diagnosis",
        "no syndrome early stop",
        "registered decoder-anchor result",
    ):
        if required not in card:
            fail(f"two-hop reproduction card lacks boundary: {required}")

    evidence = (base / "evidence/retained_stage_a.toml").read_text(
        encoding="utf-8"
    )
    for required in (
        'governance_seal = false',
        'fresh_inputs_opened = false',
        'fresh_direction_screen_launched = false',
        'candidate_decoder_run = false',
        'values = [0.0, -0.098969711158939794, -0.19129556359240465, -0.70584476358886339, -0.0036899816577923542]',
        'scientific_sha256 = "b14d0afb76235ef43d524c3a93c56c2d064ce40db69666cc57314ecc1c3f52c5"',
    ):
        if required not in evidence:
            fail(f"two-hop retained provenance lacks: {required}")

    tests = historical_test.read_text(encoding="utf-8")
    for required in (
        '"all coefficient patterns and exact-zero lower endpoint"',
        '"sparse action agrees with explicit test-only matrices"',
        '"positivity, descent, and registered condition bounds"',
        '"valid-codeword sign covariance"',
    ):
        if required not in tests:
            fail(f"historical synthetic suite lacks: {required}")
    finite_difference = local_finite_difference_test.read_text(encoding="utf-8")
    if "finite-difference action" not in finite_difference:
        fail("local finite-difference action test is absent")
    for required in (
        "synthetic J_C partial derivatives compose with the metric action",
        "five_point_testlocal_derivative",
        "reinterpret(UInt64, objective.partial_derivatives)",
    ):
        if required not in finite_difference:
            fail(f"local J_C composition gate lacks: {required}")

    local_composition_text = local_composition_test.read_text(encoding="utf-8")
    for required in (
        '"production J_C source identity and finite differences"',
        '"complete reference-free J_C-to-direction composition"',
        '"zero direction has no applicable descent test"',
        '"production composition capability boundary"',
        '"production composition fails closed"',
        ":reference_direction",
        '!occursin("teacher", lowercase(direction_source))',
        '!occursin("exact_recurrence", lowercase(direction_source))',
        '!occursin("sum_product", lowercase(direction_source))',
    ):
        if required not in local_composition_text:
            fail(f"local production-composition test lacks boundary: {required}")

    local_direction_text = local_direction_test.read_text(encoding="utf-8")
    for required in (
        '"teacher direction is diagnostic-only"',
        "opposed_teacher",
        "forbidden_outputs",
        "REGISTERED_METRIC_SOURCE_SHA256",
        "stage_b_direction_kernel.jl",
    ):
        if required not in local_direction_text:
            fail(f"local direction-kernel test lacks boundary: {required}")

    local_fixture_text = local_fixture_test.read_text(encoding="utf-8")
    for required in (
        '"durable authoritative J_C fixture provenance"',
        '"portable 40-case authoritative J_C arithmetic"',
        '"authoritative fixture generator is excluded from inference"',
        "input_corpus_sha256",
        "positive_zero_llr_witnessed",
        "untied_incident_state_witnessed",
    ):
        if required not in local_fixture_text:
            fail(f"portable authoritative fixture test lacks: {required}")
    local_population_text = local_population_test.read_text(encoding="utf-8")
    for required in (
        '"retained population arithmetic and exact-zero classes"',
        '"each population gate remains separately observable"',
        '"undefined angle statistics fail closed"',
        '"population seam source identity and capability boundary"',
        "already-materialized",
    ):
        if required not in local_population_text:
            fail(f"retained population-summary test lacks: {required}")
    local_target_text = local_target_test.read_text(encoding="utf-8")
    for required in (
        '"pure target-specific source boundary"',
        '"one condition failure has an exact denominator"',
        '"one exact-zero bit-identity failure has an exact denominator"',
    ):
        if required not in local_target_text:
            fail(f"target-specific gate test lacks: {required}")
    local_adapter_text = local_adapter_test.read_text(encoding="utf-8")
    for required in (
        '"actual retained and target reducers combine only after pairing proof"',
        '"the two gate families remain separately visible"',
        '"duplicate upstream pairing fails before either reducer"',
        ':invalid_angle_class',
        ':nonfinite_number',
    ):
        if required not in local_adapter_text:
            fail(f"origin-row adapter test lacks: {required}")
    local_full_chain_text = local_full_chain_test.read_text(encoding="utf-8")
    for required in (
        "module FullSyntheticPopulationChainTests",
        '"earlier supplied-arithmetic diagnostic remains distinct"',
        '"unchanged J_C through the fail-closed population gate"',
        "0.9935439809818444",
        "0.6852959854888271",
        "!level.generic_direction_screen_passed",
        "level.target_specific_level_passed",
        "!level.level_combined_gate_passed",
        '!occursin("teacher_direction", production_source)',
    ):
        if required not in local_full_chain_text:
            fail(f"full synthetic population-chain test lacks: {required}")
    if "/home/gabiel/Documents/GitHub/sp_gd_admm" in local_full_chain_text:
        fail("full synthetic population-chain test depends on historical checkout")

    validation = (base / "VALIDATION.toml").read_text(encoding="utf-8")
    if 'status = "pass"' not in validation:
        fail("two-hop extraction validation is not marked pass")
    if ('classification = "source-only reproduction with dormant synthetic '
            'decoder and resource measurement; no fresh science"' not in validation):
        fail("two-hop validation claim boundary is missing")
    for required in (
        "total_assertions = 5636",
        f'project_toml_sha256 = "{expected_project_sha}"',
        "source_and_action_assertions = 1202",
        "prior_assertions = 1098",
        "production_inference_seam_assertions = 104",
        "portable_fixture_assertions = 692",
        "portable_fixture_provenance_assertions = 25",
        "portable_fixture_arithmetic_assertions = 661",
        "portable_fixture_generator_boundary_assertions = 6",
        "population_seam_assertions = 262",
        "retained_population_summary_assertions = 98",
        "target_specific_gate_assertions = 112",
        "origin_adapter_integration_assertions = 52",
        "full_synthetic_population_chain_assertions = 84",
        "prior_supplied_arithmetic_diagnostic_assertions = 7",
        "production_full_synthetic_chain_assertions = 77",
        "local_jc_composition_assertions = 21",
        "adapted_direction_kernel_assertions = 102",
        "reference_direction_boundary_assertions = 36",
        "production_jc_source_assertions = 20",
        "production_jc_direction_composition_assertions = 33",
        "zero_direction_descent_semantics_assertions = 6",
        "production_capability_boundary_assertions = 31",
        "production_composition_failure_assertions = 14",
        "stage_c_decoder_source_assertions = 3396",
        "stage_c_protocol_assertions = 13",
        "stage_c_initialization_and_readout_assertions = 12",
        "stage_c_projected_armijo_assertions = 18",
        "stage_c_current_state_recomputation_assertions = 642",
        "stage_c_zero_control_assertions = 178",
        "stage_c_dense_candidate_path_assertions = 1533",
        "stage_c_nondegenerate_activation_assertions = 6",
        "stage_c_projection_compatibility_assertions = 12",
        "stage_c_sign_covariance_assertions = 853",
        "stage_c_trace_integrity_and_replay_assertions = 33",
        "stage_c_mutated_trace_failure_assertions = 36",
        "stage_c_trace_validator_boundary_assertions = 22",
        "stage_c_boundary_assertions = 38",
        f'local_source_test_sha256 = "{expected_local_finite_difference_test_sha}"',
        'registered_jc_source_sha256 = "000371f8b403e426c4757e691e10a70a0b5222376e879f83577b77b82c838d5c"',
        'registered_jc_source_path = "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-common-coordinate-state-update-20261104/experiments/rq2_graph_factorized_energy_001/graph_factorized_energy.jl"',
        'registered_fixed_diagonal_source_sha256 = "f2f92ca7f06264b079785534cf15c1ddf5f1e9985f384879b19244b2368204bb"',
        'registered_edge_metric_source_sha256 = "f9956feeb623f2a8a7734c8f12b76fb209052b0ddf9bb518149a627a4b60f9c3"',
        'registered_scalar_curvature_source_sha256 = "4f2d2977f9843ae52a3b72b42b2f08964aaddef2ef12fd6ff70d48af496070d0"',
        'historical_evaluator_sha256 = "02e78caac59bcab28fabbee5396ed60db6fb7ddd22c784c2c94518b925aac6f0"',
        'classification = "earlier read-only synthetic corroboration; not the frozen portable corpus"',
        "cases_passed = 40",
        "cases_total = 40",
        "objective_value_bit_exact = true",
        "edge_partial_derivatives_bit_exact = true",
        "scalar_partial_derivatives_bit_exact = true",
        "mean_state_bit_exact = true",
        "objective_terms_bit_exact = true",
        "portable_gate = false",
        f'production_jc_source_sha256 = "{expected_objective_source_sha}"',
        f'production_jc_direction_sha256 = "{expected_direction_composition_sha}"',
        f'production_jc_direction_test_sha256 = "{expected_local_composition_test_sha}"',
        f'stage_c_decoder_source_sha256 = "{expected_stage_c_decoder_source_sha}"',
        f'stage_c_trace_integrity_sha256 = "{expected_stage_c_trace_integrity_sha}"',
        f'stage_c_decoder_source_test_sha256 = "{expected_local_stage_c_test_sha}"',
        f'stage_c_resource_benchmark_sha256 = "{expected_stage_c_resource_benchmark_sha}"',
        f'stage_c_resource_measurement_sha256 = "{expected_stage_c_resource_measurement_sha}"',
        f'direction_kernel_sha256 = "{expected_direction_kernel_sha}"',
        f'local_direction_kernel_test_sha256 = "{expected_local_direction_test_sha}"',
        f'authoritative_fixture_sha256 = "{expected_fixture_sha}"',
        f'authoritative_fixture_generator_sha256 = "{expected_fixture_generator_sha}"',
        f'authoritative_fixture_test_sha256 = "{expected_local_fixture_test_sha}"',
        f'retained_population_summary_sha256 = "{expected_population_summary_sha}"',
        f'target_specific_gates_sha256 = "{expected_target_specific_gates_sha}"',
        f'origin_row_adapter_sha256 = "{expected_origin_row_adapter_sha}"',
        f'local_population_summary_test_sha256 = "{expected_local_population_test_sha}"',
        f'local_target_specific_gates_test_sha256 = "{expected_local_target_test_sha}"',
        f'local_origin_row_adapter_test_sha256 = "{expected_local_adapter_test_sha}"',
        f'local_full_synthetic_population_chain_test_sha256 = "{expected_local_full_chain_test_sha}"',
        f'local_test_runner_sha256 = "{expected_local_test_runner_sha}"',
        'input_corpus_sha256 = "8812d5f3e074beddaa925d21131622a3fdf485f053eb3eca1ee073f131d55432"',
        'corpus_id = "rq2-two-hop-positive-metric-001/portable-jc-corpus-40-v2"',
        "fixed_diagonal_bit_exact = true",
        "ordinary_suite_requires_historical_sources = false",
        "generator_requires_historical_sources = true",
        "unique_pairing_proved_before_reduction = true",
        "common_thresholds_required = true",
        "equal_denominators_required = true",
        "combined_gate_exercised_on_fabricated_rows = true",
        "registered_population_consumed = false",
        "actual_stage_b_gate_passed = false",
        "teacher_access_added_to_candidate_inference = false",
        "registered_jc_fixture_bit_identity_checked = true",
        "direction_kernel_source_bit_identity_checked = true",
        "caller_supplied_reference_is_diagnostic_only = true",
        "production_inference_uses_caller_reference_direction = false",
        "production_inference_advances_state = false",
        "production_inference_capability_boundary_checked = true",
        "production_zero_direction_semantics_checked = true",
        "stage_c_source_reuses_hash_pinned_metric_and_objective = true",
        "stage_c_candidate_requires_nonzero_two_hop_coefficient = true",
        "stage_c_zero_control_uses_generic_matrix_action = true",
        "stage_c_arbitrary_direction_public_hook = false",
        "stage_c_syndrome_early_stop = false",
        "stage_c_complete_trace_integrity_checked = true",
        "stage_c_exact_trace_record_schema_and_types_checked = true",
        "stage_c_same_input_replay_bit_exact = true",
        "stage_c_accepted_backtrack_checked = true",
        "stage_c_parity_valid_transition_continues = true",
        "stage_c_mutated_trace_failures_checked = 35",
        "stage_c_full_condition_limit_integration_checked = true",
        "stage_c_coefficient_admissibility_rechecked = true",
        "stage_c_independent_dense_candidate_path_checked = true",
        "stage_c_dense_reference_bypasses_production_pattern_and_action = true",
        "stage_c_nondegenerate_recipient_excluded_edge_state_checked = true",
        "stage_c_projection_compatibility_diagnostic_checked = true",
        "stage_c_candidate_late_stall_box_stationary = false",
        "stage_c_lower_endpoint_late_stall_box_stationary = true",
        "candidate_decoder_scientific_run = false",
        "synthetic_decoder_source_run = true",
        "synthetic_state_advanced = true",
        "scientific_state_advanced = false",
        "stage_b_direction_screen_launched = false",
        "actual_population_screen_passed = false",
        "synthetic_combined_gate_exercised = true",
        "full_synthetic_target_specific_gate_passed = true",
        "full_synthetic_generic_direction_gate_passed = false",
        "full_synthetic_combined_gate_passed = false",
        'classification = "pure repeated-row interface validation; no population science"',
        "distinct_diagnostics = 1",
        "synthetic_frame_count = 1",
        "distinct_input_identities = 1",
        "production_objective_is_unchanged_jc = true",
        "production_chain_improvement_degrees = 0.6852959854888271",
        "paired_improvement_threshold_degrees = 15.0",
        "all_other_generic_direction_gates_passed = true",
        "comparison_direction_is_independent_bp_evidence = false",
        "population_diversity_established = false",
        "scientific_input_loaded = false",
        "state_advanced = false",
        "exact_sum_product_called = false",
        '[stage_c_decoder_source]',
        'classification = "dormant synthetic-only projected-gradient decoder source; no scientific execution"',
        "assertions = 3396",
        "unchanged_jc_recomputed_each_update = true",
        "state_dependent_matrix_recomputed_each_update = true",
        "projected_armijo_uses_projected_displacement = true",
        "trial_count_maximum = 13",
        "attempted_update_cap = 30",
        "syndrome_early_stop = false",
        "zero_control_complete_path_bit_exact = true",
        "valid_codeword_sign_covariance_checked = true",
        "complete_trace_integrity_checked = true",
        "exact_trace_record_schema_and_types_checked = true",
        "same_input_replay_bit_exact = true",
        "accepted_backtrack_checked = true",
        "parity_valid_transition_continues_to_cap = true",
        "mutated_trace_failures_checked = 35",
        "full_condition_limit_integration_checked = true",
        "coefficient_admissibility_rechecked = true",
        "independent_dense_candidate_path_checked = true",
        "dense_reference_bypasses_production_pattern_and_action = true",
        "nondegenerate_recipient_excluded_edge_state_checked = true",
        "projection_compatibility_diagnostic_checked = true",
        "candidate_late_stall_box_stationary = false",
        "lower_endpoint_late_stall_box_stationary = true",
        "candidate_accepts_reference_or_truth = false",
        "arbitrary_direction_public_hook = false",
        "registered_frames_opened = false",
        "decoder_anchor_result = false",
        "approaches_bp_result = false",
        '[stage_c_complete_trace_resource_measurement]',
        'classification = "production-size synthetic engineering measurement; no scientific evidence or registered wall budget"',
        "update_cap_trace_summary_bytes = 69861148",
        "immediate_stall_trace_summary_bytes = 11763554",
        "maximum_measured_child_peak_rss_bytes = 899579904",
        "serialization_is_size_proxy_only = true",
        "peak_rss_cap_sealed = false",
        "production_trace_format_sealed = false",
    ):
        if required not in validation:
            fail(f"two-hop composition validation lacks: {required}")
    return 106


def verify_research_record() -> int:
    path = ROOT / "research/active_goal.md"
    text = path.read_text(encoding="utf-8")
    for required in (
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION",
        "used by the\n  first collision audit. It does not authorize a retry",
        "registered 24-case 6-dB block followed by\n"
        "the registered 24-case 1.5-dB block",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-001",
        "46d38209d89a6bd0a51f1008fa68cbde26033ecf8954f3b2750c5e5e980c510f",
        "31 collision records in six\n  groups",
        "6,437,576 KiB",
        "2,097,152-KiB cap",
        "coordinator's lifetime peak RSS",
        "largest lifetime peak RSS reported\n  for any waited child",
        "not a measured simultaneous process-tree peak",
        "neither component nor\n  per-helper RSS was retained",
        "The registered cap comparison remains failed.",
        "v11 source. Its validator passes 11/11 checks and its unit suite passes 70/70\n  tests",
        "bounded streaming parsing for `.json` files",
        "coordinator and waited-child lifetime peaks separately from per-helper\n  peaks; each helper peak is stabilized after parsing and response\n  serialization",
        "post-wait child observation is conservative through\n  process exit",
        "not claimed to use the streaming parser",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-002",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002",
        "7a796e142cd263e36c994854ea377841c6cddb262a1534690902d7c4b0681d66",
        "d3e8acb2b91aeb79788fb55d1134a4e653ee091cf2ec67a580fe4d69545d77c2",
        "Its live permissions are all false.",
        "Activation-002 was materialized and consumed by an\ninterrupted non-scientific scan; no result was published.",
        "64f5ce0aa896cff5570e88ad1f89204bdb22dd9c54112c4d2bc35a8dad7caa20",
        "25f5cc5f8c696ca478f7aaf70d65a87656e3f2a6a424da2ca0e77da080defd08",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002-PATH-CORRECTION-RETRY-001",
        "5a43ca345bd0e1083e9f35faf822377a4207b5b2f4e033b1bf5f480d1abcdc31",
        "415bfd91bfe4e812b3fe467eff8cc34375327552b8642fb0b7c0418cef756a94",
        "10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff",
        "one mutable-ledger self-reference and a recorded\ncoordinator field of 6,140,592 KiB",
        "fresh child reported 54,668 KiB",
        "preserved the pre-exec 269,952-KiB peak",
        "formal result remains failed",
        "Waited-child\nand maximum helper peaks were 269,780 and 252,660 KiB",
        "helper telemetry was\ncomplete at 32/32",
        "No manifest was created, no scientific input opened, and no\ndownstream step ran.",
        "one-sided recovery-count margin",
        "same registered cases; for each paired case",
        "parity-check matrix, transmitted word, noise realization, and vector of\nchannel LLRs are held fixed",
        "C_s >= B_s - 30",
        "quotient represented by the mean coordinates",
        "min_{u in boundary(W)} J(u) > J(u_*)",
        "no competing\n  frame reservation or scientific frame consumption",
        "Direct application of the exact sum-product recurrence is a gradient step.",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-COEFFICIENT-SEAL-002",
        "06944b797b96c93ec136c41949d708eb1613caba0387871b256003155950803b",
        "a71ebef92cd1a998be9fda33ba2fadbda0680aa9da140b9941166a75c2db38c5",
        "173a68f41e53d4e7b16a40d27271245ae9c83b0b5f4858c7f15d439f25fb3078",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-WALL-CONTRACT-AMENDMENT-001",
        "c76ba22c29bea8d0e25e31cf74057b1649347e44fc56d9f890368e9dcc372a63",
        "actual complete-valid v11 range artifact to be pinned only\n  after a later complete-valid audit succeeds",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RETAINED-WALL-BENCHMARK-001",
        "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-EXECUTION-001",
        "The approval remains\n  inoperative until",
        "No retained-wall run, fresh input, or Stage-B science has\nbegun.",
        "registered Stage-B and\nStage-C cases remain unopened",
        "RQ2-GD-OFFSET-SPLIT-001",
        "a42793a4e94485e3f91873c1bb1cdce943879447a982555275ccf13483445125",
        "RQ2-GD-PARITY-ASSIGNMENT-REFRESH-001",
        "2556c01f170d0e3f42bdcca831df47278270ec13628e84a1541a7976668c5595",
        "preregistered equivalence-within-0.05 criterion did\nnot pass",
        "passed 5,636 synthetic assertions",
        "3,396 for the dormant Stage-C decoder source",
        "first parity-valid syndrome remains telemetry",
        "caller-supplied reference direction",
        "no registered Stage-B population was\n  consumed",
        "24-edge synthetic graph",
        "bundle verifier passed 166",
        "operational-source inventory validator passed 26 files",
        "five Python tests and 240 Julia assertions",
        "34 provider",
        "actual 26-member source closure",
        "all 245 checks passing",
        "401aafec73839021d3f3c9dd3708f0f88b5ca614ea045b9bc736e84f3358abb9",
        "bit-exact golden-vector",
        "self-consistently hashed but incorrect supplied gradient",
    ):
        if required not in text:
            fail(f"active research record lacks boundary: {required}")
    for stale in (
        "not a closed scientific branch",
        "remain unanswered",
    ):
        if stale in text:
            fail(f"stale unresolved offset-split claim remains: {stale}")
    for stale in STALE_OPERATIONAL_SOURCE_MARKERS:
        if stale in text:
            fail(f"stale operational-source claim remains: {stale}")
    return 10


def verify_reconciled_reader_claims() -> int:
    records = {
        "README.md": (
            "RQ2-GD-OFFSET-SPLIT-001",
            "RQ2-GD-PARITY-ASSIGNMENT-REFRESH-001",
            "163/200 transmitted words versus 107/200",
            "projection interval recovered 106/200",
            "174/200",
            "165/200",
            "61/200",
            "70/200",
            "equivalence gate did not pass",
            "not that the offsets are BP messages",
            "coordinator's lifetime peak RSS",
            "largest lifetime peak RSS reported for\nany waited child",
            "Those peaks need not be simultaneous",
            "The registered cap comparison remains failed.",
            "7a796e142cd263e36c994854ea377841c6cddb262a1534690902d7c4b0681d66",
            "d3e8acb2b91aeb79788fb55d1134a4e653ee091cf2ec67a580fe4d69545d77c2",
            "was approved, materialized, and consumed on 7 November 2026",
            "filesystem root 5 of 17",
            "PATH-CORRECTION-RETRY-001",
            "5a43ca345bd0e1083e9f35faf822377a4207b5b2f4e033b1bf5f480d1abcdc31",
            "415bfd91bfe4e812b3fe467eff8cc34375327552b8642fb0b7c0418cef756a94",
            "10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff",
            "coordinator field of 6,140,592 KiB against the unchanged 2,097,152-KiB cap",
            "fresh child reported 54,668 KiB",
            "scanner allocated 5.86 GiB",
            "fresh pinned worker",
            "No manifest was\ncreated, no scientific input opened, and no downstream step ran.",
            "same registered 200 cases",
            "C_s >= B_s - 30",
            "06944b797b96c93ec136c41949d708eb1613caba0387871b256003155950803b",
            "a71ebef92cd1a998be9fda33ba2fadbda0680aa9da140b9941166a75c2db38c5",
            "173a68f41e53d4e7b16a40d27271245ae9c83b0b5f4858c7f15d439f25fb3078",
            "prospectively\napproved, but remain inoperative",
            "The goal is active;",
            "no retained-wall run, fresh input, or Stage-B science has begun",
        ),
        "explainers/the_path_so_far.html": (
            "RQ2-GD-OFFSET-SPLIT-001",
            "RQ2-GD-PARITY-ASSIGNMENT-REFRESH-001",
            "163/200 transmitted words versus 107/200",
            "Changing only the projection interval gives 106/200",
            "174/200",
            "165/200",
            "61/200",
            "70/200",
            "equivalence gate does not pass",
            "neither make the offsets BP messages",
            "The grid separately depicts the locked assigned-and-frozen attribution arm: 167 recovered",
            "locked attribution: assigned/frozen 167 / 200",
            "n<167?'w2':'w3'",
            "+60 recovered",
            "33 unresolved",
            "Its 26-file inventory validator, five Python tests, and 240 Julia assertions pass.",
            "12 coefficient-seal-loader, 34 provider, 165 operational-runtime, and 29 retained-callback assertions",
            "bit-exact golden vector",
            "the candidate condition values, and the local gate unchanged",
            "calculates the partial derivatives and fixed diagonal locally",
            "pinned Python 3.11 suite passes 76/76 tests",
            "all 245 source checks passing",
            "401aafec73839021d3f3c9dd3708f0f88b5ca614ea045b9bc736e84f3358abb9",
            "No persistent final source-validation bundle was published",
            "46d38209d89a6bd0a51f1008fa68cbde26033ecf8954f3b2750c5e5e980c510f",
            "31 collision records in six groups",
            "6,437,576 KiB",
            "coordinator's lifetime peak RSS",
            "not a measured simultaneous process-tree peak",
            "retained neither component nor per-helper RSS",
            "The registered cap comparison remains failed.",
            "prospective v11 preparation passes 11/11 source/provenance checks and 70/70 synthetic tests",
            "closes the result to 183 fields",
            "27 reviewed historical/test non-registration records",
            "bounded streaming parsing for <code>.json</code> files",
            "coordinator and waited-child lifetime peaks separately from per-helper peaks; each helper peak is stabilized after parsing and response serialization, while the post-wait child observation is conservative through process exit",
            "is approved and materialized at registration identity",
            "7a796e142cd263e36c994854ea377841c6cddb262a1534690902d7c4b0681d66",
            "d3e8acb2b91aeb79788fb55d1134a4e653ee091cf2ec67a580fe4d69545d77c2",
            "Activation-002 was materialized and consumed by the interrupted v11 scan",
            "filesystem root 5 of 17",
            "PATH-CORRECTION-RETRY-001",
            "10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff",
            "one documentary self-collision and a recorded coordinator field above the RSS cap",
            "a recorded coordinator field was 6,140,592 KiB against the unchanged 2,097,152-KiB cap",
            "inherited a pre-existing process-lifetime peak across <code>execve</code>",
            "not evidence that the scanner allocated 5.86 GiB",
            "same registered 200 cases",
            "C_s &gt;= B_s - 30",
            "quotient represented by the mean coordinates",
            "06944b797b96c93ec136c41949d708eb1613caba0387871b256003155950803b",
            "a71ebef92cd1a998be9fda33ba2fadbda0680aa9da140b9941166a75c2db38c5",
            "173a68f41e53d4e7b16a40d27271245ae9c83b0b5f4858c7f15d439f25fb3078",
            "prospectively approved but remain inoperative",
            "The goal is active; no retained-wall run, fresh input, or Stage-B science has begun.",
            "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-001",
            "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-002",
            "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002",
            "5,636 synthetic assertions",
            "3,396 checks of the dormant decoder source",
            "not box-stationary",
            "first parity-valid syndrome is telemetry only",
            "registered decoder anchor",
            "2,156 transitions: recurrence displacement zero; candidate direction nonzero",
            "the direct recurrence displacement was zero while the J<sub>C</sub> gradient-based candidate direction remained nonzero",
        ),
        "explainers/the_path_so_far_tree.html": (
            "RQ2-GD-OFFSET-SPLIT-001",
            "RQ2-GD-PARITY-ASSIGNMENT-REFRESH-001",
            "163/200",
            "107/200",
            "106/200",
            "174/200",
            "165/200",
            "61/200",
            "70/200",
            "cannot be called equivalent",
            "not BP-message, BP-equivalence, or low-SNR claims",
            "the operational preparation passes a 26-file inventory, five Python tests, and 240 Julia assertions",
            "12 coefficient-seal-loader, 34 provider, 165 operational-runtime, and 29 retained-callback assertions",
            "bit-exact golden vector",
            "execution-envelope validator passes and its pinned Python 3.11 suite passes 76/76 tests",
            "partial derivatives and fixed diagonal locally",
            "all 245 source checks",
            "401aafec73839021d3f3c9dd3708f0f88b5ca614ea045b9bc736e84f3358abb9",
            "No persistent final source-validation bundle was published",
            "46d38209d89a6bd0a51f1008fa68cbde26033ecf8954f3b2750c5e5e980c510f",
            "31 lexical/parser collision records in six groups",
            "6,437,576 KiB",
            "coordinator's lifetime peak RSS",
            "not a measured simultaneous process-tree peak",
            "neither component nor per-helper RSS was retained",
            "The registered cap comparison remains failed.",
            "prospective v11 preparation passes 11/11 source/provenance checks and 70/70 synthetic tests",
            "closes the result to 183 fields",
            "27 reviewed historical/test non-registration records",
            "bounded streaming parsing for <code>.json</code> files",
            "coordinator and waited-child lifetime peaks separately from per-helper peaks; each helper peak is stabilized after parsing and response serialization, while the post-wait child observation is conservative through process exit",
            "is approved and materialized at registration identity",
            "7a796e142cd263e36c994854ea377841c6cddb262a1534690902d7c4b0681d66",
            "d3e8acb2b91aeb79788fb55d1134a4e653ee091cf2ec67a580fe4d69545d77c2",
            "was materialized and consumed by the interrupted v11 scan",
            "filesystem root 5 of 17",
            "10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff",
            "one documentary self-collision and a recorded coordinator field above the RSS cap",
            "inherited a pre-existing process-lifetime peak across <code>execve</code>",
            "not evidence that the scanner allocated 5.86 GiB",
            "same registered 200 cases",
            "C_s &gt;= B_s - 30",
            "quotient represented by the mean coordinates",
            "06944b797b96c93ec136c41949d708eb1613caba0387871b256003155950803b",
            "a71ebef92cd1a998be9fda33ba2fadbda0680aa9da140b9941166a75c2db38c5",
            "173a68f41e53d4e7b16a40d27271245ae9c83b0b5f4858c7f15d439f25fb3078",
            "prospectively approved but remain inoperative",
            "The goal is active; no retained-wall run, fresh input, or Stage-B science has begun.",
            "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-001",
            "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-002",
            "RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002",
            "5,636 synthetic assertions",
            "3,396 dormant Stage-C decoder-source checks",
            "not box-stationary",
            "first parity-valid syndrome is telemetry only",
            "registered fresh Stage-B and Stage-C cases remain closed",
        ),
        "explainers/map_then_state/map_then_state.tex": (
            "RQ2-GD-OFFSET-SPLIT-001",
            "RQ2-GD-PARITY-ASSIGNMENT-REFRESH-001",
            r"\vbar{2.25}{-3.75}{163}",
            r"\vbar{0.85}{-3.75}{107}",
            r"\vbar{3.85}{-3.75}{106}",
            r"\vbar{8.30}{-3.75}{174}",
            r"\vbar{11.30}{-3.75}{165}",
            r"\vbar{9.70}{-3.75}{61}",
            r"\vbar{12.70}{-3.75}{70}",
            "equivalence gate does not pass",
            "not BP-message or low-SNR claims",
            "v10 audit: \\textbf{failed}",
            "v11 retry: \\textbf{failed}",
            "registered 24-case block",
            "The approved corrected v11 retry completed the repository scan",
            "one documentary self-collision",
            "coordinator field of 6{,}140{,}592 KiB versus the 2{,}097{,}152-KiB cap",
            "inherited a pre-existing process-lifetime peak across \\texttt{execve}",
            "quotient represented by the mean coordinates",
            "V2 seal $+$ amendment",
            "V11 result SHA-256 10618db4\\ldots a9f5ff",
            "Fresh route parser: 54{,}668 KiB",
            "threshold CSV: 80{,}024 KiB",
            "controlled pre-exec peak: 269{,}952 KiB",
            "no manifest, fresh input, or Stage-B science exists.",
            "with 2,156 cases where $F(\\mathbf z)-\\mathbf z=0$",
            "while the gradient-based candidate remains nonzero.",
        ),
    }
    texts: list[str] = []
    for relative, required_markers in records.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        texts.append(text)
        for marker in required_markers:
            if marker not in text:
                fail(f"reconciled reader claim missing from {relative}: {marker}")

    combined = "\n".join(texts)
    for stale in (
        "not a closed scientific branch",
        "remain unanswered",
        "2,156 transitions have a map displacement but a zero candidate direction",
        "2,156 updates had a nonzero recurrence displacement but a zero candidate direction",
    ):
        if stale in combined:
            fail(f"stale unresolved offset-split claim remains in explainer: {stale}")
    for stale in STALE_OPERATIONAL_SOURCE_MARKERS:
        if stale in combined:
            fail(f"stale operational-source claim remains in explainer: {stale}")
    return 5


def verify_structure() -> int:
    expected = {
        "the_path_so_far_tree.html",
        "the_path_so_far.html",
        "map_then_state",
    }
    actual = {path.name for path in (ROOT / "explainers").iterdir()}
    if actual != expected:
        fail(f"unexpected explainer entries: {sorted(actual ^ expected)}")

    implementation_dirs = sorted(
        path.name for path in (ROOT / "implementation").iterdir() if path.is_dir()
    )
    if implementation_dirs != ["compound_box_gd", "two_hop_metric_action"]:
        fail(f"unexpected implementation directories: {implementation_dirs}")

    pdf = ROOT / "explainers/map_then_state/map_then_state.pdf"
    if not pdf.read_bytes().startswith(b"%PDF-"):
        fail("map_then_state.pdf is not a PDF")
    if pdf.stat().st_size < 100_000:
        fail("map_then_state.pdf is unexpectedly small")

    tex = (ROOT / "explainers/map_then_state/map_then_state.tex").read_text(
        encoding="utf-8"
    )
    if "related native compound diagnostic" not in tex:
        fail("map_then_state.tex lacks the completed low-SNR diagnostic update")
    if "5{,}636 synthetic assertions" not in tex:
        fail("map_then_state.tex lacks the complete dormant-source validation update")
    if ("2{,}240 earlier source-and-interface assertions $+$ 3{,}396 dormant "
            "Stage-C assertions" not in tex):
        fail("map_then_state.tex lacks the current validation-count decomposition")

    for skill in (ROOT / ".agents/skills").glob("*/SKILL.md"):
        text = skill.read_text(encoding="utf-8")
        if not re.match(r"\A---\nname: [a-z0-9-]+\ndescription: .+\n---\n", text):
            fail(f"invalid skill frontmatter: {skill.relative_to(ROOT)}")
    return 7


def main() -> int:
    checks = verify_structure()
    checks += verify_html("explainers/the_path_so_far_tree.html")
    checks += verify_html("explainers/the_path_so_far.html")
    checks += verify_evidence()
    checks += verify_two_hop_metric_action()
    checks += verify_research_record()
    checks += verify_reconciled_reader_claims()
    print(f"bp-gd bundle verification passed: {checks} checks")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, OSError, ValueError) as error:
        print(f"verification failed: {error}", file=sys.stderr)
        sys.exit(1)
