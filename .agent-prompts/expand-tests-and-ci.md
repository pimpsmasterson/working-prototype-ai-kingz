# Agent Task: Expand Test Suite and Set Up Coverage/CI

## Mission
Transform the skeletal test suite (currently 19 lines, ~5% coverage) into comprehensive, production-ready tests with 70-80% coverage, then set up automated coverage reporting and CI pipeline.

## Context

### Current State
- **Test file:** `tests/warm-pool.test.js` (19 lines)
- **Current tests:** 1 trivial test with `assert.ok(true)` - doesn't actually verify functionality
- **Coverage:** ~5% of critical code paths
- **TODO comment in test:** "Mock asks PUT /asks/:id and instances endpoints"
- **Testing tools:** Mocha (framework), Chai (assertions), Sinon (spies/stubs), Nock (HTTP mocking)

### What the Application Does
This is a GPU instance warm pool manager that:
1. **Prewarms GPU instances** - Rents GPUs from Vast.ai to keep them ready for content generation
2. **Manages lifecycle** - Monitors instance status, handles claims/leases, auto-terminates idle instances
3. **Tracks usage** - Logs all events to SQLite database (admin_audit, usage_events tables)
4. **Admin controls** - Protected endpoints for starting/stopping GPUs, viewing logs
5. **Cost control** - Auto-shutdown after 15 minutes idle, safe mode for emergency termination

### Critical Files
- `server/warm-pool.js` (285 lines) - Core warm pool manager with prewarm/terminate/claim logic
- `server/vastai-proxy.js` (850+ lines) - Express API endpoints and Vast.ai proxy
- `server/db.js` - SQLite database initialization and state management
- `server/audit.js` - Audit logging functions
- `tests/warm-pool.test.js` (19 lines) - Current skeletal test file

### Key APIs to Mock
**Vast.ai endpoints:**
- `POST /api/v0/bundles/` - Search for available GPU offers
- `PUT /api/v0/asks/:id/` - Rent a specific GPU offer
- `GET /api/v0/instances/:contractId/` - Check instance status
- `DELETE /api/v0/instances/:contractId/` - Terminate instance

**Internal endpoints:**
- `POST /api/proxy/warm-pool/prewarm` - Start a GPU instance
- `POST /api/proxy/warm-pool/terminate` - Stop a GPU instance (admin only)
- `POST /api/proxy/warm-pool/claim` - Claim/lease an instance
- `GET /api/proxy/warm-pool` - Get current pool status
- `POST /api/proxy/admin/warm-pool` - Update pool configuration (admin only)
- `GET /api/proxy/admin/logs` - Retrieve audit logs (admin only)

---

## Phase 1: Expand Test Suite (Primary Focus)

### Success Criteria
- [ ] 70-80% code coverage of critical paths
- [ ] All happy path scenarios tested
- [ ] All error scenarios tested
- [ ] Database operations verified
- [ ] Audit logging verified
- [ ] No trivial assertions like `assert.ok(true)`
- [ ] All tests use proper mocking (nock for HTTP, sinon for functions)

### Test Categories to Implement

#### 1. Full Lifecycle Tests (Happy Path)
**Test: Prewarm → Running → Claim → Terminate**
- Mock Vast.ai bundle search (return GPU offers)
- Mock Vast.ai asks PUT (return contract ID)
- Mock instance status polling (return "starting" → "running")
- Verify database state updated at each step
- Verify usage_events logged correctly
- Verify instance terminated successfully
- Assert final state is clean (desiredSize=0, no instance)

**Expected flow:**
```javascript
1. POST /api/proxy/warm-pool/prewarm (desiredSize=1)
   → Vast.ai: POST /bundles/ (mocked)
   → Vast.ai: PUT /asks/:id/ (mocked with contractId)
   → DB: usage_events INSERT (instance_started)
   → DB: warm_pool UPDATE (instance=contractId, status=starting)

2. Polling loop checks status
   → Vast.ai: GET /instances/:contractId (mocked, status=running)
   → DB: warm_pool UPDATE (status=running)

3. POST /api/proxy/warm-pool/claim
   → Returns instance details for use
   → DB: usage_events INSERT (lease_claimed)

4. POST /api/proxy/warm-pool/terminate (admin key)
   → Vast.ai: DELETE /instances/:contractId (mocked)
   → DB: usage_events INSERT (instance_terminated)
   → DB: warm_pool UPDATE (instance=null, desiredSize=0)
```

