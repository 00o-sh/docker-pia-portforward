# Test Coverage Analysis

## Executive Summary

**Current Test Coverage: 0%**

The codebase currently has **no unit or integration tests**. Testing is limited to static analysis:
- ShellCheck (shell script linting)
- hadolint (Dockerfile linting)
- Helm chart linting and templating

This analysis identifies critical gaps in test coverage and proposes a comprehensive testing strategy.

---

## Current State

### Existing Quality Controls
- ✅ ShellCheck static analysis on shell scripts
- ✅ Dockerfile linting with hadolint
- ✅ Helm chart validation and templating
- ❌ No unit tests
- ❌ No integration tests
- ❌ No functional tests
- ❌ No E2E tests

### Code Inventory
1. **entrypoint.sh** (74 lines)
   - Environment validation
   - Basic connectivity checks
   - Entry point orchestration

2. **port-forward-loop.sh** (428 lines) - **CRITICAL**
   - PIA authentication
   - Gateway detection (complex logic)
   - Port forwarding API integration
   - qBittorrent integration
   - Refresh loop with error handling

3. **Dockerfile** (37 lines)
   - Container image definition

4. **Helm Chart**
   - Kubernetes deployment manifests

---

## Critical Test Gaps

### 1. Gateway Detection Logic ⚠️ **HIGH PRIORITY**
**Location:** `port-forward-loop.sh:81-158`

**Why Critical:**
- Most complex logic in the codebase
- Multiple failure modes
- Critical for core functionality
- Difficult to debug in production

**Missing Tests:**
- ❌ Test default gateway detection from routing table
- ❌ Test common PIA IP probing (10.0.0.1, 10.2.0.1, etc.)
- ❌ Test routing table IP extraction and subnet gateway derivation
- ❌ Test candidate deduplication
- ❌ Test gateway connectivity verification (port 19999 check)
- ❌ Test manual `PIA_GATEWAY` override
- ❌ Test behavior when no gateway responds
- ❌ Test timeout handling for slow gateways
- ❌ Mock different network configurations (gluetun, router VPN, Multus)

**Recommended Tests:**
```bash
# Unit tests for gateway detection
test_default_gateway_detection()
test_common_pia_ip_detection()
test_routing_table_parsing()
test_gateway_connectivity_check()
test_manual_gateway_override()
test_no_gateway_found_error()
test_gateway_timeout_handling()

# Integration tests
test_gluetun_network_detection()
test_router_vpn_detection()
test_multus_network_detection()
```

---

### 2. PIA API Integration ⚠️ **HIGH PRIORITY**
**Location:** `port-forward-loop.sh:44-264`

**Why Critical:**
- External dependency (PIA API)
- Network failures common
- Authentication can fail
- JSON parsing errors possible

**Missing Tests:**
- ❌ Test successful token retrieval
- ❌ Test invalid credentials handling
- ❌ Test network timeout during authentication
- ❌ Test malformed JSON response handling
- ❌ Test missing token field in response
- ❌ Test port forward request success
- ❌ Test port forward API errors
- ❌ Test payload/signature extraction
- ❌ Test port binding success/failure
- ❌ Test signature file persistence

**Recommended Tests:**
```bash
# Mock PIA API responses
test_pia_token_success()
test_pia_token_invalid_credentials()
test_pia_token_network_failure()
test_pia_token_malformed_json()
test_port_forward_success()
test_port_forward_api_error()
test_port_forward_timeout()
test_port_bind_success()
test_port_bind_failure()
test_signature_persistence()
```

---

### 3. qBittorrent Integration ⚠️ **MEDIUM PRIORITY**
**Location:** `port-forward-loop.sh:266-318`

**Why Important:**
- Optional feature but widely used
- Authentication complexity
- Cookie management
- API changes can break integration

**Missing Tests:**
- ❌ Test qBittorrent login success
- ❌ Test invalid qBittorrent credentials
- ❌ Test qBittorrent unreachable
- ❌ Test port update success
- ❌ Test port update API failure
- ❌ Test cookie file creation and reuse
- ❌ Test behavior when qBittorrent not configured
- ❌ Test malformed qBittorrent API responses

