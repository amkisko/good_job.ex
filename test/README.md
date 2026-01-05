# Running Tests

## Using ExUnit

All tests should be run using `mix test`

```bash
# Run all tests
mix test

# Run with fail-fast (stop on first failure)
mix test --max-failures 1

# For verbose output
DEBUG=1 mix test

# Run single test file
mix test test/good_job/executor_test.exs

# Run single test at exact line number
mix test test/good_job/executor_test.exs:42

# Run tests matching a pattern
mix test --only describe:"JobExecutor"

# Run tests in a specific directory
mix test test/good_job/job_executor/
```

## Test Structure

- `test/good_job/` - Test files mirroring the `lib/good_job/` structure
  - `executor_test.exs` - Job execution tests
  - `registry_test.exs` - Process registry tests
  - `job_executor/` - Job executor module tests
  - `job_stats/` - Job statistics and aggregation tests
  - `telemetry_test.exs` - Telemetry event tests

**Note:** Both unit and integration tests are in `test/good_job/` following the mirroring approach. Integration tests are distinguished by `@moduletag :integration` and test end-to-end workflows across multiple modules. The `integration/` subfolder violates the mirroring guidelines and should not be used.

## ExUnit Testing Guidelines

### Spec File Organization Strategies

This project uses the **"Standard" Mirroring** approach: test files mirror `lib/` structure 1-to-1.

```
lib/
└── good_job/
    ├── executor.ex
    └── job_executor/
        └── result_handler.ex

test/
└── good_job/
    ├── executor_test.exs
    └── job_executor/
        └── result_handler_test.exs
```

**Best For:** Small to medium-sized modules (< 300 lines, < 10 functions)

**Why it's consensus:** Zero cognitive load. If you see `lib/good_job/executor.ex`, tests are in `test/good_job/executor_test.exs`.

**The Problem:** As modules grow, `executor_test.exs` becomes a 2,000+ line "god object" that's hard to navigate.

#### When to Split Specs

If a test file exceeds 300 lines or requires scrolling > 2 screens to find relevant setup code, consider splitting into behavior-based files within a directory:

```
test/
└── good_job/
    └── executor/
        ├── execute_job_test.exs
        ├── handle_timeout_test.exs
        └── error_handling_test.exs
```

**Key Requirement:** Ensure the module is loaded in a main test file or shared setup.

### Core Philosophy: Behavior Verification vs. Implementation Coupling

The fundamental principle of refactoring-resistant testing is the distinction between **what** a system does (Behavior) and **how** it does it (Implementation).

- **Behavior:** Defined by the Public Contract—the inputs accepted by the System Under Test (SUT) and the observable outputs or side effects it produces at its architectural boundaries.
- **Implementation:** Encompasses internal control flow, private functions, auxiliary data structures, and the specific sequence of internal operations.

> **Principle:** True refactoring resistance is achieved only when the test suite is agnostic to the SUT's internal composition.

When a test couples itself to implementation details—for instance, by asserting that a specific private function was called or by mocking an internal helper—it violates encapsulation. Such tests verify that the code *looks* a certain way, not that it *works*. This leads to **"False Negatives"** or **"Fragile Tests,"** where a test fails simply because a developer renamed a private function or optimized a loop, even though the business logic remains correct.

### Core Principles

- **Always assume ExUnit has been integrated** - Never edit `test_helper.exs` or add new testing dependencies without careful consideration
- **Test Behavior, Not Implementation** - Verify the public contract, not internal structure
- **Refactoring Resistance** - Tests should survive internal refactoring without modification
- Keep test scope minimal - start with the most crucial and essential tests
- Never test features that are built into Elixir, OTP, or external libraries
- Never write tests for performance unless specifically requested
- Isolate external dependencies (HTTP calls, file system, time, database) at architectural boundaries only
- Use `async: true` when tests don't modify shared state
- Prefer pattern matching and guards over defensive conditionals

### Practical Metrics and Heuristics

#### The "Danger Zone" Metrics (When to Split)

These are the practical thresholds where files become hard to read/maintain, triggering a refactor or the split approach.

