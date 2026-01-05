# Contributing Guidelines

Thank you for your interest in contributing. We value **learning over perfection** but require **rigor and responsibility**.

## The Golden Rule of Automation

We welcome the use of AI and automation tools to reduce toil, but you must strictly adhere to the following:

1.  **You are the Author:** You act as the responsible agent for any code you submit. You must review, debug, and understand every line.

2.  **Manage Cognitive Load:** Do not submit massive, unreviewed automated dumps. Respect the reviewers' time by annotating complex logic.

3.  **Security:** Never feed project secrets or private context into public AI models.

## How to Contribute

### 1. Reporting Issues

* **Verify Accuracy:** Before posting, verify your information. Avoid generalizations.

* **Use Structured Inputs:** Use our Issue Templates to provide clear goals, constraints, and reproduction steps. This helps us understand the context immediately.

### 2. Pull Request Process

* **Scope:** Keep PRs focused on a single goal.

* **Context:** Explain *why* the change is necessary. Transparency builds trust.

* **Testing:** Run all smoke tests and regression checks locally. We prioritize "Safety First."

### 3. Review Process

* We encourage **productive friction**. Expect questions about your approach.

* If a reviewer suggests a change, view it as **mutual aid**, not criticism.

## Development Setup

```bash
# Install dependencies
mix deps.get

# Set up the database
mix test.setup

# Run tests
mix test

# Run quality checks
mix quality

# Format code
mix format

# Run code analysis
mix credo --strict

# Run type checking
mix dialyzer
```

## Quality Checks

Before submitting a PR, ensure all quality checks pass:

```bash
# Run all quality checks
mix quality

# Or run individually
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

## Testing

We aim for 95%+ test coverage. Please ensure:

- All new features have tests
- Edge cases are covered
- Integration tests for database operations
- Property-based tests where appropriate