**Recommended Tests:**
```bash
test_qb_login_success()
test_qb_login_invalid_credentials()
test_qb_login_unreachable()
test_qb_port_update_success()
test_qb_port_update_failure()
test_qb_cookie_management()
test_qb_integration_disabled()
test_qb_malformed_response()
```

---

### 4. Environment Variable Validation ⚠️ **MEDIUM PRIORITY**
**Location:** `entrypoint.sh:22-36`

**Why Important:**
- Prevents runtime failures
- User configuration errors common
- Default values need validation

**Missing Tests:**
- ❌ Test required variables present
- ❌ Test missing PIA_USER error
- ❌ Test missing PIA_PASS error
- ❌ Test default values applied correctly
- ❌ Test custom PORT_FILE path
- ❌ Test custom PORT_DATA_FILE path
- ❌ Test custom refresh interval
- ❌ Test invalid refresh interval values

**Recommended Tests:**
```bash
test_required_env_pia_user()
test_required_env_pia_pass()
test_missing_pia_user_exits()
test_missing_pia_pass_exits()
test_default_refresh_interval()
test_custom_refresh_interval()
test_default_port_file_path()
test_custom_port_file_path()
```

---

### 5. File Operations and Persistence ⚠️ **MEDIUM PRIORITY**
**Location:** `port-forward-loop.sh:320-339`

**Why Important:**
- Shared state with other containers
- File permissions matter (non-root user)
- JSON generation can fail
- Directory creation edge cases

**Missing Tests:**
- ❌ Test port file creation
- ❌ Test port file update
- ❌ Test port data JSON generation
- ❌ Test directory creation when missing
- ❌ Test file permissions (UID 1000)
- ❌ Test write failure handling
- ❌ Test concurrent file access
- ❌ Test payload/signature file handling

**Recommended Tests:**
```bash
test_port_file_creation()
test_port_file_update()
test_port_data_json_format()
test_directory_auto_creation()
test_file_permissions_nonroot()
test_write_permission_denied()
test_payload_signature_files()
```

---

### 6. Main Loop and Refresh Logic ⚠️ **LOW PRIORITY**
**Location:** `port-forward-loop.sh:342-427`

**Why Important:**
- Long-running process
- Retry logic on failures
- State management across cycles

**Missing Tests:**
- ❌ Test initial port forward flow
- ❌ Test successful refresh cycle
- ❌ Test refresh failure recovery
- ❌ Test token re-authentication on failure
- ❌ Test sleep interval timing
- ❌ Test graceful shutdown handling
- ❌ Test loop continues after transient errors

**Recommended Tests:**
```bash
test_initial_port_forward_success()
test_refresh_cycle_success()
test_refresh_failure_recovery()
test_token_reauth_on_failure()
test_refresh_interval_timing()
test_transient_error_recovery()
```

---

### 7. Error Handling and Edge Cases ⚠️ **MEDIUM PRIORITY**

**Missing Tests:**
- ❌ Test network disconnection during operation
- ❌ Test VPN reconnection handling
- ❌ Test DNS resolution failures
- ❌ Test curl timeout handling
- ❌ Test jq parsing errors
- ❌ Test empty/null API responses
- ❌ Test process signals (SIGTERM, SIGINT)
- ❌ Test race conditions in file writes

**Recommended Tests:**
```bash
test_network_disconnection()
test_vpn_reconnection()
test_dns_failure()
test_curl_timeout()
test_jq_parse_error()
test_empty_api_response()
test_sigterm_graceful_shutdown()
test_concurrent_file_access()
```

---

### 8. Container and Dockerfile ⚠️ **LOW PRIORITY**

**Missing Tests:**
- ❌ Test container builds successfully
- ❌ Test non-root user execution
- ❌ Test required packages installed
- ❌ Test /config directory permissions
- ❌ Test multi-arch builds (amd64, arm64)
- ❌ Test OCI compliance
- ❌ Test container startup time