| Metric | Code (lib/) | Tests (test/) | Notes |
| :--- | :--- | :--- | :--- |
| **Lines per File** | 100 - 300 | 300 - 500 | At 500+ lines, a test file becomes a "scroll nightmare." At 1,000+, it's a "God Object." |
| **Lines per Test** | 5 - 10 | 10 - 20 | `test` blocks should be short. If a `test` block is >15 lines, you're testing too many things or setup is complex. |
| **Functions per Module** | ~10 - 20 | N/A | For tests, this translates to "Tests per describe block." |

#### Elixir-Specific Rules

- **100 lines per module** (as a guideline, not strict)
- **5 lines per function** (as a guideline)
- **4 parameters maximum per function** (as a guideline)

**How this applies:** If you follow this for your `lib/` code, your modules will naturally be small, which usually means your `test/` files (Mirroring approach) stay small automatically. Your need for splitting tests often indicates your `lib/` modules are large/complex.

#### Practical ExUnit Heuristics

**The "Scroll Test"**
- If you have to scroll more than 2 screens to find the setup code that applies to the test you're reading, the file is too long or the context is too nested.

**The "Context Depth"**
- **Ideal:** 2-3 levels of nesting (`describe` -> `test`)
- **Max:** 4 levels
- **Too Deep:** 5+ levels. This usually implies you're testing logic variations that should be extracted into a separate module or function.

**For Behavior-Based Approach (Split Tests):**
- **Lines per File:** Aim for < 100 lines per behavior-test file. If a single behavior needs 200+ lines of testing, that specific behavior is likely too complex (Cyclomatic Complexity).
- **Shared Setup:** Keep your `setup` blocks under 50 lines. If your setup is larger than that, your object graph is likely too coupled.

### Test Type Selection

#### Unit Tests (`test/good_job/`)

- Use for: Module functions, business logic, data transformations
- Test: Public API behavior, error handling, edge cases
- Example: Testing `GoodJob.Executor.execute/1`, `GoodJob.JobStats.Aggregation.calculate/1`

#### Integration Tests (`test/good_job/`)

- Use for: Database operations, process communication, supervisor trees
- Test: End-to-end workflows, database transactions, process lifecycle
- Example: Testing job execution with real database, testing supervisor restarts
- **Location:** Integration tests are in `test/good_job/` directly (not in an `integration/` subfolder) to follow the mirroring approach
- **Tagging:** Use `@moduletag :integration` to distinguish integration tests from unit tests
- **Naming:** Integration tests that test cross-cutting concerns should be named descriptively (e.g., `job_execution_integration_test.exs`, `protocol_integration_test.exs`)

### Testing Workflow

1. **Plan First**: Think carefully about what tests should be written for the given scope/feature
2. **Review Existing Tests**: Check existing tests before creating new test data
3. **Isolate Dependencies**: Use mocks/stubs for external services (HTTP, file system, time)
4. **Use Mox**: Set up Mox for behavior-based mocking of external dependencies
5. **Minimal Scope**: Start with essential tests, add edge cases only when specifically requested
6. **DRY Principles**: Review `test/support/` for existing shared setup and helpers before duplicating code

### The Mocking Policy: Architectural Boundaries Only

To enforce refactoring resistance, strict controls must be placed on the use of Test Doubles (mocks, stubs, spies).

#### 🚫 STRICTLY FORBIDDEN: Internal Mocks

The policy unequivocally prohibits the mocking of internals. This prohibition covers:

1. **Mocking Private Functions:**
   - Attempts to mock private functions are fundamentally flawed
   - These functions exist solely to organize code; they do not represent a contract
   - If a test mocks a private function, it is coupled to the signature of that function

2. **Partial Mocks (Spies on the SUT):**
   - Creating a real instance of the SUT but overriding one of its functions
   - This creates a "Frankenstein" module that exists only in the test environment

3. **Reflection-Based State Manipulation:**
   - Using reflection to set private fields to bypass validation logic
   - This tests a state that might be unreachable in the actual application

#### ✅ PERMITTED MOCKS: Architectural Boundaries

Mocking is reserved exclusively for **Architectural Boundaries**—the seams where the SUT interacts with systems it does not own or control.