#### 2. Error Handling Tests
**Test: Vast.ai API Failure During Prewarm**
- Mock bundle search to return error/timeout
- Verify retry logic (should retry 3 times with backoff)
- Verify graceful failure (no instance created)
- Verify error logged to database

**Test: Instance Termination Fails (Already Deleted)**
- Mock DELETE /instances/:id to return "no_such_instance"
- Verify system handles gracefully
- Verify database marked as terminated anyway
- Verify admin_audit logs the attempt

**Test: Network Timeout During Status Polling**
- Mock GET /instances/:id to timeout
- Verify retry logic
- Verify system doesn't mark instance as failed prematurely

**Test: Unauthorized Admin Action**
- POST /api/proxy/warm-pool/terminate with wrong admin key
- Verify 401/403 response
- Verify admin_audit logs failed auth attempt with IP

#### 3. Database Operation Tests
**Test: State Persistence Across Restarts**
- Create instance in warm pool
- Save state to database
- Simulate server restart (reload state)
- Verify instance state restored correctly
- Verify lastAction timestamp preserved

**Test: Audit Log Retention**
- Create 100 admin audit entries
- Set retention to 7 days
- Run cleanup function
- Verify old entries deleted, recent entries kept

**Test: Usage Events Tracking**
- Prewarm instance
- Claim it
- Terminate it
- Query usage_events table
- Verify all 3 events logged with correct timestamps, contract ID, details

**Test: Admin Key Fingerprinting**
- Make admin API call with key "test-admin-key"
- Query admin_audit table
- Verify admin_fingerprint is HMAC-SHA256 hash, not plain text
- Verify same key produces same fingerprint (deterministic)

#### 4. Concurrent Operations Tests
**Test: Multiple Prewarm Requests (Race Condition)**
- Send 3 simultaneous POST /prewarm requests
- Verify only 1 instance created (not 3)
- Verify all 3 requests return same instance
- Verify database state consistent

**Test: Claim While Terminating**
- Start instance
- Begin termination
- Attempt to claim during termination
- Verify claim fails gracefully
- Verify no stale lease created

#### 5. Idle Shutdown Tests
**Test: Auto-Terminate After 15 Minutes**
- Mock instance with lastAction = 16 minutes ago
- Run polling loop
- Mock DELETE /instances/:id
- Verify instance terminated
- Verify usage_events logged termination reason (idle timeout)

**Test: Safe Mode Immediate Termination**
- Create instance
- Set safeMode = true
- Run polling loop
- Verify instance terminated immediately (no idle wait)
- Verify admin_audit logs safe mode trigger

**Test: Desired Size 0 Termination**
- Create instance
- POST /admin/warm-pool with desiredSize=0
- Run polling loop
- Verify instance terminated
- Verify reason logged correctly

#### 6. Admin Endpoint Tests
**Test: Get Admin Logs with Filtering**
- Create 50 audit entries with mixed actions (terminate, set_warm_pool, view_logs)
- GET /admin/logs?action=terminate&limit=10
- Verify only terminate actions returned
- Verify max 10 results
- Verify sorted by timestamp DESC

**Test: Update Warm Pool Configuration**
- POST /admin/warm-pool with {desiredSize: 1, safeMode: true}
- Verify database updated
- Verify admin_audit logged the change
- Verify response includes new config

**Test: Admin Authentication Failure**
- POST /admin/warm-pool with no x-admin-key header
- Verify 401 response
- Verify admin_audit logs failed attempt
- POST with wrong key
- Verify same behavior

