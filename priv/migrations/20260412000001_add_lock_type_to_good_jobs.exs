defmodule GoodJob.Migrations.AddLockTypeToGoodJobs do
  @moduledoc false

  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE good_jobs ADD COLUMN IF NOT EXISTS lock_type smallint;
    """
  end

  def down do
    execute """
    ALTER TABLE good_jobs DROP COLUMN IF EXISTS lock_type;
    """
  end
end