| Boundary Type | Examples | Rationale for Mocking | Preferred Double |
| :--- | :--- | :--- | :--- |
| **Persistence Layer** | Ecto Repos, Databases | Eliminates dependency on running DB; speed/isolation | Fake (In-Memory) or Stub |
| **External I/O** | HTTP Clients, RPC | Prevents network calls; simulates error states | Mock or Stub |
| **File System** | Disk Access | Decouples tests from slow/stateful disk | Fake (Virtual FS) |
| **System Env** | Time, Randomness | Removes non-determinism | Stub (Fixed Clock) |
| **Eventing** | PubSub, Events | Verifies side effects without running broker | Spy (Capture events) |

### The Input Derivation Protocol

When tempted to mock an internal function to "force" code execution, **STOP**. Instead, use the **Input Derivation Protocol**.

#### Protocol Mechanics

Treat the SUT as a logic puzzle. To execute a specific line of code, solve the logical equation defined by the control flow graph leading to it.

1. **Analyze the Logic (Path Predicate Analysis):**
   - Examine the conditional checks (`if`, `cond`, `case`, guards)
   - *Example:* `if user.age > 18: ...`

2. **Reverse Engineer the Input:**
   - Determine the initial state that satisfies the predicate
   - *Result:* Input user must have `age >= 19`

3. **Construct Data (The Fixture):**
   - Create a data fixture that naturally satisfies the conditions
   ```elixir
   valid_user = %User{age: 25, status: :active}
   ```

4. **Execute via Public API:**
   - Pass the constructed input into the public entry point

#### Addressing "Unreachable" Code

If the Input Derivation Protocol fails (no public input can trigger the line), the target code is technically **unreachable** or **dead code**, or it represents a defensive check for a state the system prevents elsewhere.

#### Techniques

- **Basis Path Testing:** Calculate cyclomatic complexity to determine the number of independent paths needed
- **Equivalence Partitioning:** Divide input space into partitions (e.g., Valid vs. Invalid) and test representative values
- **Boundary Value Analysis:** Test edges of partitions (e.g., age 17, 18, 19)
- **Pattern Matching:** Use pattern matching to test different input shapes

### Test Data Management

#### Setup and Teardown

- Use `setup` blocks for test fixtures and initialization
- Use `setup_all` for expensive one-time setup (e.g., database migrations)
- Use `on_exit/2` for cleanup that must happen after tests
- Prefer `start_supervised/2` for processes that need supervision

#### Test Data Patterns

For this library, test data is typically:
- **Database Records**: Use Ecto factories or direct inserts for test data
- **Processes**: Use `start_supervised/2` for supervised processes
- **Time**: Use `DateTime` stubs or `Process.sleep/1` for time-dependent tests
- **Configuration**: Use `Application.put_env/3` for test-specific configuration

#### Example Setup Pattern

```elixir
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case, async: false  # Set to false if tests modify shared state

  setup do
    # Setup test database transaction
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GoodJob.TestRepo)
    
    # Create test job
    job = insert_test_job()
    
    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.checkin(GoodJob.TestRepo)
    end)
    
    %{job: job}
  end

  test "executes job successfully", %{job: job} do
    assert {:ok, _result} = GoodJob.Executor.execute(job)
  end
end
```

### Shared Contexts and Helpers

- Use `test/support/` for shared setup, custom assertions, and test helpers
- Create shared contexts for truly shared behavior across multiple test files
- Scope helpers appropriately using `ExUnit.CaseTemplate` when needed

**For Split Tests Approach:**
- **Shared Contexts:** When using behavior-based approach, create shared contexts to avoid duplicating setup code
- **Keep shared contexts small:** Under 50 lines per shared context file
- **Example structure:**
  ```elixir
  # test/support/shared_contexts/job_execution.ex
  defmodule GoodJob.Test.Support.SharedContexts.JobExecution do
    defmacro __using__(_opts) do
      quote do
        setup do
          job = insert_test_job()
          %{job: job}
        end
      end
    end
  end

  # test/good_job/executor/execute_job_test.exs
  defmodule GoodJob.Executor.ExecuteJobTest do
    use ExUnit.Case, async: true
    use GoodJob.Test.Support.SharedContexts.JobExecution
    
    test "executes job", %{job: job} do
      # ... tests
    end
  end
  ```

### Isolation Best Practices

#### When to Isolate

- Expensive or flaky external IO (HTTP, file system) → stub or use Mox
- Rare/error branches hard to trigger → stub to reach them
- Nondeterminism (random, time, UUIDs) → stub to deterministic values
- Performance in tight unit scopes → replace heavy collaborators