#### 7. Edge Cases
**Test: Prewarm When Instance Already Exists**
- Create instance (already running)
- POST /prewarm again
- Verify returns existing instance (doesn't create duplicate)
- Verify desiredSize updated if changed

**Test: Terminate Non-Existent Instance**
- POST /terminate with contractId that doesn't exist
- Verify 200 response (idempotent)
- Verify message indicates no instance found
- Verify no error thrown

**Test: Claim Expired Instance**
- Create instance with status "stopped" or "exited"
- POST /claim
- Verify claim fails
- Verify error message indicates instance not available

---

### Implementation Guidelines

#### Use Nock for HTTP Mocking
```javascript
const nock = require('nock');

// Mock Vast.ai bundle search
nock('https://console.vast.ai')
  .post('/api/v0/bundles/', {
    /* search criteria */
  })
  .reply(200, {
    offers: [
      { id: 12345, gpu_name: 'RTX 3090', dph_total: 0.50 }
    ]
  });

// Mock instance rental
nock('https://console.vast.ai')
  .put('/api/v0/asks/12345/')
  .reply(200, {
    new_contract: 30495801
  });

// Mock status polling
nock('https://console.vast.ai')
  .get('/api/v0/instances/')
  .query({ id: 30495801 })
  .reply(200, {
    instances: [
      { id: 30495801, actual_status: 'running', ssh_host: 'gpu1.vast.ai', ssh_port: 12345 }
    ]
  });

// Mock termination
nock('https://console.vast.ai')
  .delete('/api/v0/instances/30495801/')
  .reply(200, { success: true });
```

#### Use Sinon for Database Mocking (Optional)
If you want to avoid hitting real SQLite:
```javascript
const sinon = require('sinon');
const db = require('../server/db');

// Stub database functions
const saveStateStub = sinon.stub(db, 'saveState').resolves();
const getStateStub = sinon.stub(db, 'getState').resolves({ desiredSize: 0, instance: null });

// Restore after test
after(() => {
  saveStateStub.restore();
  getStateStub.restore();
});
```

#### Use In-Memory SQLite for Real DB Tests
```javascript
const Database = require('better-sqlite3');
const db = new Database(':memory:'); // In-memory, doesn't persist

// Run schema migrations
db.exec(`
  CREATE TABLE IF NOT EXISTS warm_pool (
    id INTEGER PRIMARY KEY,
    desiredSize INTEGER,
    instance TEXT,
    lastAction INTEGER,
    isPrewarming INTEGER,
    safeMode INTEGER
  )
`);
```

#### Proper Assertions (No More `assert.ok(true)`)
```javascript
const { expect } = require('chai');

// Bad (current)
assert.ok(true);

// Good (detailed)
expect(response.status).to.equal(200);
expect(response.body).to.have.property('instance');
expect(response.body.instance.contractId).to.equal(30495801);
expect(response.body.instance.status).to.equal('running');
```

#### Test Structure
```javascript
describe('Warm Pool Lifecycle', () => {
  let server;

  before(() => {
    // Start Express server for testing
    server = require('../server/vastai-proxy');
  });

  beforeEach(() => {
    // Reset database state
    // Clear nock mocks
    nock.cleanAll();
  });

  afterEach(() => {
    // Verify all nock mocks were called
    expect(nock.isDone()).to.be.true;
  });

  after(() => {
    // Stop server, close database
    server.close();
  });

  it('should complete full lifecycle: prewarm → running → claim → terminate', async () => {
    // Test implementation here
  });
});
```

---

## Phase 2: Set Up Coverage Reporting and CI

### Success Criteria
- [ ] `nyc` (Istanbul) configured and working
- [ ] Coverage reports generated (HTML + text)
- [ ] `.nycrc.json` with 80% thresholds
- [ ] `.gitignore` excludes coverage artifacts
- [ ] GitHub Actions workflow runs on push/PR
- [ ] CI tests on Node 18, 20, 22
- [ ] Coverage badge added to README

### Implementation Steps

#### 1. Update package.json
```json
{
  "scripts": {
    "test": "nyc mocha tests/**/*.test.js",
    "test:coverage": "nyc report --reporter=text-lcov | coveralls",
    "coverage": "nyc report --reporter=html && open coverage/index.html"
  },
  "devDependencies": {
    "nyc": "^15.1.0",
    "mocha": "^10.2.0",
    "chai": "^4.3.7",
    "sinon": "^15.0.4",
    "nock": "^13.3.1"
  }
}
```

#### 2. Create .nycrc.json
```json
{
  "all": true,
  "check-coverage": true,
  "lines": 80,
  "functions": 80,
  "branches": 75,
  "statements": 80,
  "reporter": ["html", "text", "lcov"],
  "exclude": [
    "tests/**",
    "assets/js/**",
    "server/db_inspect.js",
    "ecosystem.config.js",
    "coverage/**",
    ".nyc_output/**",
    "node_modules/**"
  ],
  "include": [
    "server/**/*.js"
  ],
  "cache": false,
  "temp-dir": "./.nyc_output"
}
```

#### 3. Update .gitignore
Add these lines:
```
# Coverage reports
.nyc_output/
coverage/
*.lcov
```

#### 4. Create .github/workflows/test.yml
```yaml
name: Tests and Coverage

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18.x, 20.x, 22.x]

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests with coverage
        env:
          ADMIN_API_KEY: test-admin-key
          VASTAI_API_KEY: test-vast-key
          AUDIT_SALT: test-salt-for-hashing
          NODE_ENV: test
        run: npm test

      - name: Upload coverage to Codecov
        if: matrix.node-version == '20.x'
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          flags: unittests
          name: codecov-umbrella
          fail_ci_if_error: false

      - name: Generate coverage badge
        if: matrix.node-version == '20.x' && github.ref == 'refs/heads/main'
        run: |
          COVERAGE=$(node -e "const fs = require('fs'); const lcov = fs.readFileSync('./coverage/lcov.info', 'utf8'); const lines = lcov.match(/LF:(\d+)/g).reduce((a,c) => a + parseInt(c.split(':')[1]), 0); const hit = lcov.match(/LH:(\d+)/g).reduce((a,c) => a + parseInt(c.split(':')[1]), 0); console.log(Math.floor(hit/lines*100));")
          echo "COVERAGE=${COVERAGE}" >> $GITHUB_ENV

      - name: Comment coverage on PR
        if: github.event_name == 'pull_request' && matrix.node-version == '20.x'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const coverage = fs.readFileSync('./coverage/lcov.info', 'utf8');
            // Parse and comment coverage summary
```

#### 5. Add Coverage Badge to README_PROTOTYPE.md
After CI runs successfully, add to top of README:
```markdown
# AI KINGS - Warm Pool System

![Tests](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test.yml/badge.svg)
![Coverage](https://img.shields.io/badge/coverage-80%25-brightgreen)
![Node](https://img.shields.io/badge/node-18%20%7C%2020%20%7C%2022-blue)
```

#### 6. Test Locally Before Committing
```bash
# Run tests with coverage
npm test

# View HTML coverage report
npm run coverage

# Verify coverage meets thresholds
# Should show 70-80% lines/functions/statements
```

---

## Validation Checklist

### Phase 1: Tests
- [ ] Test file expanded from 19 lines to 500+ lines
- [ ] All 7 test categories implemented (lifecycle, errors, database, concurrent, idle, admin, edge cases)
- [ ] No trivial assertions remaining (`assert.ok(true)` removed)
- [ ] All HTTP calls mocked with nock
- [ ] Database operations either mocked or use in-memory SQLite
- [ ] Tests pass: `npm test` shows all green
- [ ] Coverage reaches 70-80%: `npm run coverage` shows good numbers

### Phase 2: Infrastructure
- [ ] `nyc` installed and configured
- [ ] `.nycrc.json` exists with 80% thresholds
- [ ] `.gitignore` excludes `.nyc_output/` and `coverage/`
- [ ] GitHub Actions workflow exists at `.github/workflows/test.yml`
- [ ] Workflow tests on Node 18, 20, 22
- [ ] Dummy env vars set in CI
- [ ] Coverage badge added to README
- [ ] CI passes on push

---

## Important Notes

### Environment Variables for Tests
Tests should NOT require real API keys. Use dummy values:
```javascript
process.env.ADMIN_API_KEY = 'test-admin-key';
process.env.VASTAI_API_KEY = 'test-vast-key';
process.env.AUDIT_SALT = 'test-salt';
process.env.NODE_ENV = 'test';
```

### Nock Best Practices
- Clean all mocks between tests: `nock.cleanAll()`
- Verify all mocks were called: `expect(nock.isDone()).to.be.true`
- Use `.persist()` for mocks needed multiple times
- Use `.times(n)` to expect multiple calls

### Database Best Practices
- Use in-memory SQLite for speed: `new Database(':memory:')`
- Run schema migrations in `before()` hook
- Reset state in `beforeEach()` hook
- Don't commit test databases (already in .gitignore)

### Coverage Thresholds Reasoning
- **80% lines/statements** - Industry standard for production code
- **75% branches** - Slightly lower because some error branches are hard to test
- **80% functions** - Most functions should be tested

### Files to Focus On
**High priority (test these thoroughly):**
- `server/warm-pool.js` - Core logic
- `server/vastai-proxy.js` - API endpoints
- `server/db.js` - Database operations
- `server/audit.js` - Audit logging

**Lower priority (optional):**
- `server/db_inspect.js` - Utility script
- `assets/js/**` - Client-side (needs separate browser tests)

---

## Expected Outcomes

### Before
```bash
$ npm test
  Warm Pool
    ✓ should fetch available bundles (mock) (47ms)

  1 passing (52ms)

$ npm run coverage
Lines        : 5.23% ( 12/230 )
Statements   : 5.45% ( 13/238 )
Functions    : 8.33% ( 2/24 )
Branches     : 2.50% ( 1/40 )
```

### After Phase 1
```bash
$ npm test
  Warm Pool Lifecycle
    ✓ should complete full lifecycle: prewarm → running → claim → terminate (125ms)
    ✓ should handle concurrent prewarm requests without race conditions (89ms)
    ✓ should auto-terminate instance after idle timeout (156ms)

  Warm Pool Error Handling
    ✓ should retry Vast.ai API failures 3 times with backoff (234ms)
    ✓ should handle instance termination of non-existent instance gracefully (67ms)
    ✓ should reject unauthorized admin actions and log attempt (45ms)

  Warm Pool Database Operations
    ✓ should persist state across restarts (78ms)
    ✓ should fingerprint admin keys in audit logs (34ms)
    ✓ should track all usage events correctly (91ms)

  [... 20+ more tests ...]

  32 passing (3s)

$ npm run coverage
Lines        : 78.26% ( 180/230 )
Statements   : 79.83% ( 190/238 )
Functions    : 83.33% ( 20/24 )
Branches     : 72.50% ( 29/40 )
```

### After Phase 2
- ✅ GitHub Actions badge shows "passing"
- ✅ Coverage badge shows "78%"
- ✅ Every push triggers automated tests
- ✅ PRs show coverage diff

---

## Questions to Consider

### Should we enforce coverage thresholds as CI failures?
**Recommendation:** Yes, but set to 70% initially, increase to 80% once stable.
In `.nycrc.json`, `check-coverage: true` will fail CI if below thresholds.

### Should we add Codecov or Coveralls integration?
**Recommendation:** Yes, Codecov is free for open source and provides nice PR comments showing coverage changes.

### Should we test client-side JavaScript (assets/js)?
**Recommendation:** Separate concern. Use browser testing tools (Playwright, Cypress) later. Focus on server-side for now.

### Should we mock the database or use in-memory SQLite?
**Recommendation:** In-memory SQLite (`:memory:`) for most tests - it's fast and tests real SQL. Only mock for unit tests of specific functions.

---

## Success Definition

**Phase 1 Complete When:**
- Tests execute full warm pool workflows end-to-end
- Coverage reports show 70-80% of server code tested
- All error scenarios have test coverage
- Database and audit operations verified
- Can confidently refactor code knowing tests will catch breakage

**Phase 2 Complete When:**
- `npm test` generates coverage reports automatically
- GitHub Actions runs tests on every push/PR
- Coverage badge visible in README
- CI fails if coverage drops below 70%
- Can show stakeholders professional quality metrics

---

## Deliverables

1. **Expanded test file:** `tests/warm-pool.test.js` (500+ lines with real assertions)
2. **Coverage config:** `.nycrc.json` with 80% thresholds
3. **CI workflow:** `.github/workflows/test.yml` for automated testing
4. **Updated docs:** `.gitignore`, `package.json`, `README_PROTOTYPE.md` with badge
5. **Coverage report:** HTML report in `coverage/` (git-ignored)

---

**Ready to execute this plan?** Start with Phase 1 (expand tests), then Phase 2 (infrastructure). Prioritize getting real assertions and coverage over infrastructure setup.