**Recommended Tests:**
```bash
test_dockerfile_build()
test_nonroot_user_1000()
test_packages_installed()
test_config_directory_permissions()
test_multi_arch_builds()
test_container_startup()
```

---

### 9. Helm Chart ⚠️ **LOW PRIORITY**

**Current Coverage:**
- ✅ Chart linting
- ✅ Template rendering

**Missing Tests:**
- ❌ Test with various values.yaml configurations
- ❌ Test Multus network annotations
- ❌ Test PVC creation
- ❌ Test secret generation
- ❌ Test resource limits/requests
- ❌ Test security context settings
- ❌ Test with qBittorrent enabled/disabled

**Recommended Tests:**
```bash
test_chart_default_values()
test_chart_with_multus()
test_chart_with_qbittorrent()
test_chart_pvc_creation()
test_chart_secret_creation()
test_chart_security_context()
test_chart_resource_limits()
```

---

## Proposed Testing Strategy

### Phase 1: Foundation (High Priority)
**Goal:** Cover critical failure points

1. **Gateway Detection Tests**
   - Mock network environments
   - Test all detection methods
   - Validate error messages

2. **PIA API Tests**
   - Mock PIA API endpoints
   - Test all success/failure scenarios
   - Validate JSON parsing

3. **Environment Validation Tests**
   - Test all required variables
   - Test default values
   - Test invalid inputs

**Estimated Effort:** 2-3 days

---

### Phase 2: Integration (Medium Priority)
**Goal:** Test component interactions

1. **qBittorrent Integration Tests**
   - Mock qBittorrent API
   - Test full flow
   - Test error recovery

2. **File Operations Tests**
   - Test all file I/O
   - Test permissions
   - Test concurrent access

3. **E2E Smoke Tests**
   - Test in Docker container
   - Test with mock PIA API
   - Test file output

**Estimated Effort:** 2-3 days

---

### Phase 3: Reliability (Low Priority)
**Goal:** Improve long-term stability

1. **Main Loop Tests**
   - Test refresh cycles
   - Test error recovery
   - Test long-running behavior

2. **Container Tests**
   - Test Dockerfile
   - Test multi-arch
   - Test startup/shutdown

3. **Helm Chart Tests**
   - Test all configurations
   - Test upgrades
   - Test edge cases

**Estimated Effort:** 2-3 days

---

## Testing Framework Recommendations

### For Shell Scripts

**Option 1: BATS (Bash Automated Testing System)** ⭐ RECOMMENDED
- Purpose-built for shell script testing
- Simple syntax
- Good CI/CD integration
- Active community

```bash
# Example BATS test
@test "gateway detection finds default gateway" {
  export PIA_GATEWAY=""
  run detect_gateway
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Found PIA gateway" ]]
}
```

**Option 2: shUnit2**
- xUnit-style testing
- Mature and stable
- Less active development

**Option 3: shellspec**
- BDD-style testing
- Modern features
- Smaller community

---

### For Container/E2E Tests

**Option 1: Docker-based test suite**
- Use `docker-compose` for test environments
- Mock PIA API with simple HTTP server
- Test real container behavior

**Option 2: bats-mock or stub.sh**
- Mock external commands (curl, jq)
- Test without real network calls

---

### For Helm Charts

**Option 1: Helm unittest plugin** ⭐ RECOMMENDED
```yaml
# tests/deployment_test.yaml
suite: test deployment
templates:
  - deployment.yaml
tests:
  - it: should set correct image
    asserts:
      - equal:
          path: spec.template.spec.containers[0].image
          value: pia-portforward:latest
```

**Option 2: Terratest (Go)**
- More complex but powerful
- Can test actual K8s deployment

---

## Test Coverage Goals

### Short-term (1-2 weeks)
- ✅ 60% coverage on critical functions
- ✅ All gateway detection paths tested
- ✅ All PIA API interactions mocked and tested
- ✅ Environment validation 100% covered