#### When NOT to Isolate

- Simple Elixir operations
- Cheap internal collaborations
- Where integration tests provide clearer coverage
- Pattern matching and guards (these are part of the public contract)

#### Isolation Techniques

- **Mox**: Use Mox for behavior-based mocking of external dependencies
- **Stubs**: Use `:meck` or Mox for replacing behavior
- **Spies**: Use Mox `expect` for verifying side effects
- **Time Stubs**: Use `DateTime` manipulation or `Process.sleep/1` for deterministic time-dependent tests
- **Database Sandbox**: Use `Ecto.Adapters.SQL.Sandbox` for database isolation

#### Isolation Rules

1. **Preserve Public Behavior**: Test via public API, never test private functions directly
2. **Mock Only Boundaries**: Only mock external dependencies (HTTP, DB, File System, Time), never internal functions
3. **Scope Narrowly**: Keep stubs local to tests; avoid global state
4. **Use Mox**: Prefer Mox for behavior-based mocking over `:meck`
5. **Default to Sandbox for DB**: Use Ecto Sandbox for database isolation
6. **Assert Outcomes**: Focus on behavior, not internal call choreography
7. **Input Derivation**: When you need to test a specific code path, derive the input that naturally triggers it

### Mox Configuration

- Mox is configured in `test/support/mocks.ex`
- Define behaviors for external dependencies
- Use `Mox.defmock/2` to create mock modules
- Example:

```elixir
# test/support/mocks.ex
Mox.defmock(GoodJob.Test.MockHTTPClient, for: GoodJob.HTTPClient.Behaviour)

# In test_helper.exs
Mox.Server.start_link([])

# In tests
defmodule GoodJob.ExecutorTest do
  import Mox
  
  setup :verify_on_exit!
  
  test "makes HTTP request" do
    expect(GoodJob.Test.MockHTTPClient, :get, fn _url -> {:ok, %{status: 200}} end)
    
    assert {:ok, _} = GoodJob.Executor.execute(job)
  end
end
```

### Testing Database Operations

When testing classes that interact with the database:

```elixir
defmodule GoodJob.JobTest do
  use ExUnit.Case, async: false  # Database tests should not be async
  
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GoodJob.TestRepo)
    
    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.checkin(GoodJob.TestRepo)
    end)
    
    :ok
  end
  
  test "creates job in database" do
    assert {:ok, job} = GoodJob.Job.create(%{name: "test", args: []})
    assert job.name == "test"
  end
end
```

### Testing Process Communication

When testing GenServer, Agent, or other OTP processes:

```elixir
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case, async: false
  
  test "handles job execution" do
    {:ok, pid} = start_supervised(GoodJob.Executor)
    
    assert :ok = GenServer.call(pid, {:execute, job})
  end
end
```

### Testing Error Handling

Always test error cases using pattern matching:

```elixir
test "raises error when job is invalid" do
  assert_raise ArgumentError, fn ->
    GoodJob.Executor.execute(nil)
  end
end

test "returns error tuple for invalid input" do
  assert {:error, :invalid_job} = GoodJob.Executor.execute(invalid_job)
end
```

### Code Examples: Anti-Patterns vs. Best Practices

#### 🔴 Bad Practice: Targeted Mocking (Internal Mocks)

**Why it is bad:** It couples the test to `validate_job/1`. If renamed, the test crashes. The test accepts invalid input because of the mock, creating a false positive.

```elixir
# ❌ DO NOT DO THIS
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case
  
  test "executes job when validation passes" do
    job = build_test_job()
    
    # VIOLATION: Mocking a function inside the SUT
    :meck.new(GoodJob.Executor, [:passthrough])
    :meck.expect(GoodJob.Executor, :validate_job, fn _job -> :ok end)
    
    # False Negative: The code accepts invalid input because of the mock
    result = GoodJob.Executor.execute(job)
    assert {:ok, _} = result
    
    :meck.unload(GoodJob.Executor)
  end
end
```

#### 🟢 Best Practice: Input Driven

**Why it is good:** It treats the module as a black box. It proves the logic works with valid input.

