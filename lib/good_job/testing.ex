defmodule GoodJob.Testing do
  @moduledoc """
  Testing helpers for GoodJob.

  This module provides a unified interface to all testing utilities.
  It re-exports functions from specialized modules for convenience.

  ## Usage

      use GoodJob.Testing.JobCase  # For job-related tests
      use GoodJob.Testing.RepoCase # For database tests

      # Or import specific modules
      import GoodJob.Testing.Assertions
      import GoodJob.Testing.Helpers
  """

  # Re-export assertion functions for backward compatibility
  defdelegate assert_enqueued(job_module, args, opts \\ []), to: GoodJob.Testing.Assertions
  defdelegate assert_performed(job), to: GoodJob.Testing.Assertions
  defdelegate refute_enqueued(job_module, args \\ %{}, opts \\ []), to: GoodJob.Testing.Assertions
  defdelegate perform_jobs(job_module \\ nil), to: GoodJob.Testing.Helpers
end