### Medium-term (1 month)
- ✅ 80% overall test coverage
- ✅ Integration tests for all major flows
- ✅ Container build tests
- ✅ Basic E2E smoke tests

### Long-term (2-3 months)
- ✅ 90%+ test coverage
- ✅ Comprehensive E2E test suite
- ✅ Performance/stress tests for refresh loop
- ✅ Chaos testing (network failures, etc.)

---

## Implementation Checklist

### Setup
- [ ] Choose testing framework (BATS recommended)
- [ ] Set up test directory structure
- [ ] Add test dependencies to CI/CD
- [ ] Create test fixtures and mocks

### Phase 1: Critical Tests
- [ ] Gateway detection tests (10-15 tests)
- [ ] PIA API integration tests (15-20 tests)
- [ ] Environment validation tests (8-10 tests)
- [ ] Update CI to run tests

### Phase 2: Integration Tests
- [ ] qBittorrent integration tests (8-10 tests)
- [ ] File operations tests (8-10 tests)
- [ ] Container build tests (5-8 tests)
- [ ] E2E smoke tests (3-5 tests)

### Phase 3: Comprehensive Coverage
- [ ] Main loop tests (6-8 tests)
- [ ] Error handling tests (8-10 tests)
- [ ] Helm chart tests (8-10 tests)
- [ ] Performance/stress tests

### Documentation
- [ ] Test README with running instructions
- [ ] Contributing guide for adding tests
- [ ] Test coverage reporting setup
- [ ] Badge for test coverage in main README

---

## Example Test Structure

```
tests/
├── unit/
│   ├── test_gateway_detection.bats
│   ├── test_pia_api.bats
│   ├── test_qbittorrent.bats
│   ├── test_file_operations.bats
│   └── test_env_validation.bats
├── integration/
│   ├── test_full_flow.bats
│   ├── test_refresh_cycle.bats
│   └── test_error_recovery.bats
├── e2e/
│   ├── test_container.bats
│   └── docker-compose.test.yml
├── fixtures/
│   ├── mock_pia_api.sh
│   ├── mock_qbittorrent.sh
│   └── sample_responses/
│       ├── pia_token.json
│       ├── pia_port.json
│       └── qb_login.txt
├── helm/
│   ├── deployment_test.yaml
│   └── configmap_test.yaml
└── README.md
```

---

## Priority Recommendations

### Must Have (Weeks 1-2)
1. **Gateway detection tests** - Most complex, most likely to fail
2. **PIA API tests** - External dependency, critical functionality
3. **Environment validation tests** - Catch user errors early

### Should Have (Weeks 3-4)
4. **qBittorrent integration tests** - Common use case
5. **File operations tests** - Shared state with other containers
6. **Basic E2E tests** - Validate full flow

### Nice to Have (Weeks 5-8)
7. **Main loop tests** - Long-term stability
8. **Container tests** - Build validation
9. **Helm chart tests** - K8s deployment validation
10. **Chaos/stress tests** - Production resilience

---

## Success Metrics

- **Test Coverage:** Target 80%+ line coverage
- **CI Speed:** All tests complete in <5 minutes
- **Reliability:** Zero false positives in CI
- **Maintainability:** New contributors can add tests easily
- **Documentation:** Every test clearly documents what it validates

---

## Conclusion

The codebase is currently **untested beyond static analysis**. The highest priority is testing the **gateway detection** and **PIA API integration** logic, as these are the most complex and failure-prone components.

Implementing the proposed testing strategy would:
- ✅ Catch bugs before production
- ✅ Enable confident refactoring
- ✅ Improve code quality
- ✅ Reduce debugging time
- ✅ Document expected behavior
- ✅ Enable safer contributions

**Recommended Next Steps:**
1. Set up BATS testing framework
2. Start with gateway detection tests (highest risk)
3. Add PIA API mocking and tests
4. Integrate tests into CI/CD
5. Incrementally improve coverage

---

*Generated: 2026-01-24*
*Repository: docker-pia-portforward*