```elixir
# ✅ DO THIS
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case
  
  test "executes job with valid input" do
    # 1. Setup SUT with architectural fakes (if needed)
    # In this case, we use a real job (no mocking needed)
    
    # 2. Input Derivation: Construct input that NATURALLY passes validation
    valid_job = %GoodJob.Job{
      id: 1,
      name: "test_job",
      args: [],
      scheduled_at: DateTime.utc_now()
    }
    
    # 3. Execution via Public API
    result = GoodJob.Executor.execute(valid_job)
    
    # 4. Assert Behavior
    assert {:ok, _execution_result} = result
  end
end
```

#### 🟢 Best Practice: Boundary Mocking (External Dependencies)

**Why it is good:** HTTP is an architectural boundary. We control it via dependency injection.

```elixir
# ✅ DO THIS
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case
  import Mox
  
  setup :verify_on_exit!
  
  test "includes expiration time in result" do
    # 1. Control HTTP via Boundary Mock (if HTTP was injected)
    expect(GoodJob.Test.MockHTTPClient, :post, fn _url, _body ->
      {:ok, %{status: 200, body: "success"}}
    end)
    
    job = build_test_job()
    result = GoodJob.Executor.execute(job)
    
    # 2. Assert Behavior: Result contains expected data
    assert {:ok, execution_result} = result
    assert execution_result.status == :success
  end
end
```

### Anti-Patterns to Avoid

- **Mocking Internal Functions:** Never mock private functions or functions within the module you're testing
- **Partial Mocks:** Never create partial mocks of the SUT
- **Testing Implementation Details:** Don't assert that specific private functions were called
- **Reflection-Based Manipulation:** Don't use reflection to set private fields
- **Not Isolating Boundaries:** Always isolate external dependencies (HTTP, file system, time)
- **Using Real External Services:** Never use real external services in tests
- **Testing Elixir/OTP Functionality:** Don't test features built into Elixir, OTP, or external libraries
- **Over-Testing Edge Cases:** Only test edge cases when specifically requested
- **Creating Unnecessary Data:** Avoid creating unused test data
- **Using `async: true` with Shared State:** Don't use `async: true` when tests modify shared state (database, ETS tables, etc.)
- **Non-Assertive Pattern Matching:** Use pattern matching assertively, don't match on `_` when you should match on specific patterns

### Elixir-Specific Best Practices

#### Pattern Matching

- Use pattern matching in function heads and `case` statements
- Prefer explicit pattern matching over defensive conditionals
- Use guards for additional conditions

```elixir
# ✅ Good: Assertive pattern matching
def execute({:ok, job}), do: process_job(job)
def execute({:error, reason}), do: {:error, reason}

# ❌ Bad: Defensive conditional
def execute(result) do
  if match?({:ok, _}, result) do
    process_job(elem(result, 1))
  else
    {:error, elem(result, 1)}
  end
end
```

#### Doctests

- Use doctests to keep documentation up-to-date with code examples
- Doctests are documentation first, tests second
- Use `doctest ModuleName` in test files

```elixir
defmodule GoodJob.Executor do
  @doc """
  Executes a job.
  
  ## Examples
  
      iex> job = %GoodJob.Job{id: 1, name: "test"}
      iex> GoodJob.Executor.execute(job)
      {:ok, %ExecutionResult{}}
  """
  def execute(job) do
    # ...
  end
end

# In test file
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case
  doctest GoodJob.Executor
end
```

#### Async Tests

- Use `async: true` when tests don't modify shared state
- Set `async: false` for database tests, ETS table tests, or tests that modify global state
- Each async test runs in a separate process

```elixir
# ✅ Good: Pure function, no shared state
defmodule GoodJob.UtilsTest do
  use ExUnit.Case, async: true
  
  test "calculates sum" do
    assert GoodJob.Utils.sum([1, 2, 3]) == 6
  end
end

# ✅ Good: Database test, shared state
defmodule GoodJob.JobTest do
  use ExUnit.Case, async: false
  
  test "creates job" do
    # Database operations
  end
end
```

#### Process Testing

- Use `start_supervised/2` for processes that need supervision
- Use `on_exit/2` for cleanup
- Test process communication via public API

```elixir
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case, async: false
  
  setup do
    {:ok, pid} = start_supervised(GoodJob.Executor)
    %{executor: pid}
  end
  
  test "handles messages", %{executor: pid} do
    send(pid, {:execute, job})
    assert_receive {:ok, result}
  end
end
```

### Self-Correction Checklist

