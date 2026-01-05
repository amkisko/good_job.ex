[
  plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
  plt_add_apps: [:mix, :ex_unit, :ecto, :ecto_sql],
  flags: [
    :error_handling,
    :race_conditions,
    :underspecs,
    :unknown
  ]
]