Before committing, perform this audit:

1. **Ownership Check:** Am I mocking a function that belongs to the module I am testing? (If YES → Delete mock)
2. **Verification Target:** Am I testing that the code works, or how the code works?
3. **Input Integrity:** Did I create the necessary input data to reach the code path naturally?
4. **Refactoring Resilience:** If I rename private helper functions, will this test still pass?
5. **Boundary Check:** Is the mock representing a true I/O boundary (DB, Web, Time)?
6. **Public API:** Am I testing through the public interface only?
7. **Pattern Matching:** Am I using assertive pattern matching instead of defensive conditionals?
8. **Async Safety:** Should this test be `async: true` or `async: false`?

### Example Test Structure

```elixir
defmodule GoodJob.ExecutorTest do
  use ExUnit.Case, async: false  # Database tests should not be async
  
  alias GoodJob.Executor
  alias GoodJob.Job
  
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GoodJob.TestRepo)
    
    job = %Job{
      id: 1,
      name: "test_job",
      args: [],
      scheduled_at: DateTime.utc_now()
    }
    
    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.checkin(GoodJob.TestRepo)
    end)
    
    %{job: job}
  end
  
  describe "execute/1" do
    test "executes job successfully", %{job: job} do
      # ✅ Mocking HTTP (architectural boundary) is allowed
      expect(GoodJob.Test.MockHTTPClient, :post, fn _url, _body ->
        {:ok, %{status: 200}}
      end)
      
      # Execute via public API
      result = Executor.execute(job)
      
      # Assert behavior (what it returns), not implementation
      assert {:ok, execution_result} = result
      assert execution_result.status == :success
    end
    
    test "handles HTTP error", %{job: job} do
      # ✅ Mocking HTTP error (architectural boundary)
      expect(GoodJob.Test.MockHTTPClient, :post, fn _url, _body ->
        {:error, :timeout}
      end)
      
      # Assert behavior (error handling)
      assert {:error, :http_timeout} = Executor.execute(job)
    end
    
    test "validates job before execution", %{job: job} do
      invalid_job = %{job | name: nil}
      
      # Assert behavior: validation error
      assert {:error, :invalid_job} = Executor.execute(invalid_job)
    end
  end
end
```

### Summary: The Refactoring-Resistant Testing Matrix

| Feature | Strict Mocking (Recommended) | Targeted Mocking (Prohibited) |
| :--- | :--- | :--- |
| **Primary Focus** | Public Contract / Behavior | Internal Implementation |
| **Private Functions** | Ignored (Opaque Box) | Mocked / Spied / Tested Directly |
| **Refactoring Safety** | High (Implementation agnostic) | Low (Coupled to structure) |
| **Bug Detection** | High (Verifies logic integration) | Mixed (Misses integration issues) |
| **Maintenance Cost** | Low (Survives changes) | High (Requires updates on refactor) |
| **Architectural Impact** | Encourages Decoupling & DI | Encourages Tightly Coupled Code |

### Code Quality Metrics Summary

#### Target Metrics for This Project

| Metric | Target | Warning | Critical |
| :--- | :--- | :--- | :--- |
| **Test file length** | < 100 lines | 100-300 lines | > 300 lines |
| **Test (`test`) length** | < 10 lines | 10-20 lines | > 20 lines |
| **Describe nesting depth** | 2-3 levels | 4 levels | 5+ levels |
| **Shared setup length** | < 50 lines | 50-100 lines | > 100 lines |
| **Functions per module (lib/)** | < 10 | 10-20 | > 20 |
| **Lines per module (lib/)** | < 100 | 100-300 | > 300 |

#### When to Refactor

- **Split a test file** when it exceeds 300 lines or requires scrolling > 2 screens to find relevant setup code
- **Extract shared setup** when setup code is duplicated across 3+ test files
- **Split a module** when it exceeds 300 lines or has > 20 functions (applies to `lib/` code)
- **Simplify a test** when a `test` block exceeds 15 lines or tests multiple behaviors

### Coverage Goals

- Aim for comprehensive coverage of public APIs
- Test edge cases (empty lists, nil values, boundary conditions)
- Test error conditions and boundary cases
- Focus on behavior that matters to users of the library
- Use property-based testing (StreamData) where appropriate
- Maintain 95%+ test coverage

